//
//  DSDownloadConstants.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 01/02/2019.
//

struct DSDownloadConstants {
    
    // MARK: - Settings
    static let tasksIntervalRefreshForActive: Double = 2.0 // In seconds
    static let tasksIntervalRefreshForInActive: Double = 300.0 // In seconds
    static let VPNIntervalRefresh: Double = 240.0 // In seconds
    
    // MARK: - Paths
    static let basePath: String = "https://global.QuickConnect.to/"
    
    // MARK: - Logs
    static let networkLogs: Bool = true // Show logs for api calls
    
    // MARK: - TMP
    static let forceLogin: Bool = false // Force login at launch
}
