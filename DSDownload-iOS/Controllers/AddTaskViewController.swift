//
//  AddTaskViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 24/04/2020.
//

import UIKit

class AddTaskViewController: UITableViewController {
    @IBOutlet weak var linkTextView: UITextView!
    
    @IBAction func didTapCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didTapAdd(_ sender: Any) {
        let magnet = linkTextView.text.lowercased()
        
        if !magnet.hasPrefix("magnet:") {
            showErrorMessage("Magnet link format error")
        } else {
            let taskManager = TaskManager.shared
            
            taskManager.add(magnet) { [weak self] (result) in
                guard !result else {return}
                DispatchQueue.main.async {
                    self?.showErrorMessage("An error occurred")
                }
            }
        }
    }
    
    @IBAction func didTapPaste(_ sender: Any) {
        linkTextView.text = UIPasteboard.general.string
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
    }
    
    private func showErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        
        let OKButton = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(OKButton)
        
        present(alert, animated: true, completion: nil)
    }
}
