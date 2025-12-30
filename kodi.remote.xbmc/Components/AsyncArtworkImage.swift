//
//  AsyncArtworkImage.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct AsyncArtworkImage: View {
    let path: String?
    let host: KodiHost?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
            } else {
                placeholderImage
            }
        }
        .task(id: path) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let path = path, !path.isEmpty, let host = host else {
            return
        }

        guard let url = host.imageURL(for: path) else {
            print("Failed to create image URL for path: \(path)")
            return
        }

        isLoading = true
        loadFailed = false

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        // Add basic auth if credentials exist
        if let username = host.username, !username.isEmpty {
            let password = KeychainHelper.getPassword(for: host.id) ?? ""
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        isLoading = false
                        loadFailed = true
                    }
                    return
                }
            }

            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    loadedImage = uiImage
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                    loadFailed = true
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                loadFailed = true
            }
        }
    }

    private var placeholderImage: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "photo")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack {
        AsyncArtworkImage(path: nil, host: nil)
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        AsyncArtworkImage(path: "image://some/path.jpg/", host: .preview)
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
