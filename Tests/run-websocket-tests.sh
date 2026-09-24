#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d /tmp/kommand-websocket-tests.XXXXXX)"
trap 'if [[ -f "$test_directory/WebSocketManagerTests" ]]; then rm "$test_directory/WebSocketManagerTests"; fi; rmdir "$test_directory"' EXIT

xcrun swiftc -swift-version 6 -parse-as-library \
    "$repo_root/kodi.remote.xbmc/Core/Networking/WebSocketManager.swift" \
    "$repo_root/kodi.remote.xbmc/Core/Networking/JSONRPCModels.swift" \
    "$repo_root/kodi.remote.xbmc/Core/Models/KodiHost.swift" \
    "$repo_root/kodi.remote.xbmc/Core/Utilities/KeychainService.swift" \
    "$repo_root/Tests/WebSocketManagerTests.swift" \
    -o "$test_directory/WebSocketManagerTests"

"$test_directory/WebSocketManagerTests"
