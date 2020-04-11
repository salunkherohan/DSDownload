//
//  StatisticManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 13/02/2019.
//

import SwiftyJSON
import RealmSwift
import SynologySwift


/// StatisticManager manager.
class StatisticManager: DSDownloadManager {
    
    func all(_ success : @escaping (Statistic) -> (), error : @escaping () -> ()) {
        
        guard SessionService.shared.isConnected else {
            error()
            return
        }
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Statistic",
            "method": "getinfo",
            "version": 1
        ]
        
        DSDownloadNetwork().performRequest(.get, path: "DownloadStation/statistic.cgi", params: params, success: { (results) in
            self.saveResults(results, callback: success)
        }) { (error) in
            // Error
        }
    }
    
    // Mark : Private
    
    private func saveResults(_ results: JSON, callback: (Statistic) -> ()) {
        let realm = try! Realm()
        
        guard let statistics = results.dictionary?["data"]?.object
        else {return}
        
        // Force int
        
        
        // Delete statistics
        try! realm.write {
            realm.delete(realm.objects(Statistic.self))
        }
        
        // Save statistics
        try! realm.write {
            let stats = realm.create(Statistic.self, value: statistics)
            callback(stats)
        }
    }
}
