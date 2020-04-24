//
//  HomeViewController.swift
//  DSDownload-macOS
//
//  Created by Thomas le Gravier on 05/02/2019.
//

import Cocoa
import RealmSwift
import RxSwift
import RxCocoa
import RxRealm

class HomeViewController: NSViewController {
    
    static func setup() -> HomeViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("HomeViewController")
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? HomeViewController else {fatalError("HomeViewController not found - Check Main.storyboard")}
        return viewcontroller
    }
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var progressView: NSProgressIndicator!
    
    @IBOutlet weak var downStatisticField: NSTextField!
    @IBOutlet weak var upStatisticField: NSTextField!
    @IBOutlet weak var addTaskField: NSTextField!
    @IBOutlet weak var addTaskButton: NSButton!
    @IBOutlet weak var shieldIndicator: NSImageView!
    
    @IBOutlet weak var errorView: NSView!
    @IBOutlet weak var errorMessage: NSTextField!
    
    @IBOutlet weak var bottomView: NSView!
    
    @IBOutlet weak var loginName: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    // MARK: Actions
    
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        let task = tasks[tableView.clickedRow]
        
        guard [Task.StatusType.finishing.rawValue, Task.StatusType.finished.rawValue, Task.StatusType.error.rawValue].contains(task.status) == false else {return}

        if task.status == Task.StatusType.paused.rawValue {
            taskManager.resume(task) { [weak self] (result) in
                guard !result else {return}
                DispatchQueue.main.async {
                    self?.showErrorMessage("An error occurred")
                }
            }
        } else {
            taskManager.pause(task) { [weak self] (result) in
                guard !result else {return}
                DispatchQueue.main.async {
                    self?.showErrorMessage("An error occurred")
                }
            }
        }
    }
    
    @objc func tableViewDeleteTask(_ sender: AnyObject) {
        let selectedRows = tableView.selectedRowIndexes
        guard selectedRows.isEmpty == false else {return}

        let selectedTasks = selectedRows.map({tasks[$0]})
        taskManager.delete(selectedTasks) { [weak self] (result) in
            guard !result else {return}
            DispatchQueue.main.async {
                self?.showErrorMessage("An error occurred")
            }
        }
    }
    
    @IBAction func addTaskAction(_ sender: Any) {
        if addTaskField.isHidden {
            showAddTaskField()
        } else {
            let magnet = addTaskField.stringValue.lowercased()
            if magnet == "" {
                hideAddTaskField()
            } else if !magnet.hasPrefix("magnet:") {
                showErrorMessage("Magnet link format error")
            } else {
                hideAddTaskField()
                taskManager.add(magnet) { [weak self] (result) in
                    guard !result else {return}
                    DispatchQueue.main.async {
                        self?.showErrorMessage("An error occurred")
                    }
                }
            }
        }
    }
    
    @IBAction func willExitAction(_ sender: Any) {
        guard let event = NSApplication.shared.currentEvent else {return}
        NSMenu.popUpContextMenu(exitContextMenu, with: event, for: sender as! NSView)
    }
    
    // MARK: Private
    
    private let dataManager = DBManager.shared
    private let sessionManager = SessionManager.shared
    private let taskManager = TaskManager.shared
    
    private let taskContextMenu = NSMenu()
    private let exitContextMenu = NSMenu()
    
    private let disposeBag = DisposeBag()
    
    private var tasks: [Task] {
        return dataManager.realmContent.objects(Task.self).sorted(by: { $0.createTime > $1.createTime})
    }
    
    private func configure() {
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
        configureUI()
        configureMenus()
        configureObservers()
        refreshLoadingState()
    }
    
    private func configureUI() {
        // VPN indicator
        shieldIndicator.alphaValue = 0.8
        
        // Error view
        errorView.wantsLayer = true
        errorView.layer?.backgroundColor = NSColor(calibratedRed: 0.91, green: 0.30, blue: 0.24, alpha: 1.0).cgColor
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
                self?.shieldIndicator.image = #imageLiteral(resourceName: "shield_ico.png").tint(color: results.filter({$0.status == "connected"}).isEmpty == false ? .green : .red)
            }
        }).disposed(by: disposeBag)
        
        // Statistics observer
        Observable.changeset(from: dataManager.realmContent.objects(Statistic.self)).subscribe(onNext: { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.downStatisticField.isHidden = results.isEmpty
                self?.upStatisticField.isHidden = results.isEmpty
                guard let statistics = results.first else {return}
                self?.downStatisticField.stringValue = "↓ \(Tools.convertBytes(statistics.speedDownload)) mb/s"
                self?.upStatisticField.stringValue = "↑ \(Tools.convertBytes(statistics.speedUpload)) mb/s"
            }
        }).disposed(by: disposeBag)
        
        // Tasks observer
        Observable.changeset(from: dataManager.realmContent.objects(Task.self)).subscribe(onNext: { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }).disposed(by: disposeBag)
    }
    
    private func sessionDidChange() {
        guard sessionManager.state.value == SessionManager.State.notConnected.rawValue else {return}
        AppDelegate.shared.popover.contentViewController = LoginViewController.setup()
        AppDelegate.shared.popover.contentSize = NSSize(width: 300, height: 270)
    }
    
    private func refreshLoadingState() {
        // Loading state
        if sessionManager.state.value == SessionManager.State.pendingValidation.rawValue || taskManager.state.value == TaskManager.State.actionRunning.rawValue {
            startLoading()
        } else {
            endLoading()
        }
        
        // Account name
        if let account = sessionManager.session?.account {
            loginName.stringValue = account
        } else {
            loginName.isHidden = true
        }
    }
    
    private func configureMenus() {
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(tableViewDeleteTask(_:)), keyEquivalent: "d")
        taskContextMenu.addItem(deleteItem)
        tableView.menu = taskContextMenu
        
        let logoutItem = NSMenuItem(title: "Logout", action: #selector(willLogout(_:)), keyEquivalent: "l")
        let exitAppItem = NSMenuItem(title: "Exit", action: #selector(willExit(_:)), keyEquivalent: "q")
        exitContextMenu.addItem(logoutItem)
        exitContextMenu.addItem(exitAppItem)
    }
    
    @objc private func willLogout(_ sender: AnyObject) {
        startLoading()
        sessionManager.logout()
    }
    
    @objc private func willExit(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    // MARK: Textfield
    
    private func hideAddTaskField() {
        addTaskField.isHidden = true
        addTaskField.stringValue = ""
        addTaskButton.stringValue = "Add"
        addTaskField.isEnabled = false
    }
    
    private func showAddTaskField() {
        addTaskField.isHidden = false
        addTaskButton.stringValue = "OK"
        addTaskField.isEnabled = true
        addTaskField.window?.makeFirstResponder(addTaskField)
    }
    
    // MARK: Loading
    
    private func startLoading() {
        tableView.deselectAll(nil)
        tableView.isEnabled = false
        tableView.alphaValue = 0.5
        
        addTaskButton.isEnabled = false
        
        progressView.isHidden = false
        progressView.startAnimation(nil)
    }
    
    private func endLoading() {
        tableView.isEnabled = true
        tableView.alphaValue = 1
        
        addTaskButton.isEnabled = true
        
        progressView.isHidden = true
        progressView.stopAnimation(nil)
    }
    
    // MARK: Error message
    
    private func showErrorMessage(_ message: String) {
        errorMessage.stringValue = message
        errorView.isHidden = false
        bottomView.isHidden = true
        let deadlineTime = DispatchTime.now() + .seconds(4)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
            self.hideErrorMessage()
        })
    }
    
    private func hideErrorMessage() {
        errorView.isHidden = true
        bottomView.isHidden = false
    }
}

extension HomeViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tasks.count
    }
}

extension HomeViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let nameCell = "TaskNameCellId"
        static let sizeCell = "TaskSizeCellId"
        static let speedCell = "TaskSpeedCellId"
        static let progressCell = "TaskProgressCellId"
        static let statusCell = "TaskStatusCellId"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""
        
        let task = tasks[row]
        
        if tableColumn == tableView.tableColumns[0] { // Name
            text = task.title
            cellIdentifier = CellIdentifiers.nameCell
        } else if tableColumn == tableView.tableColumns[1] { // Size
            text = task.sizeDescription
            cellIdentifier = CellIdentifiers.sizeCell
        } else if tableColumn == tableView.tableColumns[2] {  // Speed
            text = task.speed ?? ""
            cellIdentifier = CellIdentifiers.speedCell
        } else if tableColumn == tableView.tableColumns[3] { // Progress
            if let p = task.progress {
                let value = p * 100
                if value - Double(Int(value)) != 0 {
                    text = "\(String(format: "%.2f", (p * 100)))%"
                } else {
                    text = "\(Int(value))%"
                }
            }
            cellIdentifier = CellIdentifiers.progressCell
        } else if tableColumn == tableView.tableColumns[4] { // Status
            text = task.status
            cellIdentifier = CellIdentifiers.statusCell
        }
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        hideAddTaskField()
    }
}
