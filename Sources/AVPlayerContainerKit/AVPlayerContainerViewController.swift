//
//  AVPlayerContainerViewController.swift
//  

import UIKit
import AVPlayerKit

final class StaticPropertiesStorage {
    private init() {}
    
    static var playerPresentAnimationDuration = Constant.playerPresentAnimationDuration
}

/**
 Контейнер для управления двумя дочерними контроллерами представления: плеером и вторичным контроллером.

 Этот класс предоставляет функциональность для управления макетом и анимацией между двумя дочерними контроллерами
 в зависимости от ориентации устройства. Плеер может быть представлен или скрыт с анимацией.

 - Parameter Player: Тип контроллера плеера, который должен наследоваться от UIViewController
 */
open class AVPlayerContainerViewController<Player>: UIViewController where Player : UIViewController {
    
    public static var playerPresentAnimationDuration: TimeInterval {
        get { StaticPropertiesStorage.playerPresentAnimationDuration }
        set { StaticPropertiesStorage.playerPresentAnimationDuration = newValue }
    }
    
    public private(set) weak var playerViewController: Player!
    public private(set) weak var secondaryViewController: UIViewController!
    
    private var layoutController: LayoutConstraintsController!
    
    private var isPlayerPresented = false
    
    public var isPortraite: Bool { UIScreen.main.bounds.isPortraite }
    
    private var _prefersHomeIndicatorAutoHidden = false
    open override var prefersHomeIndicatorAutoHidden: Bool {
        self._prefersHomeIndicatorAutoHidden
    }
    
    public func addChildWithDefaultPlayerViewController(
        secondaryViewController: UIViewController,
        isPlayerViewControllerPresented: Bool = true
    ) where Player == PlayerViewController {
        self.addChilds(
            playerViewController: PlayerViewController(),
            secondaryViewController: secondaryViewController,
            isPlayerViewControllerPresented: isPlayerViewControllerPresented
        )
    }
    
    public func addChilds(
        playerViewController: Player,
        secondaryViewController: UIViewController,
        isPlayerViewControllerPresented: Bool = true
    ) {
        self.playerViewController = playerViewController
        self.secondaryViewController = secondaryViewController
        self.isPlayerPresented = isPlayerViewControllerPresented
        
        self.addChild(playerViewController)
        self.addChild(secondaryViewController)
        self.view.addSubview(playerViewController.view)
        self.view.addSubview(secondaryViewController.view)
        
        self.layoutController = LayoutConstraintsController(
            rootView: self.view,
            playerView: playerViewController.view,
            secondaryView: secondaryViewController.view
        )
        self.layoutController.updateLayout(
            isPortraite: self.isPortraite,
            isPlayerPresented: isPlayerViewControllerPresented
        )
        
        playerViewController.didMove(toParent: self)
        secondaryViewController.didMove(toParent: self)
        
        self._prefersHomeIndicatorAutoHidden = self.isPlayerPresented && !self.isPortraite
        self.setupNavigationBarVisability(isPortraiteOrientation: self.isPortraite)
    }
    
    private func setupNavigationBarVisability(isPortraiteOrientation: Bool) {
        let isNavigationBarHidden = self.isPlayerPresented && !isPortraiteOrientation
        self.navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: true)
    }
    
    open override func willTransition(
        to newCollection: UITraitCollection,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        // Метод вызвается непосредственно перед запросом значения переменной
        // prefersHomeIndicatorAutoHidden
        self._prefersHomeIndicatorAutoHidden = self.isPlayerPresented && UIDevice.current.orientation.isLandscape
        super.willTransition(to: newCollection, with: coordinator)
    }
    
    open override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        // Метод вызвается после запроса значения переменной
        // prefersHomeIndicatorAutoHidden
        super.viewWillTransition(to: size, with: coordinator)
        
        self.viewWillChangeOrientation(isPortraiteOrientation: size.isPortraite)
        self.layoutController.updateLayout(
            isPortraite: size.isPortraite,
            isPlayerPresented: self.isPlayerPresented
        )
        self.setupNavigationBarVisability(isPortraiteOrientation: size.isPortraite)
    }
    /**
     Уведомляет контейнер, что ориентация представления будет изменена.
     
     - Parameter isPortraite: Новая ориентация контейнера представления.
     
     Метод ничего не делает в родительском классе. Вы можете безпрепятственно переписать этот метод для собственных задач,
     связанных с изменение ориентации.
     */
    open func viewWillChangeOrientation(isPortraiteOrientation: Bool) { }
    
    public func presentPlayerViewContainerWithAnimation() {
        if self.isPlayerPresented { return }
        self.isPlayerPresented = true
        
        UIView.animate(
            withDuration: AVPlayerContainerViewController.playerPresentAnimationDuration
        ) { [weak self, isPortraite, isPlayerPresented] in
            self?.layoutController.updateLayout(
                isPortraite: isPortraite,
                isPlayerPresented: isPlayerPresented
            )
            self?.view.layoutIfNeeded()
        }
    }
    

}
