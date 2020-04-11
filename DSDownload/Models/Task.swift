//
//  Task.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 11/02/2019.
//

import Foundation
import RealmSwift


class Task: Object {
    
    enum StatusType: String {
        case waiting = "waiting"
        case downloading = "downloading"
        case paused = "paused"
        case finishing = "finishing"
        case finished = "finished"
        case hash_checking = "hash checking"
        case seeding = "seeding"
        case filehosting_waiting = "filehosting waiting"
        case extracting = "extracting"
        case error = "error"
    }
    
    @objc dynamic var id = ""
    @objc dynamic var title = ""
    @objc dynamic var size = 0
    @objc dynamic var status = ""
    @objc dynamic var status_extra: TaskExtra? = nil
    @objc dynamic var type = ""
    @objc dynamic var username = ""
    @objc dynamic var additional: TaskAdditional? = nil
    @objc dynamic var update_date = Date()
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    // MARK: Tools
    
    /* Return speed on download or upload for task.
     * Priority on download speed.
     * Return empty string if task is not active.
     */
    var speed: String {
        guard let additional = additional,
            let transfer = additional.transfer,
            transfer.speed_upload > 0 || transfer.speed_download > 0
            else {return ""}
        
        let up = DSDownloadTools.convertBytes(transfer.speed_upload)
        let down = DSDownloadTools.convertBytes(transfer.speed_download)
        
        return transfer.speed_download > 0 ? "↓ \(down) mb/s" : "↑ \(up) mb/s"
    }
    
    /* Return progress in % of a task. */
    var progress: String {
        guard let additional = additional else {return ""}
        
        if  additional.detail?.completed_time ?? 0 > 0 {
            return "100%"
        } else if let downloadSize = additional.transfer?.size_downloaded {
            if size > 0 && downloadSize == size {
                return "100%"
            } else if downloadSize > 0 && size > 0 {
                let progress = (Double(downloadSize)/Double(size))*100
                return "\(String(format: "%.2f", progress))%"
            } else {
                return "0%"
            }
        }
        return ""
    }
    
    /* Return size for task in GB. */
    var sizeToString: String {
        return size <= 0 ? "N/A" : DSDownloadTools.convertBytes(size, unit: .useGB)
    }
}

class TaskExtra: Object {
    @objc dynamic var error_detail = ""
}

class TaskAdditional: Object {
    @objc dynamic var detail: TaskAdditionalDetail? = nil
    @objc dynamic var transfer: TaskAdditionalTransfer? = nil
}

/* Task Additional infos */

class TaskAdditionalDetail: Object {
    @objc dynamic var destination = ""
    @objc dynamic var uri = ""
    @objc dynamic var create_time = 0
    @objc dynamic var started_time = 0
    @objc dynamic var completed_time = 0
    @objc dynamic var priority: String? = nil
    @objc dynamic var total_peers = 0
    @objc dynamic var connected_leechers = 0
    @objc dynamic var connected_peers = 0
    @objc dynamic var connected_seeders = 0
    @objc dynamic var waiting_seconds = 0
}

class TaskAdditionalTransfer: Object {
    @objc dynamic var downloaded_pieces = 0
    @objc dynamic var size_downloaded = 0
    @objc dynamic var size_uploaded = 0
    @objc dynamic var speed_download = 0
    @objc dynamic var speed_upload = 0
}
