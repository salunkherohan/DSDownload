//
//  DBManager.swift
//  DSDownload
//
//  Created by Thomas LE GRAVIER on 18/04/2020.
//

import Foundation
import RealmSwift

class DBManager {
    
    // MARK: Singleton
    
    static let shared = DBManager()
    
    // MARK: DB composition
    
    static let contentDBObjectTypes = [
        User.self,
        Task.self,
        TaskExtra.self,
        TaskAdditional.self,
        TaskAdditionalDetail.self,
        TaskAdditionalTransfer.self,
        Statistic.self,
        VPNProfile.self,
        Item.self
    ]
    
    // MARK: Public properties
    
    var realmContent: Realm {
        if Thread.isMainThread {
            return defaultRealmContent
        } else {
            return try! Realm(configuration: realmContentConfiguration)
        }
    }
    
    init() {
        guard let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {fatalError("DSDownload wrong documents URL")}

        let contentDBURL = documentsUrl.appendingPathComponent(Constants.realmContentDBName)
        
        // Uncomment this line to remove current DB - FOR TESTING ONLY
        // try? fileManager.removeItem(at: contentDBURL)
        
        realmContentConfiguration = Realm.Configuration(fileURL: contentDBURL, schemaVersion: UInt64(Constants.realmContentDBVersion), migrationBlock: { _, _ in
            // Nothing to do. Content base doesn't need migration.
        }, objectTypes: DBManager.contentDBObjectTypes)
        defaultRealmContent = try! Realm(configuration: realmContentConfiguration)
        
        if Constants.realmLogs, let url = realmContentConfiguration.fileURL {print("🥁 Realm content DB path: \(url)")}
    }
    
    // MARK: Private
    
    private let fileManager = FileManager.default
    
    private let realmContentConfiguration: Realm.Configuration
    private let defaultRealmContent: Realm
}
