//
//  WebSocketManager.swift
//  kodi.remote.xbmc
//

import Foundation

actor WebSocketManager {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var host: KodiHost?
    private(set) var connectionState: ConnectionState = .disconnected

    private var notificationContinuation: AsyncStream<JSONRPCNotification>.Continuation?
    private var reconnectTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?

    // Reconnection parameters
    private let maxReconnectAttempts = 5
    private let initialReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 30.0

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func connect(to host: KodiHost) -> AsyncStream<JSONRPCNotification> {
        self.host = host

        let stream = AsyncStream<JSONRPCNotification> { continuation in
            self.notificationContinuation = continuation

            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.disconnect()
                }
            }
        }

        Task {
            await establishConnection()
        }

        return stream
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        notificationContinuation?.finish()
        notificationContinuation = nil
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    // MARK: - Connection Management

    private func establishConnection() async {
        guard let host = host, let url = host.webSocketURL else {
            connectionState = .disconnected
            return
        }

        connectionState = .connecting

        var request = URLRequest(url: url)

        // Add basic auth if credentials exist
        if let username = host.username, !username.isEmpty {
            let password = KeychainHelper.getPassword(for: host.id) ?? ""
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Send ping to verify connection
        do {
            try await sendPing()
            connectionState = .connected
            startReceiveLoop()
        } catch {
            connectionState = .disconnected
            await handleDisconnection()
        }
    }

    private func sendPing() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webSocketTask?.sendPing { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func startReceiveLoop() {
        receiveTask = Task {
            await receiveMessages()
        }
    }

    private func receiveMessages() async {
        guard let task = webSocketTask else { return }

        while connectionState == .connected && !Task.isCancelled {
            do {
                let message = try await task.receive()

                switch message {
                case .string(let text):
                    await processMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await processMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                // Connection lost
                if !Task.isCancelled {
                    await handleDisconnection()
                }
                break
            }
        }
    }

    private func processMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }

        // Try to decode as notification (no id field)
        if let notification = try? JSONDecoder().decode(JSONRPCNotification.self, from: data) {
            notificationContinuation?.yield(notification)
        }
        // Ignore RPC responses (they have an id field) - we use HTTP for those
    }

    // MARK: - Reconnection

    private func handleDisconnection() async {
        guard connectionState == .connected || connectionState == .connecting else { return }

        webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
        webSocketTask = nil

        // Cancel any existing reconnect task before starting a new one
        reconnectTask?.cancel()

        reconnectTask = Task {
            var attempt = 1

            while attempt <= maxReconnectAttempts && !Task.isCancelled {
                connectionState = .reconnecting(attempt: attempt)

                let delay = min(
                    initialReconnectDelay * pow(2, Double(attempt - 1)),
                    maxReconnectDelay
                )

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                if Task.isCancelled { break }

                await establishConnection()

                if connectionState == .connected {
                    return // Successfully reconnected
                }

                attempt += 1
            }

            // Max attempts reached - give up
            connectionState = .disconnected
            notificationContinuation?.finish()
        }
    }
}
