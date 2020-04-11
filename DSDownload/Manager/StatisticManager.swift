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
        
        DSDownloadNetwork().performRequest(.get, path: "DownloadStation/statistic.cgi", params: params, success: { [weak self] (results) in
            guard let stats = self?.save(results) else {return}
            DispatchQueue.main.async {success(stats)}
        }) { (error) in
            // Error
        }
    }
    
    // MARK: Private
    
    private func save(_ results: JSON) -> Statistic? {
        let realm = try! Realm()
        
        guard let statistics = results.dictionary?["data"]?.object
        else {return nil}
        
        // Delete statistics
        try! realm.write {
            realm.delete(realm.objects(Statistic.self))
        }
        
        // Save statistics
        let stats = Statistic(value: statistics)
        try! realm.write {
            realm.add(stats)
        }
        
        return stats
    }
}
