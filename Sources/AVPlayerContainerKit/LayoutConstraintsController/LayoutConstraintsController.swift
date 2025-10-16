//
//  LayoutConstraintsController.swift
//  AVPlayerContainerKit
//
//  Created by Александр Алгашев on 15.10.2025.
//

import UIKit

/**
 Контроллер управления набором ограничений Auto Layout для компоновки плеера и дополнительного представления.
 */
struct LayoutConstraintsController {
    /**
     Коллекция ограничений с условиями активации.
     */
    let constraints: [Constraint]
    
    /**
     Создает контроллер ограничений и подготавливает набор `constraints` для различных состояний ориентации и отображения плеера.

     - Parameter rootView: Корневая вью, относительно которой выстраиваются ограничения.
     - Parameter playerView: Вью, содержащая плеер.
     - Parameter secondaryView: Дополнительная вью под плеером.
     */
    init(rootView: UIView, playerView: UIView, secondaryView: UIView) {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        secondaryView.translatesAutoresizingMaskIntoConstraints = false
        
        self.constraints = [
            playerView.topAnchor.constraint(equalTo: rootView.safeAreaTopAnchor).bind(with: [.portrait, .landscapePlayerHidden]),
            playerView.topAnchor.constraint(equalTo: rootView.topAnchor).bind(with: [.landscapePlayerPresented]),
            playerView.leftAnchor.constraint(equalTo: rootView.leftAnchor).bind(),
            playerView.widthAnchor.constraint(equalTo: rootView.widthAnchor).bind(),
            playerView.heightAnchor.constraint(equalTo: rootView.widthAnchor, multiplier: Constant.playerAspectRatio).bind(with: [.portraitPlayerPresented]),
            playerView.heightAnchor.constraint(equalToConstant: 0.0).bind(with: [.portraitPlayerHidden, .landscapePlayerHidden]),
            playerView.heightAnchor.constraint(equalTo: rootView.heightAnchor).bind(with: [.landscapePlayerPresented]),
            
            secondaryView.topAnchor.constraint(equalTo: playerView.bottomAnchor).bind(),
            secondaryView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor).bind(),
            secondaryView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor).bind(),
            secondaryView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor).setPriority(.defaultHigh).bind(with: .portrait),
            secondaryView.heightAnchor.constraint(equalTo: rootView.heightAnchor).bind(with: .landscape),
        ]
    }
    
    /**
     Обновляет активные ограничения на основании текущей ориентации и состояния плеера.

     - Parameter isPortraite: Флаг портретной ориентации устройства.
     - Parameter isPlayerPresented: Флаг отображения плеера на экране.
     */
    func updateLayout(isPortraite: Bool, isPlayerPresented: Bool) {
        let condition: Constraint.Condition
        switch (isPortraite, isPlayerPresented) {
        case (true, true):
            condition = .portraitPlayerPresented
        case (true, false):
            condition = .portraitPlayerHidden
        case (false, true):
            condition = .landscapePlayerPresented
        case (false, false):
            condition = .landscapePlayerHidden
        }
        self.updateLayout(for: condition)
    }
    /**
     Активирует и деактивирует ограничения согласно переданному условию.

     - Parameter condition: Условие, определяющее набор активных ограничений.
     */
    private func updateLayout(for condition: Constraint.Condition) {
        let deactivate = self.constraints.filter { !$0.condition.contains(condition) }.map(\.rawValue)
        NSLayoutConstraint.deactivate(deactivate)
        let activate = self.constraints.filter { $0.condition.contains(condition) }.map(\.rawValue)
        NSLayoutConstraint.activate(activate)
    }
    
    
}

extension NSLayoutConstraint {
    /**
     Оборачивает ограничение в `Constraint`, сопоставляя его с условием активации.

     - Parameter condition: Условие, при котором ограничение должно быть активно.
     */
    func bind(with condition: Constraint.Condition = .all) -> Constraint {
        Constraint(condition: condition, rawValue: self)
    }
    
    
}
