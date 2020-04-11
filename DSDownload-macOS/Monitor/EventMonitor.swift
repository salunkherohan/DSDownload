//
//  EventMonitor.swift
//  DSDownload-macOS
//
//  Created by Thomas le Gravier on 01/02/2019.
//

import Cocoa


class EventMonitor {
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
    
    // MARK: Private
    
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    private var monitor: Any?
}
