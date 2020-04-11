//
//  KeychainService.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 05/02/2019.
//

import Foundation
import Security


let kSecClassValue = NSString(format: kSecClass)
let kSecAttrAccountValue = NSString(format: kSecAttrAccount)
let kSecValueDataValue = NSString(format: kSecValueData)
let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword)
let kSecAttrServiceValue = NSString(format: kSecAttrService)
let kSecMatchLimitValue = NSString(format: kSecMatchLimit)
let kSecReturnDataValue = NSString(format: kSecReturnData)
let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne)


class KeychainService: NSObject {
    
    func save(service: String, key: String, data: Data) {
        let keychainQuery: NSMutableDictionary = NSMutableDictionary(objects: [kSecClassGenericPasswordValue, service, key, data], forKeys: [kSecClassValue, kSecAttrServiceValue, kSecAttrAccountValue, kSecValueDataValue])
        let status = SecItemAdd(keychainQuery as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            update(service: service, key: key, data: data)
        } else if status != errSecSuccess {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Write failed: \(err)")
            }
        }
    }
    
    func update(service: String, key:String, data: Data) {
        let keychainQuery: NSMutableDictionary = NSMutableDictionary(objects: [kSecClassGenericPasswordValue, service, key], forKeys: [kSecClassValue, kSecAttrServiceValue, kSecAttrAccountValue])
        
        let status = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueDataValue: data] as CFDictionary)
        
        if status != errSecSuccess {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Update failed: \(err)")
            }
        }
    }
    
    func load(service: String, key: String) -> Data? {
        let keychainQuery: NSMutableDictionary = NSMutableDictionary(objects: [kSecClassGenericPasswordValue, service, key, kCFBooleanTrue, kSecMatchLimitOneValue], forKeys: [kSecClassValue, kSecAttrServiceValue, kSecAttrAccountValue, kSecReturnDataValue, kSecMatchLimitValue])
        var dataTypeRef :AnyObject?
        
        let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        var contentsOfKeychain: Data?
        
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data {
                contentsOfKeychain = retrievedData
            }
        }
        
        return contentsOfKeychain
    }
    
    func remove(service: String, key: String) {
        let keychainQuery: NSMutableDictionary = NSMutableDictionary(objects: [kSecClassGenericPasswordValue, service, key, kCFBooleanTrue], forKeys: [kSecClassValue, kSecAttrServiceValue, kSecAttrAccountValue, kSecReturnDataValue])
        
        let status = SecItemDelete(keychainQuery as CFDictionary)
        if status != errSecSuccess {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Remove failed: \(err)")
            }
        }
        
    }
}
