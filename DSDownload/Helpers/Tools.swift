//
//  Tools.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 11/02/2019.
//

import Foundation

class Tools {
    
    /* Convert size in bytes to size in string without unit */
    static func convertBytes(_ bytes: Int, unit: ByteCountFormatter.Units = .useMB) -> String {
        guard bytes > 0 else {return "0"}
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [unit]
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    static func prettyPrintNumber(_ number: Int) -> String {
        switch number {
        case 0..<1024:
            return "\(number) "
        case 1_000..<1024*1024:
            return String(format:"%.1f", Float(number)/1024) + " k"
        case 1_000_000..<1024*1024*1024:
            return String(format:"%.1f", Float(number)/1024/1024) + " M"
        default:
            return String(format:"%.1f", Float(number)/1024/1024/1024) + " G"
        }
    }
}
