//
//  NSLayoutConstraint.swift
//  AVPlayerContainerKit
//
//  Created by Александр Алгашев on 16.10.2025.
//

import UIKit

extension NSLayoutConstraint {
    /**
     Устанавливает новый приоритет для текущего ограничения верстки.

     - Parameter priority: Приоритет, который нужно установить ограничению.

     ## Пример
     ```swift
     let constraint = view.widthAnchor.constraint(equalToConstant: 100)
         .setPriority(.defaultHigh)
     ```
     */
    func setPriority(_ priority: UILayoutPriority) -> Self {
        self.priority = priority
        return self
    }
    
    
}
