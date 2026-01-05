//
//  AboutView.swift
//  kodi.remote.xbmc
//

import SwiftUI

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
