//
//  NotificationManager.swift
//  DSDownload-macOS
//
//  Created by Thomas LE GRAVIER on 02/05/2020.
//

import Foundation
import RealmSwift
import RxSwift
import RxCocoa

class NotificationManager {
    
    // MARK: Singleton
    
    static let shared = NotificationManager()
    
    // MARK: Init
    
    init() {
        configure()
    }
    
    deinit {
        globalNotificationToken?.invalidate()
        completedNotificationToken?.invalidate()
    }
    
    // MARK: Private
    
    private let dataManager = DBManager.shared
    private let sessionManager = SessionManager.shared
    private let taskManager = TaskManager.shared
    
    private let disposeBag = DisposeBag()
    
    private var taskManagerAsyncState: Int?
    
    private var globalNotificationToken: NotificationToken?
    private var completedNotificationToken: NotificationToken?
    
    private func configure() {
        // Task manager state observer
        taskManager.state.subscribe(onNext: { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.taskManagerAsyncState = self?.taskManager.state.value
            }
        }).disposed(by: disposeBag)
        
        // Global tasks observer
        globalNotificationToken = dataManager.realmContent.objects(Task.self).observe { [weak self] (changes) in
            // Be sure user is connected
            guard self?.sessionManager.state.value == SessionManager.State.connected.rawValue else {return}
            
            // Analyse changes only after a user action
            guard self?.taskManagerAsyncState == TaskManager.State.actionRunning.rawValue else {return}
            
            switch changes {
            case .update(let results, _, let insertions, _):
                for i in insertions {
                    guard i < results.count else {continue}
                    self?.notify(with: "added-\(results[i].id)", title: NSLocalizedString("Notification.added.title", comment: ""), text: results[i].title)
                }
            case .initial, .error: break
            }
        }
        
        // Completed tasks observer
        completedNotificationToken = dataManager.realmContent.objects(Task.self).filter("status = %@", Task.StatusType.finished.rawValue).observe { [weak self] (changes) in
            // Be sure user is connected
            guard self?.sessionManager.state.value == SessionManager.State.connected.rawValue else {return}
            
            // Analyse changes only when task manager running
            guard self?.taskManagerAsyncState == TaskManager.State.running.rawValue || self?.taskManagerAsyncState == TaskManager.State.actionRunning.rawValue else {return}
            
            switch changes {
            case .update(let results, _, let insertions, _):
                for i in insertions {
                    guard i < results.count else {continue}
                    self?.notify(with: "completed-\(results[i].id)", title: NSLocalizedString("Notification.completed.title", comment: ""), text: results[i].title)
                }
            case .initial, .error: break
            }
        }
    }
    
    // MARK: Helpers
    
    private func notify(with id: String, title: String, subtitle: String? = nil, text: String? = nil) {
        // cf : https://blog.gaelfoppolo.com/user-notifications-in-macos-66c25ed5c692
        
        let notification = NSUserNotification()
        notification.identifier = id
        notification.title = title
        notification.subtitle = subtitle
        notification.informativeText = text
        
        // Display notification
        let notificationCenter = NSUserNotificationCenter.default
        notificationCenter.deliver(notification)
    }
}
