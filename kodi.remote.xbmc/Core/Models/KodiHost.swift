//
//  KodiHost.swift
//  kodi.remote.xbmc
//

import Foundation

struct KodiHost: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var httpPort: Int
    var tcpPort: Int
    var username: String?
    var macAddress: String?
    var isDefault: Bool

    // Password stored separately in Keychain

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        httpPort: Int = 8080,
        tcpPort: Int = 9090,
        username: String? = nil,
        macAddress: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.httpPort = httpPort
        self.tcpPort = tcpPort
        self.username = username
        self.macAddress = macAddress
        self.isDefault = isDefault
    }

    var httpBaseURL: URL? {
        URL(string: "http://\(address):\(httpPort)")
    }

    var jsonRPCURL: URL? {
        httpBaseURL?.appendingPathComponent("jsonrpc")
    }

    var webSocketURL: URL? {
        URL(string: "ws://\(address):\(tcpPort)/jsonrpc")
    }

    func imageURL(for kodiImagePath: String) -> URL? {
        guard !kodiImagePath.isEmpty else { return nil }

        // Kodi returns paths like: image://path/to/image.jpg/
        // We need to transform to: http://host:port/image/image%3A%2F%2Fpath%2Fto%2Fimage.jpg%2F
        // The entire Kodi image path must be percent-encoded as a single path component

        // Use a custom character set that encodes everything except alphanumerics
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~") // Keep these per RFC 3986

        guard let encodedPath = kodiImagePath.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }

        return URL(string: "http://\(address):\(httpPort)/image/\(encodedPath)")
    }
}

// MARK: - Preview Helper

extension KodiHost {
    static let preview = KodiHost(
        name: "Living Room Kodi",
        address: "192.168.1.100",
        httpPort: 8080,
        tcpPort: 9090,
        isDefault: true
    )
}
