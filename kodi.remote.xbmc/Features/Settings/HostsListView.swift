//
//  HostsListView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct HostsListView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddHost = false
    @State private var hostToEdit: KodiHost?

    var body: some View {
        List {
            if appState.hosts.isEmpty {
                ContentUnavailableView {
                    Label("No Hosts", systemImage: "server.rack")
                } description: {
                    Text("Add a Kodi server to get started")
                } actions: {
                    Button("Add Host") {
                        showingAddHost = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(appState.hosts) { host in
                    HostRow(host: host, isSelected: host.id == appState.currentHost?.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.setDefaultHost(host)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                appState.deleteHost(host)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                hostToEdit = host
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .navigationTitle("Hosts")
        .navigationBarTitleDisplayMode(.inline)
        .themedScrollBackground()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddHost = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddHost) {
            AddHostView()
        }
        .sheet(item: $hostToEdit) { host in
            EditHostView(host: host)
        }
    }
}

struct HostRow: View {
    let host: KodiHost
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Server type icon
            Image(systemName: "play.tv")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(host.name)
                    .font(.headline)

                Text("\(host.address):\(host.httpPort)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HostsListView()
    }
    .environment(AppState())
}
