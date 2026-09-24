import Foundation
import XCTest
@testable import kodi_remote_xbmc

final class NowPlayingTests: XCTestCase {
    func testMediaTypeParsingIsCaseInsensitiveAndFallsBackToUnknown() {
        XCTAssertEqual(MediaType(from: "MOVIE"), .movie)
        XCTAssertEqual(MediaType(from: "MusicVideo"), .musicvideo)
        XCTAssertEqual(MediaType(from: "picture"), .unknown)
    }

    func testPlayingItemEstimatesPositionProgressAndRemainingTime() {
        let capturedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let item = makeItem(duration: 120, position: 30, speed: 1, lastUpdated: capturedAt)
        let observedAt = capturedAt.addingTimeInterval(15)

        XCTAssertTrue(item.isPlaying)
        XCTAssertEqual(item.progress, 0.25, accuracy: 0.000_1)
        XCTAssertEqual(item.remainingTime, 90, accuracy: 0.000_1)
        XCTAssertEqual(item.estimatedPosition(at: observedAt), 45, accuracy: 0.000_1)
        XCTAssertEqual(item.estimatedProgress(at: observedAt), 0.375, accuracy: 0.000_1)
        XCTAssertEqual(item.estimatedRemainingTime(at: observedAt), 75, accuracy: 0.000_1)
    }

    func testEstimatedPositionIsClampedAndPausedPositionDoesNotAdvance() {
        let capturedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let playing = makeItem(duration: 60, position: 55, speed: 1, lastUpdated: capturedAt)
        let paused = makeItem(duration: 60, position: 20, speed: 0, lastUpdated: capturedAt)
        let observedAt = capturedAt.addingTimeInterval(30)

        XCTAssertEqual(playing.estimatedPosition(at: observedAt), 60)
        XCTAssertEqual(playing.estimatedRemainingTime(at: observedAt), 0)
        XCTAssertEqual(paused.estimatedPosition(at: observedAt), 20)
        XCTAssertFalse(paused.isPlaying)
    }

    func testStreamDisplayNamesHaveUsefulFallbacks() {
        let audio = AudioStream(id: 2, name: "Director Commentary", language: "eng", codec: "aac", channels: 2)
        let unnamedAudio = AudioStream(id: 4, name: "", language: nil, codec: nil, channels: nil)
        let subtitle = Subtitle(id: 3, name: "", language: "spa")
        let unnamedSubtitle = Subtitle(id: 5, name: "", language: nil)

        XCTAssertEqual(audio.displayName, "Director Commentary (eng) [aac]")
        XCTAssertEqual(unnamedAudio.displayName, "Track 4")
        XCTAssertEqual(subtitle.displayName, "spa")
        XCTAssertEqual(unnamedSubtitle.displayName, "Subtitle 5")
    }

    func testTimeIntervalFormattingUsesClockStyle() {
        XCTAssertEqual(TimeInterval(65).formattedDuration, "1:05")
        XCTAssertEqual(TimeInterval(3_661).formattedDuration, "1:01:01")
    }

    private func makeItem(
        duration: TimeInterval,
        position: TimeInterval,
        speed: Int,
        lastUpdated: Date
    ) -> NowPlayingItem {
        NowPlayingItem(
            type: .movie,
            title: "Movie",
            subtitle: nil,
            artworkPath: nil,
            fanartPath: nil,
            duration: duration,
            position: position,
            speed: speed,
            audioStreams: [],
            subtitles: [],
            currentAudioStreamIndex: 0,
            currentSubtitleIndex: 0,
            subtitlesEnabled: false,
            videoCodec: nil,
            audioCodec: nil,
            hdrType: nil,
            videoWidth: nil,
            videoHeight: nil,
            audioChannels: nil,
            audioLanguage: nil,
            subtitleLanguage: nil,
            filePath: nil,
            dolbyVisionProfile: nil,
            hasAtmos: false,
            lastUpdated: lastUpdated
        )
    }
}
