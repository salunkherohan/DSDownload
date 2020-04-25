//
//  ErrorMessenger.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 25/04/2020.
//

import UIKit

protocol ErrorMessenger {
    func showErrorMessage(_ message: String)
}

extension UIViewController: ErrorMessenger {
    func showErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        
        let OKAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(OKAction)
        
        present(alert, animated: true, completion: nil)
    }
}
