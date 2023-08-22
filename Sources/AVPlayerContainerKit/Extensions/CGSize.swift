//
//  CGSize.swift
//  

import CoreGraphics

extension CGSize {
    @inlinable
    @inline(__always)
    var isPortraiteOrientation: Bool {
        self.height > self.width
    }
    
    
}
