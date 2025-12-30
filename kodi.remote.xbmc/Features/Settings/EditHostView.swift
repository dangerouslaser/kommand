//
//  EditHostView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct EditHostView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let host: KodiHost

    @State private var displayName: String
    @State private var address: String
    @State private var httpPort: String
    @State private var tcpPort: String
    @State private var username: String
    @State private var password: String
    @State private var macAddress: String

    init(host: KodiHost) {
        self.host = host
        _displayName = State(initialValue: host.displayName)
        _address = State(initialValue: host.address)
        _httpPort = State(initialValue: String(host.httpPort))
        _tcpPort = State(initialValue: String(host.tcpPort))
        _username = State(initialValue: host.username ?? "")
        _password = State(initialValue: "")
        _macAddress = State(initialValue: host.macAddress ?? "")
    }

    var isValid: Bool {
        !displayName.isEmpty && !address.isEmpty && Int(httpPort) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Host Information") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("IP Address or Hostname", text: $address)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section("Ports") {
                    HStack {
                        Text("HTTP Port")
                        Spacer()
                        TextField("8080", text: $httpPort)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("TCP Port")
                        Spacer()
                        TextField("9090", text: $tcpPort)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Authentication (Optional)") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password (leave empty to keep current)", text: $password)
                        .textContentType(.password)
                }

                Section("Wake on LAN (Optional)") {
                    TextField("MAC Address", text: $macAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveHost()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveHost() {
        guard let port = Int(httpPort) else { return }

        var updatedHost = host
        updatedHost.displayName = displayName
        updatedHost.address = address
        updatedHost.httpPort = port
        updatedHost.tcpPort = Int(tcpPort) ?? 9090
        updatedHost.username = username.isEmpty ? nil : username
        updatedHost.macAddress = macAddress.isEmpty ? nil : macAddress

        if !password.isEmpty {
            KeychainHelper.setPassword(password, for: host.id)
        }

        appState.updateHost(updatedHost)
        dismiss()
    }
}

#Preview {
    EditHostView(host: .preview)
        .environment(AppState())
}
