//
//  KodiClient+Settings.swift
//  kodi.remote.xbmc
//

import Foundation

extension KodiClient {
    func getSettingValue(setting: String) async throws -> SettingValueResponse {
        try await send(method: "Settings.GetSettingValue", params: [
            "setting": setting
        ])
    }

    func setSettingValue(setting: String, value: Any) async throws {
        let _: Bool = try await send(method: "Settings.SetSettingValue", params: [
            "setting": setting,
            "value": value
        ])
    }

    // MARK: - Kodi Settings Browser

    func getSettingSections() async throws -> SettingSectionsResponse {
        try await send(method: "Settings.GetSections", params: [
            "level": "expert"
        ])
    }

    func getSettingCategories(section: String) async throws -> SettingCategoriesResponse {
        try await send(method: "Settings.GetCategories", params: [
            "section": section,
            "level": "expert"
        ])
    }

    func getSettings(section: String? = nil, category: String? = nil) async throws -> SettingsListResponse {
        var params: [String: Any] = ["level": "expert"]
        var filter: [String: String] = [:]
        if let section = section {
            filter["section"] = section
        }
        if let category = category {
            filter["category"] = category
        }
        if !filter.isEmpty {
            params["filter"] = filter
        }
        return try await send(method: "Settings.GetSettings", params: params)
    }

    func resetSettingToDefault(setting: String) async throws {
        let _: String = try await send(method: "Settings.ResetSettingValue", params: [
            "setting": setting
        ])
    }
}
