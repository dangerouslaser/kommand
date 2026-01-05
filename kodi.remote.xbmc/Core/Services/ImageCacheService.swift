//
//  ImageCacheService.swift
//  kodi.remote.xbmc
//

import UIKit
import CryptoKit

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL?
    private let cacheExpiration: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private init() {
        // Configure memory cache limits
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 100_000_000 // ~100MB

        // Setup disk cache directory
        diskCacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("KodiArtwork", isDirectory: true)

        createDiskCacheDirectoryIfNeeded()
    }

    // MARK: - Public API

    func image(for url: URL, host: KodiHost) async -> UIImage? {
        let key = cacheKey(for: url)

        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Check disk cache
        if let diskImage = loadFromDisk(for: url) {
            let cost = diskImage.jpegData(compressionQuality: 0.8)?.count ?? 0
            memoryCache.setObject(diskImage, forKey: key as NSString, cost: cost)
            return diskImage
        }

        // 3. Fetch from network
        guard let image = await fetchImage(from: url, host: host) else {
            return nil
        }

        // 4. Cache in memory and disk
        let cost = image.jpegData(compressionQuality: 0.8)?.count ?? 0
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        saveToDisk(image, for: url)

        return image
    }

    func clearCache() {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        guard let cacheURL = diskCacheURL else { return }

        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            // Ignore errors
        }
    }

    func pruneExpiredCache() {
        guard let cacheURL = diskCacheURL else { return }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )

            let expirationDate = Date().addingTimeInterval(-cacheExpiration)

            for file in contents {
                if let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = attributes.contentModificationDate,
                   modDate < expirationDate {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            // Ignore errors
        }
    }

    var diskCacheSize: Int {
        guard let cacheURL = diskCacheURL else { return 0 }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.fileSizeKey]
            )

            return contents.reduce(0) { total, file in
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + size
            }
        } catch {
            return 0
        }
    }

    // MARK: - Private Helpers

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
    }

    private func diskFilename(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined() + ".jpg"
    }

    private func createDiskCacheDirectoryIfNeeded() {
        guard let cacheURL = diskCacheURL else { return }

        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
    }

    private func loadFromDisk(for url: URL) -> UIImage? {
        guard let cacheURL = diskCacheURL else { return nil }

        let filename = diskFilename(for: url)
        let fileURL = cacheURL.appendingPathComponent(filename)

        // Check if file exists and is not expired
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let modDate = attributes[.modificationDate] as? Date {
            let expirationDate = Date().addingTimeInterval(-cacheExpiration)
            if modDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        }

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private func saveToDisk(_ image: UIImage, for url: URL) {
        guard let cacheURL = diskCacheURL else { return }

        let filename = diskFilename(for: url)
        let fileURL = cacheURL.appendingPathComponent(filename)

        // Save as JPEG for smaller file size
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        try? data.write(to: fileURL)
    }

    private func fetchImage(from url: URL, host: KodiHost) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData // We handle caching ourselves

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

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }

            return image
        } catch {
            return nil
        }
    }
}
