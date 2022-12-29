//
//  AVPlayerContainerViewController.swift
//  

import UIKit
import AVPlayerKit

open class AVPlayerContainerViewController: UIViewController {
    public static var playerPresentAnimationDuration = Constant.playerPresentAnimationDuration
    
    public private(set) weak var playerViewController: UIViewController!
    public private(set) weak var streamsViewController: UIViewController!
    
    private var playerViewContainerConstraints = [NSLayoutConstraint]()
    private var streamsViewControllerConstraints = [NSLayoutConstraint]()
    
    private var isPlayerViewControllerPresented = false
    
    private var _prefersHomeIndicatorAutoHidden = false
    open override var prefersHomeIndicatorAutoHidden: Bool {
        self._prefersHomeIndicatorAutoHidden
    }
    
    public func addChildWithDefaultPlayerViewController(
        streamsViewController: UIViewController,
        isPlayerViewControllerPresented: Bool)
    {
        self.addChilds(
            playerViewController: PlayerViewController(),
            streamsViewController: streamsViewController,
            isPlayerViewControllerPresented: isPlayerViewControllerPresented)
        self._prefersHomeIndicatorAutoHidden = self.isPlayerViewControllerPresented && !UIScreen.main.bounds.size.isPortraiteOrientation
    }
    
    public func addChilds(
        playerViewController: UIViewController,
        streamsViewController: UIViewController,
        isPlayerViewControllerPresented: Bool)
    {
        self.isPlayerViewControllerPresented = isPlayerViewControllerPresented
        let isPortraiteOrientation = UIScreen.main.bounds.size.isPortraiteOrientation
        
        self.playerViewController = playerViewController
        self.addChild(playerViewController)
        self.view.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.setupPlayerViewControllerConstraints(playerViewController, isPortraiteOrientation: isPortraiteOrientation)
        NSLayoutConstraint.activate(self.playerViewContainerConstraints)
        playerViewController.didMove(toParent: self)
        
        self.streamsViewController = streamsViewController
        self.addChild(streamsViewController)
        self.view.addSubview(streamsViewController.view)
        streamsViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.setupStreamsViewControllerConstraints(streamsViewController, isPortraiteOrientation: isPortraiteOrientation)
        NSLayoutConstraint.activate(self.streamsViewControllerConstraints)
        streamsViewController.didMove(toParent: self)
    }
    
    private func setupPlayerViewControllerConstraints(_ playerViewController: UIViewController, isPortraiteOrientation: Bool) {
        let playerViewContainer = playerViewController.view!
        if isPortraiteOrientation {
            let playerHeightConstraint: NSLayoutConstraint
            if self.isPlayerViewControllerPresented {
                self.navigationController?.setNavigationBarHidden(false, animated: true)
                playerHeightConstraint = playerViewContainer.heightAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: Constant.playerAspectRatio)
            } else {
                playerHeightConstraint = playerViewContainer.heightAnchor.constraint(equalToConstant: 0)
            }
            self.playerViewContainerConstraints = [
                playerViewContainer.topAnchor.constraint(equalTo: self.view.safeAreaTopAnchor),
                playerViewContainer.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                playerViewContainer.widthAnchor.constraint(equalTo: self.view.widthAnchor),
                playerHeightConstraint
            ]
        } else {
            let topAnchor: NSLayoutYAxisAnchor
            let playerHeightConstraint: NSLayoutConstraint
            if self.isPlayerViewControllerPresented {
                self.navigationController?.setNavigationBarHidden(true, animated: true)
                playerHeightConstraint = playerViewContainer.heightAnchor.constraint(equalTo: self.view.heightAnchor)
                topAnchor = self.view.topAnchor
            } else {
                playerHeightConstraint = playerViewContainer.heightAnchor.constraint(equalToConstant: 0)
                topAnchor = self.view.safeAreaTopAnchor
            }
            self.playerViewContainerConstraints = [
                playerViewContainer.topAnchor.constraint(equalTo: topAnchor),
                playerViewContainer.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                playerViewContainer.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                playerHeightConstraint
            ]
        }
    }
    
    private func setupStreamsViewControllerConstraints(_ streamsViewController: UIViewController, isPortraiteOrientation: Bool) {
        let streamsViewContainer = streamsViewController.view!
        if isPortraiteOrientation {
            let streamsViewContainerBottomConstraint = streamsViewContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            streamsViewContainerBottomConstraint.priority = .defaultHigh
            self.streamsViewControllerConstraints = [
                streamsViewContainer.topAnchor.constraint(equalTo: self.playerViewController.view.bottomAnchor),
                streamsViewContainer.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                streamsViewContainer.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                streamsViewContainerBottomConstraint,
            ]
        } else {
            self.streamsViewControllerConstraints = [
                streamsViewContainer.topAnchor.constraint(equalTo: self.playerViewController.view.bottomAnchor),
                streamsViewContainer.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                streamsViewContainer.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                streamsViewContainer.heightAnchor.constraint(equalTo: self.view.heightAnchor)
            ]
        }
    }
    
    private func setupContainers(isPortraiteOrientation: Bool) {
        self.setupPlayerViewControllerConstraints(self.playerViewController, isPortraiteOrientation: isPortraiteOrientation)
        self.setupStreamsViewControllerConstraints(self.streamsViewController, isPortraiteOrientation: isPortraiteOrientation)
    }
    
    open override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        // Метод вызвается непосредственно перед запросом значения переменной
        // prefersHomeIndicatorAutoHidden
        self._prefersHomeIndicatorAutoHidden = self.isPlayerViewControllerPresented && UIDevice.current.orientation.isLandscape
        super.willTransition(to: newCollection, with: coordinator)
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // Метод вызвается после запроса значения переменной
        // prefersHomeIndicatorAutoHidden
        super.viewWillTransition(to: size, with: coordinator)
        
        NSLayoutConstraint.deactivate(self.playerViewContainerConstraints + self.streamsViewControllerConstraints)
        self.setupContainers(isPortraiteOrientation: size.isPortraiteOrientation)
        NSLayoutConstraint.activate(self.playerViewContainerConstraints + self.streamsViewControllerConstraints)
    }
    
    public func presentPlayerViewContainerWithAnimation() {
        guard !self.isPlayerViewControllerPresented else { return }
        
        self.isPlayerViewControllerPresented = true
        let playerViewContainer = self.playerViewController.view!
        if UIScreen.main.bounds.size.isPortraiteOrientation {
            UIView.animate(withDuration: AVPlayerContainerViewController.playerPresentAnimationDuration) {
                self.playerViewContainerConstraints[3].isActive = false
                self.playerViewContainerConstraints[3] = playerViewContainer.heightAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: Constant.playerAspectRatio)
                self.playerViewContainerConstraints[3].isActive = true
                self.view.layoutIfNeeded()
            }
        } else {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
            UIView.animate(withDuration: AVPlayerContainerViewController.playerPresentAnimationDuration) {
                self.playerViewContainerConstraints[0].isActive = false
                self.playerViewContainerConstraints[0] = playerViewContainer.topAnchor.constraint(equalTo: self.view.topAnchor)
                self.playerViewContainerConstraints[0].isActive = true
                self.playerViewContainerConstraints[3].isActive = false
                self.playerViewContainerConstraints[3] = playerViewContainer.heightAnchor.constraint(equalTo: self.view.heightAnchor)
                self.playerViewContainerConstraints[3].isActive = true
                self.view.layoutIfNeeded()
            }
        }
    }
    

}
