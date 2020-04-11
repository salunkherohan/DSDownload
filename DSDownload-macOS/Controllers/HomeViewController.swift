//
//  HomeViewController.swift
//  DSDownload-macOS
//
//  Created by Thomas le Gravier on 05/02/2019.
//

import Cocoa
import RealmSwift


class HomeViewController: NSViewController {

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
    
    static func setup(fromLogin: Bool = false) -> HomeViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("HomeViewController")
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? HomeViewController else {
            fatalError("HomeViewController not found - Check Main.storyboard")
        }
        viewcontroller.launchFromLogin = fromLogin
        
        return viewcontroller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureMenus()
        
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        startLoading()
        if !launchFromLogin {
            sessionManager.testReachability(success: {
                self.initCommonTasks()
            }) {
                self.finishLogout()
            }
        } else {
            initCommonTasks()
        }
        
        /* Account name */
        if let account = SessionService.shared.session?.account {
            loginName.stringValue = account
        } else {
            loginName.isHidden = true
        }
        
        /* VPN indicator */
        shieldIndicator.alphaValue = 0.8
        
        /* Error view */
        errorView.wantsLayer = true
        errorView.layer?.backgroundColor = NSColor(calibratedRed: 0.91, green: 0.30, blue: 0.24, alpha: 1.0).cgColor
        
        /* Session expired observer */
        NotificationCenter.default.addObserver(self, selector: #selector(finishLogout(_:)), name: .sessionExpired, object: nil)
    }
    
    // Mark : Actions
    
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        let task = tasks[tableView.clickedRow]
        guard task.status != TasksManager.State.finished.rawValue && task.status != TasksManager.State.finishing.rawValue && task.status != TasksManager.State.error.rawValue else {return}
        
        if task.status == TasksManager.State.paused.rawValue {
            startLoading()
            tasksManager.resume(task, success: {
                self.refreshTasks(completion: {
                    self.endLoading()
                })
            }) {
                self.endLoading()
                self.showErrorMessage("Oups error on resume task")
            }
        } else {
            startLoading()
            tasksManager.pause(task, success: {
                self.refreshTasks(completion: {
                    self.endLoading()
                })
            }) {
                self.endLoading()
                self.showErrorMessage("Oups error on pause task")
            }
        }
    }
    
    @objc func tableViewDeleteTask(_ sender: AnyObject) {
        let selectedTasks = tableView.selectedRowIndexes
        guard selectedTasks.count > 0 else {return}
        
        var selectedT: [Task] = []
        for i in selectedTasks {
            selectedT.append(tasks[i])
        }
        
        startLoading()
        tasksManager.delete(selectedT, success: {
            self.refreshTasks(completion: {
                self.endLoading()
            })
        }) {
            self.endLoading()
            self.showErrorMessage("Oups error on deletion")
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
                startLoading()
                tasksManager.add(magnet, success: {
                    self.hideAddTaskField()
                    self.refreshTasks(completion: {
                        self.endLoading()
                    })
                }) { (error) in
                    self.endLoading()
                    self.showErrorMessage(error?.localizedDescription ?? "Oups error on add")
                }
            }
        }
    }
    
    @IBAction func willExitAction(_ sender: Any) {
        guard let event = NSApplication.shared.currentEvent else {return}
        NSMenu.popUpContextMenu(exitContextMenu, with: event, for: sender as! NSView)
    }
    
    // Mark : Private
    
    private let tasksManager = TasksManager()
    private let sessionManager = SessionManager()
    private let networkManager = NetworkManager()
    
    private let taskContextMenu = NSMenu()
    private let exitContextMenu = NSMenu()
    
    private var launchFromLogin = false
    
    private var refreshVPNTimer: Timer?
    private var refreshTasksTimer: Timer?
    private var refreshStatisticsTimer: Timer?
    
    private var tasks = List<Task>() {
        didSet {
            tableView.reloadData()
        }
    }
    
    private func initCommonTasks() {
        /* Setup timers */
        setupRefreshDataTimers()
        
        /* Refresh immediatly */
        refreshVPN()
        resfreshStatistics()
        refreshTasks() {
            self.endLoading()
        }
    }
    
    private func setupRefreshDataTimers() {
        let haActiveTasks = tasksManager.haActiveTasks()
        let vpnInterval = DSDownloadConstants.VPNIntervalRefresh
        let taskInterval = haActiveTasks ? DSDownloadConstants.tasksIntervalRefreshForActive : DSDownloadConstants.tasksIntervalRefreshForInActive
        let statInterval = haActiveTasks ? DSDownloadConstants.statisticsIntervalRefreshForActive : DSDownloadConstants.statisticsIntervalRefreshForInActive
        
        /* Setup VPN timer if necessary */
        if (refreshVPNTimer?.timeInterval ?? 0) != vpnInterval {
            refreshVPNTimer?.invalidate()
            refreshVPNTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(vpnInterval), repeats: true, block: { (timer) in
                self.refreshVPN()
            })
        }
        
        /* Setup task timer if necessary */
        if (refreshTasksTimer?.timeInterval ?? 0) != taskInterval {
            refreshTasksTimer?.invalidate()
            refreshTasksTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(taskInterval), repeats: true, block: { (timer) in
                self.refreshTasks()
            })
        }
        
        /* Setup statistics timer if necessary */
        if (refreshStatisticsTimer?.timeInterval ?? 0) != statInterval {
            refreshStatisticsTimer?.invalidate()
            refreshStatisticsTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(statInterval), repeats: true, block: { (timer) in
                self.resfreshStatistics()
            })
        }
    }
    
    private func configureMenus() {
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(tableViewDeleteTask(_:)), keyEquivalent: "d")
        taskContextMenu.addItem(deleteItem)
        tableView.menu = taskContextMenu
        
        let logoutItem = NSMenuItem(title: "Logout", action: #selector(willLogout(_:)), keyEquivalent: "l")
        let exitAppItem = NSMenuItem(title: "Exit", action: #selector(willExit(_:)), keyEquivalent: "q")
        let settingsAppItem = NSMenuItem(title: "Settings", action: #selector(showSettings(_:)), keyEquivalent: ",")
        exitContextMenu.addItem(logoutItem)
        exitContextMenu.addItem(exitAppItem)
        exitContextMenu.addItem(settingsAppItem)
    }
    
    private func refreshVPN(completion: (() -> ())? = nil) {
        networkManager.vpn({ (profiles) in
            let connectedProfiles = profiles.filter { $0.status == "connected" }
            self.shieldIndicator.image = #imageLiteral(resourceName: "shield_ico.png").tint(color: connectedProfiles.count > 0 ? .green : .red)
        }, error: {
            self.shieldIndicator.image = #imageLiteral(resourceName: "shield_ico.png").tint(color: .red)
        })
    }
    
    private func refreshTasks(completion: (() -> ())? = nil) {
        tasksManager.all({ (tasks) in
            self.tasks = tasks
            self.setupRefreshDataTimers()
            completion?()
        }, error: {
            self.showErrorMessage("An error occured. Please retry later.")
            completion?()
        })
    }
    
    private func resfreshStatistics() {
        StatisticManager().all({ (stats) in
            let up = DSDownloadTools.convertBytes(stats.speed_upload)
            let down = DSDownloadTools.convertBytes(stats.speed_download)
            self.downStatisticField.stringValue = "↓ \(down) mb/s"
            self.upStatisticField.stringValue = "↑ \(up) mb/s"
            self.setupRefreshDataTimers()
        }, error: {
            self.downStatisticField.stringValue = "↓ N/A"
            self.upStatisticField.stringValue = "↑ N/A"
        })
    }
    
    @objc private func willLogout(_ sender: AnyObject) {
        startLoading()
        sessionManager.logout(success: {
            self.finishLogout()
        }, error: {
            self.endLoading()
            self.showErrorMessage("Oups error on logout")
        })
    }
    
    @objc private func willExit(_ sender: AnyObject) {
        /* Shutdown app */
        NSApplication.shared.terminate(self)
    }
    
    @objc private func showSettings(_ sender: AnyObject) {
        print("OK show settings")
    }
    
    // Mark : Textfield
    
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
    
    // Mark : Loading
    
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
    
    // Mark : Error message
    
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
    
    // Mark : Logout
    
    @objc private func finishLogout(_ sender: AnyObject? = nil) {
        refreshTasksTimer?.invalidate()
        refreshStatisticsTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        SessionService.shared.reset()
        DispatchQueue.main.async {
            AppDelegate.shared.popover.contentViewController = LoginViewController.setup()
            AppDelegate.shared.popover.contentSize = NSSize(width: 300, height: 270)
        }
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
            text = task.sizeToString
            cellIdentifier = CellIdentifiers.sizeCell
        } else if tableColumn == tableView.tableColumns[2] {  // Speed
            text = task.speed
            cellIdentifier = CellIdentifiers.speedCell
        } else if tableColumn == tableView.tableColumns[3] { // Progress
            text = task.progress
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
