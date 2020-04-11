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
    
    struct LoginDetails: Codable {
        let quickId: String
        let login: String
        let password: String
    }
    
    var session: SynologySwiftAuth.DSAuthInfos?
    var loginDetails: LoginDetails?
    
    var isConnected: Bool {
        return session?.sid != nil
    }
    
    /* Initialize session service at launch */
    func initialize() {
        restoreSession()
        restoreLogin()
    }
    
    func saveSession(_ session: SynologySwiftAuth.DSAuthInfos, details: LoginDetails?) {
        let jsonEncoder = JSONEncoder()
        guard let jsonData = try? jsonEncoder.encode(session) else {return}
        guard let detailsJsonData = try? jsonEncoder.encode(details) else {return}
        keychainService.save(service: keychainServiceName, key: keychainServiceSession, data: jsonData)
        keychainService.save(service: keychainServiceName, key: keychainServiceLoginDetails, data: detailsJsonData)
        self.session = session
        self.loginDetails = details
    }
    
    func reset(automatic: Bool = false) {
        keychainService.remove(service: keychainServiceName, key: keychainServiceSession)
        self.session = nil
        
        // Clean login details if not automatic logout
        if automatic == false {
            keychainService.remove(service: keychainServiceName, key: keychainServiceLoginDetails)
            self.loginDetails = nil
        }
    }
    
    // MARK: Private
    
    private let keychainService: KeychainService = KeychainService()
    private let keychainServiceName: String = "synology-connector"
    private let keychainServiceSession: String = "synology-session"
    private let keychainServiceLoginDetails: String = "synology-login-details"

    private func restoreSession() {
        let jsonDecoder = JSONDecoder()
        guard let sessionData = keychainService.load(service: keychainServiceName, key: keychainServiceSession),
              let session = try? jsonDecoder.decode(SynologySwiftAuth.DSAuthInfos.self, from: sessionData)
        else {return}
        self.session = session
    }
    
    private func restoreLogin() {
        let jsonDecoder = JSONDecoder()
        guard let loginDetailsData = keychainService.load(service: keychainServiceName, key: keychainServiceLoginDetails),
              let loginDetails = try? jsonDecoder.decode(LoginDetails.self, from: loginDetailsData)
        else {return}
        self.loginDetails = loginDetails
    }
}
