//
//  DSInit.swift
//  DSDownload
//
//  Created by Thomas LE GRAVIER on 18/04/2020.
//

class DSInit {

    static func configure() {
        
        // Initialize session soon as possible
        _ = SessionManager.shared
        
        // Initialize managers
        _ = TaskManager.shared
        _ = StatisticManager.shared
        _ = VPNProfileManager.shared
        _ = SearchManager.shared
    }
}
