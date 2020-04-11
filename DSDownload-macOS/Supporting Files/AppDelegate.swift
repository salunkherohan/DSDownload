//
//  AppDelegate.swift
//  DSDownload-macOS
//
//  Created by Thomas le Gravier on 31/01/2019.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    static private(set) var shared: AppDelegate!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let popover = NSPopover()
    var eventMonitor: EventMonitor?
    
    override init() {
        super.init()
        
        assert(AppDelegate.shared == nil)
        AppDelegate.shared = self
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        /* Core init */
        DSDownloadInit.launch()
        
        /* Create menu button */
        if let button = statusItem.button {
            button.image = NSImage(imageLiteralResourceName: "img_status_bar_ico")
            button.action = #selector(AppDelegate.togglePopover(_:))
        }
        
        popover.contentViewController = SessionService.shared.isConnected && !DSDownloadConstants.forceLogin ? HomeViewController.setup() : LoginViewController.setup()
        popover.behavior = .transient
        popover.animates = false
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let strongSelf = self, strongSelf.popover.isShown else {return}
            self?.closePopover(sender: event)
        }
    }
    
    // MARK: Popover
    
    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    func showPopover(sender: Any?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            eventMonitor?.start()
        }
    }
    
    func closePopover(sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    
}

