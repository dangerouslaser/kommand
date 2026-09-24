//
//  WebSocketManager.swift
//  kodi.remote.xbmc
//

import Foundation

/// The small transport surface also lets connection failures be tested without a server.
nonisolated protocol WebSocketConnection: Sendable {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func sendPing(pongReceiveHandler: @escaping @Sendable (Error?) -> Void)
    func receive() async throws -> URLSessionWebSocketTask.Message
}

extension URLSessionWebSocketTask: WebSocketConnection {}

actor WebSocketManager {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    private var webSocketTask: (any WebSocketConnection)?
    private let session: URLSession
    private let makeSocket: @Sendable (URLRequest) -> any WebSocketConnection
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private(set) var connectionState: ConnectionState = .disconnected

    private var notificationContinuation: AsyncStream<JSONRPCNotification>.Continuation?
    private var connectionTask: Task<Void, Never>?
    private var connectionID = UUID()
    private var pendingPing: (id: UUID, continuation: CheckedContinuation<Void, Error>)?
    private var pingTimeoutTask: Task<Void, Never>?

    private let maxReconnectAttempts = 5
    private let initialReconnectDelay: TimeInterval = 1
    private let maxReconnectDelay: TimeInterval = 30
    private let pingTimeout: TimeInterval = 5

    init(
        makeSocket: (@Sendable (URLRequest) -> any WebSocketConnection)? = nil,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { delay in
            try await Task.sleep(for: .seconds(delay))
        }
    ) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        self.session = session
        self.makeSocket = makeSocket ?? { session.webSocketTask(with: $0) }
        self.sleep = sleep
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: - Public API

    func connect(to host: KodiHost, password: String? = nil) -> AsyncStream<JSONRPCNotification> {
        teardown()
        let id = connectionID

        let stream = AsyncStream<JSONRPCNotification> { continuation in
            notificationContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.disconnect(connectionID: id) }
            }
        }

        guard let url = host.webSocketURL else {
            teardown()
            return stream
        }

        var request = URLRequest(url: url)
        if let username = host.username, !username.isEmpty {
            let password = password ?? KeychainService.getPassword(for: host.id) ?? ""
            let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        connectionState = .connecting
        connectionTask = Task { await runConnection(request: request, connectionID: id) }
        return stream
    }

    func disconnect() {
        teardown()
    }

    private func disconnect(connectionID id: UUID) {
        guard id == connectionID else { return }
        teardown()
    }

    private func teardown() {
        // Invalidate suspended work and old stream termination handlers before resuming it.
        connectionID = UUID()
        connectionTask?.cancel()
        connectionTask = nil
        if let ping = pendingPing {
            completePing(id: ping.id, result: .failure(CancellationError()))
        }
        closeSocket()
        connectionState = .disconnected
        let continuation = notificationContinuation
        notificationContinuation = nil
        continuation?.finish()
    }

    private func closeSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    // MARK: - Connection state machine

    private func runConnection(request: URLRequest, connectionID id: UUID) async {
        var attempt = 0

        // One task owns initial connection, receiving, and all subsequent retries.
        while id == connectionID && !Task.isCancelled {
            do {
                if attempt > 0 {
                    connectionState = .reconnecting(attempt: attempt)
                    let delay = min(initialReconnectDelay * pow(2, Double(attempt - 1)), maxReconnectDelay)
                    try await sleep(delay)
                    try Task.checkCancellation()
                    guard id == connectionID else { return }
                }

                let socket = makeSocket(request)
                webSocketTask = socket
                socket.resume()
                try await sendPing(on: socket)
                try Task.checkCancellation()
                guard id == connectionID else { return }

                connectionState = .connected
                attempt = 0
                try await receiveMessages(on: socket, connectionID: id)
                return
            } catch {
                guard id == connectionID, !Task.isCancelled else { return }
                closeSocket()
                guard attempt < maxReconnectAttempts else {
                    // Finishing the stream tells RemoteViewModel to start HTTP polling.
                    teardown()
                    return
                }
                attempt += 1
            }
        }
    }

    private func sendPing(on socket: any WebSocketConnection) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                pendingPing = (id, continuation)
                pingTimeoutTask = Task { [weak self, sleep, pingTimeout] in
                    do {
                        try await sleep(pingTimeout)
                        try Task.checkCancellation()
                    } catch {
                        return
                    }
                    await self?.completePing(id: id, result: .failure(URLError(.timedOut)))
                }
                socket.sendPing { [weak self] error in
                    let result: Result<Void, Error> = error.map { .failure($0) } ?? .success(())
                    Task { await self?.completePing(id: id, result: result) }
                }
            }
        } onCancel: {
            Task { await self.completePing(id: id, result: .failure(CancellationError())) }
        }
    }

    private func completePing(id: UUID, result: Result<Void, Error>) {
        guard let ping = pendingPing, ping.id == id else { return }
        pendingPing = nil
        pingTimeoutTask?.cancel()
        pingTimeoutTask = nil
        // The callback, timeout, and cancellation all race through this one-shot gate.
        // No task group waits for a callback that URLSession might never deliver.
        ping.continuation.resume(with: result)
    }

    private func receiveMessages(on socket: any WebSocketConnection, connectionID id: UUID) async throws {
        while id == connectionID && !Task.isCancelled {
            let message = try await socket.receive()
            try Task.checkCancellation()
            guard id == connectionID else { return }

            let data: Data
            switch message {
            case .string(let text):
                data = Data(text.utf8)
            case .data(let receivedData):
                data = receivedData
            @unknown default:
                continue
            }
            if let notification = try? JSONDecoder().decode(JSONRPCNotification.self, from: data) {
                notificationContinuation?.yield(notification)
            }
        }
    }
}
