//
//  CGSize.swift
//  

import CoreGraphics

extension CGSize {
    var isPortraiteOrientation: Bool {
        self.height > self.width
    }
    
    
}
