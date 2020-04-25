//
//  TasksViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 24/04/2020.
//

import Foundation
import RealmSwift
import RxSwift
import RxCocoa
import RxRealm

class TasksViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var vpnIndicator: UIBarButtonItem!
    
    @IBAction func didTapLogout(_ sender: Any) {
        sessionManager.logout()
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureObservers()
        refreshLoadingState()
    }
    
    // MARK: Private
    
    private let dataManager = DBManager.shared
    private let sessionManager = SessionManager.shared
    private let taskManager = TaskManager.shared
    
    private let disposeBag = DisposeBag()
    
    private var tasks: [Task] {
        return dataManager.realmContent.objects(Task.self).sorted(by: { $0.createTime > $1.createTime})
    }
    
    private func configureObservers() {
        // Session observer
        sessionManager.state.subscribe(onNext: { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshLoadingState()
                self?.sessionDidChange()
            }
        }).disposed(by: disposeBag)
        
        // Task manager state observer
        taskManager.state.subscribe(onNext: { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshLoadingState()
            }
        }).disposed(by: disposeBag)
        
        // VPN profile observer
        Observable.changeset(from: dataManager.realmContent.objects(VPNProfile.self)).subscribe(onNext: { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.vpnIndicator.image = results.filter({$0.status == "connected"}).isEmpty == false ? UIImage(systemName: "shield") : UIImage(systemName: "shield.slash")
            }
        }).disposed(by: disposeBag)
        
        // Statistics observer
        Observable.changeset(from: dataManager.realmContent.objects(Statistic.self)).subscribe(onNext: { [weak self] _, _ in
            DispatchQueue.main.async {
                if !(self?.tableView?.isEditing ?? true) { self?.tableView?.reloadData() }
            }
        }).disposed(by: disposeBag)
        
        // Tasks observer
        Observable.changeset(from: dataManager.realmContent.objects(Task.self)).subscribe(onNext: { [weak self] results, _ in
            DispatchQueue.main.async {
                if !(self?.tableView?.isEditing ?? true) { self?.tableView?.reloadData() }
            }
        }).disposed(by: disposeBag)
    }
    
    private func sessionDidChange() {
        guard sessionManager.state.value == SessionManager.State.notConnected.rawValue else { return }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    private func refreshLoadingState() {
        // Loading state
        if sessionManager.state.value == SessionManager.State.pendingValidation.rawValue || taskManager.state.value == TaskManager.State.actionRunning.rawValue {
            startLoading()
        } else {
            endLoading()
        }
        
        // Account name
        if let accountName = sessionManager.session?.account {
            navigationItem.prompt = "Connected as \(accountName)"
        } else {
            navigationItem.prompt = "Not connected"
        }
    }
    
    // MARK: Loading
    
    private func startLoading() {
        if let selectedRowIndex = tableView?.indexPathForSelectedRow {
            tableView?.deselectRow(at: selectedRowIndex, animated: true)
        }
        
        tableView?.isUserInteractionEnabled = false
        tableView?.alpha = 0.5
        
        addButton.isEnabled = false
        
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }
    
    private func endLoading() {
        tableView?.reloadData()
        
        tableView?.isUserInteractionEnabled = true
        tableView?.alpha = 1
        
        addButton.isEnabled = true
        
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }
    
    private func showErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        
        let OKButton = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(OKButton)
        
        present(alert, animated: true, completion: nil)
    }
}

extension TasksViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let statistics = dataManager.realmContent.objects(Statistic.self).first else { return "↑ 0 kb/s - ↓ 0 kb/s" }
        
        let downStatistic = "↓ \(Tools.prettyPrintNumber(statistics.speedDownload))b/s"
        let upStatistic = "↑ \(Tools.prettyPrintNumber(statistics.speedUpload))b/s"
        
        return "\(upStatistic) - \(downStatistic)"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let task = tasks[indexPath.row]
        
        let identifier = "cellIdentifier"
        
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        
        cell.textLabel?.text = task.title
        
        cell.accessoryType = .disclosureIndicator
        
        if let transfer = task.additional?.transfer {
            let completion = Float(transfer.sizeDownloaded) / Float(task.size) * 100
            cell.detailTextLabel?.text = "\(task.status.capitalized) - \(String(format:"%.1f", completion)) % - ↑ \(Tools.prettyPrintNumber(transfer.speedUpload))b/s - ↓ \(Tools.prettyPrintNumber(transfer.speedDownload))b/s"
        }
        
        return cell
    }
}

extension TasksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let task = tasks[indexPath.row]
        
        let pauseAction = UIContextualAction(style: .normal, title: (task.status == Task.StatusType.downloading.rawValue) ? "Pause" : "Resume", handler: { [weak self] _,_,_ in
            DispatchQueue.main.async {
                self?.startLoading()
            }
            
            if task.status == Task.StatusType.downloading.rawValue {
                self?.taskManager.pause(task) { [weak self] (result) in
                    DispatchQueue.main.async {
                        self?.endLoading()
                    }
                    
                    guard !result else { return }
                    DispatchQueue.main.async {
                        self?.showErrorMessage("An error occurred")
                    }
                }
            } else {
                self?.taskManager.resume(task) { [weak self] (result) in
                    DispatchQueue.main.async {
                        self?.endLoading()
                    }
                    
                    guard !result else {return}
                    DispatchQueue.main.async {
                        self?.showErrorMessage("An error occurred")
                    }
                }
            }
        })
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete", handler: { [weak self] _,_,_ in
            DispatchQueue.main.async {
                self?.startLoading()
            }
            
            self?.taskManager.delete([task]) { [weak self] (result) in
                DispatchQueue.main.async {
                    self?.endLoading()
                    
                    guard !result else {
                        return
                    }
                    
                    self?.showErrorMessage("An error occurred")
                }
            }
        })
        
        if task.status == Task.StatusType.downloading.rawValue || task.status == Task.StatusType.paused.rawValue {
            return UISwipeActionsConfiguration(actions: [deleteAction, pauseAction])
        }
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
