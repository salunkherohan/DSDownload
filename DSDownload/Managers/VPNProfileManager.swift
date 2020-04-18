//
//  VPNProfileManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 25/04/2019.
//

import Foundation
import Alamofire
import SwiftyJSON
import RealmSwift
import RxSwift
import RxCocoa

class VPNProfileManager {
    
    // MARK: Singleton
    
    static let shared = VPNProfileManager()
    
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
        sessionManager.state.asObservable().skip(1).subscribe(onNext: { [weak self] _ in
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
                dataManager.realmContent.delete(dataManager.realmContent.objects(VPNProfile.self))
            }
        }
    }
    
    private func configureRetriever(delay: TimeInterval? = nil) {
        // Be sure retriever is clear
        retrieverOperationQueue.cancelAllOperations()
        
        // Add new retriever operation
        let retrieveOperation = AsyncOperation<JSON?>(delay: Constants.VPNIntervalRefresh)
        retrieveOperation.setBlockOperation { operationEnded in
            let params: [String: Any] = [
                "api": "SYNO.Entry.Request",
                "method": "request",
                "version": 1,
                "stopwhenerror": false,
                "compound": "[{\"api\":\"SYNO.Entry.Request\",\"method\":\"request\",\"version\":1,\"stopwhenerror\":false,\"compound\":[{\"api\":\"SYNO.Core.Network.VPN.PPTP\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]},{\"api\":\"SYNO.Core.Network.VPN.OpenVPNWithConf\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]},{\"api\":\"SYNO.Core.Network.VPN.OpenVPN\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]},{\"api\":\"SYNO.Core.Network.VPN.L2TP\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]}]}]"
            ]
            Network().performRequest(.post, path: "entry.cgi", params: params, encoding: URLEncoding.httpBody, success: { (results) in
                operationEnded(.success(results))
            }) { (_) in
                operationEnded(.failure(.requestError))
            }
        }
        retrieveOperation.completionBlock = { [weak self] in
            guard let result = retrieveOperation.result else {return}
            switch result {
            case .success(let json):
                guard let profilesData = json?.dictionary?["data"]?["result"].array?.first?.dictionary?["data"]?["result"].array,
                      let realm = self?.dataManager.realmContent
                else {return}
                
                try? realm.safeWrite {
                    // Remove existing statistics
                    realm.delete(realm.objects(VPNProfile.self))
                    
                    // Insert fresh profiles
                    for p in profilesData {
                        guard let pData = p.dictionaryObject, let profile = VPNProfile(JSON: pData) else {continue}
                        profile.updateDate = Date()
                        realm.add(profile, update: .all)
                    }
                }
            case .failure:
                guard let strongSelf = self else {return}
                try? strongSelf.dataManager.realmContent.safeWrite {
                    // Remove existing profiles
                    strongSelf.dataManager.realmContent.delete(strongSelf.dataManager.realmContent.objects(VPNProfile.self))
                }
            }
            
            DispatchQueue.main.async {
                self?.configureRetriever()
            }
        }
        retrieverOperationQueue.addOperation(retrieveOperation)
    }
}
