//
//  TasksManager.swift
//  DSDownload-iOS
//
//  Created by Thomas le Gravier on 07/02/2019.
//

import SwiftyJSON
import RealmSwift
import SynologySwift
import Alamofire


/// TasksManager manager.
class TasksManager: DSDownloadManager {
    
    enum State: String {
        case waiting = "waiting"
        case downloading = "downloading"
        case paused = "paused"
        case finishing = "finishing"
        case finished = "finished"
        case hash_checking = "hash_checking"
        case filehosting_waiting = "filehosting_waiting"
        case extracting = "extracting"
        case error = "error"
    }
    
    func all(_ success : @escaping (List<Task>) -> (), error : @escaping () -> ()) {
        
        guard SessionService.shared.isConnected else {
            error()
            return
        }
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "list",
            "additional": "transfer, detail",
            "version": 1
        ]
        
        DSDownloadNetwork().performRequest(.get, path: "DownloadStation/task.cgi", params: params, success: { (results) in
            self.saveResults(results, callback: success)
        }) { (e) in
            error()
        }
    }
    
    func delete(_ tasks: [Task] , success : @escaping () -> (), error : @escaping () -> ()) {
        guard tasks.count > 0 else {error(); return}
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "delete",
            "force_complete": false,
            "version": 1,
            "id": tasks.map{ return $0.id }.joined(separator: ",")
        ]
        
        DSDownloadNetwork().performRequest(.get, path: "DownloadStation/task.cgi", params: params, success: { (results) in
            success()
        }) { (error) in
            // Error
        }
    }
    
    func pause(_ task: Task, success : @escaping () -> (), error : @escaping () -> ()) {
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "pause",
            "version": 1,
            "id": task.id
        ]
        
        DSDownloadNetwork().performRequest(.get, path: "DownloadStation/task.cgi", params: params, success: { (results) in
            success()
        }) { (error) in
            // Error
        }
    }
    
    func resume(_ task: Task, success : @escaping () -> (), error : @escaping () -> ()) {
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "resume",
            "version": 1,
            "id": task.id
        ]
        
        DSDownloadNetwork().performRequest(.get, path: "DownloadStation/task.cgi", params: params, success: { (results) in
            success()
        }) { (error) in
            // Error
        }
    }
    
    func add(_ magnet: String , success : @escaping () -> (), error : @escaping (Error?) -> ()) {
        
        let params: [String: Any] = [
            "api": "SYNO.DownloadStation.Task",
            "method": "create",
            "version": 1,
            "uri": magnet
        ]
        
        DSDownloadNetwork().performRequest(.post, path: "DownloadStation/task.cgi", params: params, encoding: URLEncoding(destination: .httpBody), success: { (results) in
            success()
        }) { (e) in
            error(e)
        }
    }
    
    // Mark : Tools
    
    func haActiveTasks() -> Bool {
        let stopStates = [Task.StatusType.paused.rawValue, Task.StatusType.finished.rawValue, Task.StatusType.seeding.rawValue, Task.StatusType.error.rawValue]
        let realm = try! Realm()
        let taks = realm.objects(Task.self).filter("NOT (status IN %@)", stopStates)
        return taks.count > 0
    }
    
    // Mark : Private
    
    private func saveResults(_ results: JSON, callback: (List<Task>) -> ()) {
        let realm = try! Realm()
        var tasks = List<Task>()
        
        guard let tasksData = results.dictionary?["data"]?["tasks"].array
        else {return}
        
        // Delete all
        try! realm.write {
            realm.delete(realm.objects(Task.self))
            realm.delete(realm.objects(TaskExtra.self))
        }
        
        // Save tasks
        for task in tasksData {
            let t = Task(value: task.object)
            try! realm.write {
                realm.add(t, update: true)
            }
            tasks.append(t)
        }
        tasks.reverse()
        callback(tasks)
    }
    
}
