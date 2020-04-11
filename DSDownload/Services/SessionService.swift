//
//  SessionService.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 06/02/2019.
//

import Foundation
import SynologySwift


class SessionService: NSObject {
    
    static let shared: SessionService = SessionService()
    
    var session: SynologySwiftAuth.DSAuthInfos?
    
    var isConnected: Bool {
        return session?.sid != nil
    }
    
    override init() {
        super.init()
        // Do something ?
    }
    
    /* Initialize session service at launch */
    func initialize() {
        restoreSession()
    }
    
    func saveSession(_ session: SynologySwiftAuth.DSAuthInfos) {
        let jsonEncoder = JSONEncoder()
        guard let jsonData = try? jsonEncoder.encode(session) else {return}
        keychainService.save(service: keychainServiceName, key: keychainServiceSession, data: jsonData)
        self.session = session
    }
    
    func reset() {
        keychainService.remove(service: keychainServiceName, key: keychainServiceSession)
        self.session = nil
    }
    
    // Mark : Private
    
    private let keychainService: KeychainService = KeychainService()
    private let keychainServiceName: String = "synology-connector"
    private let keychainServiceSession: String = "synology-session"

    private func restoreSession() {
        let jsonDecoder = JSONDecoder()
        guard let sessionData = keychainService.load(service: keychainServiceName, key: keychainServiceSession),
              let session = try? jsonDecoder.decode(SynologySwiftAuth.DSAuthInfos.self, from: sessionData)
        else {return}
        self.session = session
    }
}
