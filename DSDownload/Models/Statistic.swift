//
//  Statistic.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 13/02/2019.
//

import Foundation
import RealmSwift
import ObjectMapper

class Statistic: Object, Mappable {
    
    @objc dynamic var speedDownload: Int = 0
    @objc dynamic var speedUpload: Int = 0
    @objc dynamic var updateDate = Date()
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        speedDownload <- map["speed_download"]
        speedUpload <- map["speed_upload"]
    }
}
