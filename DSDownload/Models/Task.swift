//
//  Task.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 11/02/2019.
//

import Foundation
import RealmSwift
import ObjectMapper

class Task: Object, Mappable {
    
    enum StatusType: String {
        case waiting
        case downloading
        case paused
        case finishing
        case finished
        case hashChecking = "hash checking"
        case seeding
        case filehostingWaiting = "filehosting waiting"
        case extracting
        case error
    }
    
    @objc dynamic var id: String = ""
    @objc dynamic var title: String = ""
    @objc dynamic var type: String = ""
    @objc dynamic var username: String = ""
    @objc dynamic var size: Int = 0
    @objc dynamic var status: String = ""
    @objc dynamic var extra: TaskExtra?
    @objc dynamic var additional: TaskAdditional?
    @objc dynamic var updateDate = Date()
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    var speed: String? {
        guard let additional = additional, let transfer = additional.transfer, transfer.speedDownload > 0 || transfer.speedDownload > 0 else {return nil}
        return transfer.speedDownload > 0 ? "↓ \(Tools.convertBytes(transfer.speedDownload)) mb/s" : "↑ \(Tools.convertBytes(transfer.speedUpload)) mb/s"
    }
    
    var progress: Double? {
        guard let additional = additional else {return nil}
        guard additional.detail?.completedTime ?? 0 == 0 else {return 1}
        guard let downloadSize = additional.transfer?.sizeDownloaded else {return nil}
        return size > 0 && downloadSize >= size ? 1 : downloadSize > 0 && size > 0 ? min(1, max(0, Double(downloadSize)/Double(size))) : 0
    }
    
    var sizeDescription: String {
        return size <= 0 ? "N/A" : Tools.convertBytes(size, unit: .useGB)
    }
    
    var createTime: Int {
        return additional?.detail?.createTime ?? 0
    }
    
    var remainingTime: Int? {
        guard let transfer = additional?.transfer else { return nil }
        guard transfer.speedDownload > 0 else { return nil }
        
        let remainingSize = size - transfer.sizeDownloaded
        return remainingSize/transfer.speedDownload
    }
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        title <- map["title"]
        type <- map["type"]
        username <- map["username"]
        size <- map["size"]
        status <- map["status"]
        extra <- map["status_extra"]
        additional <- map["additional"]
    }
}

class TaskExtra: Object, Mappable {
    
    @objc dynamic var errorDetail: String = ""
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        errorDetail <- map["error_detail"]
    }
}

class TaskAdditional: Object, Mappable {
    
    @objc dynamic var detail: TaskAdditionalDetail?
    @objc dynamic var transfer: TaskAdditionalTransfer?
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        detail <- map["detail"]
        transfer <- map["transfer"]
    }
}

class TaskAdditionalDetail: Object, Mappable {
    
    @objc dynamic var destination: String = ""
    @objc dynamic var uri: String = ""
    @objc dynamic var createTime: Int = 0
    @objc dynamic var startedTime: Int = 0
    @objc dynamic var completedTime: Int = 0
    @objc dynamic var priority: String?
    @objc dynamic var peers: Int = 0
    @objc dynamic var connectedLeechers: Int = 0
    @objc dynamic var connectedPeers: Int = 0
    @objc dynamic var connectedSeeders: Int = 0
    @objc dynamic var waitingSeconds: Int = 0
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        destination <- map["destination"]
        uri <- map["uri"]
        createTime <- map["create_time"]
        startedTime <- map["started_time"]
        completedTime <- map["completed_time"]
        priority <- map["priority"]
        peers <- map["total_peers"]
        connectedLeechers <- map["connected_leechers"]
        connectedPeers <- map["connected_peers"]
        connectedSeeders <- map["connected_seeders"]
        waitingSeconds <- map["waiting_seconds"]
    }
}

class TaskAdditionalTransfer: Object, Mappable {
    
    @objc dynamic var downloadedPieces: Int = 0
    @objc dynamic var sizeDownloaded: Int = 0
    @objc dynamic var sizeUploaded: Int = 0
    @objc dynamic var speedDownload: Int = 0
    @objc dynamic var speedUpload: Int = 0
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        downloadedPieces <- map["downloaded_pieces"]
        sizeDownloaded <- map["size_downloaded"]
        sizeUploaded <- map["size_uploaded"]
        speedDownload <- map["speed_download"]
        speedUpload <- map["speed_upload"]
    }
}
