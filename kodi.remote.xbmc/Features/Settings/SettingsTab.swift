//
//  SettingsTab.swift
//  kodi.remote.xbmc
//

import SwiftUI
import UIKit

struct SettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Connections") {
                    NavigationLink {
                        HostsListView()
                    } label: {
                        Label {
                            HStack {
                                Text("Kodi Hosts")
                                Spacer()
                                if let host = appState.currentHost {
                                    Text(host.name)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "server.rack")
                        }
                    }

                    if appState.currentHost != nil {
                        HStack {
                            Label("Status", systemImage: "circle.fill")
                                .foregroundStyle(appState.connectionState.statusColor)
                            Spacer()
                            if appState.isCoreELEC && appState.connectionState == .connected {
                                Text("CoreELEC")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(.blue)
                            }
                            Text(appState.connectionState.statusText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if appState.connectionState == .connected {
                    Section("Kodi") {
                        NavigationLink {
                            KodiSettingsView()
                        } label: {
                            Label("Kodi Settings", systemImage: "slider.horizontal.3")
                        }
                    }
                }

                Section("Appearance") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Theme & Display", systemImage: "paintbrush")
                    }
                }

                Section("Library") {
                    NavigationLink {
                        LibrarySettingsView()
                    } label: {
                        Label("Media Types", systemImage: "square.stack")
                    }
                }

                Section("Behavior") {
                    NavigationLink {
                        BehaviorSettingsView()
                    } label: {
                        Label("Controls & Gestures", systemImage: "hand.tap")
                    }
                }

                if appState.isCoreELEC {
                    Section("CoreELEC") {
                        NavigationLink {
                            CoreELECSettingsView()
                        } label: {
                            Label("System Settings", systemImage: "cpu")
                        }
                    }
                }

                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Kommand", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .themedScrollBackground()
        }
    }
}

// MARK: - Placeholder Views

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("colorScheme") private var colorSchemeSetting = 0 // 0=System, 1=Light, 2=Dark
    @AppStorage("selectedTheme") private var selectedThemeId = "default"
    @AppStorage("nowPlayingBackground") private var nowPlayingBackground = 0 // 0=Blur, 1=Solid
    @AppStorage("showDolbyVisionProfile") private var showDolbyVisionProfile = false
    @AppStorage("isProUnlocked") private var isProUnlocked = false
    @State private var showProPaywall = false

    private var effectiveColorScheme: ColorScheme {
        switch colorSchemeSetting {
        case 1: return .light
        case 2: return .dark
        default: return systemColorScheme
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $colorSchemeSetting) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
            } header: {
                Text("Color Scheme")
            }

            Section {
                ThemeGridPicker(
                    selectedThemeId: $selectedThemeId,
                    effectiveColorScheme: effectiveColorScheme,
                    isProUnlocked: isProUnlocked,
                    onProThemeTapped: { showProPaywall = true }
                )
            } header: {
                Text("Theme")
            } footer: {
                if let theme = AppTheme.allThemes.first(where: { $0.id == selectedThemeId }) {
                    if theme.id == "pureBlack" {
                        Text("True black backgrounds for OLED displays.")
                    } else if theme.id == "noir" {
                        Text("Monochrome elegance with inverted accent colors.")
                    } else if theme.id == "ember" {
                        Text("Warm amber tones for comfortable night viewing.")
                    } else if theme.id == "cinema" {
                        Text("Theater curtain inspired with deep reds.")
                    }
                }
            }

            Section("Now Playing") {
                Picker("Background Style", selection: $nowPlayingBackground) {
                    Text("Blurred Artwork").tag(0)
                    Text("Solid Color").tag(1)
                }
            }

            Section {
                Toggle("Dolby Vision Profile", isOn: $showDolbyVisionProfile)
            } header: {
                Text("Pro Features")
            } footer: {
                Text("Show detailed Dolby Vision profile information (e.g., P7 FEL, P8.1 MEL) on the Now Playing card.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
        .sheet(isPresented: $showProPaywall) {
            ProPaywallView()
        }
    }
}

// MARK: - Theme Grid Picker

struct ThemeGridPicker: View {
    @Binding var selectedThemeId: String
    let effectiveColorScheme: ColorScheme
    let isProUnlocked: Bool
    let onProThemeTapped: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 70), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppTheme.allThemes) { theme in
                ThemeSwatch(
                    theme: theme,
                    colorScheme: effectiveColorScheme,
                    isSelected: selectedThemeId == theme.id,
                    isLocked: theme.isPro && !isProUnlocked
                ) {
                    if theme.isPro && !isProUnlocked {
                        onProThemeTapped()
                    } else {
                        selectedThemeId = theme.id
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Theme Swatch

struct ThemeSwatch: View {
    let theme: AppTheme
    let colorScheme: ColorScheme
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    private var colors: ThemeColorSet {
        theme.colors(for: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Background circle showing theme background
                    Circle()
                        .fill(colors.background)
                        .frame(width: 50, height: 50)

                    // Inner circle showing accent color
                    Circle()
                        .fill(colors.accent)
                        .frame(width: 28, height: 28)

                    // Selection ring
                    if isSelected {
                        Circle()
                            .stroke(colors.accent, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }

                    // Lock badge for Pro themes
                    if isLocked {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("PRO")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.orange, in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .frame(width: 56, height: 56)
                    }

                    // Checkmark for selected
                    if isSelected && !isLocked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(colors.invertAccentText ? colors.accent == .white ? .black : .white : .white)
                    }
                }
                .frame(width: 60, height: 60)

                Text(theme.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .opacity(isLocked ? 0.7 : 1)
    }
}

// MARK: - Pro Paywall

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isProUnlocked") private var isProUnlocked = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                VStack(spacing: 12) {
                    Text("Unlock Premium Themes")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Get access to 8 beautiful premium themes designed for the best viewing experience.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Theme previews
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(AppTheme.allThemes.filter { $0.isPro }) { theme in
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.dark.background)
                                        .frame(width: 80, height: 60)

                                    Circle()
                                        .fill(theme.dark.accent)
                                        .frame(width: 24, height: 24)
                                }

                                Text(theme.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        // TODO: Implement StoreKit purchase
                        isProUnlocked = true
                        dismiss()
                    } label: {
                        Text("Unlock Pro — $2.99")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }

                    Button("Restore Purchases") {
                        // TODO: Implement restore
                        isProUnlocked = true
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BehaviorSettingsView: View {
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("seekInterval") private var seekInterval = 30
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("showVolumeSlider") private var showVolumeSlider = false

    // Power Menu Settings
    @AppStorage("powerMenuRestartKodi") private var powerMenuRestartKodi = true
    @AppStorage("powerMenuSuspend") private var powerMenuSuspend = false
    @AppStorage("powerMenuReboot") private var powerMenuReboot = false
    @AppStorage("powerMenuShutdown") private var powerMenuShutdown = false

    var body: some View {
        Form {
            Section("Feedback") {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }

            Section("Playback") {
                Picker("Seek Interval", selection: $seekInterval) {
                    Text("10 seconds").tag(10)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                }
            }

            Section("Remote") {
                Toggle("Show Volume Slider", isOn: $showVolumeSlider)
            }

            Section("Display") {
                Toggle("Keep Screen On", isOn: $keepScreenOn)
            }

            Section {
                Toggle("Restart Kodi", isOn: $powerMenuRestartKodi)
                Toggle("Suspend Device", isOn: $powerMenuSuspend)
                Toggle("Reboot Device", isOn: $powerMenuReboot)
                Toggle("Shutdown Device", isOn: $powerMenuShutdown)
            } header: {
                Text("Power Menu")
            } footer: {
                Text("Choose which options appear in the power menu on the Remote tab. The power menu is only visible when connected to a CoreELEC device.")
            }
        }
        .navigationTitle("Behavior")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
    }
}

struct LibrarySettingsView: View {
    @AppStorage("showMoviesTab") private var showMoviesTab = true
    @AppStorage("showTVShowsTab") private var showTVShowsTab = true
    @AppStorage("showMusicTab") private var showMusicTab = true
    @AppStorage("showPVRTab") private var showPVRTab = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showMoviesTab) {
                    Label("Movies", systemImage: "film")
                }

                Toggle(isOn: $showTVShowsTab) {
                    Label("TV Shows", systemImage: "tv")
                }

                Toggle(isOn: $showMusicTab) {
                    Label("Music", systemImage: "music.note")
                }

                Toggle(isOn: $showPVRTab) {
                    Label("Live TV & Radio", systemImage: "play.tv")
                }
            } header: {
                Text("Show in Tab Bar")
            } footer: {
                Text("Choose which media libraries appear in the main navigation. The Remote tab is always visible. Live TV requires a PVR backend to be configured in Kodi.")
            }
        }
        .navigationTitle("Media Types")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
    }
}

struct CoreELECSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CoreELECViewModel()
    @State private var showSuspendConfirm = false
    @State private var showRebootConfirm = false
    @State private var showShutdownConfirm = false

    var body: some View {
        List {
            // System Info Section
            Section("System Information") {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if let name = viewModel.systemInfo?.friendlyName, !name.isEmpty {
                        InfoRow(label: "Name", value: name)
                    }

                    if let version = viewModel.systemInfo?.buildVersion, !version.isEmpty {
                        InfoRow(label: "Kodi Version", value: version)
                    }

                    if let os = viewModel.systemInfo?.osVersionInfo, !os.isEmpty {
                        InfoRow(label: "OS", value: os)
                    }

                    if let kernel = viewModel.systemInfo?.kernelVersion, !kernel.isEmpty {
                        InfoRow(label: "Kernel", value: kernel)
                    }

                    if let uptime = viewModel.systemInfo?.uptime, !uptime.isEmpty {
                        InfoRow(label: "Uptime", value: uptime)
                    }
                }
            }

            // Hardware Section
            Section("Hardware") {
                if let cpuTemp = viewModel.systemInfo?.cpuTemperature, !cpuTemp.isEmpty {
                    InfoRow(label: "CPU Temperature", value: cpuTemp, icon: "thermometer.medium")
                }

                if let gpuTemp = viewModel.systemInfo?.gpuTemperature, !gpuTemp.isEmpty {
                    InfoRow(label: "GPU Temperature", value: gpuTemp, icon: "thermometer.medium")
                }

                if let memory = viewModel.systemInfo?.memoryUsedPercent, !memory.isEmpty {
                    InfoRow(label: "Memory Used", value: memory, icon: "memorychip")
                }
            }

            // Storage Section
            Section("Storage") {
                if let used = viewModel.systemInfo?.usedSpace,
                   let total = viewModel.systemInfo?.totalSpace,
                   let free = viewModel.systemInfo?.freeSpace,
                   !used.isEmpty && !total.isEmpty {
                    InfoRow(label: "Used", value: used)
                    InfoRow(label: "Free", value: free)
                    InfoRow(label: "Total", value: total)
                } else {
                    Text("Storage info unavailable")
                        .foregroundStyle(.secondary)
                }
            }

            // Power Controls Section
            Section {
                Button {
                    showSuspendConfirm = true
                } label: {
                    Label("Suspend", systemImage: "moon.fill")
                }

                Button {
                    showRebootConfirm = true
                } label: {
                    Label("Reboot", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    showShutdownConfirm = true
                } label: {
                    Label("Shutdown", systemImage: "power")
                }
            } header: {
                Text("Power")
            } footer: {
                Text("Suspend puts the device into sleep mode (S3). It can be woken via CEC or Wake-on-LAN.")
            }
        }
        .navigationTitle("CoreELEC")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            viewModel.configure(appState: appState)
            await viewModel.loadSystemInfo()
        }
        .confirmationDialog("Suspend Device?", isPresented: $showSuspendConfirm, titleVisibility: .visible) {
            Button("Suspend") {
                Task { await viewModel.suspend() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The device will enter sleep mode. You can wake it with the remote or Wake-on-LAN.")
        }
        .confirmationDialog("Reboot Device?", isPresented: $showRebootConfirm, titleVisibility: .visible) {
            Button("Reboot") {
                Task { await viewModel.reboot() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The device will restart. This may take a few minutes.")
        }
        .confirmationDialog("Shutdown Device?", isPresented: $showShutdownConfirm, titleVisibility: .visible) {
            Button("Shutdown", role: .destructive) {
                Task { await viewModel.shutdown() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The device will power off completely. You'll need to manually turn it back on or use Wake-on-LAN.")
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - CoreELEC ViewModel

@Observable
final class CoreELECViewModel {
    private var appState: AppState?
    private let client = KodiClient()

    var systemInfo: SystemInfoResponse?
    var appInfo: ApplicationPropertiesResponse?
    var isLoading = false
    var error: String?

    func configure(appState: AppState) {
        self.appState = appState
        if let host = appState.currentHost {
            Task {
                await client.configure(with: host)
            }
        }
    }

    func loadSystemInfo() async {
        await MainActor.run { isLoading = true }

        do {
            async let systemTask = client.getSystemInfo()
            async let appTask = client.getApplicationProperties()

            let (system, app) = try await (systemTask, appTask)

            await MainActor.run {
                systemInfo = system
                appInfo = app
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func refresh() async {
        await loadSystemInfo()
    }

    func suspend() async {
        do {
            try await client.suspend()
            triggerHaptic(.success)
        } catch {
            print("Suspend error: \(error)")
            triggerHaptic(.error)
        }
    }

    func reboot() async {
        do {
            try await client.reboot()
            triggerHaptic(.success)
        } catch {
            print("Reboot error: \(error)")
            triggerHaptic(.error)
        }
    }

    func shutdown() async {
        do {
            try await client.shutdown()
            triggerHaptic(.success)
        } catch {
            print("Shutdown error: \(error)")
            triggerHaptic(.error)
        }
    }

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Link(destination: URL(string: "https://kodi.tv")!) {
                    Label("Kodi Website", systemImage: "globe")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
    }
}

#Preview {
    SettingsTab()
        .environment(AppState())
}
