//
//  TaskDetailsViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 25/04/2020.
//

import UIKit

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
    
    var task: Task?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateDisplay()
    }
    
    // MARK: Private
    
    private func updateDisplay() {
        guard let task = task else { return }
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
}
