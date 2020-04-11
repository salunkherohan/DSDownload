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
       
        // Realm configuration
        let config = Realm.Configuration(schemaVersion: 1)
        Realm.Configuration.defaultConfiguration = config
        
        // Init session
        SessionService.shared.initialize()
    }
}
