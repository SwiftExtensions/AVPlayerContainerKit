//
//  UIView.swift
//  

import UIKit

extension UIView {
    var safeAreaTopAnchor: NSLayoutYAxisAnchor {
        let topAnchor: NSLayoutYAxisAnchor
        if #available(iOS 11.0, *) {
            topAnchor = self.safeAreaLayoutGuide.topAnchor
        } else {
            topAnchor = self.topAnchor
        }
        
        return topAnchor
    }
    
    
}
