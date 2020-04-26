//
//  Item.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 15/04/2020.
//

import Foundation
import RealmSwift
import ObjectMapper

class Item: Object, Mappable {
    @objc dynamic var result_id = 0
    @objc dynamic var title = ""
    @objc dynamic var category = ""
    @objc dynamic var date = Date()
    @objc dynamic var dlurl = ""
    @objc dynamic var page = ""
    @objc dynamic var peers = 0
    @objc dynamic var leechs = 0
    @objc dynamic var size = 0
    
    override static func primaryKey() -> String? {
        return "result_id"
    }
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        result_id <- map["result_id"]
        title <- map["title"]
        category <- map["category"]
        date <- (map["date"], StringDateTransform())
        dlurl <- map["dlurl"]
        page <- map["page"]
        peers <- map["peers"]
        leechs <- map["leechs"]
        size <- map["size"]
    }
}

open class StringDateTransform: TransformType {
    public typealias Object = Date
    public typealias JSON = String

    private var dateFormatter: DateFormatter {
        return DateFormatter(withFormat: "yyyy-MM-dd HH:mm:ss Z", locale: "en_US")
    }

    open func transformFromJSON(_ value: Any?) -> Date? {
        guard let stringValue = value as? String else { return nil }
        
        return dateFormatter.date(from: stringValue)
    }

    open func transformToJSON(_ value: Date?) -> String? {
        if let date = value {
            return dateFormatter.string(from: date)
        }
        
        return nil
    }
}
