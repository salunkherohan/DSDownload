//
//  StatisticManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 13/02/2019.
//

import Foundation
import SwiftyJSON
import RealmSwift
import RxSwift
import RxCocoa

class StatisticManager {
    
    // MARK: Singleton
    
    static let shared = StatisticManager()
    
    // MARK: Init
    
    init() {
        configure()
    }
    
    // MARK: Private
    
    private let dataManager = DBManager.shared
    private let sessionManager = SessionManager.shared
    private let taskManager = TaskManager.shared
    
    private let retrieverOperationQueue = OperationQueue()
    
    private let disposeBag = DisposeBag()
    
    private func configure() {
        retrieverOperationQueue.name = "Retriever operations queue"
        retrieverOperationQueue.maxConcurrentOperationCount = 1

        configureObservers()
    }
    
    private func configureObservers() {
        // Session observer
        taskManager.state.asObservable().skip(1).subscribe(onNext: { [weak self] _ in
            self?.sessionDidChange()
        }).disposed(by: disposeBag)
    }
    
    private func sessionDidChange() {
        // Clear & reset current operations
        retrieverOperationQueue.cancelAllOperations()
        
        if sessionManager.isConnected {
            configureRetriever(delay: 0)
        } else {
            try? dataManager.realmContent.safeWrite {
                dataManager.realmContent.delete(dataManager.realmContent.objects(Statistic.self))
            }
        }
    }
    
    private func configureRetriever(delay: TimeInterval? = nil) {
        // Be sure retriever is clear
        retrieverOperationQueue.cancelAllOperations()
        
        // Add new retriever operation
        let retrieveOperation = AsyncOperation<JSON?>(delay: delay ?? (taskManager.haActiveTasks ? Constants.statisticsIntervalRefreshForActive : Constants.statisticsIntervalRefreshForInActive))
        retrieveOperation.setBlockOperation { operationEnded in
            let params: [String: Any] = [
                "api": "SYNO.DownloadStation.Statistic",
                "method": "getinfo",
                "version": 1
            ]
            Network().performRequest(.get, path: "DownloadStation/statistic.cgi", params: params, success: { (results) in
                operationEnded(.success(results))
            }) { (_) in
                operationEnded(.failure(.requestError))
            }
        }
        retrieveOperation.completionBlock = { [weak self] in
            guard let result = retrieveOperation.result else {return}
            switch result {
            case .success(let json):
                guard let statsData = json?.dictionary?["data"]?.dictionaryObject,
                      let statistics = Statistic(JSON: statsData),
                      let realm = self?.dataManager.realmContent
                else {return}
                
                try? realm.safeWrite {
                    // Remove existing statistics
                    realm.delete(realm.objects(Statistic.self))
                    
                    // Insert fresh statistics
                    statistics.updateDate = Date()
                    realm.add(statistics)
                }
            case .failure:
                guard let strongSelf = self else {return}
                try? strongSelf.dataManager.realmContent.safeWrite {
                    // Remove existing statistics
                    strongSelf.dataManager.realmContent.delete(strongSelf.dataManager.realmContent.objects(Statistic.self))
                }
            }
            
            DispatchQueue.main.async {
                self?.configureRetriever()
            }
        }
        
        retrieverOperationQueue.addOperation(retrieveOperation)
    }
}
