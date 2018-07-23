//
//  NoteViewController.swift
//  NoNote
//
//  Created by Xie Liwei on 14/07/2018.
//  Copyright © 2018 Xie Liwei. All rights reserved.
//

import UIKit
import SwiftDate
import CloudKit
import NVActivityIndicatorView
class NoteViewController: UIViewController,UITextViewDelegate {
    @IBOutlet weak var noteTextView: UITextView!
    @IBOutlet weak var indicatorBackgourndView: UIView!
    @IBOutlet weak var indicatorView: NVActivityIndicatorView!
    
    var date: Date?
    let database = CKContainer.default().privateCloudDatabase

    override func viewDidLoad() {
        super.viewDidLoad()
        noteTextView.delegate = self
        noteTextView.becomeFirstResponder()
        setTitle()
        displayDefaultText()
        setupIndicatorView()
    }
    
    func setTitle() {
        guard let date = date else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy EEEE"
        let dateString = formatter.string(from: date)
        title = dateString
    }
    
    func displayDefaultText() {
        let user = UserDefaults.standard
        guard let date = date else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let dateString = formatter.string(from: date)
        guard let noteString = user.string(forKey: "\(dateString)") else { return }
        noteTextView.text = noteString
    }
    
    func setupIndicatorView() {
        indicatorBackgourndView.layoutIfNeeded()
        let blur = createBlursOnView(view: indicatorBackgourndView)
        indicatorBackgourndView.addSubview(blur)
        indicatorBackgourndView.sendSubview(toBack: blur)
        indicatorBackgourndView.alpha = 0
        indicatorView.color = UIColor.noNoteGreen()
        indicatorView.type = .lineScalePulseOut
    }
    
    func showIndicatorView() {
        indicatorBackgourndView.alpha = 0.6
        indicatorView.startAnimating()
    }
    
    @IBAction func finishedNote(_ sender: Any) {
        if noteTextView.text == "" {
            completedDiary()
            return
        }
        let user = UserDefaults.standard
        guard let date = date else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let dateString = formatter.string(from: date)
        formatter.dateFormat = "M-yyyy"
        let monthString = formatter.string(from: date)
        user.set(noteTextView.text, forKey: "\(dateString)")
        user.set(true, forKey: "\(dateString)IsSet")
        showIndicatorView()
        checkIfDiaryExsit(date: dateString, month: monthString)
    }
    
    func checkIfDiaryExsit(date:String, month:String) {
        let predicate = NSPredicate(format: "diaryDate == %@", date)
        let query = CKQuery(recordType: "Diary", predicate: predicate)
        database.perform(query, inZoneWith: nil) { (diaries, error) in
            if let error = error {
                self.showAlertWhenCannotConnectToICloud()
                print(error.localizedDescription)
            } else {
                guard let diaries = diaries else { return }
                if diaries.count != 0 {
                    let record = diaries[0]
                    record.setObject(self.noteTextView.text as CKRecordValue, forKey: "diary")
                    self.database.save(record, completionHandler: { (record, error) in
                        if error == nil {
                            self.completedDiary()
                        }
                    })
                } else {
                    self.uploadDiaryToICloud(date: date, month: month)
                }
            }
        }
    }
    
    func uploadDiaryToICloud(date:String, month:String) {
        let record = CKRecord(recordType: "Diary")
        record.setObject(date as CKRecordValue, forKey: "diaryDate")
        record.setObject(month as CKRecordValue, forKey: "diaryDayAndMonth")
        record.setObject(noteTextView.text as CKRecordValue, forKey: "diary")
        database.save(record) { (savedRecord, error) in
            if let error = error {
                self.showAlertWhenCannotConnectToICloud()
                debugPrint(error)
            } else {
                self.completedDiary()
            }
        }
    }
    
    func completedDiary() {
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func showAlertWhenCannotConnectToICloud() {
        if UserDefaults.standard.bool(forKey: "dontShowAlert") {
            completedDiary()
            return
        }
        let alert = UIAlertController(title: NSLocalizedString("#oops", comment: ""), message: NSLocalizedString("#saveToICloundError", comment: ""), preferredStyle: .alert)
        let ok = UIAlertAction(title: NSLocalizedString("#ok", comment: ""), style: .cancel) { (action) in
            self.completedDiary()
        }
        
        let dontShowAgain = UIAlertAction(title: NSLocalizedString("#dontShowAlert", comment: ""), style: .default) { (action) in
            UserDefaults.standard.set(true, forKey: "dontShowAlert")
            self.completedDiary()
        }
        
        alert.addAction(ok)
        alert.addAction(dontShowAgain)
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
}
