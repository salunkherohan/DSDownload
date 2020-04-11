//
//  DSDownloadInit.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 11/02/2019.
//

import Foundation
import RealmSwift


class DSDownloadInit: NSObject {
    
    static func launch() {
       
        // Realm migration
        let config = Realm.Configuration(
            schemaVersion: 4,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 4 {
                    // Do nothing
                }
        }, deleteRealmIfMigrationNeeded: true)
        Realm.Configuration.defaultConfiguration = config
        
        // Init session
        SessionService.shared.initialize()
    }
}
