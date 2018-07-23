//
//  CalendarViewController.swift
//  NoNote
//
//  Created by Xie Liwei on 14/07/2018.
//  Copyright © 2018 Xie Liwei. All rights reserved.
//

import UIKit
import SwiftDate
import FSCalendar
import CloudKit
class CalendarViewController: UIViewController, FSCalendarDelegate, FSCalendarDataSource{
    @IBOutlet weak var calendar: FSCalendar!
    @IBOutlet weak var nowButton: UIButton!
    
    @IBOutlet weak var writeButton: UIButton!
    
    var selectedDate: Date?
    var hasDiaryDates = [String]()
    let database = CKContainer.default().privateCloudDatabase
    override func viewDidLoad() {
        super.viewDidLoad()
        calendar.delegate = self
        calendar.dataSource = self
        calendar.placeholderType = .none
        calendar.today = nil
        calendar.appearance.titleFont = UIFont(name: "Roboto-Medium", size: 15)
        calendar.appearance.weekdayFont = UIFont(name: "Roboto-Bold", size: 17)
        calendar.appearance.headerTitleFont = UIFont(name: "Roboto-Regular", size: 17)
        updateUI()
        fetchDiariesOfCurrentMonth()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        calendar.reloadData()
    }
    
    func updateUI() {
        nowButton.layer.cornerRadius = 28
        writeButton.layer.cornerRadius = 28
        writeButton.setTitle(NSLocalizedString("#write", comment: ""), for: .normal)
        nowButton.setTitle(NSLocalizedString("#now", comment: ""), for: .normal)
        nowButton.layer.borderColor = UIColor.noNoteGreen().cgColor
        nowButton.layer.borderWidth = 2
    }
    
    func fetchDiariesOfCurrentMonth() {
        let month = Date().month
        let year = Date().year
        fetchDiary(monthAndYear: "\(month)-\(year)") {
            
        }
    }
    
    @IBAction func returnToToday(_ sender: Any) {
        calendar.setCurrentPage(Date(), animated: true)
        calendar.select(Date())
    }
    
    @IBAction func addNewNote(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "NoteViewController") as! NoteViewController
        vc.date = selectedDate ?? Date()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    //MARK:- Calendar delegate
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date
    }
    
    func calendar(_ calendar: FSCalendar, imageFor date: Date) -> UIImage? {
        let formater = DateFormatter()
        formater.dateFormat = "M-d-yyyy"
        let dateString = formater.string(from: date)
        let isSet = UserDefaults.standard.bool(forKey: "\(dateString)IsSet")
        if isSet {
            print("\(dateString)IsSet")
        }
        return isSet ? UIImage(named: "sheepIcon") : nil
    }
    
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        let month = (calendar.currentPage + 1.days).month
        let year = (calendar.currentPage + 1.days).year
        fetchDiary(monthAndYear: "\(month)-\(year)") {
            DispatchQueue.main.async {
                self.calendar.reloadData()
            }
        }
    }
    
    //MARK:- Alert
    func showAlertWhenCannotConnectToICloud() {
        if UserDefaults.standard.bool(forKey: "dontShowAlert") {
            return
        }
        let alert = UIAlertController(title: NSLocalizedString("#oops", comment: ""), message: NSLocalizedString("#cannotConnectToICloud", comment: ""), preferredStyle: .alert)
        let ok = UIAlertAction(title: NSLocalizedString("#ok", comment: ""), style: .cancel)
        let dontShowAgain = UIAlertAction(title: NSLocalizedString("#dontShowAlert", comment: ""), style: .default) { (action) in
            UserDefaults.standard.set(true, forKey: "dontShowAlert")
        }
        alert.addAction(ok)
        alert.addAction(dontShowAgain)
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
}
