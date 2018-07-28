//
//  CalendarViewController+iClound.swift
//  NoNote
//
//  Created by Xie Liwei on 15/07/2018.
//  Copyright © 2018 Xie Liwei. All rights reserved.
//

import Foundation
import CloudKit
extension CalendarViewController {    
    func fetchDiary(monthAndYear: String, completion: @escaping ()-> Void) {
        let predicate = NSPredicate(format: "diaryDayAndMonth == %@", monthAndYear)
        let query = CKQuery(recordType: "Diary", predicate: predicate)
        database.perform(query, inZoneWith: nil) { (diaries, error) in
            if let error = error {
                self.showAlertWhenCannotConnectToICloud()
                print(error.localizedDescription)
            } else {
                guard let diaries = diaries else { return }
                for diary in diaries {
                    guard let diaryDate = diary.object(forKey: "diaryDate") as? String,
                        let diaryString = diary.object(forKey: "diary") as? String
                        else { return }
                    if let isDelete = diary.object(forKey: "isDeleted") as? String {
                        if isDelete == "true" {
                            UserDefaults.standard.removeObject(forKey: "\(diaryDate)IsSet")
                            UserDefaults.standard.removeObject(forKey: "\(diaryDate)")
                        } else {
                            UserDefaults.standard.set(true, forKey: "\(diaryDate)IsSet")
                            UserDefaults.standard.set(diaryString, forKey: "\(diaryDate)")
                        }
                    } else {
                        UserDefaults.standard.set(true, forKey: "\(diaryDate)IsSet")
                        UserDefaults.standard.set(diaryString, forKey: "\(diaryDate)")
                    }

                    DispatchQueue.main.async {
                        self.calendar.reloadData()
                    }
                }
            }
        }
    }
}
