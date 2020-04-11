//
//  VPNProfile.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 21/05/2019.
//

import Foundation
import RealmSwift


class VPNProfile: Object {
    @objc dynamic var id = ""
    @objc dynamic var confname = ""
    @objc dynamic var reconnect = false
    @objc dynamic var status = ""
    @objc dynamic var uptime = ""
    @objc dynamic var prtl = ""
    @objc dynamic var user = ""
    @objc dynamic var update_date = DSDownloadModel.getCurrentDateTime()
    
    override static func primaryKey() -> String? {
        return "id"
    }
}
