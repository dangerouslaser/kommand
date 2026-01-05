//
//  ProPaywallView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isProUnlocked") private var isProUnlocked = false
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                VStack(spacing: 12) {
                    Text("Unlock Kommand Pro")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Get premium themes and Lock Screen controls with Live Activity support.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Feature list
                VStack(alignment: .leading, spacing: 16) {
                    ProFeatureRow(icon: "paintbrush.fill", title: "Premium Themes", description: "8 beautiful themes including OLED black")
                    ProFeatureRow(icon: "lock.circle.fill", title: "Live Activity", description: "Control playback from Lock Screen & Dynamic Island")
                    ProFeatureRow(icon: "tv.fill", title: "Dolby Vision Info", description: "Detailed DV profile information")
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 8)

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
                        liveActivityEnabled = true // Auto-enable Live Activity on purchase
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
                        liveActivityEnabled = true
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

// MARK: - Pro Feature Row

struct ProFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
