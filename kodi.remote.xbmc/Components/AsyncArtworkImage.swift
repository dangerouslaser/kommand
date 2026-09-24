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

    private struct LoadID: Hashable {
        let path: String?
        let hostID: UUID?
    }

    static func == (lhs: AsyncArtworkImage, rhs: AsyncArtworkImage) -> Bool {
        lhs.path == rhs.path && lhs.host?.id == rhs.host?.id
    }

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("Artwork")
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            } else if loadFailed {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Artwork unavailable")
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .task(id: LoadID(path: path, hostID: host?.id)) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // State survives SwiftUI view updates. Clear the previous request's result
        // before validating the new input so an item without artwork cannot keep
        // displaying the preceding item's image.
        loadedImage = nil
        isLoading = false
        loadFailed = false

        guard let path = path, !path.isEmpty, let host = host else {
            return
        }

        guard let url = host.imageURL(for: path) else {
            return
        }

        isLoading = true
        let image = await ImageCacheService.shared.image(for: url, host: host)

        // `.task(id:)` cancels the previous load when either the path or host
        // changes. Do not allow that obsolete request to overwrite the new state.
        guard !Task.isCancelled else { return }

        if let image {
            loadedImage = image
            isLoading = false
        } else {
            isLoading = false
            loadFailed = true
        }
    }

}

#Preview {
    VStack {
        AsyncArtworkImage(path: nil, host: nil)
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail))

        AsyncArtworkImage(path: "image://some/path.jpg/", host: .preview)
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.thumbnail))
    }
}
