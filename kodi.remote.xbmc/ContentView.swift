//
//  ContentView.swift
//  kodi.remote.xbmc
//

import SwiftUI

// MARK: - Themed Background Modifiers

/// A view modifier that applies the theme background to navigation-based views
struct ThemedBackgroundModifier: ViewModifier {
    @Environment(\.themeColors) private var colors

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(colors.background.ignoresSafeArea())
            .toolbarBackground(colors.background, for: .navigationBar)
    }
}

/// A view modifier that applies the themed scrollable background (for List/Form)
struct ThemedScrollBackgroundModifier: ViewModifier {
    @Environment(\.themeColors) private var colors

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(colors.background.ignoresSafeArea())
            .toolbarBackground(colors.background, for: .navigationBar)
    }
}

/// A view modifier that adds subtle card borders when theme requires it
struct ThemeCardBorderModifier: ViewModifier {
    @Environment(\.themeColors) private var colors
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if let borderColor = colors.cardBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: 0.5)
                }
            }
    }
}

extension View {
    /// Applies themed background from current theme (for NavigationStack content)
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }

    /// Applies themed scroll background (for List/Form content)
    func themedScrollBackground() -> some View {
        modifier(ThemedScrollBackgroundModifier())
    }

    /// Adds subtle border to cards when theme requires it
    func themeCardBorder(cornerRadius: CGFloat = 12) -> some View {
        modifier(ThemeCardBorderModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - App Tab

enum AppTab: String, CaseIterable {
    case home
    case remote
    case movies
    case tvShows
    case music
    case pvr
    case settings
}

// MARK: - Content View

struct ContentView: View {
    @State private var appState = AppState()
    @State private var selectedTab: AppTab = .home
    @Environment(\.colorScheme) private var systemColorScheme

    @AppStorage("showMoviesTab") private var showMoviesTab = true
    @AppStorage("showTVShowsTab") private var showTVShowsTab = true
    @AppStorage("showMusicTab") private var showMusicTab = true
    @AppStorage("showPVRTab") private var showPVRTab = false
    @AppStorage("colorScheme") private var colorSchemeSetting = 0 // 0=System, 1=Light, 2=Dark
    @AppStorage("selectedTheme") private var selectedThemeId = "default"

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeSetting {
        case 1: return .light
        case 2: return .dark
        default: return nil // System
        }
    }

    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? systemColorScheme
    }

    private var currentTheme: AppTheme {
        AppTheme.theme(for: selectedThemeId)
    }

    private var themeColors: ThemeColorSet {
        currentTheme.colors(for: effectiveColorScheme)
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
        .environment(\.currentTheme, currentTheme)
        .environment(\.themeColors, themeColors)
        .preferredColorScheme(preferredColorScheme)
        .tint(themeColors.accent)
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
        .onAppear {
            updateTabBarAppearance()
        }
        .onChange(of: selectedThemeId) { _, _ in
            updateTabBarAppearance()
        }
        .onChange(of: colorSchemeSetting) { _, _ in
            updateTabBarAppearance()
        }
        .task {
            await connectAndDetect()
        }
    }

    private func updateTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(themeColors.background)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
                appState.serverCapabilities.isCoreELEC = isCoreELEC
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
    @Environment(\.themeColors) private var colors
    @State private var showingAddHost = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "play.tv")
                    .font(.system(size: 80))
                    .foregroundStyle(colors.accent)

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
                        HStack {
                            Image(systemName: "play.tv")
                            Text("Add Kodi Host")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colors.accent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }

                    Text("Make sure Kodi is running and the web server is enabled")
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
