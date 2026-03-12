import Foundation
import CloudKit

struct DiaryEntry: Identifiable {
    let id: CKRecord.ID
    let diaryDate: String
    let diaryDayAndMonth: String
    var diary: String
    var isDeleted: Bool

    init(record: CKRecord) {
        self.id = record.recordID
        self.diaryDate = record["diaryDate"] as? String ?? ""
        self.diaryDayAndMonth = record["diaryDayAndMonth"] as? String ?? ""
        self.diary = record["diary"] as? String ?? ""
        let deletedString = record["isDeleted"] as? String ?? "false"
        self.isDeleted = deletedString == "true"
    }
}
