//
//  CGSize.swift
//  

import CoreGraphics

extension CGSize {
    @inlinable
    @inline(__always)
    var isPortraite: Bool {
        self.height > self.width
    }
    
    
}
