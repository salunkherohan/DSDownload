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
    
    func applicationWillFinishLaunching(_ aNotification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleOpenURL(event:reply:)), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialization
        DSInit.configure()
        
        // Create menu button
        if let button = statusItem.button {
            button.image = NSImage(imageLiteralResourceName: "status-bar-icon")
            button.action = #selector(AppDelegate.togglePopover(_:))
        }
        
        let sessionManager = SessionManager.shared
        popover.contentViewController = sessionManager.state.value == SessionManager.State.pendingValidation.rawValue || sessionManager.isConnected ? HomeViewController.setup() : LoginViewController.setup()
        popover.behavior = .transient
        popover.animates = false
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let strongSelf = self, strongSelf.popover.isShown else {return}
            self?.closePopover(sender: event)
        }
    }
    
    @objc  func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        TaskManager.shared.add(URL(fileURLWithPath: filename))
        return true
    }
    
    @objc func handleOpenURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let magnet = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {return}
        TaskManager.shared.add(magnet)
    }
    
    // MARK: Popover
    
    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    // MARK: Private
    
    private func showPopover(sender: Any?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            eventMonitor?.start()
        }
    }
    
    private func closePopover(sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    
}

