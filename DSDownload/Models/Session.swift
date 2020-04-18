//
//  Session.swift
//  DSDownload-iOS
//
//  Created by Thomas LE GRAVIER on 19/04/2020.
//

import Foundation
import RealmSwift
import SynologySwift

// IMPORTANT: DO NOT STORE THIS OBJECTS

class Session: Object {
    @objc dynamic var sid: String?
    @objc dynamic var account: String?
    @objc dynamic var dsInfos: SessionDSInfos?
    
    var authInfos: SynologySwiftAuth.DSAuthInfos {
        SynologySwiftAuth.DSAuthInfos(sid: sid, account: account, dsInfos: dsInfos?.dsInfos)
    }
    
    var isConnected: Bool {
        return sid != nil && dsInfos != nil
    }
    
    // Helpers
    
    func refresh(for infos: SynologySwiftAuth.DSAuthInfos) {
        sid = infos.sid
        account = infos.account
        
        // DS infos
        if let ds = infos.dsInfos {
            dsInfos = SessionDSInfos(value: ["quickId": ds.quickId, "host": ds.host, "port": ds.port])
        }
    }
    
    func reset() {
        sid = nil
        account = nil
        dsInfos = nil
    }
}

class SessionDSInfos: Object {
    @objc dynamic var quickId: String = ""
    @objc dynamic var host: String = ""
    @objc dynamic var port: Int = 0
    
    var dsInfos: SynologySwiftURLResolver.DSInfos {
        return SynologySwiftURLResolver.DSInfos(quickId: quickId, host: host, port: port)
    }
}
