//
//  TaskDetailsViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 25/04/2020.
//

import UIKit
import RealmSwift
import RxSwift
import RxCocoa
import RxRealm

class TaskDetailsViewController: UITableViewController {
    @IBAction func dismissController(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBOutlet weak var filenameField: UILabel!
    @IBOutlet weak var destinationField: UILabel!
    @IBOutlet weak var fileSizeField: UILabel!
    @IBOutlet weak var usernameField: UILabel!
    @IBOutlet weak var creationDateField: UILabel!
    
    @IBOutlet weak var statusField: UILabel!
    @IBOutlet weak var progressField: UILabel!
    @IBOutlet weak var transferredField: UILabel!
    @IBOutlet weak var connectedPairs: UILabel!
    @IBOutlet weak var speedField: UILabel!
    @IBOutlet weak var timeLeftField: UILabel!
    
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    var taskID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateDisplay()
        configureObservers()
    }
    
    // MARK: Private
    
     private let dataManager = DBManager.shared
    private let taskManager = TaskManager.shared
    
    private let disposeBag = DisposeBag()
    
    private func updateDisplay() {
        guard let task = dataManager.realmContent.objects(Task.self).filter({ $0.id == self.taskID }).first else { return }
        guard let transfer = task.additional?.transfer else { return }
        guard let detail = task.additional?.detail else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = .current
        
        let intervalFormatter = DateComponentsFormatter()
        intervalFormatter.allowedUnits = [.day, .hour, .minute, .second]
        intervalFormatter.unitsStyle = .abbreviated
        intervalFormatter.maximumUnitCount = 2
        
        filenameField.text = task.title
        destinationField.text = detail.destination
        fileSizeField.text = Tools.prettyPrintNumber(task.size) + "b"
        usernameField.text = task.username
        creationDateField.text = dateFormatter.string(from: Date(timeIntervalSince1970: Double(detail.createTime)))
        
        statusField.text = task.status.capitalized
        progressField.text = String(format: "%.1f", Float(transfer.sizeDownloaded) / Float(task.size) * 100) + " %"
        transferredField.text = "↑ \(Tools.prettyPrintNumber(transfer.sizeUploaded))b - ↓ \(Tools.prettyPrintNumber(transfer.sizeDownloaded))b"
        speedField.text = "↑ \(Tools.prettyPrintNumber(transfer.speedUpload))b/s - ↓ \(Tools.prettyPrintNumber(transfer.speedDownload))b/s"
        timeLeftField.text = (task.remainingTime == nil) ? "Unknown" : intervalFormatter.string(from: Double(task.remainingTime!))
    }
    
    private func configureObservers() {
        // Tasks observer
        Observable.changeset(from: dataManager.realmContent.objects(Task.self)).subscribe(onNext: { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.updateDisplay()
            }
        }).disposed(by: disposeBag)
    }
}
