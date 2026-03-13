import Foundation
import CloudKit

struct DiaryEntry: Identifiable {
    let id: CKRecord.ID
    let diaryDate: String
    let diaryDayAndMonth: String
    var diary: String
    var isDeleted: Bool
    var mood: String?
    var photoAssets: [CKAsset]
    var legacyPhotoAsset: CKAsset?

    /// Returns photos from the new `photos` field, falling back to legacy single `photo`.
    var allPhotoAssets: [CKAsset] {
        if !photoAssets.isEmpty { return photoAssets }
        if let legacy = legacyPhotoAsset { return [legacy] }
        return []
    }

    init(record: CKRecord) {
        self.id = record.recordID
        self.diaryDate = record["diaryDate"] as? String ?? ""
        self.diaryDayAndMonth = record["diaryDayAndMonth"] as? String ?? ""
        self.diary = record["diary"] as? String ?? ""
        let deletedString = record["isDeleted"] as? String ?? "false"
        self.isDeleted = deletedString == "true"
        self.mood = record["mood"] as? String
        self.photoAssets = record["photos"] as? [CKAsset] ?? []
        self.legacyPhotoAsset = record["photo"] as? CKAsset
    }
}
