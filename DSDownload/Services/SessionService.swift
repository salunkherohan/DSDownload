//
//  SessionService.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 06/02/2019.
//

import Foundation
import SynologySwift
import KeychainSwift

class SessionService {
    
    static let shared: SessionService = SessionService()
    
    struct LoginCredentials: Codable {
        let quickId: String
        let login: String
        let password: String
    }
    
    init() {
        configure()
    }
    
    private(set) var session: SynologySwiftAuth.DSAuthInfos?
    private(set) var loginCredentials: LoginCredentials?
    
    var isConnected: Bool {
        return session?.sid != nil
    }
    
    func saveSession(_ session: SynologySwiftAuth.DSAuthInfos, credentials: LoginCredentials?) {
        let jsonEncoder = JSONEncoder()
        guard let sessionData = try? jsonEncoder.encode(session) else {return}
        guard let credentialsData = try? jsonEncoder.encode(credentials) else {return}
        
        // Save session
        keychainService.set(sessionData, forKey: keychainServiceSession)
        
        // Save credentials
        keychainService.set(credentialsData, forKey: keychainServiceLoginCredentials)
        
        self.session = session
        self.loginCredentials = credentials
    }
    
    func reset(automatic: Bool = false) {
        keychainService.delete(keychainServiceSession)
        session = nil
        
        // Clean login details if not automatic logout
        if automatic == false {
            keychainService.delete(keychainServiceLoginCredentials)
            loginCredentials = nil
        }
    }
    
    // MARK: Private
    
    private let keychainService = KeychainSwift()
    private let keychainServiceName = "synology-connector"
    private let keychainServiceSession = "synology-session"
    private let keychainServiceLoginCredentials = "synology-login-credentials"
    
    private func configure() {
        keychainService.accessGroup = keychainServiceName
        
        restoreSession()
        restoreLogin()
    }

    private func restoreSession() {
        let jsonDecoder = JSONDecoder()
        guard let sessionData = keychainService.getData(keychainServiceSession),
              let session = try? jsonDecoder.decode(SynologySwiftAuth.DSAuthInfos.self, from: sessionData)
        else {return}
        self.session = session
    }
    
    private func restoreLogin() {
        let jsonDecoder = JSONDecoder()
        guard let loginCredentialsData = keychainService.getData(keychainServiceLoginCredentials),
              let loginCredentials = try? jsonDecoder.decode(LoginCredentials.self, from: loginCredentialsData)
        else {return}
        self.loginCredentials = loginCredentials
    }
}
