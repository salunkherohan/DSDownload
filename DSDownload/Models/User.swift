//
//  User.swift
//  DSDownload
//
//  Created by Thomas LE GRAVIER on 21/04/2020.
//

import Foundation
import RealmSwift

class User: Object {
    
    @objc dynamic var id: Int = 0
    @objc dynamic var login: String = ""
    @objc dynamic var taskUpdateDate: Date?
    @objc dynamic var createdDate = Date()
    
    override static func primaryKey() -> String? {
        return "id"
    }
}
