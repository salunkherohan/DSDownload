//
//  DSDownloadConstants.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 01/02/2019.
//

struct Constants {
    
    // MARK: Settings
    
    static let tasksIntervalRefreshForActive: Double = 2.0 // In seconds
    static let tasksIntervalRefreshForInActive: Double = 300.0 // In seconds
    static let statisticsIntervalRefreshForActive: Double = 2.0 // In seconds
    static let statisticsIntervalRefreshForInActive: Double = 300.0 // In seconds
    static let VPNIntervalRefresh: Double = 240.0 // In seconds
    
    // MARK: Realm

    static let realmContentDBName: String = "dsdownload_content_db.realm"
    static let realmContentDBVersion: Int = 1
    
    #if DEBUG
    
    // MARK: Logs
    static let crashLogs: Bool = true
    static let networkLogs: Bool = true
    static let realmLogs: Bool = true
    
    #else // Prod version
    
    // MARK: Logs
    static let crashLogs: Bool = false
    static let networkLogs: Bool = false
    static let realmLogs: Bool = false
    
    #endif
}
