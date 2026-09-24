import Foundation
import XCTest
@testable import kodi_remote_xbmc

final class JSONRPCModelsTests: XCTestCase {
    func testRequestEncodesJSONRPCEnvelopeAndNestedParameters() throws {
        let request = JSONRPCRequest(
            method: "Player.Open",
            params: [
                "item": ["movieid": 42],
                "options": ["resume": true],
                "labels": ["one", "two"],
            ],
            id: 7
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )

        XCTAssertEqual(object["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(object["method"] as? String, "Player.Open")
        XCTAssertEqual(object["id"] as? Int, 7)

        let params = try XCTUnwrap(object["params"] as? [String: Any])
        let item = try XCTUnwrap(params["item"] as? [String: Any])
        let options = try XCTUnwrap(params["options"] as? [String: Any])
        XCTAssertEqual(item["movieid"] as? Int, 42)
        XCTAssertEqual(options["resume"] as? Bool, true)
        XCTAssertEqual(params["labels"] as? [String], ["one", "two"])
    }

    func testAnyCodableRoundTripsSupportedJSONValues() throws {
        let source: [String: AnyCodable] = [
            "null": AnyCodable(NSNull()),
            "bool": AnyCodable(true),
            "int": AnyCodable(12),
            "double": AnyCodable(2.5),
            "string": AnyCodable("Kodi"),
            "array": AnyCodable([1, "two", false] as [Any]),
            "object": AnyCodable(["nested": "value"] as [String: Any]),
        ]

        let decoded = try JSONDecoder().decode(
            [String: AnyCodable].self,
            from: JSONEncoder().encode(source)
        )

        XCTAssertTrue(decoded["null"]?.value is NSNull)
        XCTAssertEqual(decoded["bool"]?.value as? Bool, true)
        XCTAssertEqual(decoded["int"]?.value as? Int, 12)
        XCTAssertEqual(decoded["double"]?.value as? Double, 2.5)
        XCTAssertEqual(decoded["string"]?.value as? String, "Kodi")

        let array = try XCTUnwrap(decoded["array"]?.value as? [Any])
        XCTAssertEqual(array[0] as? Int, 1)
        XCTAssertEqual(array[1] as? String, "two")
        XCTAssertEqual(array[2] as? Bool, false)

        let object = try XCTUnwrap(decoded["object"]?.value as? [String: Any])
        XCTAssertEqual(object["nested"] as? String, "value")
    }

    func testResponseDecodesSuccessfulResultEnvelope() throws {
        let data = Data(#"{"jsonrpc":"2.0","id":18,"result":{"volume":73,"muted":false}}"#.utf8)

        let response = try JSONDecoder().decode(JSONRPCResponse<VolumeResponse>.self, from: data)

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, 18)
        XCTAssertEqual(response.result?.volume, 73)
        XCTAssertEqual(response.result?.muted, false)
        XCTAssertNil(response.error)
    }

    func testResponseDecodesErrorEnvelopeAndDiagnosticData() throws {
        let data = Data(
            #"{"jsonrpc":"2.0","id":3,"error":{"code":-32602,"message":"Invalid params.","data":{"method":"Player.Open","stack":[1,"frame"]}}}"#.utf8
        )

        let response = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

        XCTAssertNil(response.result)
        XCTAssertEqual(response.error?.code, -32602)
        XCTAssertEqual(response.error?.message, "Invalid params.")
        let diagnostic = try XCTUnwrap(response.error?.data?.value as? [String: Any])
        XCTAssertEqual(diagnostic["method"] as? String, "Player.Open")
        let stack = try XCTUnwrap(diagnostic["stack"] as? [Any])
        XCTAssertEqual(stack[0] as? Int, 1)
        XCTAssertEqual(stack[1] as? String, "frame")
    }

    func testNotificationDecodesOptionalSenderAndData() throws {
        let data = Data(
            #"{"jsonrpc":"2.0","method":"Player.OnPause","params":{"sender":"xbmc","data":{"player":{"playerid":1}}}}"#.utf8
        )

        let notification = try JSONDecoder().decode(JSONRPCNotification.self, from: data)

        XCTAssertEqual(notification.method, KodiNotification.playerOnPause.rawValue)
        XCTAssertEqual(notification.params?.sender, "xbmc")
        let payload = try XCTUnwrap(notification.params?.data?.value as? [String: Any])
        let player = try XCTUnwrap(payload["player"] as? [String: Any])
        XCTAssertEqual(player["playerid"] as? Int, 1)
    }

    func testPlayerTimeIncludesMilliseconds() throws {
        let data = Data(#"{"hours":1,"minutes":2,"seconds":3,"milliseconds":450}"#.utf8)

        let time = try JSONDecoder().decode(PlayerPropertiesResponse.TimeInfo.self, from: data)

        XCTAssertEqual(time.totalSeconds, 3723.45, accuracy: 0.000_1)
    }

    func testMediaItemPrefersArtPosterIncludingKodiDottedKey() throws {
        let data = Data(
            #"{"item":{"id":2,"type":"episode","label":"Episode","thumbnail":"thumb.jpg","fanart":"fanart.jpg","art":{"tvshow.poster":"show-poster.jpg","thumb":"art-thumb.jpg"}}}"#.utf8
        )

        let response = try JSONDecoder().decode(PlayerItemResponse.self, from: data)

        XCTAssertEqual(response.item.artworkPath, "show-poster.jpg")
    }

    func testApplicationVersionFormattingOmitsStableTag() throws {
        let stable = Data(#"{"major":21,"minor":2,"revision":"git:abc","tag":"stable"}"#.utf8)
        let prerelease = Data(#"{"major":22,"minor":0,"revision":null,"tag":"beta1"}"#.utf8)

        let stableVersion = try JSONDecoder().decode(ApplicationPropertiesResponse.VersionInfo.self, from: stable)
        let prereleaseVersion = try JSONDecoder().decode(ApplicationPropertiesResponse.VersionInfo.self, from: prerelease)

        XCTAssertEqual(stableVersion.displayVersion, "21.2")
        XCTAssertEqual(prereleaseVersion.displayVersion, "22.0 (beta1)")
    }

    func testDynamicCoreELECResponsesExposeTypedValues() throws {
        let dolbyVisionData = Data(
            #"{"Player.Process(video.dovi.profile)":"8","Player.Process(video.dovi.el.type)":"minimum","Player.Process(video.dovi.el.present)":"TRUE","Player.Process(video.dovi.bl.present)":"true","Player.Process(video.dovi.bl.signal.compatibility)":"1"}"#.utf8
        )
        let audioData = Data(#"{"VideoPlayer.AudioCodec":"truehd_atmos"}"#.utf8)

        let dolbyVision = try JSONDecoder().decode(DolbyVisionInfoResponse.self, from: dolbyVisionData)
        let audio = try JSONDecoder().decode(PlayerAudioInfoResponse.self, from: audioData)

        XCTAssertEqual(dolbyVision.profile, 8)
        XCTAssertTrue(dolbyVision.hasEnhancementLayer)
        XCTAssertTrue(dolbyVision.hasBaseLayer)
        XCTAssertEqual(dolbyVision.signalCompatibility, 1)
        XCTAssertEqual(dolbyVision.formattedProfile, "P8.1 MEL")
        XCTAssertEqual(audio.audioCodec, "truehd_atmos")
        XCTAssertTrue(audio.hasAtmos)
        XCTAssertFalse(audio.hasDTSX)
    }

    func testAnyCodableValueDecodesScalarSettings() throws {
        let decoder = JSONDecoder()

        let string = try decoder.decode(AnyCodableValue.self, from: Data(#""expert""#.utf8))
        let integer = try decoder.decode(AnyCodableValue.self, from: Data("4".utf8))
        let boolean = try decoder.decode(AnyCodableValue.self, from: Data("true".utf8))
        let null = try decoder.decode(AnyCodableValue.self, from: Data("null".utf8))

        XCTAssertEqual(string.stringValue, "expert")
        XCTAssertEqual(integer.intValue, 4)
        XCTAssertEqual(boolean.boolValue, true)
        XCTAssertNil(null.stringValue)
        XCTAssertNil(null.intValue)
        XCTAssertNil(null.boolValue)
    }
}
