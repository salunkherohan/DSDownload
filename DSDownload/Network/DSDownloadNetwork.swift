//
//  DSDownloadNetwork.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Alamofire
import SwiftyJSON


/// DSDownloadNetwork class. Perform and manager all network calls.
class DSDownloadNetwork: NSObject {
    
    fileprivate let domainNetwork = "fr.thomas-legravier.DSDownload"
    
    typealias successBlock = (_ success: JSON) -> ()
    typealias defaultSuccessBlock = (_ success: String) -> ()
    typealias errorBlock = (_ errorResult: NSError) -> ()
    
    /**
     Perform a request. Trigger start, progress, success and error callback.
     - parameter action: Method type (GET, POST, PUT...)
     - parameter path: Path on API
     - parameter params: Params pass for call - Optional
     - parameter start: Callback on start action - Optional
     - parameter progress: Callback on progress action - Optional
     - parameter success: Callback on success action - Optional
     - parameter error: Callback on error action - Optional
     - returns: Void
     */
    func performRequest(_ action: HTTPMethod, path: String, params: [String: Any] = [String: String](), encoding: ParameterEncoding = URLEncoding(destination: .queryString), success: successBlock? = nil, error: errorBlock? = nil) {
        
        guard let session = SessionService.shared.session,
              let dsInfos = session.dsInfos
        else {
            error?(self.getErrorFormated("API error", description: "An error occured", code:-1))
            return
        }
        
        let fullPath = "http://\(dsInfos.host):\(dsInfos.port)/webapi/\(path)"
        
        let headers: [String:String] = [
            "Accept": "application/json"
        ]
        
        /* Add sid in params */
        var params = params
        params["_sid"] = session.sid
        
        if DSDownloadConstants.networkLogs {
            print("Network headers : \(headers)")
            print("Network api call : \(fullPath)")
            print("Network params : \(params)")
        }
        
        Alamofire.request(fullPath, method: action, parameters: params, encoding: encoding, headers: headers)
            .responseJSON { response in
                if response.response != nil {
                    if response.response!.statusCode == 503 {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "networkCode503"), object: nil) // Offline
                    }
                }
                if response.result.error != nil {
                    if response.response == nil {
                        error?(self.getErrorFormated("Connection error", description: "network is not reachable", code: -1))
                    } else {
                        error?(self.getErrorFormated("API error", description: "An error occured", code:response.response!.statusCode))
                    }
                } else if let value = response.result.value {
                    var json = JSON([:])
                    if let jsonDictionary = value as? [String: Any] {
                        if let successData = jsonDictionary["success"] as? Bool,
                           !successData {
                            /* Check if session expired */
                            if let e = jsonDictionary["error"] as? [String: Any], let errorCode = e["code"] as? Int, 105...107 ~= errorCode {
                                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                                error?(self.getErrorFormated("API error", description: "Session expired", code: 1001))
                            } else {
                                error?(self.getErrorFormated("API error", description: "An error occured", code: response.response!.statusCode))
                            }
                            return
                        }
                        json = JSON(jsonDictionary)
                    } else if let jsonArray = value as? [[String: Any]] {
                        json = JSON(jsonArray)
                    }
                    success?(json)
                } else {
                    print("JSON format error")
                }
        }
    }
    
    /**
     Format call error.
     - parameter reason: Reason of error
     - parameter description: Error description
     - parameter code: Error code
     - returns: NSError
     */
    fileprivate func getErrorFormated(_ reason: String, description: String, code: Int) -> NSError {
        let dict : [String: AnyObject] = [
            NSLocalizedDescriptionKey: description as AnyObject,
            NSLocalizedFailureReasonErrorKey : reason as AnyObject,
            NSUnderlyingErrorKey : reason as AnyObject
        ]
        let error : NSError = NSError(domain: domainNetwork,
                                      code: code,
                                      userInfo:dict)
        
        return error
    }
}
