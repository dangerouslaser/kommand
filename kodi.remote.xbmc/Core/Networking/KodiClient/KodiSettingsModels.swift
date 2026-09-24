//
//  KodiSettingsModels.swift
//  kodi.remote.xbmc
//

import Foundation

nonisolated struct SettingValueResponse: Decodable, Sendable {
    let value: AnyCodableValue
}

// MARK: - Kodi Settings Models

nonisolated struct SettingSectionsResponse: Decodable, Sendable {
    let sections: [SettingSection]?
}

nonisolated struct SettingSection: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let help: String?

    static func == (lhs: SettingSection, rhs: SettingSection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct SettingCategoriesResponse: Decodable, Sendable {
    let categories: [SettingCategory]?
}

nonisolated struct SettingCategory: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let help: String?

    static func == (lhs: SettingCategory, rhs: SettingCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct SettingsListResponse: Decodable, Sendable {
    let settings: [KodiSetting]?
}

nonisolated struct KodiSetting: Decodable, Identifiable, Sendable {
    let id: String
    let label: String
    let help: String?
    let type: String
    let value: AnyCodableValue?
    let `default`: AnyCodableValue?
    let enabled: Bool?
    let parent: String?
    let control: SettingControl?
    let options: [SettingOption]?
    let minimum: Double?
    let maximum: Double?
    let step: Double?

    var settingType: SettingType {
        SettingType(rawValue: type) ?? .unknown
    }
}

nonisolated struct SettingControl: Decodable, Sendable {
    let type: String
    let format: String?
}

nonisolated struct SettingOption: Decodable, Identifiable, Sendable {
    let label: String
    let value: AnyCodableValue

    var id: String {
        if let intVal = value.intValue {
            return String(intVal)
        } else if let strVal = value.stringValue {
            return strVal
        }
        return label
    }
}

nonisolated enum SettingType: String, Sendable {
    case boolean = "boolean"
    case integer = "integer"
    case number = "number"
    case string = "string"
    case action = "action"
    case list = "list"
    case path = "path"
    case addon = "addon"
    case unknown

    var icon: String {
        switch self {
        case .boolean: return "switch.2"
        case .integer, .number: return "number"
        case .string, .path: return "textformat"
        case .action: return "play.circle"
        case .list: return "list.bullet"
        case .addon: return "puzzlepiece"
        case .unknown: return "questionmark.circle"
        }
    }
}

// Helper for decoding any JSON value
nonisolated enum AnyCodableValue: Decodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}
