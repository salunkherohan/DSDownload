//
//  NetworkManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 25/04/2019.
//

import SwiftyJSON
import RealmSwift
import SynologySwift
import Alamofire


/// NetworkManager manager.
class NetworkManager: DSDownloadManager {

    func vpn(_ success : @escaping (List<VPNProfile>) -> (), error : @escaping () -> ()) {
        
        guard SessionService.shared.isConnected else {
            error()
            return
        }
        
        let params: [String: Any] = [
            "api": "SYNO.Entry.Request",
            "method": "request",
            "version": 1,
            "stopwhenerror": false,
            "compound": "[{\"api\":\"SYNO.Entry.Request\",\"method\":\"request\",\"version\":1,\"stopwhenerror\":false,\"compound\":[{\"api\":\"SYNO.Core.Network.VPN.PPTP\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]},{\"api\":\"SYNO.Core.Network.VPN.OpenVPNWithConf\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]},{\"api\":\"SYNO.Core.Network.VPN.OpenVPN\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]},{\"api\":\"SYNO.Core.Network.VPN.L2TP\",\"method\":\"list\",\"version\":1,\"additional\":[\"status\"]}]}]"
        ]
        
        DSDownloadNetwork().performRequest(.post, path: "entry.cgi", params: params, encoding: URLEncoding.httpBody, success: { (results) in
            self.saveResults(results, callback: { (profiles) in
                success(profiles)
            })
        }) { (e) in
            error()
        }
    }
    
    
    private func saveResults(_ results: JSON, callback: (List<VPNProfile>) -> ()) {
        let realm = try! Realm()
        let profiles = List<VPNProfile>()
        
        guard let vpnProfiles = results.dictionary?["data"]?["result"].array?.first?.dictionary?["data"]?["result"].array
        else {callback(profiles);return}
        
        // Save VPN profiles
        for profile in vpnProfiles {
            guard let pDatas = profile.dictionary?["data"]?.array?.first,
                  !pDatas.isEmpty
            else {continue}
            let p = VPNProfile(value: pDatas.object)
            try! realm.write {
                realm.add(p, update: true)
            }
            profiles.append(p)
        }
        
        callback(profiles)
    }
}
