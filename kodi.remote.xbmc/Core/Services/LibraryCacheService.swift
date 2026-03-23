//
//  LibraryCacheService.swift
//  kodi.remote.xbmc
//

import Foundation
import os

actor LibraryCacheService {
    static let shared = LibraryCacheService()

    private let fileManager = FileManager.default
    private let diskCacheURL: URL?
    private let logger = Logger(subsystem: "kommand", category: "cache")

    private init() {
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("KodiLibrary", isDirectory: true)
        diskCacheURL = cacheURL

        if let cacheURL, !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Movies

    func loadMovies(for hostId: UUID) -> (movies: [Movie], savedAt: Date)? {
        guard let envelope: CacheEnvelope<[Movie]> = loadEnvelope(type: "movies", hostId: hostId) else {
            return nil
        }
        logger.info("Library cache hit: \(envelope.items.count) movies for host \(hostId.uuidString.prefix(8))")
        return (envelope.items, envelope.savedAt)
    }

    func saveMovies(_ movies: [Movie], for hostId: UUID) {
        let envelope = CacheEnvelope(savedAt: Date(), items: movies)
        saveEnvelope(envelope, type: "movies", hostId: hostId)
        logger.info("Library cache saved: \(movies.count) movies for host \(hostId.uuidString.prefix(8))")
    }

    // MARK: - TV Shows

    func loadTVShows(for hostId: UUID) -> (tvShows: [TVShow], savedAt: Date)? {
        guard let envelope: CacheEnvelope<[TVShow]> = loadEnvelope(type: "tvshows", hostId: hostId) else {
            return nil
        }
        logger.info("Library cache hit: \(envelope.items.count) TV shows for host \(hostId.uuidString.prefix(8))")
        return (envelope.items, envelope.savedAt)
    }

    func saveTVShows(_ shows: [TVShow], for hostId: UUID) {
        let envelope = CacheEnvelope(savedAt: Date(), items: shows)
        saveEnvelope(envelope, type: "tvshows", hostId: hostId)
        logger.info("Library cache saved: \(shows.count) TV shows for host \(hostId.uuidString.prefix(8))")
    }

    // MARK: - Cache Management

    func clearCache(for hostId: UUID) {
        guard let cacheURL = diskCacheURL else { return }
        let prefix = hostId.uuidString
        if let contents = try? fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil) {
            for file in contents where file.lastPathComponent.hasPrefix(prefix) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func clearAllCaches() {
        guard let cacheURL = diskCacheURL else { return }
        if let contents = try? fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil) {
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
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

    // MARK: - Private

    private struct CacheEnvelope<T: Codable>: Codable {
        let savedAt: Date
        let items: T
    }

    private func cacheFileURL(type: String, hostId: UUID) -> URL? {
        diskCacheURL?.appendingPathComponent("\(hostId.uuidString)-\(type).json")
    }

    private func loadEnvelope<T: Codable>(type: String, hostId: UUID) -> CacheEnvelope<T>? {
        guard let fileURL = cacheFileURL(type: type, hostId: hostId),
              fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(CacheEnvelope<T>.self, from: data)
        } catch {
            logger.error("Library cache decode failed for \(type): \(error.localizedDescription)")
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    private func saveEnvelope<T: Codable>(_ envelope: CacheEnvelope<T>, type: String, hostId: UUID) {
        guard let fileURL = cacheFileURL(type: type, hostId: hostId) else { return }

        // Ensure directory exists
        if let cacheURL = diskCacheURL, !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }

        do {
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Library cache save failed for \(type): \(error.localizedDescription)")
        }
    }
}
