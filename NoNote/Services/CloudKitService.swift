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
        // Load text+mood cache synchronously (fast, no file I/O per entry)
        let cached = LocalStorageService.loadDiaryCache()
        self.diaryCache = cached
        self.diaryDates = Set(cached.keys)

        // Defer photo migration + widget update + pending uploads to avoid blocking first frame
        Task { @MainActor [weak self] in
            guard let self else { return }
            for dateString in self.diaryCache.keys {
                PhotoCacheService.migrateLegacy(for: dateString)
                self.diaryCache[dateString]?.photoFileURLs = PhotoCacheService.photoURLs(for: dateString)
            }
            SharedDataStore.update(from: self)
            self.uploadPendingEntries()
        }
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
                    var cacheEntry = DiaryCacheEntry(text: entry.diary, mood: entry.mood, weather: entry.weather)

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

    /// Updates text + mood + weather instantly so CalendarView refreshes before navigation completes.
    func updateCacheInMemory(text: String, date: Date, mood: String?, weather: String?) {
        let dateString = dateKey(from: date)
        diaryDates.insert(dateString)
        var cacheEntry = diaryCache[dateString] ?? DiaryCacheEntry(text: text)
        cacheEntry.text = text
        cacheEntry.mood = mood
        cacheEntry.weather = weather
        cacheEntry.needsUpload = true
        diaryCache[dateString] = cacheEntry
        persistLocally()
    }

    // MARK: - Background Save (photo I/O + CloudKit)

    /// Saves photos to disk on a background thread, then syncs to CloudKit.
    /// Each source is (fullImage for new photos, sourceURL for existing photos on disk).
    func saveInBackground(text: String, date: Date, mood: String?, weather: String?, photoSources: [(image: UIImage?, url: URL?)]) {
        let dateString = dateKey(from: date)
        let hasNewPhotos = photoSources.contains { $0.image != nil }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Step 1: Read ALL images into memory BEFORE deleting anything
            var allImages: [UIImage] = []
            for source in photoSources {
                let img = source.image ?? source.url.flatMap { UIImage(contentsOfFile: $0.path) }
                if let img { allImages.append(img) }
            }

            // Step 2: Only delete and re-save local files when photos actually changed
            var urls: [URL]
            if hasNewPhotos {
                PhotoCacheService.deleteAll(for: dateString)
                urls = []
                for (index, img) in allImages.enumerated() {
                    if let url = PhotoCacheService.save(image: img, for: dateString, at: index) {
                        urls.append(url)
                    }
                }
            } else {
                // No new photos — keep existing files, just preserve URL order
                urls = photoSources.compactMap(\.url)
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.diaryCache[dateString]?.photoFileURLs = urls
                self.persistLocally()
                SharedDataStore.update(from: self)

                Task {
                    do {
                        try await self.saveDiaryToCloud(text: text, date: date, mood: mood, weather: weather, photos: allImages)
                        self.diaryCache[dateString]?.needsUpload = false
                        self.persistLocally()
                        print("CloudKit: saved \(dateString) (mood: \(mood ?? "nil"), weather: \(weather ?? "nil"), photos: \(allImages.count))")
                    } catch {
                        print("CloudKit: save failed for \(dateString) — \(error)")
                        // needsUpload stays true — will retry on next launch
                    }
                }
            }
        }
    }

    // MARK: - Year Prefetch

    /// Pull a whole year's months into the cache.
    ///
    /// The month picker marks months that hold entries, and `diaryDates` only ever knew about
    /// months that had already been fetched — so on a fresh install every month looked empty,
    /// which is worse than showing nothing. Warming the year makes those marks truthful, and
    /// paging into any of those months is then instant.
    ///
    /// Failures are ignored on purpose: offline just means the marks stay as they were.
    func prefetchYear(_ year: Int) async {
        let calendar = Calendar.current
        let now = Date()
        let thisYear = calendar.component(.year, from: now)
        let lastMonth = year == thisYear ? calendar.component(.month, from: now) : 12
        guard year <= thisYear else { return }

        await withTaskGroup(of: Void.self) { group in
            for month in 1...lastMonth {
                group.addTask { [weak self] in
                    try? await self?.fetchDiaries(monthAndYear: "\(month)-\(year)")
                }
            }
        }
    }

    // MARK: - Bulk Import

    struct ImportSummary {
        var imported = 0
        /// Days that already had text — never overwritten.
        var skippedExisting = 0
        var uploaded = 0
        var failedUpload = 0
    }

    /// Writes imported entries locally, then pushes them to CloudKit a few at a time.
    ///
    /// Local first on purpose: the calendar fills in immediately and the data is safe even if
    /// the upload is interrupted. Anything that does not make it keeps `needsUpload = true`
    /// and is retried by `uploadPendingEntries()` on the next launch.
    ///
    /// Days that already hold text are skipped, never merged over — an import must not be able
    /// to destroy something the user actually wrote.
    func importEntries(_ entries: [ImportedEntry],
                       progress: @escaping (Int, Int) -> Void) async -> ImportSummary {
        var summary = ImportSummary()
        var toUpload: [(dateKey: String, date: Date, text: String, mood: String?)] = []

        for entry in entries {
            let existing = diaryCache[entry.dateKey]?.text ?? ""
            if !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                summary.skippedExisting += 1
                continue
            }
            var cacheEntry = DiaryCacheEntry(text: entry.text)
            cacheEntry.mood = entry.mood
            cacheEntry.needsUpload = true
            diaryCache[entry.dateKey] = cacheEntry
            diaryDates.insert(entry.dateKey)
            summary.imported += 1
            toUpload.append((entry.dateKey, entry.date, entry.text, entry.mood))
        }

        persistLocally()
        SharedDataStore.update(from: self)
        progress(0, toUpload.count)

        // A few at a time: hundreds of parallel CKQuery + save pairs get throttled by CloudKit
        // and would spike memory for no gain.
        let batchSize = 4
        var done = 0
        for start in stride(from: 0, to: toUpload.count, by: batchSize) {
            let batch = Array(toUpload[start..<min(start + batchSize, toUpload.count)])
            await withTaskGroup(of: (String, Bool).self) { group in
                for item in batch {
                    group.addTask { [weak self] in
                        guard let self else { return (item.dateKey, false) }
                        do {
                            try await self.saveDiaryToCloud(text: item.text, date: item.date,
                                                            mood: item.mood, weather: nil, photos: [])
                            return (item.dateKey, true)
                        } catch {
                            print("CloudKit: import upload failed for \(item.dateKey) — \(error)")
                            return (item.dateKey, false)
                        }
                    }
                }
                for await (dateKey, ok) in group {
                    if ok {
                        diaryCache[dateKey]?.needsUpload = false
                        summary.uploaded += 1
                    } else {
                        summary.failedUpload += 1
                    }
                    done += 1
                    progress(done, toUpload.count)
                }
            }
            persistLocally()
        }

        SharedDataStore.update(from: self)
        return summary
    }

    // MARK: - Retry Pending Uploads

    private func uploadPendingEntries() {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"

        let pending = diaryCache.filter { $0.value.needsUpload }
        if !pending.isEmpty {
            print("CloudKit: retrying \(pending.count) pending upload(s)")
        }

        // A bulk import can leave hundreds pending; firing them all at once gets throttled by
        // CloudKit and spikes memory. Take a slice per launch — the rest retry next time.
        let batch = pending.sorted { $0.key < $1.key }.prefix(25)
        for (dateString, entry) in batch {
            guard let date = formatter.date(from: dateString) else { continue }
            let text = entry.text
            let mood = entry.mood
            let weather = entry.weather
            let photoURLs = entry.photoFileURLs

            // Load images off main thread to avoid UI freeze
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let images: [UIImage] = photoURLs.compactMap { UIImage(contentsOfFile: $0.path) }
                DispatchQueue.main.async {
                    guard let self else { return }
                    Task {
                        do {
                            try await self.saveDiaryToCloud(text: text, date: date, mood: mood, weather: weather, photos: images)
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

    private func saveDiaryToCloud(text: String, date: Date, mood: String?, weather: String?, photos: [UIImage]) async throws {
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
            record["weather"] = weather as CKRecordValue?
            record["photos"] = assets.isEmpty ? nil : assets as CKRecordValue
            record["photo"] = nil
            try await database.save(record)
        } else {
            let record = CKRecord(recordType: "Diary")
            record["diaryDate"] = dateString
            record["diaryDayAndMonth"] = monthString
            record["diary"] = text
            record["mood"] = mood as CKRecordValue?
            record["weather"] = weather as CKRecordValue?
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
                        diaryCache[entry.diaryDate] = DiaryCacheEntry(text: entry.diary, mood: entry.mood, weather: entry.weather)
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
    private let debugMoods = ["happy", "good", "neutral", "sad", "happy", "good", "happy"]
    private let debugWeathers = ["0", "2", "63", "0", "2", "81", "0", "95", "2", "0", "53", "2", "0"]
    /// Demo diary text for screenshots — one table per UI language.
    private let debugDiaryTexts: [AppLanguage: [String]] = [
        .en: [
            "Had a wonderful brunch with friends today. ☀️",
            "Finished reading that book. Really inspiring.",
            "Normal day at work. Peaceful and productive.",
            "Rainy day. Stayed home and cooked soup.",
            "Great workout this morning! New personal record. 💪",
            "Went to the farmer's market. Beautiful flowers.",
            "Movie night with the family. 🎬",
            "Tried a new coffee shop downtown.",
            "Sketching in the park. Cherry blossoms blooming. 🌸",
            "Cleaned the whole apartment today.",
            "Deep conversation with an old friend.",
            "Homemade pasta from scratch. Delicious! 🍝",
            "Discovered a lovely little bookshop.",
            "Morning yoga. Quiet walk along the river.",
            "Game night! Board games until midnight. 🎲",
        ],
        .zhHans: [
            "和朋友吃了顿超棒的早午餐 ☀️",
            "终于读完那本书了，很受启发。",
            "平静又高效的一天。",
            "下雨天，在家煲了汤。",
            "早上健身刷新了个人纪录！💪",
            "去了趟菜市场，买了花。",
            "和家人一起看电影 🎬",
            "打卡了市中心新开的咖啡店。",
            "在公园写生，樱花开了 🌸",
            "把整个家打扫了一遍。",
            "和老朋友聊了很久，很治愈。",
            "自己动手做了意面，好吃！🍝",
            "发现一家很可爱的小书店。",
            "晨间瑜伽，沿着河边散步。",
            "桌游之夜！玩到半夜 🎲",
        ],
        .zhHant: [
            "和朋友吃了一頓超棒的早午餐 ☀️",
            "終於把那本書讀完了，很受啟發。",
            "平靜又有效率的一天。",
            "下雨天，在家煮了湯。",
            "早上健身刷新了個人紀錄！💪",
            "去了一趟菜市場，買了花。",
            "和家人一起看電影 🎬",
            "去了市區新開的咖啡店。",
            "在公園寫生，櫻花開了 🌸",
            "把整個家都打掃了一遍。",
            "和老朋友聊了很久，很療癒。",
            "自己動手做了義大利麵，好吃！🍝",
            "發現一家很可愛的小書店。",
            "晨間瑜伽，沿著河邊散步。",
            "桌遊之夜！玩到半夜 🎲",
        ],
        .ja: [
            "友だちと最高のブランチ ☀️",
            "あの本をやっと読み終えた。すごく刺激的。",
            "おだやかで、はかどった一日。",
            "雨の日。家でスープを煮こんだ。",
            "朝トレで自己記録を更新！💪",
            "朝市へ。きれいな花を買った。",
            "家族で映画の夜 🎬",
            "駅前にできたカフェに行ってみた。",
            "公園でスケッチ。桜が満開 🌸",
            "家じゅうを大そうじした。",
            "旧友とじっくり話した。",
            "パスタを一から手作り。おいしい！🍝",
            "かわいい小さな本屋を見つけた。",
            "朝ヨガ。川沿いをのんびり散歩。",
            "ゲームの夜！深夜までボードゲーム 🎲",
        ],
        .ko: [
            "친구들과 아주 좋은 브런치 ☀️",
            "그 책을 드디어 다 읽었다. 정말 좋았어.",
            "차분하고 알찬 하루.",
            "비 오는 날. 집에서 국을 끓였다.",
            "아침 운동에서 개인 기록 경신! 💪",
            "시장에 다녀왔다. 꽃도 한 다발.",
            "가족과 영화 보는 밤 🎬",
            "시내에 새로 생긴 카페에 가 봤다.",
            "공원에서 스케치. 벚꽃이 활짝 🌸",
            "집 안을 전부 청소했다.",
            "오랜 친구와 깊은 이야기.",
            "파스타를 처음부터 직접. 맛있다! 🍝",
            "아주 예쁜 작은 책방을 발견했다.",
            "아침 요가. 강가를 천천히 걸었다.",
            "게임의 밤! 자정까지 보드게임 🎲",
        ],
        .es: [
            "Un brunch buenísimo con amigos. ☀️",
            "Terminé ese libro. Muy inspirador.",
            "Día tranquilo y productivo.",
            "Día de lluvia. En casa haciendo sopa.",
            "¡Buen entreno esta mañana! Récord personal. 💪",
            "Fui al mercado. Flores preciosas.",
            "Noche de película en familia. 🎬",
            "Probé una cafetería nueva del centro.",
            "Dibujando en el parque. Cerezos en flor. 🌸",
            "Limpié toda la casa hoy.",
            "Charla larga con un amigo de siempre.",
            "Pasta casera desde cero. ¡Riquísima! 🍝",
            "Descubrí una librería pequeña encantadora.",
            "Yoga por la mañana. Paseo junto al río.",
            "¡Noche de juegos! Mesa hasta medianoche. 🎲",
        ],
    ]

    /// Generate test entries: `count` consecutive days ending today (streak = count).
    /// If `breakStreak` is true, skip today so sheep are sleeping.
    func generateTestData(count: Int = 20, breakStreak: Bool = false) {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let cal = Calendar.current
        let today = Date()

        diaryDates.removeAll()
        diaryCache.removeAll()

        // Build a consecutive streak of `count` days ending at today (or yesterday if breakStreak)
        let texts = AppLanguage.current.pick(debugDiaryTexts)
        let startOffset = breakStreak ? 1 : 0
        for i in startOffset..<(count + startOffset) {
            guard let date = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let dateString = formatter.string(from: date)
            let mood = debugMoods[i % debugMoods.count]
            let text = texts[i % texts.count]
            let weather = debugWeathers[i % debugWeathers.count]
            diaryDates.insert(dateString)
            diaryCache[dateString] = DiaryCacheEntry(text: text, mood: mood, weather: weather)
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
