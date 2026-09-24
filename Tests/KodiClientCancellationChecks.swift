import Foundation

@main
struct KodiClientCancellationChecks {
    static func main() async {
        let host = KodiHost(name: "Canceled session", address: "127.0.0.1", httpPort: 1)
        let client = KodiClient(host: host, password: "")
        await client.cancelInFlightWork()
        // A disposed session must remain sealed even if an old task starts later.
        do {
            _ = try await client.testConnection()
            preconditionFailure("Disposed clients must reject new HTTP requests")
        } catch is CancellationError {
            // Expected before URLSession is consulted.
        } catch {
            preconditionFailure("Expected cancellation, received \(error)")
        }
        let stream = await client.connectWebSocket()
        precondition(stream == nil, "Disposed clients must not open new sockets")
        let connected = await client.isWebSocketConnected
        precondition(!connected)
        await client.cancelInFlightWork() // Disposal is idempotent.
        print("PASS: disposed KodiClient rejects HTTP and WebSocket work")
    }
}
