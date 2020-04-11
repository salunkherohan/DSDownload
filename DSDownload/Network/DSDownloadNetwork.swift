//
//  DSDownloadNetwork.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Alamofire
import SwiftyJSON

class DSDownloadNetwork {
    
    fileprivate let domainNetwork = "com.dsdownload"
    
    typealias successBlock = (_ success: JSON) -> ()
    typealias defaultSuccessBlock = (_ success: String) -> ()
    typealias errorBlock = (_ errorResult: NSError) -> ()

    func performRequest(_ action: HTTPMethod, path: String, params: [String: Any] = [String: String](), encoding: ParameterEncoding = URLEncoding(destination: .queryString), success: successBlock? = nil, error: errorBlock? = nil) {
        
        guard let session = SessionService.shared.session,
              let dsInfos = session.dsInfos
        else {
            error?(self.errorFormated("API error", description: "An error occured", code: -1))
            return
        }
        
        let fullPath = "http://\(dsInfos.host):\(dsInfos.port)/webapi/\(path)"
        
        let headers = HTTPHeaders(["Accept": "application/json"])
        
        /* Add sid in params */
        var params = params
        params["_sid"] = session.sid
        
        if DSDownloadConstants.networkLogs {
            print("Network headers : \(headers)")
            print("Network api call : \(fullPath)")
            print("Network params : \(params)")
        }
        
        AF.request(fullPath, method: action, parameters: params, encoding: encoding, headers: headers)
            .responseJSON { response in
                switch response.result {
                case .success(let result):
                    // Construct JSON result
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
    }
    
    // MARK: Private
    
    private func errorFormated(_ reason: String, description: String, code: Int) -> NSError {
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
