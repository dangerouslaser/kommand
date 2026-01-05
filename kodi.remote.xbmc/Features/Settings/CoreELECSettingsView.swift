//
//  CoreELECSettingsView.swift
//  kodi.remote.xbmc
//

import SwiftUI
import UIKit

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
            HapticService.notification(.success)
        } catch {
            HapticService.notification(.error)
        }
    }

    func reboot() async {
        do {
            try await client.reboot()
            HapticService.notification(.success)
        } catch {
            HapticService.notification(.error)
        }
    }

    func shutdown() async {
        do {
            try await client.shutdown()
            HapticService.notification(.success)
        } catch {
            HapticService.notification(.error)
        }
    }
}
