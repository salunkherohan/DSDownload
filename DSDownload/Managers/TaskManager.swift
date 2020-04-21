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
        guard sessionManager.isConnected else {completion?(false); return}
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "create",
            "version": 1,
            "uri": magnet
        ]
        configureAction(for: .post, params: params, encoding: URLEncoding(destination: .httpBody), completion: completion)
    }
    
    func delete(_ tasks: [Task], completion: ((_ result: Bool) -> ())? = nil) {
        guard sessionManager.isConnected else {completion?(false); return}
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
        guard sessionManager.isConnected else {completion?(false); return}
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "pause",
            "version": 1,
            "id": task.id
        ]
        configureAction(for: .get, params: params, completion: completion)
    }
    
    func resume(_ task: Task, completion: ((_ result: Bool) -> ())? = nil) {
        guard sessionManager.isConnected else {completion?(false); return}
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
        
        actionOperationQueue.name = "Action operations queue"
        actionOperationQueue.maxConcurrentOperationCount = 1
        
        configureObservers()
    }
    
    private func configureObservers() {
        // Session observer
        sessionManager.state.asObservable().skip(1).subscribe(onNext: { [weak self] _ in
            self?.sessionDidChange()
        }).disposed(by: disposeBag)
    }
    
    private func sessionDidChange() {
        // Clear & reset current operations
        retrieverOperationQueue.cancelAllOperations()
        actionOperationQueue.cancelAllOperations()
        
        if sessionManager.isConnected {
            configureRetriever(delay: 0)
            let isFirstRetrieve = dataManager.realmContent.object(ofType: User.self, forPrimaryKey: 0)?.taskUpdateDate == nil
            state.accept(isFirstRetrieve ? State.actionRunning.rawValue : State.running.rawValue)
        } else {
            state.accept(State.none.rawValue)
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
                try? realm.safeWrite {
                    // Remove existing tasks
                    [Task.self, TaskExtra.self, TaskAdditional.self, TaskAdditionalDetail.self, TaskAdditionalTransfer.self].forEach({
                        realm.delete(realm.objects($0))
                    })
                    
                    // Insert fresh tasks
                    for t in tasksData {
                        guard let tData = t.dictionaryObject, let task = Task(JSON: tData) else {continue}
                        task.updateDate = Date()
                        realm.add(task, update: .all)
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
    
    private func configureAction(for action: HTTPMethod, params: [String: Any], encoding: ParameterEncoding? = nil, completion: ((_ result: Bool) -> ())? = nil) {
        // Clear retriever
        retrieverOperationQueue.cancelAllOperations()
        
        // Update state
        state.accept(State.actionRunning.rawValue)
        
        // Add new action operation
        let actionOperation = AsyncOperation<JSON?>()
        actionOperation.setBlockOperation { operationEnded in
            Network().performRequest(action, path: "DownloadStation/task.cgi", params: params, encoding: encoding ?? URLEncoding(destination: .queryString), success: { (results) in
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
