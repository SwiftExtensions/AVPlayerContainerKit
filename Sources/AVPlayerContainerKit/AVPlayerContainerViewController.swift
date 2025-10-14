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
    
    private var playerViewConstraints = [NSLayoutConstraint]()
    private var secondaryViewConstraints = [NSLayoutConstraint]()
    
    private var isPlayerViewControllerPresented = false
    
    public var isPortraiteOrientation: Bool { UIScreen.main.bounds.isPortraiteOrientation }
    
    private var _prefersHomeIndicatorAutoHidden = false
    open override var prefersHomeIndicatorAutoHidden: Bool {
        self._prefersHomeIndicatorAutoHidden
    }
    
    public func addChildWithDefaultPlayerViewController(
        secondaryViewController: UIViewController,
        isPlayerViewControllerPresented: Bool
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
        isPlayerViewControllerPresented: Bool
    ) {
        self.isPlayerViewControllerPresented = isPlayerViewControllerPresented
        let isPortraiteOrientation = self.isPortraiteOrientation
        
        self.playerViewController = playerViewController
        self.insertChild(playerViewController) { parentView, childView in
            childView.translatesAutoresizingMaskIntoConstraints = false
            self.setupPlayerViewConstraints(childView, isPortraiteOrientation: isPortraiteOrientation)
            NSLayoutConstraint.activate(self.playerViewConstraints)
        }
        
        self.secondaryViewController = secondaryViewController
        self.insertChild(secondaryViewController) { parentView, childView in
            childView.translatesAutoresizingMaskIntoConstraints = false
            self.setupSecondaryViewConstraints(childView, isPortraiteOrientation: isPortraiteOrientation)
            NSLayoutConstraint.activate(self.secondaryViewConstraints)
        }
        
        self._prefersHomeIndicatorAutoHidden = self.isPlayerViewControllerPresented && !self.isPortraiteOrientation
        self.setupNavigationBarVisability(isPortraiteOrientation: self.isPortraiteOrientation)
    }
    
    private func setupNavigationBarVisability(isPortraiteOrientation: Bool) {
        let isNavigationBarHidden = self.isPlayerViewControllerPresented && !isPortraiteOrientation
        self.navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: true)
    }
    
    private func setupPlayerViewConstraints(_ playerView: UIView, isPortraiteOrientation: Bool) {
        if isPortraiteOrientation {
            let playerHeightConstraint: NSLayoutConstraint
            if self.isPlayerViewControllerPresented {
                playerHeightConstraint = playerView.heightAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: Constant.playerAspectRatio)
            } else {
                playerHeightConstraint = playerView.heightAnchor.constraint(equalToConstant: 0.0)
            }
            self.playerViewConstraints = [
                playerView.topAnchor.constraint(equalTo: self.view.safeAreaTopAnchor),
                playerView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                playerView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
                playerHeightConstraint
            ]
        } else {
            let topAnchor: NSLayoutYAxisAnchor
            let playerHeightConstraint: NSLayoutConstraint
            if self.isPlayerViewControllerPresented {
                playerHeightConstraint = playerView.heightAnchor.constraint(equalTo: self.view.heightAnchor)
                topAnchor = self.view.topAnchor
            } else {
                playerHeightConstraint = playerView.heightAnchor.constraint(equalToConstant: 0.0)
                topAnchor = self.view.safeAreaTopAnchor
            }
            self.playerViewConstraints = [
                playerView.topAnchor.constraint(equalTo: topAnchor),
                playerView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                playerView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                playerHeightConstraint
            ]
        }
    }
    
    private func setupSecondaryViewConstraints(_ secondaryView: UIView, isPortraiteOrientation: Bool) {
        if isPortraiteOrientation {
            let secondaryViewBottomConstraint = secondaryView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            secondaryViewBottomConstraint.priority = .defaultHigh
            self.secondaryViewConstraints = [
                secondaryView.topAnchor.constraint(equalTo: self.playerViewController.view.bottomAnchor),
                secondaryView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                secondaryView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                secondaryViewBottomConstraint,
            ]
        } else {
            self.secondaryViewConstraints = [
                secondaryView.topAnchor.constraint(equalTo: self.playerViewController.view.bottomAnchor),
                secondaryView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                secondaryView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                secondaryView.heightAnchor.constraint(equalTo: self.view.heightAnchor)
            ]
        }
    }
    
    open override func willTransition(
        to newCollection: UITraitCollection,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        // Метод вызвается непосредственно перед запросом значения переменной
        // prefersHomeIndicatorAutoHidden
        self._prefersHomeIndicatorAutoHidden = self.isPlayerViewControllerPresented && UIDevice.current.orientation.isLandscape
        super.willTransition(to: newCollection, with: coordinator)
    }
    
    open override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        // Метод вызвается после запроса значения переменной
        // prefersHomeIndicatorAutoHidden
        super.viewWillTransition(to: size, with: coordinator)
        
        NSLayoutConstraint.deactivate(self.playerViewConstraints + self.secondaryViewConstraints)
        self.setupContainers(isPortraiteOrientation: size.isPortraiteOrientation)
        NSLayoutConstraint.activate(self.playerViewConstraints + self.secondaryViewConstraints)
        self.setupNavigationBarVisability(isPortraiteOrientation: size.isPortraiteOrientation)
    }
    /**
     Уведомляет контейнер, что ориентация представления будет изменена.
     
     - Parameter isPortraiteOrientation: Новая ориентация контейнера представления.
     
     Метод ничего не делает в родительском классе. Вы можете безпрепятственно переписать этот метод для собственных задач,
     связанных с изменение ориентации.
     */
    open func viewWillChangeOrientation(isPortraiteOrientation: Bool) { }
    
    private func setupContainers(isPortraiteOrientation: Bool) {
        self.viewWillChangeOrientation(isPortraiteOrientation: isPortraiteOrientation)
        self.setupPlayerViewConstraints(self.playerViewController.view, isPortraiteOrientation: isPortraiteOrientation)
        self.setupSecondaryViewConstraints(self.secondaryViewController.view, isPortraiteOrientation: isPortraiteOrientation)
    }
    
    public func presentPlayerViewContainerWithAnimation() {
        guard !self.isPlayerViewControllerPresented else { return }
        
        self.isPlayerViewControllerPresented = true
        let playerViewContainer = self.playerViewController.view!
        if self.isPortraiteOrientation {
            UIView.animate(withDuration: AVPlayerContainerViewController.playerPresentAnimationDuration) {
                self.playerViewConstraints[3].isActive = false
                self.playerViewConstraints[3] = playerViewContainer.heightAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: Constant.playerAspectRatio)
                self.playerViewConstraints[3].isActive = true
                self.view.layoutIfNeeded()
            }
        } else {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
            UIView.animate(withDuration: AVPlayerContainerViewController.playerPresentAnimationDuration) {
                self.playerViewConstraints[0].isActive = false
                self.playerViewConstraints[0] = playerViewContainer.topAnchor.constraint(equalTo: self.view.topAnchor)
                self.playerViewConstraints[0].isActive = true
                self.playerViewConstraints[3].isActive = false
                self.playerViewConstraints[3] = playerViewContainer.heightAnchor.constraint(equalTo: self.view.heightAnchor)
                self.playerViewConstraints[3].isActive = true
                self.view.layoutIfNeeded()
            }
        }
    }
    

}
