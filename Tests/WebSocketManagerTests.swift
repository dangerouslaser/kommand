import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestFailure(description: message) }
}

private func eventually(_ message: String, _ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !(await condition()) {
        guard ContinuousClock.now < deadline else { throw TestFailure(description: message) }
        await Task.yield()
    }
}

/// Tests advance individual sleeps explicitly; no backoff or ping deadline uses wall time.
private actor ManualClock {
    private var sleepers: [UUID: (delay: TimeInterval, continuation: CheckedContinuation<Void, Error>)] = [:]

    func sleep(_ delay: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                sleepers[id] = (delay, continuation)
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    private func cancel(_ id: UUID) {
        sleepers.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
    }

    func contains(_ delay: TimeInterval) -> Bool {
        sleepers.values.contains { $0.delay == delay }
    }

    var isEmpty: Bool { sleepers.isEmpty }

    func advance(_ delay: TimeInterval) {
        for id in sleepers.filter({ $0.value.delay == delay }).keys {
            sleepers.removeValue(forKey: id)?.continuation.resume()
        }
    }
}

private final class FakeSocket: WebSocketConnection, @unchecked Sendable {
    enum PingReply { case success, failure, silent }
    private let reply: PingReply
    private let lock = NSLock()
    private var callback: (@Sendable (Error?) -> Void)?
    private var cancellations = 0
    private let messages: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
    private let continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation

    init(_ reply: PingReply) {
        self.reply = reply
        (messages, continuation) = AsyncThrowingStream.makeStream()
    }

    var wasPinged: Bool { lock.withLock { callback != nil } }
    var wasCancelled: Bool { lock.withLock { cancellations > 0 } }

    func resume() {}

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        lock.withLock { cancellations += 1 }
        continuation.finish(throwing: URLError(.cancelled))
        // Deliberately do not invoke the ping callback, even during cancellation.
    }

    func sendPing(pongReceiveHandler: @escaping @Sendable (Error?) -> Void) {
        lock.withLock { callback = pongReceiveHandler }
        switch reply {
        case .success: pongReceiveHandler(nil)
        case .failure: pongReceiveHandler(URLError(.cannotConnectToHost))
        case .silent: break
        }
    }

    func finishPing(_ error: Error? = nil) {
        lock.withLock { callback }?(error)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        var iterator = messages.makeAsyncIterator()
        guard let message = try await iterator.next() else { throw URLError(.networkConnectionLost) }
        return message
    }

    func notify() {
        continuation.yield(.string(#"{"jsonrpc":"2.0","method":"Player.OnPlay"}"#))
    }

    func failReceive() {
        continuation.finish(throwing: URLError(.networkConnectionLost))
    }
}

private final class SocketFactory: @unchecked Sendable {
    private let lock = NSLock()
    private let sockets: [FakeSocket]
    private var index = 0
    private var authorization: String?

    init(_ sockets: [FakeSocket]) { self.sockets = sockets }
    var count: Int { lock.withLock { index } }
    var lastAuthorization: String? { lock.withLock { authorization } }

    func makeSocket(_ request: URLRequest) -> any WebSocketConnection {
        lock.withLock {
            authorization = request.value(forHTTPHeaderField: "Authorization")
            let socket = sockets[min(index, sockets.count - 1)]
            index += 1
            return socket
        }
    }
}

private actor StreamProbe {
    var finished = false
    var methods: [String] = []

    func consume(_ stream: AsyncStream<JSONRPCNotification>) async {
        for await notification in stream { methods.append(notification.method) }
        finished = true
    }
}

@main
private struct WebSocketManagerTests {
    static let host = KodiHost(name: "Test", address: "127.0.0.1")

    static func main() async throws {
        try await exhaustedRetriesFinishStream()
        try await successfulReconnectResetsRetryBudget()
        try await missingPingCallbackTimesOut()
        try await replacementIgnoresOldCompletion()
        try await cancellingConsumerStopsBackoff()
        try await invalidURLFinishesStream()
        try await suppliedPasswordUsed()
        print("PASS: 7 WebSocketManager regression tests")
    }

    private static func manager(_ factory: SocketFactory, _ clock: ManualClock) -> WebSocketManager {
        WebSocketManager(makeSocket: { factory.makeSocket($0) }, sleep: { try await clock.sleep($0) })
    }

    private static func waitForBackoff(_ manager: WebSocketManager, _ clock: ManualClock, attempt: Int) async throws {
        let delay = pow(2.0, Double(attempt - 1))
        try await eventually("Missing reconnect attempt \(attempt)") {
            let state = await manager.connectionState
            let sleeping = await clock.contains(delay)
            return state == .reconnecting(attempt: attempt) && sleeping
        }
    }

    private static func exhaustedRetriesFinishStream() async throws {
        let clock = ManualClock()
        let sockets = (0..<6).map { _ in FakeSocket(.failure) }
        let factory = SocketFactory(sockets)
        let manager = manager(factory, clock)
        let stream = await manager.connect(to: host)
        let probe = StreamProbe()
        let consumer = Task { await probe.consume(stream) }

        for attempt in 1...5 {
            try await waitForBackoff(manager, clock, attempt: attempt)
            try require(factory.count == attempt, "Retry spawned extra sockets")
            await clock.advance(pow(2.0, Double(attempt - 1)))
        }

        try await eventually("Exhausted retries did not finish the stream") { await probe.finished }
        try require(await manager.connectionState == .disconnected, "Exhaustion must disconnect")
        try require(factory.count == 6, "Expected initial connection and five retries")
        try require(sockets.allSatisfy(\.wasCancelled), "Every failed socket must be cancelled")
        await consumer.value
    }

    private static func successfulReconnectResetsRetryBudget() async throws {
        let clock = ManualClock()
        let first = FakeSocket(.failure)
        let second = FakeSocket(.silent)
        let third = FakeSocket(.success)
        let factory = SocketFactory([first, second, third])
        let manager = manager(factory, clock)
        let stream = await manager.connect(to: host)
        let probe = StreamProbe()
        let consumer = Task { await probe.consume(stream) }

        try await waitForBackoff(manager, clock, attempt: 1)
        await clock.advance(1)
        try await eventually("Retry did not ping") { second.wasPinged }
        try require(await manager.connectionState == .reconnecting(attempt: 1), "Retry should stay reconnecting until verified")
        second.finishPing()
        try await eventually("Retry did not connect") { await manager.isConnected }
        second.notify()
        try await eventually("Notification was not delivered") { await probe.methods == ["Player.OnPlay"] }
        second.failReceive()
        try await waitForBackoff(manager, clock, attempt: 1)
        await clock.advance(1)
        try await eventually("Receive failure did not reconnect") { await manager.isConnected }
        try require(factory.count == 3, "Receive failure must create a new socket")
        await manager.disconnect()
        await consumer.value
    }

    private static func missingPingCallbackTimesOut() async throws {
        let clock = ManualClock()
        let silent = FakeSocket(.silent)
        let healthy = FakeSocket(.success)
        let factory = SocketFactory([silent, healthy])
        let manager = manager(factory, clock)
        let stream = await manager.connect(to: host)
        let probe = StreamProbe()
        let consumer = Task { await probe.consume(stream) }

        try await eventually("Ping timer was not started") { await clock.contains(5) }
        await clock.advance(5)
        try await waitForBackoff(manager, clock, attempt: 1)
        try require(silent.wasCancelled, "Timed out socket was not closed")
        await clock.advance(1)
        try await eventually("Timeout did not permit reconnection") { await manager.isConnected }
        silent.finishPing(URLError(.timedOut))
        healthy.notify()
        try await eventually("Late ping callback interrupted replacement socket") { await probe.methods.count == 1 }
        try require(await manager.isConnected, "Late timeout changed connection state")
        await manager.disconnect()
        await consumer.value
    }

    private static func replacementIgnoresOldCompletion() async throws {
        let clock = ManualClock()
        let old = FakeSocket(.silent)
        let replacement = FakeSocket(.success)
        let factory = SocketFactory([old, replacement])
        let manager = manager(factory, clock)
        let oldStream = await manager.connect(to: host)
        let oldProbe = StreamProbe()
        let oldConsumer = Task { await oldProbe.consume(oldStream) }
        try await eventually("Initial ping did not start") { old.wasPinged }

        let newStream = await manager.connect(to: host)
        let newProbe = StreamProbe()
        let newConsumer = Task { await newProbe.consume(newStream) }
        try await eventually("Replacement was disconnected by old stream termination") { await manager.isConnected }
        try await eventually("Previous stream was not finished") { await oldProbe.finished }
        try require(old.wasCancelled, "Previous socket was not cancelled")
        old.finishPing()
        replacement.notify()
        try await eventually("Replacement notification missing") { await newProbe.methods.count == 1 }
        await manager.disconnect()
        await oldConsumer.value
        await newConsumer.value
        try await eventually("Ping timeout leaked after disconnect") { await clock.isEmpty }
        try require(await manager.connectionState == .disconnected, "Disconnect must be final")
    }

    private static func cancellingConsumerStopsBackoff() async throws {
        let clock = ManualClock()
        let factory = SocketFactory([FakeSocket(.failure)])
        let manager = manager(factory, clock)
        let stream = await manager.connect(to: host)
        let probe = StreamProbe()
        let consumer = Task { await probe.consume(stream) }
        try await waitForBackoff(manager, clock, attempt: 1)
        consumer.cancel()
        await consumer.value
        try await eventually("Consumer cancellation did not disconnect") { await manager.connectionState == .disconnected }
        try await eventually("Cancelled backoff is still suspended") { await clock.isEmpty }
        await clock.advance(1)
        try require(factory.count == 1, "Cancelled backoff created another socket")
    }

    private static func invalidURLFinishesStream() async throws {
        let clock = ManualClock()
        let factory = SocketFactory([FakeSocket(.success)])
        let manager = manager(factory, clock)
        let invalid = KodiHost(name: "Invalid", address: "[invalid")
        try require(invalid.webSocketURL == nil, "Invalid URL fixture is valid")
        let stream = await manager.connect(to: invalid)
        var iterator = stream.makeAsyncIterator()
        try require(await iterator.next() == nil, "Invalid URL must finish the stream")
        try require(factory.count == 0, "Invalid URL must not create a socket")
    }

    private static func suppliedPasswordUsed() async throws {
        let clock = ManualClock()
        let factory = SocketFactory([FakeSocket(.success), FakeSocket(.success)])
        let manager = manager(factory, clock)
        let authenticatedHost = KodiHost(name: "Authenticated", address: "127.0.0.1", username: "kodi")
        for password in ["session-password", ""] {
            let stream = await manager.connect(to: authenticatedHost, password: password)
            let probe = StreamProbe()
            let consumer = Task { await probe.consume(stream) }
            try await eventually("Authenticated socket did not connect") { await manager.isConnected }
            let expected = "Basic " + Data("kodi:\(password)".utf8).base64EncodedString()
            try require(factory.lastAuthorization == expected, "Socket ignored the supplied session password")
            await manager.disconnect()
            await consumer.value
        }
    }
}
