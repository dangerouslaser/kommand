//
//  KodiSettingsView.swift
//  kodi.remote.xbmc
//

import SwiftUI
import UIKit

// MARK: - View Model

@Observable
final class KodiSettingsViewModel {
    private var client = KodiClient() // Replaced in configure() with shared instance
    private var host: KodiHost?

    var sections: [SettingSection] = []
    var categories: [String: [SettingCategory]] = [:]
    var settings: [String: [KodiSetting]] = [:]

    var isLoadingSections = false
    var isLoadingCategories = false
    var isLoadingSettings = false
    var error: String?

    func configure(host: KodiHost?, client: KodiClient) {
        self.host = host
        self.client = client
        if let host = host {
            Task {
                await client.configure(with: host)
            }
        }
    }

    func loadSections() async {
        guard host != nil else { return }

        await MainActor.run {
            isLoadingSections = true
            error = nil
        }

        do {
            let response = try await client.getSettingSections()
            await MainActor.run {
                sections = response.sections ?? []
                isLoadingSections = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoadingSections = false
            }
        }
    }

    func loadCategories(for section: SettingSection) async {
        guard categories[section.id] == nil else { return }

        await MainActor.run {
            isLoadingCategories = true
        }

        do {
            let response = try await client.getSettingCategories(section: section.id)
            await MainActor.run {
                categories[section.id] = response.categories ?? []
                isLoadingCategories = false
            }
        } catch {
            await MainActor.run {
                isLoadingCategories = false
            }
        }
    }

    func loadSettings(for category: SettingCategory, in section: SettingSection) async {
        let key = "\(section.id).\(category.id)"
        guard settings[key] == nil else { return }

        await MainActor.run {
            isLoadingSettings = true
        }

        do {
            let response = try await client.getSettings(section: section.id, category: category.id)
            await MainActor.run {
                // Filter to only enabled settings and sort by label
                let filteredSettings = (response.settings ?? [])
                    .filter { $0.enabled != false }
                    .sorted { $0.label < $1.label }
                settings[key] = filteredSettings
                isLoadingSettings = false
            }
        } catch {
            await MainActor.run {
                isLoadingSettings = false
            }
        }
    }

    func updateSetting(_ setting: KodiSetting, value: Any) async {
        do {
            try await client.setSettingValue(setting: setting.id, value: value)
            // Refresh the settings for this category
            if let categoryId = setting.id.components(separatedBy: ".").dropLast().joined(separator: ".").components(separatedBy: ".").first {
                settings.removeValue(forKey: categoryId)
            }
            HapticService.notification(.success)
        } catch {
            HapticService.notification(.error)
        }
    }

    func resetSetting(_ setting: KodiSetting) async {
        do {
            try await client.resetSettingToDefault(setting: setting.id)
            HapticService.notification(.success)
        } catch {
            HapticService.notification(.error)
        }
    }
}

// MARK: - Sections View (Top Level)

struct KodiSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = KodiSettingsViewModel()

    var body: some View {
        List {
            if viewModel.isLoadingSections {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading settings...")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.sections.isEmpty {
                ContentUnavailableView {
                    Label("No Settings", systemImage: "gear")
                } description: {
                    Text("Could not load Kodi settings")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.sections.filter { $0.id != "games" }) { section in
                    NavigationLink {
                        KodiCategoriesView(section: section, viewModel: viewModel)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.label)
                                if let help = section.help, !help.isEmpty {
                                    Text(help)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        } icon: {
                            Image(systemName: iconForSection(section.id))
                        }
                    }
                }
            }
        }
        .navigationTitle("Kodi Settings")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
        .task {
            viewModel.configure(host: appState.currentHost, client: appState.client)
            await viewModel.loadSections()
        }
    }

    private func iconForSection(_ id: String) -> String {
        switch id {
        case "player": return "play.rectangle"
        case "media": return "photo.on.rectangle"
        case "pvr": return "tv"
        case "interface": return "uiwindow.split.2x1"
        case "services": return "network"
        case "system": return "gearshape.2"
        case "games": return "gamecontroller"
        default: return "folder"
        }
    }
}

// MARK: - Categories View

struct KodiCategoriesView: View {
    let section: SettingSection
    let viewModel: KodiSettingsViewModel

    var body: some View {
        List {
            if viewModel.isLoadingCategories && viewModel.categories[section.id] == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let categories = viewModel.categories[section.id], !categories.isEmpty {
                ForEach(categories) { category in
                    NavigationLink {
                        KodiSettingsListView(section: section, category: category, viewModel: viewModel)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.label)
                            if let help = category.help, !help.isEmpty {
                                Text(help)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } else {
                Text("No categories found")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(section.label)
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
        .task {
            await viewModel.loadCategories(for: section)
        }
    }
}

// MARK: - Settings List View

struct KodiSettingsListView: View {
    let section: SettingSection
    let category: SettingCategory
    let viewModel: KodiSettingsViewModel

    private var settingsKey: String {
        "\(section.id).\(category.id)"
    }

    var body: some View {
        List {
            if viewModel.isLoadingSettings && viewModel.settings[settingsKey] == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let settings = viewModel.settings[settingsKey], !settings.isEmpty {
                ForEach(settings) { setting in
                    SettingRow(setting: setting, viewModel: viewModel)
                }
            } else {
                Text("No settings found")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(category.label)
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
        .task {
            await viewModel.loadSettings(for: category, in: section)
        }
        .refreshable {
            viewModel.settings.removeValue(forKey: settingsKey)
            await viewModel.loadSettings(for: category, in: section)
        }
    }
}

// MARK: - Setting Row

struct SettingRow: View {
    let setting: KodiSetting
    let viewModel: KodiSettingsViewModel

    @State private var boolValue: Bool = false
    @State private var intValue: Int = 0
    @State private var doubleValue: Double = 0
    @State private var stringValue: String = ""
    @State private var showingOptions = false

    var body: some View {
        Group {
            switch setting.settingType {
            case .boolean:
                Toggle(isOn: $boolValue) {
                    settingLabel
                }
                .onChange(of: boolValue) { _, newValue in
                    Task { await viewModel.updateSetting(setting, value: newValue) }
                }

            case .integer where setting.options != nil && !setting.options!.isEmpty:
                // Integer with options - show as picker
                NavigationLink {
                    OptionPickerView(setting: setting, viewModel: viewModel)
                } label: {
                    HStack {
                        settingLabel
                        Spacer()
                        Text(selectedOptionLabel(for: setting))
                            .foregroundStyle(.secondary)
                    }
                }

            case .integer, .number:
                if let min = setting.minimum, let max = setting.maximum, min < max {
                    let step = (setting.step ?? 1) > 0 ? (setting.step ?? 1) : 1
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            settingLabel
                            Spacer()
                            Text(setting.settingType == .integer ? "\(Int(doubleValue))" : String(format: "%.1f", doubleValue))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $doubleValue, in: min...max, step: step) { editing in
                            if !editing {
                                // Only save when user finishes dragging
                                let value: Any = setting.settingType == .integer ? Int(doubleValue) : doubleValue
                                Task { await viewModel.updateSetting(setting, value: value) }
                            }
                        }
                    }
                } else {
                    HStack {
                        settingLabel
                        Spacer()
                        Text("\(intValue)")
                            .foregroundStyle(.secondary)
                    }
                }

            case .string where setting.options != nil && !setting.options!.isEmpty:
                NavigationLink {
                    OptionPickerView(setting: setting, viewModel: viewModel)
                } label: {
                    HStack {
                        settingLabel
                        Spacer()
                        Text(selectedOptionLabel(for: setting))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

            case .string, .path:
                HStack {
                    settingLabel
                    Spacer()
                    Text(stringValue.isEmpty ? "Not set" : stringValue)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

            case .action:
                Button {
                    Task { await viewModel.updateSetting(setting, value: true) }
                } label: {
                    settingLabel
                }

            default:
                HStack {
                    settingLabel
                    Spacer()
                    Text(setting.type)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .onAppear {
            initializeValue()
        }
    }

    private var settingLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(setting.label)
            if let help = setting.help, !help.isEmpty {
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func initializeValue() {
        switch setting.settingType {
        case .boolean:
            boolValue = setting.value?.boolValue ?? false
        case .integer:
            intValue = setting.value?.intValue ?? 0
            doubleValue = Double(intValue)
        case .number:
            if let intVal = setting.value?.intValue {
                doubleValue = Double(intVal)
            } else if case .double(let val) = setting.value {
                doubleValue = val
            }
        case .string, .path:
            stringValue = setting.value?.stringValue ?? ""
        default:
            break
        }
    }

    private func selectedOptionLabel(for setting: KodiSetting) -> String {
        guard let options = setting.options, let currentValue = setting.value else {
            return "Unknown"
        }

        if let intVal = currentValue.intValue {
            return options.first { $0.value.intValue == intVal }?.label ?? "Unknown"
        } else if let strVal = currentValue.stringValue {
            return options.first { $0.value.stringValue == strVal }?.label ?? strVal
        }
        return "Unknown"
    }
}

// MARK: - Option Picker View

struct OptionPickerView: View {
    let setting: KodiSetting
    let viewModel: KodiSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let options = setting.options {
                ForEach(options) { option in
                    Button {
                        Task {
                            if let intVal = option.value.intValue {
                                await viewModel.updateSetting(setting, value: intVal)
                            } else if let strVal = option.value.stringValue {
                                await viewModel.updateSetting(setting, value: strVal)
                            }
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSelected(option) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(setting.label)
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
    }

    private func isSelected(_ option: SettingOption) -> Bool {
        guard let currentValue = setting.value else { return false }

        if let intVal = currentValue.intValue, let optionInt = option.value.intValue {
            return intVal == optionInt
        } else if let strVal = currentValue.stringValue, let optionStr = option.value.stringValue {
            return strVal == optionStr
        }
        return false
    }
}

#Preview {
    NavigationStack {
        KodiSettingsView()
    }
    .environment(AppState())
}
