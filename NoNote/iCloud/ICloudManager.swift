//
//  ICloudManager.swift
//  NoDiary
//
//  Created by Xie Liwei on 29/07/2018.
//  Copyright © 2018 Xie Liwei. All rights reserved.
//

import Foundation
import CloudKit

final class CloudKitManager {
    static func appCloudDataBase() -> CKDatabase? {
        if let _ = FileManager.default.ubiquityIdentityToken {
            let appDb = CKContainer.default().privateCloudDatabase
            
            return appDb
        } else {
            print("No iCloud access, save to local")
            return nil
        }
    }
    
    static func checkIfDiaryExsit(date: String, completion: @escaping (_ records: [CKRecord]?, _ hasRecord: Bool) -> Void) {
        let predicate = NSPredicate(format: "diaryDate == %@", date)
        let query = CKQuery(recordType: "Diary", predicate: predicate)
        guard let database = appCloudDataBase() else { return }
        database.perform(query, inZoneWith: nil) { (diaries, error) in
            if let error = error {
                print(error.localizedDescription)
            } else {
                guard let diaries = diaries else { return }
                if diaries.count != 0 {
                    completion(diaries,true)
                } else {
                    completion(nil, false)
                }
            }
        }
    }
    
    static func deleteDiaryFromICould(record: CKRecord, completion: @escaping () -> Void) {
        record.setObject("true" as CKRecordValue, forKey: "isDeleted")
        guard let database = appCloudDataBase() else { return }
        database.save(record) { (record, error) in
            if let error = error {
                print(error.localizedDescription)
            } else {
                completion()
            }
        }
    }
}
