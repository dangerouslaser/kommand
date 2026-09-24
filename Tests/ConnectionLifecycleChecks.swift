// Standalone regression checks for the production AppState and KodiHost sources.
// Platform services are replaced below so these checks do not need an iOS runner,
// credentials, a Kodi server, or permission to create Live Activities.
import Foundation
import Synchronization

@main
struct ConnectionLifecycleChecks {
    static func main() async {
        let suite = "kommand.connection-checks.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        precondition(state.currentHost == nil)
        precondition(state.connectionState == .disconnected)

        let first = KodiHost(name: "First", address: "first.local")
        let second = KodiHost(name: "Second", address: "second.local")
        precondition(state.addHost(first, password: "initial-password"))
        precondition(state.currentHost?.id == first.id)
        precondition(state.client.password == "initial-password")
        let firstClient = state.client
        let firstRemote = state.remote
        let firstRevision = state.connectionRevision
        precondition(state.addHost(second))
        precondition(state.client === firstClient, "Adding an inactive host must preserve the session")
        precondition(!state.addHost(first, password: "duplicate-password"), "Duplicate hosts must not restart a session")
        precondition(KeychainService.getPassword(for: first.id) == "initial-password")

        seedPlayback(state)
        state.setDefaultHost(second)
        precondition(state.currentHost?.id == second.id)
        precondition(state.currentHost?.isDefault == true)
        precondition(state.client !== firstClient)
        precondition(state.remote !== firstRemote && firstRemote.stopped)
        precondition(state.connectionRevision != firstRevision)
        expectReset(state)
        // Wait for the asynchronous teardown contract, without network access.
        for _ in 0..<100 where !(await firstClient.cancelled) {
            await Task.yield()
        }
        let cancelled = await firstClient.cancelled
        precondition(cancelled)

        // All of these retain the same host ID. A no-field-change save models
        // a password-only update stored before the client takes its snapshot.
        let edits: [(inout KodiHost) -> Void] = [
            { $0.address = "edited.local" },
            { $0.httpPort = 8081 },
            { $0.tcpPort = 9091 },
            { $0.username = "new-user" },
            { _ in }
        ]
        for (index, edit) in edits.enumerated() {
            var host = state.currentHost!
            let oldClient = state.client
            let oldRemote = state.remote
            let oldRevision = state.connectionRevision
            seedPlayback(state)
            edit(&host)
            state.updateHost(host, password: index == edits.count - 1 ? "changed-password" : nil)
            precondition(state.currentHost == host)
            precondition(state.client !== oldClient)
            precondition(state.remote !== oldRemote && oldRemote.stopped)
            precondition(state.connectionRevision != oldRevision)
            precondition(state.client.host == host)
            if index == edits.count - 1 {
                precondition(state.client.password == "changed-password")
            }
            expectReset(state)
        }

        let currentClient = state.client
        var inactive = first
        inactive.username = "inactive-user"
        state.updateHost(inactive)
        precondition(state.client === currentClient, "Editing another host must preserve the session")

        // Delayed teardown from the old host must not clear the replacement's
        // synchronous intent configuration.
        await Task.yield()
        precondition(KodiConnectionManager.shared.client === state.client)
        precondition(KodiConnectionManager.shared.host == state.currentHost)
        precondition(KodiConnectionManager.shared.playerID == nil)

        state.deleteHost(state.currentHost!)
        precondition(state.currentHost?.id == first.id)
        precondition(state.client !== currentClient)
        state.deleteHost(state.currentHost!)
        precondition(state.currentHost == nil)
        precondition(state.connectionState == .disconnected)
        precondition(KodiConnectionManager.shared.host == nil)
        precondition(state.client.host == nil)

        // Persisted selection is configured at initialization, before any view task.
        precondition(state.addHost(first))
        precondition(state.addHost(second))
        state.setDefaultHost(second)
        let reloaded = AppState(defaults: defaults)
        precondition(reloaded.currentHost?.id == second.id)
        precondition(reloaded.client.host == reloaded.currentHost)
        precondition(reloaded.remote.appState === reloaded)
        print("PASS: initial load, add, switch, five same-ID edits, inactive edit, delete, and old-session teardown")
    }

    static func seedPlayback(_ state: AppState) {
        state.connectionState = .connected
        state.nowPlaying = NowPlayingItem()
        state.activePlayerId = 1
        state.volume = 12
        state.isMuted = true
        state.isCoreELEC = true
        state.serverCapabilities.supportsSuspend = true
        state.libraryUpdateSignal = Date()
    }

    static func expectReset(_ state: AppState) {
        precondition(state.connectionState == .connecting)
        precondition(state.nowPlaying == nil && state.activePlayerId == nil)
        precondition(state.volume == 100 && !state.isMuted)
        precondition(!state.isCoreELEC && !state.serverCapabilities.supportsSuspend)
        precondition(state.libraryUpdateSignal == nil)
    }
}

// Test doubles for AppState's side effects, not copies of its lifecycle logic.
actor KodiClient {
    nonisolated let host: KodiHost?
    nonisolated let password: String?
    private(set) var cancelled = false
    init(host: KodiHost? = nil) {
        self.host = host
        self.password = host.flatMap { KeychainService.getPassword(for: $0.id) }
    }
    func cancelInFlightWork() { cancelled = true }
}

final class RemoteViewModel {
    weak var appState: AppState?
    var stopped = false
    func configure(appState: AppState) { self.appState = appState }
    func stopPolling() { stopped = true }
}

struct NowPlayingItem {}

nonisolated enum KeychainService {
    private static let passwords = Mutex<[UUID: String]>([:])
    static func migrateFromUserDefaults(hostIds: [UUID]) {}
    static func deletePassword(for hostID: UUID) {
        passwords.withLock { $0[hostID] = nil }
    }
    static func setPassword(_ password: String, for hostID: UUID) {
        passwords.withLock { $0[hostID] = password }
    }
    static func getPassword(for hostID: UUID) -> String? {
        passwords.withLock { $0[hostID] }
    }
}

final class KodiConnectionManager {
    static let shared = KodiConnectionManager()
    var host: KodiHost?
    var client: KodiClient?
    var playerID: Int?
    func configure(host: KodiHost?, client: KodiClient) {
        self.host = host
        self.client = client
        playerID = nil
    }
}

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    func endActivity() {}
}
