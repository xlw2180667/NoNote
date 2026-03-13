import Foundation

enum LocalStorageService {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("diary_data", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("diaryCache.json")
    }

    static func saveDiaryCache(_ cache: [String: DiaryCacheEntry]) {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("LocalStorageService: failed to save – \(error)")
        }
    }

    static func loadDiaryCache() -> [String: DiaryCacheEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([String: DiaryCacheEntry].self, from: data)
        } catch {
            print("LocalStorageService: failed to load – \(error)")
            return [:]
        }
    }
}
