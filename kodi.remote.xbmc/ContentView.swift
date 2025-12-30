//
//  ContentView.swift
//  kodi.remote.xbmc
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case home
    case remote
    case movies
    case tvShows
    case music
    case pvr
    case settings
}

struct ContentView: View {
    @State private var appState = AppState()
    @State private var selectedTab: AppTab = .home

    @AppStorage("showMoviesTab") private var showMoviesTab = true
    @AppStorage("showTVShowsTab") private var showTVShowsTab = true
    @AppStorage("showMusicTab") private var showMusicTab = true
    @AppStorage("showPVRTab") private var showPVRTab = false
    @AppStorage("colorScheme") private var colorScheme = 0 // 0=System, 1=Light, 2=Dark

    private var preferredColorScheme: ColorScheme? {
        switch colorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil // System
        }
    }

    var body: some View {
        Group {
            if appState.hosts.isEmpty {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .environment(appState)
        .preferredColorScheme(preferredColorScheme)
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardTab()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            RemoteTab()
                .tabItem {
                    Label("Remote", systemImage: "appletvremote.gen4")
                }
                .tag(AppTab.remote)

            if showMoviesTab {
                MoviesTab()
                    .tabItem {
                        Label("Movies", systemImage: "film")
                    }
                    .tag(AppTab.movies)
            }

            if showTVShowsTab {
                TVShowsTab()
                    .tabItem {
                        Label("TV Shows", systemImage: "tv")
                    }
                    .tag(AppTab.tvShows)
            }

            if showMusicTab {
                MusicTab()
                    .tabItem {
                        Label("Music", systemImage: "music.note")
                    }
                    .tag(AppTab.music)
            }

            if showPVRTab {
                PVRTab()
                    .tabItem {
                        Label("Live TV", systemImage: "play.tv")
                    }
                    .tag(AppTab.pvr)
            }

            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
        .task {
            await connectAndDetect()
        }
    }

    private func connectAndDetect() async {
        guard let host = appState.currentHost else { return }

        await MainActor.run {
            appState.connectionState = .connecting
        }

        let client = KodiClient()
        await client.configure(with: host)

        // Test connection
        do {
            _ = try await client.testConnection()
            await MainActor.run {
                appState.connectionState = .connected
            }

            // Check for CoreELEC
            let isCoreELEC = await client.detectCoreELEC()
            await MainActor.run {
                appState.isCoreELEC = isCoreELEC
            }
        } catch {
            await MainActor.run {
                appState.connectionState = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddHost = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "play.tv")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                VStack(spacing: 12) {
                    Text("Welcome to Kommand")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Control your Kodi media center from your iPhone or iPad")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showingAddHost = true
                    } label: {
                        Text("Add Kodi Host")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }

                    Text("Make sure Kodi is running and JSON-RPC is enabled in Settings → Services → Control")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .sheet(isPresented: $showingAddHost) {
                AddHostView()
            }
        }
    }
}

#Preview {
    ContentView()
}
