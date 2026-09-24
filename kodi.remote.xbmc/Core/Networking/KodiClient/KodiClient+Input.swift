//
//  KodiClient+Input.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    // MARK: - Input Commands

    func sendInput(_ action: InputAction) async throws {
        let _: String = try await send(method: "Input.\(action.rawValue)")
    }

    func sendText(_ text: String, done: Bool = true) async throws {
        let _: String = try await send(method: "Input.SendText", params: ["text": text, "done": done])
    }

    // MARK: - CEC Volume Control (for TV/AVR via HDMI-CEC)

    /// Execute an action via Input.ExecuteAction - used for CEC volume passthrough
    func executeAction(_ action: String) async throws {
        let _: String = try await send(method: "Input.ExecuteAction", params: ["action": action])
    }

    /// Increase volume via CEC (sends to TV/AVR if CEC is configured)
    func cecVolumeUp() async throws {
        try await executeAction("volumeup")
    }

    /// Decrease volume via CEC (sends to TV/AVR if CEC is configured)
    func cecVolumeDown() async throws {
        try await executeAction("volumedown")
    }

    /// Toggle mute via CEC (sends to TV/AVR if CEC is configured)
    func cecMute() async throws {
        try await executeAction("mute")
    }
}

nonisolated enum InputAction: String {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    case select = "Select"
    case back = "Back"
    case home = "Home"
    case contextMenu = "ContextMenu"
    case info = "Info"
    case osd = "ShowOSD"
}
