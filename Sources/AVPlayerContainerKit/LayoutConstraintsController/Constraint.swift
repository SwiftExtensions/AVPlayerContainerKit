//
//  Constraint.swift
//  AVPlayerContainerKit
//
//  Created by Александр Алгашев on 16.10.2025.
//

import UIKit

/**
 Представляет ограничение Auto Layout вместе с условием его активации.
 */
struct Constraint {
    /**
     Условия, при которых ограничение должно быть активно.
     */
    let layoutState: LayoutState
    /**
     Оригинальное ограничение `NSLayoutConstraint`, на которое накладываются условия.
     */
    let rawValue: NSLayoutConstraint
    
    
}
