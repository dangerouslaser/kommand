//
//  AddHostView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct AddHostView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var httpPort = "8080"
    @State private var tcpPort = "9090"
    @State private var username = ""
    @State private var password = ""
    @State private var macAddress = ""

    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    var isValid: Bool {
        !name.isEmpty && !address.isEmpty && Int(httpPort) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Host Information") {
                    TextField("Display Name", text: $name)
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

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section("Wake on LAN (Optional)") {
                    TextField("MAC Address", text: $macAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(!isValid || isTesting)

                    if let result = testResult {
                        switch result {
                        case .success:
                            Label("Connection successful", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Add Host")
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

    private func testConnection() {
        guard let port = Int(httpPort) else { return }

        isTesting = true
        testResult = nil

        let host = KodiHost(
            name: name,
            address: address,
            httpPort: port,
            tcpPort: Int(tcpPort) ?? 9090,
            username: username.isEmpty ? nil : username
        )

        Task {
            let client = KodiClient()
            await client.configure(with: host, password: password.isEmpty ? nil : password)

            do {
                let success = try await client.testConnection()
                await MainActor.run {
                    isTesting = false
                    testResult = success ? .success : .failure("Connection failed")
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func saveHost() {
        guard let port = Int(httpPort) else { return }

        let host = KodiHost(
            name: name,
            address: address,
            httpPort: port,
            tcpPort: Int(tcpPort) ?? 9090,
            username: username.isEmpty ? nil : username,
            macAddress: macAddress.isEmpty ? nil : macAddress
        )

        if !password.isEmpty {
            KeychainHelper.setPassword(password, for: host.id)
        }

        appState.addHost(host)
        dismiss()
    }
}

#Preview {
    AddHostView()
        .environment(AppState())
}
