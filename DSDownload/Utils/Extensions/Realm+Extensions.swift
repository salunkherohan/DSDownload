//
//  Realm+Extensions.swift
//  DSDownload
//
//  Created by Thomas LE GRAVIER on 20/04/2020.
//

import RealmSwift

extension Realm {
    
    func safeWrite(_ block: (() throws -> Void)) throws {
        if isInWriteTransaction {
            try block()
        } else {
            try write(block)
        }
    }
}
