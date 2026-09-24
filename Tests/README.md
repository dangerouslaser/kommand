# WebSocket regression tests

Run `bash Tests/run-websocket-tests.sh` from the repository root on a Mac with Xcode.
The runner compiles the production manager, JSON-RPC models, host model, and keychain
service with Swift 6, then runs seven asynchronous regression tests without adding
an Xcode test target. It removes its temporary executable when finished.

Fake sockets and a manually advanced clock cover initial failure and retry exhaustion,
receive failure after a successful reconnect, a ping callback that never arrives,
late callbacks and stream termination after replacement, cancellation during backoff,
an invalid URL, and explicit session passwords (including an empty password).
The five-second observation deadline only prevents a broken test from hanging;
all connection timeouts and reconnect delays are advanced explicitly.

# Connection lifecycle checks

Run `sh Tests/run-connection-checks.sh` on a Mac with Xcode selected. These checks compile with Swift 6 and default MainActor isolation and leave no test executable behind.

`ConnectionLifecycleChecks.swift` compiles the production `AppState` and `KodiHost` with platform-service doubles. It checks initial configuration, credential-save ordering, switching, same-ID endpoint/port/username/password edits, inactive-host edits, state reset, deletion, and old-client teardown. `KodiClientCancellationChecks.swift` compiles the actual networking implementation and verifies that a disposed client cannot issue HTTP requests or open a WebSocket.

These checks do not exercise SwiftUI view identity, actual Kodi traffic, or ActivityKit. Before release, use two Kodi hosts to verify:

- Switching while a request is pending resets playback, volume, libraries, and detail navigation; commands and notifications use the selected host.
- Editing the selected host's address, HTTP/TCP ports, username, or only its password reconnects without visiting the Remote tab.
- Rapid A → B → A switching and deleting the last host leave no prior-host playback or Live Activity state.
- Remote monitoring continues when switching app tabs and refreshes on return from the background.
