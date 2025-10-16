//
//  CGRect.swift
//

import CoreGraphics

extension CGRect {
    @inlinable
    @inline(__always)
    var isPortraite: Bool {
        self.size.isPortraite
    }
    
    
}
