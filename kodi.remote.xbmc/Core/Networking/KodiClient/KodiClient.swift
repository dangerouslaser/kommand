//
//  KodiClient.swift
//  kodi.remote.xbmc
//

import Foundation
import os

actor KodiClient {
    private let host: KodiHost?
    private let password: String?
    private var session: URLSession
    private var requestId: Int = 0
    private var webSocketManager: WebSocketManager?
    private var isCancelled = false

    init(host: KodiHost? = nil, password: String? = nil) {
        self.host = host
        self.password = password ?? host.flatMap { KeychainService.getPassword(for: $0.id) }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection

    func testConnection() async throws -> Bool {
        let _: String = try await send(method: "JSONRPC.Ping")
        return true
    }

    // MARK: - WebSocket

    func connectWebSocket() async -> AsyncStream<JSONRPCNotification>? {
        guard !isCancelled, !Task.isCancelled, let host else { return nil }
        let manager = WebSocketManager()
        let previousManager = webSocketManager
        webSocketManager = manager
        await previousManager?.disconnect()
        guard !isCancelled, !Task.isCancelled, webSocketManager === manager else { return nil }
        let stream = await manager.connect(to: host, password: password)
        guard !isCancelled, !Task.isCancelled, webSocketManager === manager else {
            await manager.disconnect()
            return nil
        }
        return stream
    }

    func disconnectWebSocket() async {
        let manager = webSocketManager
        webSocketManager = nil
        await manager?.disconnect()
    }

    /// Cancel any in-flight HTTP requests and tear down the WebSocket. Use when
    /// discarding a client (e.g. before replacing it with a new one) so background
    /// requests don't continue against a host that nothing is listening for.
    /// Named `cancelInFlightWork` (not `shutdown`) to avoid colliding with the
    /// `shutdown()` method that issues `System.Shutdown` to Kodi.
    func cancelInFlightWork() async {
        isCancelled = true
        session.invalidateAndCancel()
        await disconnectWebSocket()
    }

    var isWebSocketConnected: Bool {
        get async {
            await webSocketManager?.isConnected ?? false
        }
    }

    // MARK: - JSON-RPC

    private func nextRequestId() -> Int {
        requestId += 1
        return requestId
    }

    func send<T: Decodable & Sendable>(method: String, params: [String: Any] = [:]) async throws -> T {
        try Task.checkCancellation()
        guard !isCancelled else { throw CancellationError() }
        guard let host = host, let url = host.jsonRPCURL else {
            throw KodiError.notConnected
        }

        let request = JSONRPCRequest(method: method, params: params, id: nextRequestId())
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let username = host.username, !username.isEmpty {
            let credentials = "\(username):\(password ?? "")"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                urlRequest.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try Task.checkCancellation()
        guard !isCancelled else { throw CancellationError() }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KodiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            Logger.networking.error("HTTP \(httpResponse.statusCode) from \(request.method, privacy: .public)")
            throw KodiError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let rpcResponse = try decoder.decode(JSONRPCResponse<T>.self, from: data)

        if let error = rpcResponse.error {
            throw KodiError.rpcError(error.code, error.message)
        }

        guard let result = rpcResponse.result else {
            // Some methods return empty result
            if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
                return empty
            }
            throw KodiError.noResult
        }

        return result
    }
}

nonisolated struct EmptyResponse: Decodable, Sendable {}

// MARK: - Errors

nonisolated enum KodiError: LocalizedError, Sendable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case rpcError(Int, String)
    case noResult
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Kodi"
        case .invalidResponse:
            return "Invalid response from Kodi"
        case .httpError(let code):
            switch code {
            case 401: return "Authentication failed (HTTP 401) — check the username and password for this host"
            case 403: return "Access forbidden (HTTP 403) — Kodi rejected the credentials"
            case 404: return "Not found (HTTP 404) — JSON-RPC endpoint missing or wrong port"
            case 500...599: return "Kodi server error (HTTP \(code))"
            default: return "HTTP error \(code)"
            }
        case .rpcError(let code, let message):
            return "RPC error \(code): \(message)"
        case .noResult:
            return "No result returned"
        case .timeout:
            return "Connection timed out"
        }
    }
}
