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
