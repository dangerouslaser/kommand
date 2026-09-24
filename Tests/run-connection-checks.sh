#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
checks_binary="$(mktemp /tmp/kommand-connection-checks.XXXXXX)"
trap 'rm -f "$checks_binary"' EXIT
xcrun swiftc -swift-version 6 -default-isolation MainActor -parse-as-library \
    kodi.remote.xbmc/Core/Models/KodiHost.swift \
    kodi.remote.xbmc/Core/State/AppState.swift \
    Tests/ConnectionLifecycleChecks.swift \
    -o "$checks_binary"
"$checks_binary"
xcrun swiftc -swift-version 6 -default-isolation MainActor -parse-as-library \
    kodi.remote.xbmc/Core/Models/KodiHost.swift \
    kodi.remote.xbmc/Core/Models/Movie.swift \
    kodi.remote.xbmc/Core/Models/TVShow.swift \
    kodi.remote.xbmc/Core/Models/Music.swift \
    kodi.remote.xbmc/Core/Models/PVR.swift \
    kodi.remote.xbmc/Core/Models/NowPlaying.swift \
    kodi.remote.xbmc/Core/Networking/JSONRPCModels.swift \
    kodi.remote.xbmc/Core/Networking/KodiClient.swift \
    kodi.remote.xbmc/Core/Networking/WebSocketManager.swift \
    kodi.remote.xbmc/Core/Utilities/KeychainService.swift \
    kodi.remote.xbmc/Core/Utilities/Log.swift \
    Tests/KodiClientCancellationChecks.swift \
    -o "$checks_binary"
"$checks_binary"
