//
//  AVPlayerContainerViewController.swift
//  

import UIKit
import AVPlayerKit

/**
 Хранилище общих параметров контейнера плеера.
 */
final class StaticPropertiesStorage {
    private init() {}
    
    /**
     Длительность анимации появления плеера по умолчанию.
     */
    static var playerPresentAnimationDuration = Constant.playerPresentAnimationDuration
}

/**
 Контейнер для управления двумя дочерними контроллерами представления: плеером и вторичным контроллером.

 Этот класс предоставляет функциональность для управления макетом и анимацией между двумя дочерними контроллерами
 в зависимости от ориентации устройства. Плеер может быть представлен или скрыт с анимацией.

 - Parameter Player: Тип контроллера плеера, который должен наследоваться от UIViewController
 */
open class AVPlayerContainerViewController<Player>: UIViewController where Player : UIViewController {
    /**
     Длительность анимации отображения плеера для всех экземпляров контейнера.
     */
    public static var playerPresentAnimationDuration: TimeInterval {
        get { StaticPropertiesStorage.playerPresentAnimationDuration }
        set { StaticPropertiesStorage.playerPresentAnimationDuration = newValue }
    }
    
    /**
     Контроллер плеера, добавленный в контейнер.
     */
    public private(set) weak var playerViewController: Player!
    /**
     Вторичный контроллер, отображаемый под плеером.
     */
    public private(set) weak var secondaryViewController: UIViewController!
    
    /**
     Управляет ограничениями макета для плеера и вторичного представления.
     */
    private var layoutController: LayoutConstraintsController!
    
    /**
     Флаг, указывающий, отображается ли плеер на экране.
     */
    private var isPlayerPresented = false
    
    /**
     Показывает, находится ли устройство в портретной ориентации.
     */
    public var isPortraite: Bool { UIScreen.main.bounds.isPortraite }
    
    /**
     Внутренний флаг для скрытия индикатора домашней панели.
     */
    private var _prefersHomeIndicatorAutoHidden = false
    open override var prefersHomeIndicatorAutoHidden: Bool {
        self._prefersHomeIndicatorAutoHidden
    }
    
    /**
     Добавляет дочерние контроллеры с контроллером плеера по умолчанию.

     - Parameter secondaryViewController: Вторичный контроллер, размещаемый под плеером.
     - Parameter isPlayerViewControllerPresented: Флаг, отображается ли плеер изначально.
     */
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
    
    /**
     Добавляет пользовательские контроллеры плеера и вторичного содержимого в контейнер.

     - Parameter playerViewController: Контроллер плеера, который будет размещен сверху.
     - Parameter secondaryViewController: Вторичный контроллер интерфейса под плеером.
     - Parameter isPlayerViewControllerPresented: Флаг, отображается ли плеер после добавления.
     */
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
    
    /**
     Управляет видимостью навигационной панели в зависимости от ориентации и отображения плеера.

     - Parameter isPortraiteOrientation: Флаг портретной ориентации.
     */
    private func setupNavigationBarVisability(isPortraiteOrientation: Bool) {
        let isNavigationBarHidden = self.isPlayerPresented && !isPortraiteOrientation
        self.navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: true)
    }
    
    /**
     Синхронизирует состояние контейнера перед изменением характеристик интерфейса.

     - Parameter newCollection: Новая коллекция характеристик.
     - Parameter coordinator: Координатор анимации перехода.
     */
    open override func willTransition(
        to newCollection: UITraitCollection,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        // Метод вызвается непосредственно перед запросом значения переменной
        // prefersHomeIndicatorAutoHidden
        self._prefersHomeIndicatorAutoHidden = self.isPlayerPresented && UIDevice.current.orientation.isLandscape
        super.willTransition(to: newCollection, with: coordinator)
    }
    
    /**
     Обрабатывает изменение размеров представления и перестраивает макет.

     - Parameter size: Новый размер контейнера после поворота.
     - Parameter coordinator: Координатор анимации перехода размеров.
     */
    open override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        // Метод вызвается после запроса значения переменной
        // prefersHomeIndicatorAutoHidden
        super.viewWillTransition(to: size, with: coordinator)
        
        self.viewWillChangeOrientation(isPortraite: size.isPortraite)
        self.layoutController.updateLayout(
            isPortraite: size.isPortraite,
            isPlayerPresented: self.isPlayerPresented
        )
        self.setupNavigationBarVisability(isPortraiteOrientation: size.isPortraite)
    }
    /**
     Уведомляет контейнер, что ориентация представления будет изменена.
     
     - Parameter isPortraite: Новая ориентация контейнера представления.
     
     Метод ничего не делает в родительском классе. Вы можете безопасно переписать этот метод для собственных задач,
     связанных с изменение ориентации.
     */
    open func viewWillChangeOrientation(isPortraite: Bool) { }
    
    /**
     Меняет состояние отображения плеера и синхронизирует ограничения представлений.

     - Parameter isPlayerPresented: Новое состояние отображения плеера.
     - Parameter animated: Флаг анимации перехода между состояниями.
     */
    public func updatePlayerState(isPlayerPresented: Bool, animated: Bool = true) {
        if self.isPlayerPresented == isPlayerPresented { return }
        self.isPlayerPresented = isPlayerPresented
        
        let duration = animated
        ? AVPlayerContainerViewController.playerPresentAnimationDuration
        : 0.0
        UIView.animate(withDuration: duration) { [weak self, isPortraite, isPlayerPresented] in
            self?.layoutController.updateLayout(
                isPortraite: isPortraite,
                isPlayerPresented: isPlayerPresented
            )
            self?.view.layoutIfNeeded()
        }
    }
    

}
