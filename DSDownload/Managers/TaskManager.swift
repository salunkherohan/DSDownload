//
//  TaskManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 07/02/2019.
//

import Foundation
import Alamofire
import SwiftyJSON
import RealmSwift
import RxSwift
import RxCocoa

class TaskManager {
    
    enum State: Int {
        case none
        case running
        case actionRunning
    }
    
    private(set) var state: BehaviorRelay<Int> = BehaviorRelay(value: 0) // Represent task manager state
    
    var haActiveTasks: Bool {
        let stopStates = [Task.StatusType.paused.rawValue, Task.StatusType.finished.rawValue, Task.StatusType.seeding.rawValue, Task.StatusType.error.rawValue]
        return dataManager.realmContent.objects(Task.self).filter("NOT (status IN %@)", stopStates).isEmpty == false
    }
    
    // MARK: Singleton
    
    static let shared = TaskManager()
    
    // MARK: Init
    
    init() {
        configure()
    }
    
    // MARK: Helpers
    
    func add(_ magnet: String, completion: ((_ result: Bool) -> ())? = nil) {
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "create",
            "version": 1,
            "uri": magnet
        ]
        configureAction(for: .post, params: params, encoding: URLEncoding(destination: .httpBody), completion: completion)
    }
    
    func add(_ file: URL, completion: ((_ result: Bool) -> ())? = nil) {
        guard let data = try? Data(contentsOf: file) else {completion?(false); return}
        let file = (data: data, name: "file", fileName: file.lastPathComponent, mimeType: "application/x-bittorrent")
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "create",
            "version": 1
        ]
        configureAction(for: .post, params: params, file: file, completion: completion)
    }
    
    func delete(_ tasks: [Task], completion: ((_ result: Bool) -> ())? = nil) {
        guard tasks.count > 0 else {completion?(false); return}
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "delete",
            "force_complete": false,
            "version": 1,
            "id": tasks.map{ return $0.id }.joined(separator: ",")
        ]
        configureAction(for: .get, params: params, completion: completion)
    }
    
    func pause(_ task: Task, completion: ((_ result: Bool) -> ())? = nil) {
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "pause",
            "version": 1,
            "id": task.id
        ]
        configureAction(for: .get, params: params, completion: completion)
    }
    
    func resume(_ task: Task, completion: ((_ result: Bool) -> ())? = nil) {
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "resume",
            "version": 1,
            "id": task.id
        ]
        configureAction(for: .get, params: params, completion: completion)
    }
    
    // MARK: Private
    
    private let dataManager = DBManager.shared
    private let sessionManager = SessionManager.shared
    
    private let retrieverOperationQueue = OperationQueue()
    private let actionOperationQueue = OperationQueue()
    
    private let disposeBag = DisposeBag()
    
    private func configure() {
        retrieverOperationQueue.name = "Retriever operations queue"
        retrieverOperationQueue.maxConcurrentOperationCount = 1
        retrieverOperationQueue.isSuspended = true
        
        actionOperationQueue.name = "Action operations queue"
        actionOperationQueue.maxConcurrentOperationCount = 1
        actionOperationQueue.isSuspended = true
        
        configureObservers()
    }
    
    private func configureObservers() {
        // Session observer
        sessionManager.state.asObservable().skip(1).subscribe(onNext: { [weak self] _ in
            self?.sessionDidChange()
        }).disposed(by: disposeBag)
    }
    
    private func sessionDidChange() {
        if sessionManager.isConnected {
            // Relaunch queues
            retrieverOperationQueue.isSuspended = false
            actionOperationQueue.isSuspended = false
            if actionOperationQueue.operations.isEmpty {configureRetriever(delay: 0)}
            
            // Update state
            let isFirstRetrieve = dataManager.realmContent.object(ofType: User.self, forPrimaryKey: 0)?.taskUpdateDate == nil
            state.accept(isFirstRetrieve || !actionOperationQueue.operations.isEmpty ? State.actionRunning.rawValue : State.running.rawValue)
        } else {
            state.accept(State.none.rawValue)
            
            // Stop & clear queues
            retrieverOperationQueue.isSuspended = true
            retrieverOperationQueue.cancelAllOperations()
            actionOperationQueue.isSuspended = true
            actionOperationQueue.cancelAllOperations()
        }
    }
    
    private func configureRetriever(delay: TimeInterval? = nil) {
        guard sessionManager.isConnected, actionOperationQueue.operations.isEmpty else {return}
        
        // Be sure retriever is clear
        retrieverOperationQueue.cancelAllOperations()
        
        // Add new retriever operation
        let retrieveOperation = AsyncOperation<JSON?>(delay: delay ?? (haActiveTasks ? Constants.tasksIntervalRefreshForActive : Constants.tasksIntervalRefreshForInActive))
        retrieveOperation.setBlockOperation { operationEnded in
            let params: [String: Any] = [
                "api": "SYNO.DownloadStation.Task",
                "method": "list",
                "additional": "transfer, detail",
                "version": 1
            ]
            Network().performRequest(.get, path: "DownloadStation/task.cgi", params: params, success: { (results) in
                operationEnded(.success(results))
            }) { (_) in
                operationEnded(.failure(.requestError))
            }
        }
        retrieveOperation.completionBlock = { [weak self] in
            guard let result = retrieveOperation.result else {return}
            switch result {
            case .success(let json):
                guard let tasksData = json?.dictionary?["data"]?["tasks"].array, let realm = self?.dataManager.realmContent else {return}
                
                // List fresh task
                var newTasks: [Task] = []
                for t in tasksData {
                    guard let tData = t.dictionaryObject, let task = Task(JSON: tData) else {continue}
                    task.updateDate = Date()
                    newTasks.append(task)
                }
                
                try? realm.safeWrite {
                    // Remove existing tasks
                    let deletedTasks = realm.objects(Task.self).filter("NOT (id IN %@)", newTasks.map({$0.id}))
                    for task in deletedTasks {
                        let objectsToDelete: [Object?] = [
                            task.additional?.detail,
                            task.additional?.transfer,
                            task.additional,
                            task.extra,
                            task
                        ]
                        // Remove task & details
                        objectsToDelete.compactMap({$0}).forEach({realm.delete($0)})
                    }
                    
                    // Insert fresh tasks
                    for task in newTasks {
                        realm.add(task, update: .modified)
                    }
                    
                    // Save update date
                    realm.object(ofType: User.self, forPrimaryKey: 0)?.taskUpdateDate = Date()
                }
            case .failure:
                (/* Do something ? */)
            }
            
            // Update state. Stop action running cycle if necessary. Tasks data are up to date.
            if self?.state.value == State.actionRunning.rawValue {
                self?.state.accept(State.running.rawValue)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.configureRetriever()
            }
        }
        retrieverOperationQueue.addOperation(retrieveOperation)
    }
    
    private func configureAction(for action: HTTPMethod, params: [String: Any], encoding: ParameterEncoding? = nil, file: Network.FileDescription? = nil, completion: ((_ result: Bool) -> ())? = nil) {
        // Clear retriever
        retrieverOperationQueue.cancelAllOperations()
        
        // Update state
        state.accept(State.actionRunning.rawValue)
        
        // Add new action operation
        let actionOperation = AsyncOperation<JSON?>()
        actionOperation.setBlockOperation { operationEnded in
            Network().performRequest(action, path: "DownloadStation/task.cgi", params: params, encoding: encoding ?? URLEncoding(destination: .queryString), file: file, success: { (results) in
                operationEnded(.success(results))
            }) { (_) in
                operationEnded(.failure(.requestError))
            }
        }
        actionOperation.completionBlock = { [weak self] in
            guard let result = actionOperation.result else {return}
            switch result {
            case .success:
                completion?(true)
            case .failure:
                completion?(false)
                if self?.actionOperationQueue.operations.isEmpty ?? true {
                    self?.state.accept(State.running.rawValue)
                }
            }
            
            // Call retriever if there is no action to perform
            if self?.actionOperationQueue.operations.isEmpty ?? true {
                self?.configureRetriever(delay: 0)
            }
        }
        actionOperationQueue.addOperation(actionOperation)
    }
}
