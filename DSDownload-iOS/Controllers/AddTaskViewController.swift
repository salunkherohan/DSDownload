//
//  AddTaskViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 24/04/2020.
//

import UIKit

class AddTaskViewController: UITableViewController {
    @IBOutlet weak var linkTextView: UITextView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBAction func didTapCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBOutlet weak var addButton: UIButton!
    @IBAction func didTapAdd(_ sender: Any) {
        startLoading()
        
        let magnet = linkTextView.text.lowercased()
        
        if !magnet.hasPrefix("magnet:") {
            showErrorMessage("Magnet link format error")
            endLoading()
        } else {
            let taskManager = TaskManager.shared
            
            taskManager.add(magnet) { [weak self] (result) in
                DispatchQueue.main.async {
                    self?.endLoading()
                    
                    guard !result else {
                        self?.dismiss(animated: true, completion: nil)
                        return
                    }
                    
                    self?.showErrorMessage("An error occurred")
                }
            }
        }
    }
    
    @IBOutlet weak var pasteButton: UIButton!
    @IBAction func didTapPaste(_ sender: Any) {
        linkTextView.text = UIPasteboard.general.string
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
    }
    
    // MARK: Private
    
    private func showErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        
        let OKButton = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(OKButton)
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: Loading
    
    private func startLoading() {
        if let selectedRowIndex = tableView?.indexPathForSelectedRow {
            tableView?.deselectRow(at: selectedRowIndex, animated: true)
        }
        
        tableView?.isUserInteractionEnabled = false
        
        [addButton, cancelButton, pasteButton].forEach { $0?.isEnabled = false }
    }
    
    private func endLoading() {
        tableView?.isUserInteractionEnabled = true
        
        [addButton, cancelButton, pasteButton].forEach { $0?.isEnabled = true }
    }
}
