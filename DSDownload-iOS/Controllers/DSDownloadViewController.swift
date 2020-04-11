//
//  DSDownloadViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Foundation
import UIKit


class DSDownloadViewController: UIViewController {
    
    /* Analytics */
    var screenName: String
    
    /* Init class. Set class name for default screen name. */
    required init(coder aDecoder: NSCoder) {
        screenName = NSStringFromClass(type(of: self))
        super.init(coder: aDecoder)!
    }
    
    /* Custom viewDidLoad. */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Something to do ?
    }
    
    /* Custom viewWillAppear. */
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Something to do ?
    }
}
