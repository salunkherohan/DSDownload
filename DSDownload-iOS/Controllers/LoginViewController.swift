//
//  LoginViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Foundation
import SynologySwift


class LoginViewController: DSDownloadViewController {
    
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var quickConnectIdField: UITextField!
    @IBOutlet weak var loginField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var rememberMeSwitch: UISwitch!
    @IBOutlet weak var autologinSwitch: UISwitch!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        confirmButton.layer.cornerRadius = 8
        autologinSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.userDefaultsAutoLogin)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if sessionManager.isConnected || sessionManager.state.value == SessionManager.State.pendingValidation.rawValue {
            self.performSegue(withIdentifier: "toHome", sender: nil)
        } else {
            if autologinSwitch.isOn {
                if let qcID = quickConnectIdField.text, let username = loginField.text, let password = passwordField.text, !qcID.isEmpty, !username.isEmpty, !password.isEmpty {
                    login()
                }
            }
        }
    }
    
    @IBAction func launchConnect(_ sender: Any) {
        login()
    }
    
    // MARK: Private
    
    private let sessionManager = SessionManager.shared
    
    private func configureUI() {
        if let loginCredentials = sessionManager.loginCredentials {
            quickConnectIdField.text = loginCredentials.quickId
            loginField.text = loginCredentials.login
            passwordField.text = loginCredentials.password
        }
    }
    
    private func login() {
        UserDefaults.standard.set(autologinSwitch.isOn, forKey: Constants.userDefaultsAutoLogin)
        
        guard let quickConnectId = quickConnectIdField.text, let login = loginField.text, let password = passwordField.text else {
            fatalError("Could not get reference to login field")
        }
        
        let progressView = UIAlertController(title: "Authentication in progress", message: nil, preferredStyle: .alert)
        let progressIndicator = UIActivityIndicatorView()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        progressView.view.addSubview(progressIndicator)
        
        progressView.view.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        progressIndicator.centerYAnchor.constraint(equalTo: progressView.view.centerYAnchor, constant: 16).isActive = true
        progressIndicator.centerXAnchor.constraint(equalTo: progressView.view.centerXAnchor).isActive = true
        
        progressIndicator.startAnimating()
        
        self.present(progressView, animated: true, completion: nil)
        
        sessionManager.login(with: quickConnectId, login: login, passwd: password, rememberIdentInfos: rememberMeSwitch.isOn) { (result) in
            DispatchQueue.main.async {
                progressIndicator.stopAnimating()
                progressView.dismiss(animated: true, completion: nil)
            }
            
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "toHome", sender: nil)
                }
            case .failure(let error):
                let errorMessage: String
                switch error {
                case .other(let message):
                    errorMessage = message
                case .requestError:
                    errorMessage = "Request error"
                }
                DispatchQueue.main.async {
                    self.errorLabel.text = errorMessage
                    self.errorLabel.isHidden = false
                }
            }
        }
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case quickConnectIdField:
            quickConnectIdField.resignFirstResponder()
            loginField.becomeFirstResponder()
        case loginField:
            loginField.resignFirstResponder()
            passwordField.becomeFirstResponder()
        case passwordField:
            passwordField.resignFirstResponder()
            login()
        default:
            break
        }
        
        return true
    }
}
