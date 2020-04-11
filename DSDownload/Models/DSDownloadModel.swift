//
//  DSDownloadModel.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 11/02/2019.
//

import Foundation
import RealmSwift


class DSDownloadModel: Object {

    static func getCurrentDateTime() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "CEST")
        return formatter.string(from: date)
    }
}
