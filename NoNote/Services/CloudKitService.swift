import Foundation
import CloudKit
import UIKit

enum CloudKitError: LocalizedError {
    case iCloudUnavailable
    case networkError(Error)
    case recordNotFound

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return String(localized: "#cannotConnectToICloud")
        case .networkError(let error):
            return error.localizedDescription
        case .recordNotFound:
            return "Record not found"
        }
    }
}

@MainActor
final class CloudKitService: ObservableObject {
    @Published var diaryDates: Set<String> = []
    @Published var diaryCache: [String: DiaryCacheEntry] = [:]

    private let database = CKContainer.default().privateCloudDatabase

    init() {
        var cached = LocalStorageService.loadDiaryCache()
        for (dateString, _) in cached {
            PhotoCacheService.migrateLegacy(for: dateString)
            cached[dateString]?.photoFileURLs = PhotoCacheService.photoURLs(for: dateString)
        }
        self.diaryCache = cached
        self.diaryDates = Set(cached.keys)
        SharedDataStore.update(from: self)
        uploadPendingEntries()
    }

    // MARK: - Read Helpers

    func diaryText(for date: Date) -> String {
        let dateString = dateKey(from: date)
        return diaryCache[dateString]?.text ?? ""
    }

    func diaryCacheEntry(for date: Date) -> DiaryCacheEntry? {
        let dateString = dateKey(from: date)
        return diaryCache[dateString]
    }

    func diaryMood(for date: Date) -> String? {
        let dateString = dateKey(from: date)
        return diaryCache[dateString]?.mood
    }

    func moodForDateString(_ dateString: String) -> String? {
        return diaryCache[dateString]?.mood
    }

    // MARK: - Fetch

    func fetchDiaries(monthAndYear: String) async throws {
        let predicate = NSPredicate(format: "diaryDayAndMonth == %@", monthAndYear)
        let query = CKQuery(recordType: "Diary", predicate: predicate)

        let (results, _) = try await database.records(matching: query)

        for (_, result) in results {
            if let record = try? result.get() {
                let entry = DiaryEntry(record: record)
                // Skip entries pending local upload to avoid overwriting unsaved changes
                if diaryCache[entry.diaryDate]?.needsUpload == true { continue }
                if entry.isDeleted {
                    diaryDates.remove(entry.diaryDate)
                    diaryCache.removeValue(forKey: entry.diaryDate)
                } else {
                    diaryDates.insert(entry.diaryDate)
                    var cacheEntry = DiaryCacheEntry(text: entry.diary, mood: entry.mood)

                    // Clear old cached photos and re-cache from assets
                    PhotoCacheService.deleteAll(for: entry.diaryDate)
                    let assets = entry.allPhotoAssets
                    var urls: [URL] = []
                    for (index, asset) in assets.enumerated() {
                        if let fileURL = asset.fileURL,
                           let cachedURL = PhotoCacheService.save(fromAssetURL: fileURL, for: entry.diaryDate, at: index) {
                            urls.append(cachedURL)
                        }
                    }
                    cacheEntry.photoFileURLs = urls

                    diaryCache[entry.diaryDate] = cacheEntry
                }
            }
        }

        persistLocally()
        SharedDataStore.update(from: self)
    }

    // MARK: - Fast In-Memory Cache Update (no file I/O)

    /// Updates text + mood instantly so CalendarView refreshes before navigation completes.
    func updateCacheInMemory(text: String, date: Date, mood: String?) {
        let dateString = dateKey(from: date)
        diaryDates.insert(dateString)
        var cacheEntry = diaryCache[dateString] ?? DiaryCacheEntry(text: text)
        cacheEntry.text = text
        cacheEntry.mood = mood
        cacheEntry.needsUpload = true
        diaryCache[dateString] = cacheEntry
        persistLocally()
    }

    // MARK: - Background Save (photo I/O + CloudKit)

    /// Saves photos to disk on a background thread, then syncs to CloudKit.
    /// Each source is (fullImage for new photos, sourceURL for existing photos on disk).
    func saveInBackground(text: String, date: Date, mood: String?, photoSources: [(image: UIImage?, url: URL?)]) {
        let dateString = dateKey(from: date)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Step 1: Read ALL images into memory BEFORE deleting anything
            var allImages: [UIImage] = []
            for source in photoSources {
                let img = source.image ?? source.url.flatMap { UIImage(contentsOfFile: $0.path) }
                if let img { allImages.append(img) }
            }

            // Step 2: Now safe to delete old files and re-save
            PhotoCacheService.deleteAll(for: dateString)
            var urls: [URL] = []
            for (index, img) in allImages.enumerated() {
                if let url = PhotoCacheService.save(image: img, for: dateString, at: index) {
                    urls.append(url)
                }
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.diaryCache[dateString]?.photoFileURLs = urls
                self.persistLocally()
                SharedDataStore.update(from: self)

                Task {
                    do {
                        try await self.saveDiaryToCloud(text: text, date: date, mood: mood, photos: allImages)
                        self.diaryCache[dateString]?.needsUpload = false
                        self.persistLocally()
                        print("CloudKit: saved \(dateString) (mood: \(mood ?? "nil"), photos: \(allImages.count))")
                    } catch {
                        print("CloudKit: save failed for \(dateString) — \(error)")
                        // needsUpload stays true — will retry on next launch
                    }
                }
            }
        }
    }

    // MARK: - Retry Pending Uploads

    private func uploadPendingEntries() {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"

        let pending = diaryCache.filter { $0.value.needsUpload }
        if !pending.isEmpty {
            print("CloudKit: retrying \(pending.count) pending upload(s)")
        }

        for (dateString, entry) in pending {
            guard let date = formatter.date(from: dateString) else { continue }
            let text = entry.text
            let mood = entry.mood
            let photoURLs = entry.photoFileURLs

            // Load images off main thread to avoid UI freeze
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let images: [UIImage] = photoURLs.compactMap { UIImage(contentsOfFile: $0.path) }
                DispatchQueue.main.async {
                    guard let self else { return }
                    Task {
                        do {
                            try await self.saveDiaryToCloud(text: text, date: date, mood: mood, photos: images)
                            self.diaryCache[dateString]?.needsUpload = false
                            self.persistLocally()
                            print("CloudKit: retry succeeded for \(dateString)")
                        } catch {
                            print("CloudKit: retry failed for \(dateString) — \(error)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - CloudKit Sync

    private func saveDiaryToCloud(text: String, date: Date, mood: String?, photos: [UIImage]) async throws {
        let dateString = dateKey(from: date)
        let monthString = monthKey(from: date)

        let predicate = NSPredicate(format: "diaryDate == %@", dateString)
        let query = CKQuery(recordType: "Diary", predicate: predicate)
        let (results, _) = try await database.records(matching: query)

        let assets = photos.enumerated().compactMap { index, image in
            createSingleAsset(from: image, dateString: dateString, index: index)
        }

        if let (_, result) = results.first, let record = try? result.get() {
            record["diary"] = text
            record["isDeleted"] = "false"
            record["mood"] = mood as CKRecordValue?
            record["photos"] = assets.isEmpty ? nil : assets as CKRecordValue
            record["photo"] = nil
            try await database.save(record)
        } else {
            let record = CKRecord(recordType: "Diary")
            record["diaryDate"] = dateString
            record["diaryDayAndMonth"] = monthString
            record["diary"] = text
            record["mood"] = mood as CKRecordValue?
            if !assets.isEmpty {
                record["photos"] = assets as CKRecordValue
            }
            try await database.save(record)
        }
    }

    // MARK: - Delete

    func deleteDiary(date: Date) async throws {
        let dateString = dateKey(from: date)

        // Update local state first so data persists even if CloudKit fails
        diaryDates.remove(dateString)
        diaryCache.removeValue(forKey: dateString)
        PhotoCacheService.deleteAll(for: dateString)

        persistLocally()
        SharedDataStore.update(from: self)

        let predicate = NSPredicate(format: "diaryDate == %@", dateString)
        let query = CKQuery(recordType: "Diary", predicate: predicate)
        let (results, _) = try await database.records(matching: query)

        if let (_, result) = results.first, let record = try? result.get() {
            record["isDeleted"] = "true"
            try await database.save(record)
        }
    }

    // MARK: - Remove All Photos

    func removePhotos(for date: Date) {
        let dateString = dateKey(from: date)
        diaryCache[dateString]?.photoFileURLs = []
        PhotoCacheService.deleteAll(for: dateString)
        persistLocally()
    }

    // MARK: - Search

    func searchDiaries(query searchText: String) async throws -> [(dateString: String, text: String)] {
        let predicate = NSPredicate(format: "diary CONTAINS[c] %@ AND isDeleted != %@", searchText, "true")
        let ckQuery = CKQuery(recordType: "Diary", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "diaryDate", ascending: false)]

        let (results, _) = try await database.records(matching: ckQuery)

        var found: [(dateString: String, text: String)] = []
        for (_, result) in results {
            if let record = try? result.get() {
                let entry = DiaryEntry(record: record)
                if !entry.isDeleted {
                    found.append((dateString: entry.diaryDate, text: entry.diary))
                    // Also update local cache, but respect pending uploads
                    if diaryCache[entry.diaryDate]?.needsUpload != true {
                        diaryDates.insert(entry.diaryDate)
                        diaryCache[entry.diaryDate] = DiaryCacheEntry(text: entry.diary, mood: entry.mood)
                    }
                }
            }
        }
        persistLocally()
        return found
    }

    // MARK: - Local Persistence

    private func persistLocally() {
        LocalStorageService.saveDiaryCache(diaryCache)
    }

    // MARK: - Debug Test Data

    #if DEBUG
    func generateTestData() {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let cal = Calendar.current
        let today = Date()

        let moods = ["happy", "good", "neutral", "sad", "happy", "good", "happy"]
        let texts = [
            "Had a wonderful brunch with friends today. The weather was perfect and we sat outside enjoying the sunshine. ☀️",
            "Finished reading that book I've been working on. Really inspiring story about perseverance.",
            "Normal day at work. Nothing special happened but it was peaceful and productive.",
            "Rainy day. Stayed home and cooked a big pot of soup. The apartment smells amazing now.",
            "Great workout this morning! Hit a new personal record. Feeling strong and energized. 💪",
            "Went to the farmer's market and got the most beautiful flowers and fresh vegetables.",
            "Movie night with the family. We laughed so much watching that comedy together. 🎬",
            "Tried a new coffee shop downtown. Their latte art was incredible!",
            "Spent the afternoon in the park sketching. The cherry blossoms are starting to bloom. 🌸",
            "Cleaned the whole apartment today. It feels so refreshing to have a tidy space.",
            "Had a deep conversation with an old friend. Some friendships just pick up where they left off.",
            "Cooked a new recipe — homemade pasta from scratch. Messy but delicious! 🍝",
            "Discovered a lovely little bookshop tucked away in a side street. Bought three books.",
            "Morning yoga session followed by a quiet walk along the river. Perfect start to the day.",
            "Game night! Played board games until midnight. So competitive but so fun. 🎲",
        ]

        // Generate entries for the past 25 days
        for i in 0..<25 {
            // Skip some days to look natural
            if i == 3 || i == 7 || i == 12 || i == 18 || i == 22 { continue }

            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let dateString = formatter.string(from: date)
            let mood = moods[i % moods.count]
            let text = texts[i % texts.count]

            diaryDates.insert(dateString)
            diaryCache[dateString] = DiaryCacheEntry(text: text, mood: mood)
        }

        persistLocally()
        SharedDataStore.update(from: self)
    }

    func clearTestData() {
        diaryDates.removeAll()
        diaryCache.removeAll()
        persistLocally()
        SharedDataStore.update(from: self)
    }
    #endif

    // MARK: - Private Helpers

    private func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        return formatter.string(from: date)
    }

    private func monthKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-yyyy"
        return formatter.string(from: date)
    }

    private func createSingleAsset(from image: UIImage, dateString: String, index: Int) -> CKAsset? {
        let resized = PhotoCacheService.resizeImage(image, maxDimension: 1920)
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("upload_\(dateString)_\(index).jpg")
        do {
            try data.write(to: tempURL)
            return CKAsset(fileURL: tempURL)
        } catch {
            return nil
        }
    }
}
