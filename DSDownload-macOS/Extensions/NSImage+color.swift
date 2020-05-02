//
//  NSImage+color.swift
//  DSDownload
//
//  Created by Thomas le Gravier on 21/05/2019.
//

import Cocoa


extension NSImage {
    
    func tint(color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        
        let imageRect = NSRect(origin: NSZeroPoint, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        
        return image
    }
}
