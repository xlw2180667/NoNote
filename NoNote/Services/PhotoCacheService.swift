import Foundation
import UIKit
import ImageIO

enum PhotoCacheService {
    private static var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("diary_photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Save

    static func save(image: UIImage, for dateString: String, at index: Int) -> URL? {
        let resized = resizeImage(image, maxDimension: 1920)
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent("\(dateString)_\(index).jpg")
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    static func save(fromAssetURL assetURL: URL, for dateString: String, at index: Int) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent("\(dateString)_\(index).jpg")
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
            try FileManager.default.copyItem(at: assetURL, to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Query

    static func photoURLs(for dateString: String) -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        let prefix = dateString + "_"
        return files
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Delete

    static func deleteAll(for dateString: String) {
        let fm = FileManager.default
        // Delete indexed files
        for url in photoURLs(for: dateString) {
            try? fm.removeItem(at: url)
        }
        // Also delete legacy single-photo file
        let legacyURL = cacheDirectory.appendingPathComponent("\(dateString).jpg")
        try? fm.removeItem(at: legacyURL)
    }

    static func delete(for dateString: String, at index: Int) {
        let fm = FileManager.default
        let fileURL = cacheDirectory.appendingPathComponent("\(dateString)_\(index).jpg")
        try? fm.removeItem(at: fileURL)
        // Re-index remaining files
        reindex(for: dateString)
    }

    // MARK: - Migration

    /// Migrate legacy `{dateString}.jpg` → `{dateString}_0.jpg`
    static func migrateLegacy(for dateString: String) {
        let fm = FileManager.default
        let legacyURL = cacheDirectory.appendingPathComponent("\(dateString).jpg")
        let newURL = cacheDirectory.appendingPathComponent("\(dateString)_0.jpg")
        guard fm.fileExists(atPath: legacyURL.path),
              !fm.fileExists(atPath: newURL.path) else { return }
        try? fm.moveItem(at: legacyURL, to: newURL)
    }

    // MARK: - Thumbnail (fast ImageIO downsampling, no full decode)

    static func loadThumbnail(from url: URL, maxSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Resize

    static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }

        let ratio: CGFloat
        if size.width > size.height {
            ratio = maxDimension / size.width
        } else {
            ratio = maxDimension / size.height
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Private

    private static func reindex(for dateString: String) {
        let urls = photoURLs(for: dateString)
        let fm = FileManager.default
        for (newIndex, url) in urls.enumerated() {
            let expected = cacheDirectory.appendingPathComponent("\(dateString)_\(newIndex).jpg")
            if url != expected {
                try? fm.moveItem(at: url, to: expected)
            }
        }
    }
}
