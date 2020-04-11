//
//  Statistic.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 13/02/2019.
//

import Foundation
import RealmSwift


class Statistic: Object {
    @objc dynamic var speed_download = 0
    @objc dynamic var speed_upload = 0
}
