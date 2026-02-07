//
//  AsyncArtworkImage.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct AsyncArtworkImage: View, Equatable {
    let path: String?
    let host: KodiHost?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    static func == (lhs: AsyncArtworkImage, rhs: AsyncArtworkImage) -> Bool {
        lhs.path == rhs.path && lhs.host?.id == rhs.host?.id
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadFailed {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
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
