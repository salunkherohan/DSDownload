//
//  DSDownloadTools.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 11/02/2019.
//

import Foundation


class DSDownloadTools {
    
    /* Format params dictonary to query string */
    static func queryStringForParams(_ params: [String: Any]) -> String? {
        var postComponents = URLComponents()
        postComponents.queryItems = params.map{ URLQueryItem(name: $0.key, value: $0.value as? String) }
        return postComponents.percentEncodedQuery!.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "+").inverted)
    }
    
    /* Convert size in bytes to size in string without unit */
    static func convertBytes(_ bytes: Int, unit: ByteCountFormatter.Units = .useMB) -> String {
        guard bytes > 0 else {return "0"}
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [unit]
        return bcf.string(fromByteCount: Int64(bytes))
    }
}
