//
//  CGRect.swift
//

import CoreGraphics

extension CGRect {
    @inlinable
    @inline(__always)
    var isPortraiteOrientation: Bool {
        self.size.isPortraiteOrientation
    }
    
    
}
