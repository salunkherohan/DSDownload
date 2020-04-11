//
//  SessionManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 05/02/2019.
//

import SwiftyJSON
import RealmSwift
import SynologySwift


/// SessionManager manager.
class SessionManager: DSDownloadManager {

    func login(with quickId: String, login: String, passwd: String, completion: @escaping (_ result: SynologySwift.Result<SynologySwiftAuth.DSAuthInfos>) -> ()) {
        SynologySwift.login(quickConnectid: quickId, sessionType: "FileStation", login: login, password: passwd, useDefaultCacheApis: true) { (result) in
            switch result {
            case .success(let session):
                SessionService.shared.saveSession(session, credentials: SessionService.LoginCredentials(quickId: quickId, login: login, password: passwd))
            case .failure(_): (/* Do something ? */)
            }
            completion(result)
        }
    }
    
    func logout(success : @escaping () -> (), error : @escaping () -> ()) {
        guard let session = SessionService.shared.session else {return}
        SynologySwift.logout(dsAuthInfos: session, sessionType: "FileStation") { (result) in
            switch result {
            case .success(let result):
                if result {success()}
                else      {error()}
            case .failure(_):
                error()
            }
        }
    }
    
    func testReachability(success : @escaping () -> (), error : @escaping () -> ()) {
        guard let session = SessionService.shared.session, let dsInfos = session.dsInfos else {
            error()
            return
        }
        SynologySwift.ping(dsInfos: dsInfos) { (result) in
            switch result {
            case .success(_):
                success()
            case .failure(_):
                error()
            }
        }
    }
}
