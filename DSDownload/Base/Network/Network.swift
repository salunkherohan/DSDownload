//
//  NetworkManager.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Alamofire
import SwiftyJSON

class Network {
    
    typealias FileDescription = (data: Data, name: String, fileName: String, mimeType: String)
    
    func performRequest(_ action: HTTPMethod, path: String, params: [String: Any] = [String: String](), encoding: ParameterEncoding = URLEncoding(destination: .queryString), file: FileDescription? = nil, success: ((_ success: JSON) -> ())? = nil, error: ((_ errorResult: NSError) -> ())? = nil) {
        
        guard let sid = sessionManager.session?.sid, let dsInfos = sessionManager.session?.dsInfos else {error?(errorFormated("Session error", description: "Sid or DS infos missing", code: -1)); return}
        
        let fullPath = "http://\(dsInfos.host):\(dsInfos.port)/webapi/\(path)"
        let headers = HTTPHeaders(["Accept": "application/json"])
        
        // Add sid in params
        var params = params
        params["_sid"] = sid
        
        if Constants.networkLogs {
            print("Network headers : \(headers)")
            print("Network api call : \(fullPath)")
            print("Network params : \(params)")
        }
        
        let completion = { (response: AFDataResponse<Any>) -> Void in
            switch response.result {
            case .success(let result):
                var json = JSON([:])
                if let jsonDictionary = result as? [String: Any] {
                    if let successData = jsonDictionary["success"] as? Bool, successData == false {
                        // Check if session expired
                        if let e = jsonDictionary["error"] as? [String: Any], let errorCode = e["code"] as? Int, 105...107 ~= errorCode {
                            NotificationCenter.default.post(name: .sessionExpired, object: nil)
                            error?(self.errorFormated("API error", description: "Session expired", code: 1001))
                        } else {
                            error?(self.errorFormated("API error", description: "An error occured", code: response.response!.statusCode))
                        }
                        return
                    }
                    json = JSON(jsonDictionary)
                } else if let jsonArray = result as? [[String: Any]] {
                    json = JSON(jsonArray)
                }
                success?(json)
            case .failure(let e):
                error?(self.errorFormated("API error", description: "\("An error occured") [\(e.localizedDescription)]", code: response.response?.statusCode ?? 0))
            }
        }
        
        if let file = file {
            AF.upload(multipartFormData: { (multipartFormData) in
                for (key, value) in params {
                    guard let value = "\(value)".data(using: String.Encoding.utf8) else {continue}
                    multipartFormData.append(value, withName: key)
                }
                multipartFormData.append(file.data, withName: file.name, fileName: file.fileName, mimeType: file.mimeType)
            }, to: fullPath).responseJSON { response in
                completion(response)
            }
        } else {
            AF.request(fullPath, method: action, parameters: params, encoding: encoding, headers: headers)
            .responseJSON { response in
                completion(response)
            }
        }
    }
    
    // MARK: Private
    
    private let domainNetwork = "com.dsdownload"
    
    private let sessionManager = SessionManager.shared
    
    private func errorFormated(_ reason: String, description: String, code: Int) -> NSError {
        let dict: [String: AnyObject] = [
            NSLocalizedDescriptionKey: description as AnyObject,
            NSLocalizedFailureReasonErrorKey: reason as AnyObject,
            NSUnderlyingErrorKey: reason as AnyObject
        ]
        return NSError(domain: domainNetwork, code: code, userInfo: dict)
    }
}
