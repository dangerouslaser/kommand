import Foundation
import XCTest
@testable import kodi_remote_xbmc

final class KodiHostTests: XCTestCase {
    private let id = UUID(uuidString: "225F9054-05A2-4ED4-B225-34BCA5E8CCED")!

    func testEndpointURLsUseConfiguredAddressAndPorts() {
        let host = KodiHost(
            id: id,
            name: "Den",
            address: "kodi.local",
            httpPort: 8181,
            tcpPort: 9191
        )

        XCTAssertEqual(host.httpBaseURL?.absoluteString, "http://kodi.local:8181")
        XCTAssertEqual(host.jsonRPCURL?.absoluteString, "http://kodi.local:8181/jsonrpc")
        XCTAssertEqual(host.webSocketURL?.absoluteString, "ws://kodi.local:9191/jsonrpc")
    }

    func testImageURLPercentEncodesKodiPathAsOneComponent() {
        let host = KodiHost(id: id, name: "Den", address: "192.168.1.20", httpPort: 8080)

        let url = host.imageURL(for: "image://Movies/Alien & Aliens/poster #1.jpg/")

        XCTAssertEqual(
            url?.absoluteString,
            "http://192.168.1.20:8080/image/image%3A%2F%2FMovies%2FAlien%20%26%20Aliens%2Fposter%20%231.jpg%2F"
        )
    }

    func testImageURLPreservesRFC3986UnreservedCharacters() {
        let host = KodiHost(id: id, name: "Den", address: "kodi.local")

        let url = host.imageURL(for: "image://a-Z_0.9~cover/")

        XCTAssertEqual(
            url?.absoluteString,
            "http://kodi.local:8080/image/image%3A%2F%2Fa-Z_0.9~cover%2F"
        )
    }

    func testEmptyImagePathProducesNoURL() {
        let host = KodiHost(id: id, name: "Den", address: "kodi.local")

        XCTAssertNil(host.imageURL(for: ""))
    }

    func testCodableRoundTripPreservesHostIdentityAndCredentialsMetadata() throws {
        let host = KodiHost(
            id: id,
            name: "Living Room",
            address: "10.0.0.5",
            httpPort: 18080,
            tcpPort: 19090,
            username: "remote",
            macAddress: "AA:BB:CC:DD:EE:FF",
            isDefault: true
        )

        let decoded = try JSONDecoder().decode(KodiHost.self, from: JSONEncoder().encode(host))

        XCTAssertEqual(decoded, host)
    }
}
