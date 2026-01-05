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
            return
        }

        isLoading = true
        loadFailed = false

        if let image = await ImageCacheService.shared.image(for: url, host: host) {
            await MainActor.run {
                loadedImage = image
                isLoading = false
            }
        } else {
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
