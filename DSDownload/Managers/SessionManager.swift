//
//  SessionManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 05/02/2019.
//

import Foundation
import RealmSwift
import SynologySwift
import KeychainSwift
import RxSwift
import RxCocoa

class SessionManager {
    
    enum State: Int {
        case notConnected = 0
        case pendingValidation
        case connected
    }
    
    struct LoginCredentials: Codable {
        let quickId: String
        let login: String
        let password: String
    }
    
    private(set) var state: BehaviorRelay<Int> = BehaviorRelay(value: 0) // Represent session state
    
    private(set) var loginCredentials: LoginCredentials?
    private(set) var session: SynologySwiftAuth.DSAuthInfos? {
        didSet {
            state.accept(isConnected ? State.connected.rawValue : State.notConnected.rawValue)
        }
    }
    
    // MARK: Singleton
    
    static let shared = SessionManager()
    
    // MARK: Init
    
    init() {
        configure()
    }
    
    // MARK: Helpers
    
    var isConnected: Bool {
        guard let session = session else {return false}
        return session.sid != nil && session.dsInfos != nil
    }
    
    func login(with quickId: String, login: String, passwd: String, completion: ((SynologySwift.Result<SynologySwiftAuth.DSAuthInfos>) -> ())? = nil) {
        SynologySwift.login(quickConnectid: quickId, sessionType: "DownloadStation", login: login, password: passwd, useDefaultCacheApis: true) { [weak self] (result) in
            switch result {
            case .success(let session): self?.save(session, credentials: LoginCredentials(quickId: quickId, login: login, password: passwd))
            case .failure:              (/* Do something ? */)
            }
            completion?(result)
        }
    }
    
    func logout(completion: ((SynologySwift.Result<Bool>) -> ())? = nil) {
        guard let session = session else {completion?(.success(false)); return}
        SynologySwift.logout(dsAuthInfos: session, sessionType: "DownloadStation") { [weak self] (result) in
            self?.reset()
            completion?(result)
        }
    }
    
    // MARK: Private

    private let keychainService = KeychainSwift()
    private let keychainServiceName = "dsdownload-connector"
    private let keychainServiceSession = "dsdownload-session"
    private let keychainServiceLoginCredentials = "dsdownload-login-credentials"
    
    private let dataManager = DBManager.shared
    
    private func configure() {
        keychainService.accessGroup = keychainServiceName
        restoreSession()
        restoreLogin()
        
        // Session expired observer
        NotificationCenter.default.addObserver(forName: .sessionExpired, object: nil, queue: nil) { [weak self] _ in
            self?.reset(clearCredentials: false)
        }
    }
    
    private func save(_ session: SynologySwiftAuth.DSAuthInfos, credentials: LoginCredentials?) {
        let jsonEncoder = JSONEncoder()
        guard let sessionData = try? jsonEncoder.encode(session) else {return}
        guard let credentialsData = try? jsonEncoder.encode(credentials) else {return}
        
        // Save session
        keychainService.set(sessionData, forKey: keychainServiceSession)
        
        // Save credentials
        keychainService.set(credentialsData, forKey: keychainServiceLoginCredentials)
        
        // Reset all datas & create new user if necessary
        if loginCredentials == nil || loginCredentials?.quickId != credentials?.quickId || loginCredentials?.login != credentials?.login {
            try? dataManager.realmContent.safeWrite {
                dataManager.realmContent.deleteAll()
                dataManager.realmContent.add(User(value: ["login": credentials?.login ?? ""]))
            }
        }
        
        self.session = session
        self.loginCredentials = credentials
    }
    
    private func reset(clearCredentials: Bool = true) {
        keychainService.delete(keychainServiceSession)
        session = nil
        
        // Clear login credentials on user logout action
        if clearCredentials == false {
            keychainService.delete(keychainServiceLoginCredentials)
            loginCredentials = nil
        }
    }
    
    // MARK: Restore session & credentials

    private func restoreSession() {
        let jsonDecoder = JSONDecoder()
        guard let sessionData = keychainService.getData(keychainServiceSession),
              let session = try? jsonDecoder.decode(SynologySwiftAuth.DSAuthInfos.self, from: sessionData),
              let dsInfos = session.dsInfos
        else {return}
        
        // Update state
        state.accept(State.pendingValidation.rawValue)
        
        // Check host reachability
        SynologySwift.ping(dsInfos: dsInfos) { [weak self] (result) in
            switch result {
            case .success: self?.session = session
            case .failure: self?.reset(clearCredentials: false)
            }
        }
    }
    
    private func restoreLogin() {
        let jsonDecoder = JSONDecoder()
        guard let loginCredentialsData = keychainService.getData(keychainServiceLoginCredentials),
              let loginCredentials = try? jsonDecoder.decode(LoginCredentials.self, from: loginCredentialsData)
        else {return}
        self.loginCredentials = loginCredentials
    }
}
