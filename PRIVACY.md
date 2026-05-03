# Privacy Policy

**Last updated: May 3, 2026**

Kommand is a native iOS remote control app for the open-source Kodi media center. This policy describes what data Kommand handles and how. The short version: Kommand does not collect, transmit, or share any personal data. All connections are made directly from your device to the Kodi server you configure.

## Data Kommand Stores On Your Device

Kommand stores the following information locally on your iPhone or iPad so it can connect to your Kodi server:

- **Kodi host configuration** — display name, IP address or hostname, HTTP port, TCP/WebSocket port, username, and (optionally) the device's MAC address for Wake-on-LAN.
- **Kodi passwords** — stored in the iOS Keychain with App Group access so the Kommand app and its Live Activity widget can both read them. Passwords are never written to any other location.
- **App preferences** — your selected theme, color scheme, haptic settings, tab visibility, sort and filter choices, and similar UI options.
- **Cached artwork** — movie posters, fan art, TV show stills, and album art fetched from your Kodi server are cached on disk under `Library/Caches/KodiArtwork/`. Items older than 7 days are automatically pruned at app launch.
- **Cached library metadata** — titles, descriptions, ratings, and similar metadata are cached on disk under `Library/Caches/KodiLibrary/` so the app can show your library quickly when offline or while it refreshes.

All of this data lives only on your device. Deleting the app removes it.

## Data Kommand Does Not Collect

Kommand does **not**:

- Collect or transmit any analytics, telemetry, crash reports, advertising IDs, location data, contacts, photos, or any other personal information.
- Use third-party SDKs, ad networks, or analytics providers. The app has zero external dependencies.
- Require an account, sign-in, or registration of any kind.
- Communicate with any server operated by the developer or by Anthropic.
- Sync data to iCloud or any other cloud service.

## Network Activity

The only network traffic Kommand initiates is direct communication with the Kodi server(s) you have configured, on your local network. This includes:

- HTTP JSON-RPC requests to control Kodi and fetch library data.
- A WebSocket connection to receive real-time playback notifications.
- HTTP requests to download artwork from your Kodi server for caching.

Kommand connects only to addresses you have explicitly added in Settings. It does not contact any other server, including the developer's.

## Children's Privacy

Kommand does not knowingly collect personal information from anyone, including children under 13.

## Changes to This Policy

If material changes are made to this policy, the "Last updated" date at the top of this document will be revised. Because Kommand collects no data, changes are expected to be rare.

## Contact

Questions about this policy can be sent to:

**Bryan Hoban**
bryan.hoban@gmail.com
