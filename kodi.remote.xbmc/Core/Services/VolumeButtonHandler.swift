//
//  VolumeButtonHandler.swift
//  kodi.remote.xbmc
//
//  Intercepts iPhone physical volume buttons to control CEC volume
//

import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

@Observable
final class VolumeButtonHandler {
    private var audioSession: AVAudioSession?
    // nonisolated(unsafe) so the deinit (which runs in a nonisolated context) can
    // call invalidate() on it. NSKeyValueObservation.invalidate() is thread-safe,
    // and the property is only mutated from start()/stop() on the main actor —
    // deinit only happens when no other reference exists, so the read is race-free.
    nonisolated(unsafe) private var volumeObserver: NSKeyValueObservation?
    private var lastVolume: Float = 0.5
    private(set) var isActive = false

    // Callbacks for volume button presses
    var onVolumeUp: (@MainActor () -> Void)?
    var onVolumeDown: (@MainActor () -> Void)?

    func start() {
        guard !isActive else { return }
        isActive = true

        // Set up audio session to receive volume button events
        audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession?.setCategory(.ambient, options: .mixWithOthers)
            try audioSession?.setActive(true)
        } catch {
            return
        }

        // Get current volume and set as baseline
        lastVolume = audioSession?.outputVolume ?? 0.5

        // Capture callbacks before entering the observe closure
        let volumeUp = onVolumeUp
        let volumeDown = onVolumeDown

        // Observe volume changes
        volumeObserver = audioSession?.observe(\.outputVolume, options: [.new, .old]) { session, change in
            guard let newVolume = change.newValue,
                  let oldVolume = change.oldValue else { return }

            // Detect direction of change and dispatch to MainActor
            if newVolume > oldVolume {
                Task { @MainActor in volumeUp?() }
            } else if newVolume < oldVolume {
                Task { @MainActor in volumeDown?() }
            }
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false

        volumeObserver?.invalidate()
        volumeObserver = nil
    }

    deinit {
        // Belt-and-suspenders: if a view ever forgets to call stop() (lifecycle
        // mismatch, exception during teardown), the KVO observation would
        // otherwise keep the handler alive indefinitely. invalidate() is safe
        // to call from any thread and on a nil/already-invalidated observer.
        volumeObserver?.invalidate()
    }
}

// MARK: - Hidden Volume View (hides system HUD and allows volume reset)

struct HiddenVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.alpha = 0.0001 // Nearly invisible but still functional
        // Route button is effectively hidden since the entire view is invisible
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}

    // Helper to set volume programmatically
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.async {
                slider.value = volume
            }
        }
    }
}
