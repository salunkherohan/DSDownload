//
//  VPNProfile.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 21/05/2019.
//

import Foundation
import RealmSwift
import ObjectMapper
import ObjectMapperAdditions


class VPNProfile: Object, Mappable {
    
    @objc dynamic var id: String = ""
    @objc dynamic var configurationName: String = ""
    @objc dynamic var reconnect: Bool = false
    @objc dynamic var status: String = ""
    @objc dynamic var uptime: String = ""
    @objc dynamic var prtl: String = ""
    @objc dynamic var user: String = ""
    @objc dynamic var updateDate = Date()
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        configurationName <- map["confname"]
        reconnect <- (map["reconnect"], BoolTransform())
        status <- map["status"]
        uptime <- map["uptime"]
        prtl <- map["prtl"]
        user <- map["user"]
    }
}
