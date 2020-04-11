//
//  LoginViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Foundation
import SynologySwift


class LoginViewController: DSDownloadViewController {
    
    /* Custom viewDidLoad. */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // To Remove
//        InitManager().globalInfos()
    }
    
    @IBAction func launchConnect(_ sender: Any) {
        connect()
    }
    
    // Mark  : Private
    
    private func connect() {
        SynologySwift.login(quickConnectid: DSDownloadConstants.quickConnectId, login: DSDownloadConstants.quickConnectLogin, password: DSDownloadConstants.quickConnectPassword, useDefaultCacheApis: true) { (result) in
            switch result {
            case .success(let data):
                print("OKKK : \(data)")
            case .failure(let error):
                print("OUPS: \(error)")
            }
        }
    }
}
