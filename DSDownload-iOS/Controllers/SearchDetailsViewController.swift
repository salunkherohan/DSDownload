//
//  SearchDetailsViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 26/04/2020.
//

import UIKit
import RealmSwift
import RxSwift
import RxCocoa
import RxRealm

class SearchDetailsViewController: UITableViewController {
    
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBAction func add(_ sender: Any) {
        guard let item = dataManager.realmContent.objects(Item.self).filter({ $0.result_id == self.itemID }).first else { return }
        
        startLoading()
        
        let magnet = item.dlurl
        
        if !magnet.hasPrefix("magnet:") {
            showErrorMessage("Magnet link format error")
            endLoading()
        } else {
            let taskManager = TaskManager.shared
            
            taskManager.add(magnet) { [weak self] (result) in
                DispatchQueue.main.async {
                    self?.endLoading()
                    
                    guard !result else {
                        self?.dismiss(animated: true, completion: nil)
                        return
                    }
                    
                    self?.showErrorMessage("An error occurred")
                }
            }
        }
    }
    
    @IBOutlet weak var titleField: UILabel!
    @IBOutlet weak var dateField: UILabel!
    @IBOutlet weak var categoryField: UILabel!
    @IBOutlet weak var pageCell: UITableViewCell!
    @IBOutlet weak var pageField: UILabel!
    
    @IBOutlet weak var sizeField: UILabel!
    @IBOutlet weak var peersField: UILabel!
    
    @IBOutlet weak var dURLField: UILabel!
    
    var itemID: Int?
    
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
        guard let item = dataManager.realmContent.objects(Item.self).filter({ $0.result_id == self.itemID }).first else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = .current
        
        titleField.text = item.title
        dateField.text = dateFormatter.string(from: item.date)
        categoryField.text = item.category
        pageField.text = item.page
        
        sizeField.text = "\(Tools.prettyPrintNumber(item.size))b"
        peersField.text = "\(item.peers)/\(item.leechs)"
        dURLField.text = item.dlurl
    }
    
    private func configureObservers() {
        // Tasks observer
        Observable.changeset(from: dataManager.realmContent.objects(Item.self)).subscribe(onNext: { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.updateDisplay()
            }
        }).disposed(by: disposeBag)
    }
    
    // MARK: Loading
    
    private func startLoading() {
        if let selectedRowIndex = tableView?.indexPathForSelectedRow {
            tableView?.deselectRow(at: selectedRowIndex, animated: true)
        }
        
        tableView?.isUserInteractionEnabled = false
        
        cancelButton.isEnabled = false
        addButton.isEnabled = false
    }
    
    private func endLoading() {
        tableView?.isUserInteractionEnabled = true
        
        cancelButton.isEnabled = true
        addButton.isEnabled = true
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataManager.realmContent.objects(Item.self).filter({ $0.result_id == self.itemID }).first else { return }
        
        if tableView.cellForRow(at: indexPath) == pageCell {
            if let url = URL(string: item.page) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
