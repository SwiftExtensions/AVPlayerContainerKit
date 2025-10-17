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
            playerView.topAnchor.constraint(equalTo: rootView.safeAreaTopAnchor).bind(with: .portraitPlayerPresented),
            playerView.topAnchor.constraint(equalTo: rootView.topAnchor).bind(with: .landscapePlayerPresented),
            playerView.leftAnchor.constraint(equalTo: rootView.leftAnchor).bind(),
            playerView.widthAnchor.constraint(equalTo: rootView.widthAnchor).bind(),
            playerView.heightAnchor.constraint(equalTo: rootView.widthAnchor, multiplier: Constant.playerAspectRatio).bind(with: [.portrait]),
            playerView.heightAnchor.constraint(equalTo: rootView.heightAnchor).bind(with: [.landscape]),
            playerView.bottomAnchor.constraint(equalTo: rootView.topAnchor).bind(with: [.portraitPlayerHidden, .landscapePlayerHidden]),
            
            secondaryView.topAnchor.constraint(equalTo: playerView.bottomAnchor).bind(with: [.portraitPlayerPresented, .landscapePlayerPresented]),
            secondaryView.topAnchor.constraint(equalTo: rootView.safeAreaTopAnchor).bind(with: .portraitPlayerHidden),
            secondaryView.topAnchor.constraint(equalTo: rootView.topAnchor).bind(with: .landscapePlayerHidden),
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
        let layoutState: Constraint.LayoutState
        switch (isPortraite, isPlayerPresented) {
        case (true, true):
            layoutState = .portraitPlayerPresented
        case (true, false):
            layoutState = .portraitPlayerHidden
        case (false, true):
            layoutState = .landscapePlayerPresented
        case (false, false):
            layoutState = .landscapePlayerHidden
        }
        self.updateLayout(for: layoutState)
    }
    /**
     Активирует и деактивирует ограничения согласно переданному условию.

     - Parameter layoutState: Условие, определяющее набор активных ограничений.
     */
    private func updateLayout(for layoutState: Constraint.LayoutState) {
        let deactivate = self.constraints.filter { !$0.layoutState.contains(layoutState) }.map(\.rawValue)
        NSLayoutConstraint.deactivate(deactivate)
        let activate = self.constraints.filter { $0.layoutState.contains(layoutState) }.map(\.rawValue)
        NSLayoutConstraint.activate(activate)
    }
    
    
}

extension NSLayoutConstraint {
    /**
     Оборачивает ограничение в `Constraint`, сопоставляя его с условием активации.

     - Parameter layoutState: Условие, при котором ограничение должно быть активно.
     */
    func bind(with layoutState: Constraint.LayoutState = .all) -> Constraint {
        Constraint(layoutState: layoutState, rawValue: self)
    }
    
    
}
