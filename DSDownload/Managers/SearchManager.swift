//
//  SearchManager.swift
//  DSDownload
//
//  Created by Thomas Brichart on 14/04/2020.
//

import Foundation
import Alamofire
import SwiftyJSON
import RealmSwift
import RxSwift
import RxCocoa


/// TasksManager manager.
class SearchManager {
    
    enum State: Int {
        case none
        case idle
        case error
        case searchRunning
        case searchFinished
    }
    
    private(set) var state: BehaviorRelay<Int> = BehaviorRelay(value: 0) // Represent search manager state
    
    // MARK: Singleton
    
    static let shared = SearchManager()
    
    // MARK: Init
    
    init() {
        configure()
    }
    
    
    // MARK: Helpers
    
    func search(_ keyword: String, completion: ((_ result: Bool) -> ())? = nil) {
        // Remove previous search results
        try? dataManager.realmContent.safeWrite {
            // Remove existing tasks
            [Item.self].forEach({
                dataManager.realmContent.delete(dataManager.realmContent.objects($0))
            })
        }
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation2.BTSearch",
            "method": "start",
            "version": 1,
            "keyword": keyword
        ]
        configureAction(for: .get, params: params, completion: completion)
    }
    
    // MARK: Private
    
    private let sessionManager = SessionManager.shared
    private let dataManager = DBManager.shared
    
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
            
            // Update state
            state.accept(!actionOperationQueue.operations.isEmpty ? State.searchRunning.rawValue : State.idle.rawValue)
        } else {
            state.accept(State.none.rawValue)
            
            // Stop & clear queues
            retrieverOperationQueue.isSuspended = true
            retrieverOperationQueue.cancelAllOperations()
            actionOperationQueue.isSuspended = true
            actionOperationQueue.cancelAllOperations()
        }
    }
    
    private func configureRetriever(taskID: String, delay: TimeInterval? = nil) {
        guard sessionManager.isConnected, actionOperationQueue.operations.isEmpty else {return}
        
        // Be sure retriever is clear
        retrieverOperationQueue.cancelAllOperations()
        
        // Add new retriever operation
        let retrieveOperation = AsyncOperation<JSON?>(delay: Constants.tasksIntervalRefreshForActive)
        
        retrieveOperation.setBlockOperation { operationEnded in
            let params: [String: Any] = [
                "api": "SYNO.Entry.Request",
                "method": "request",
                "version": 1,
                "stop_when_error": false,
                "mode": "sequential",
                "compound": "[{\"api\":\"SYNO.DownloadStation2.BTSearch\",\"method\":\"list\",\"version\":1,\"sort_by\":\"seeds\",\"order\":\"DESC\",\"offset\":0,\"limit\":50,\"id\":\"\(taskID)\"}]"
            ]
            
            Network().performRequest(.get, path: "entry.cgi", params: params, success: { (results) in
                operationEnded(.success(results))
            }) { (_) in
                operationEnded(.failure(.requestError))
            }
        }
        
        retrieveOperation.completionBlock = { [weak self] in
            guard let result = retrieveOperation.result else {return}
            switch result {
            case .success(let json):
                if let has_failed = json?.dictionary?["data"]?["has_fail"].bool, has_failed == true {
                    self?.state.accept(State.error.rawValue)
                    return
                }
                
                if let is_running = json?.dictionary?["data"]?["result"][0]["data"]["is_running"].bool, is_running == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.configureRetriever(taskID: taskID)
                    }
                } else {
                    self?.state.accept(State.searchFinished.rawValue)
                }
                
                guard let itemsData = json?.dictionary?["data"]?["result"][0]["data"]["results"].array, let realm = self?.dataManager.realmContent else {return}
                try? realm.safeWrite {
                    // Remove existing results
                    [Item.self].forEach({
                        realm.delete(realm.objects($0))
                    })
                    
                    // Insert fresh results
                    for i in itemsData {
                        guard let iData = i.dictionaryObject, let item = Item(JSON: iData) else {continue}
                        realm.add(item, update: .all)
                    }
                }
            case .failure:
                (/* Do something ? */)
            }
        }
        retrieverOperationQueue.addOperation(retrieveOperation)
    }
    
    private func configureAction(for action: HTTPMethod, params: [String: Any], encoding: ParameterEncoding? = nil, completion: ((_ result: Bool) -> ())? = nil) {
        // Clear retriever
        retrieverOperationQueue.cancelAllOperations()
        
        // Update state
        state.accept(State.searchRunning.rawValue)
        
        // Add new action operation
        let actionOperation = AsyncOperation<JSON?>()
        
        var taskID = ""
        
        actionOperation.setBlockOperation { operationEnded in
            Network().performRequest(action, path: "entry.cgi", params: params, encoding: encoding ?? URLEncoding(destination: .queryString), success: { (results) in
                taskID = results.dictionary?["data"]?["id"].string ?? ""
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
            }
            
            // Call retriever if there is no action to perform
            if self?.actionOperationQueue.operations.isEmpty ?? true {
                self?.configureRetriever(taskID: taskID, delay: 0)
            }
        }
        
        actionOperationQueue.addOperation(actionOperation)
    }
}

