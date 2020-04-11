//
//  LoginViewController.swift
//  DSDownload-macOS
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Cocoa

class LoginViewController: NSViewController {
    
    static func setup() -> LoginViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("LoginViewController")
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? LoginViewController else {fatalError("LoginViewController not found - Check Main.storyboard")}
        return viewcontroller
    }
    
    @IBOutlet weak var quickConnectIdField: NSTextField!
    @IBOutlet weak var loginField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    @IBOutlet weak var confirmButton: NSButton!
    
    @IBOutlet weak var progressView: NSProgressIndicator!
    @IBOutlet weak var errorLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureMenus()
    }
    
    @IBAction func launchConnect(_ sender: Any) {
        progressView.isHidden = false
        progressView.startAnimation(nil)
        confirmButton.isEnabled = false
        errorLabel.stringValue = ""
        SessionManager().login(with: quickConnectIdField.stringValue, login: loginField.stringValue, passwd: passwordField.stringValue) { (result) in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    AppDelegate.shared.popover.contentViewController = HomeViewController.setup(fromLogin: true)
                    AppDelegate.shared.popover.contentSize = NSSize(width: 500, height: 170)
                }
            case .failure(let error):
                var errorMessage = "Unknown error"
                switch error {
                case .other(let message):
                    errorMessage = message
                case .requestError(_): ()
                }
                DispatchQueue.main.async {
                    self.errorLabel.stringValue = errorMessage
                    self.errorLabel.isHidden = false
                }
            }
            DispatchQueue.main.async {
                self.progressView.isHidden = true
                self.progressView.startAnimation(nil)
                self.confirmButton.isEnabled = true
            }
        }
    }
    
    @IBAction func willExitAction(_ sender: Any) {
        guard let event = NSApplication.shared.currentEvent else {return}
        NSMenu.popUpContextMenu(exitContextMenu, with: event, for: sender as! NSView)
    }
    
    @objc private func willExit(_ sender: AnyObject) {
        /* Shutdown app */
        NSApplication.shared.terminate(self)
    }
    
    // MARK: Private
    
    private let exitContextMenu = NSMenu()
    
    private func configureUI() {
        confirmButton.wantsLayer = true
        confirmButton.layer?.backgroundColor = NSColor(calibratedRed: 0.20, green: 0.44, blue: 0.58, alpha: 1.0).cgColor
    
        if let loginCredentials = SessionService.shared.loginCredentials {
            quickConnectIdField.stringValue = loginCredentials.quickId
            loginField.stringValue = loginCredentials.login
            passwordField.stringValue = loginCredentials.password
        }
    }
    
    private func configureMenus() {
        let exitAppItem = NSMenuItem(title: "Exit", action: #selector(willExit(_:)), keyEquivalent: "q")
        exitContextMenu.addItem(exitAppItem)
    }
}
