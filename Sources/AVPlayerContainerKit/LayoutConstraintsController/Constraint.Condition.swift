//
//  Constraint.LayoutState.swift
//  AVPlayerContainerKit
//
//  Created by Александр Алгашев on 16.10.2025.
//


extension Constraint {
    /**
     Набор условий, описывающих состояние плеера и устройства для активации ограничений.
     */
    struct LayoutState: OptionSet {
        /**
         Битовое представление набора условий.
         */
        let rawValue: Int

        /**
         Плеер отображается в портретной ориентации.
         */
        static let portraitPlayerPresented  = LayoutState(rawValue: 1 << 0)
        /**
         Плеер скрыт в портретной ориентации.
         */
        static let portraitPlayerHidden     = LayoutState(rawValue: 1 << 1)
        /**
         Плеер отображается в ландшафтной ориентации.
         */
        static let landscapePlayerPresented = LayoutState(rawValue: 1 << 2)
        /**
         Плеер скрыт в ландшафтной ориентации.
         */
        static let landscapePlayerHidden    = LayoutState(rawValue: 1 << 3)

        /**
         Любое состояние в портретной ориентации.
         */
        static let portrait: LayoutState = [.portraitPlayerPresented, .portraitPlayerHidden]
        /**
         Любое состояние в ландшафтной ориентации.
         */
        static let landscape: LayoutState = [.landscapePlayerPresented, .landscapePlayerHidden]
        /**
         Все возможные состояния ориентации и отображения плеера.
         */
        static let all: LayoutState = [.portrait, .landscape]


    }

    
}
