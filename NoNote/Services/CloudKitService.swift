import Foundation
import CloudKit

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
    @Published var diaryCache: [String: String] = [:]

    private let database = CKContainer.default().privateCloudDatabase

    func fetchDiaries(monthAndYear: String) async throws {
        let predicate = NSPredicate(format: "diaryDayAndMonth == %@", monthAndYear)
        let query = CKQuery(recordType: "Diary", predicate: predicate)

        let (results, _) = try await database.records(matching: query)

        for (_, result) in results {
            if let record = try? result.get() {
                let entry = DiaryEntry(record: record)
                if entry.isDeleted {
                    diaryDates.remove(entry.diaryDate)
                    diaryCache.removeValue(forKey: entry.diaryDate)
                } else {
                    diaryDates.insert(entry.diaryDate)
                    diaryCache[entry.diaryDate] = entry.diary
                }
            }
        }
    }

    func saveDiary(text: String, date: Date) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let dateString = formatter.string(from: date)
        formatter.dateFormat = "M-yyyy"
        let monthString = formatter.string(from: date)

        let predicate = NSPredicate(format: "diaryDate == %@", dateString)
        let query = CKQuery(recordType: "Diary", predicate: predicate)
        let (results, _) = try await database.records(matching: query)

        if let (_, result) = results.first, let record = try? result.get() {
            record["diary"] = text
            record["isDeleted"] = "false"
            try await database.save(record)
        } else {
            let record = CKRecord(recordType: "Diary")
            record["diaryDate"] = dateString
            record["diaryDayAndMonth"] = monthString
            record["diary"] = text
            try await database.save(record)
        }

        diaryDates.insert(dateString)
        diaryCache[dateString] = text
    }

    func deleteDiary(date: Date) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let dateString = formatter.string(from: date)

        let predicate = NSPredicate(format: "diaryDate == %@", dateString)
        let query = CKQuery(recordType: "Diary", predicate: predicate)
        let (results, _) = try await database.records(matching: query)

        if let (_, result) = results.first, let record = try? result.get() {
            record["isDeleted"] = "true"
            try await database.save(record)
        }

        diaryDates.remove(dateString)
        diaryCache.removeValue(forKey: dateString)
    }

    func diaryText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let dateString = formatter.string(from: date)
        return diaryCache[dateString] ?? ""
    }
}
