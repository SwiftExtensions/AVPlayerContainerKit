//
//  AVPlayerContainerViewController.swift
//  

import UIKit
import AVPlayerKit

open class AVPlayerContainerViewController: UIViewController {
    public static var playerPresentAnimationDuration = Constant.playerPresentAnimationDuration
    
    public private(set) weak var playerViewController: UIViewController!
    public private(set) weak var secondaryViewController: UIViewController!
    
    private var playerViewConstraints = [NSLayoutConstraint]()
    private var secondaryViewConstraints = [NSLayoutConstraint]()
    
    private var isPlayerViewControllerPresented = false
    
    private var isPortraiteOrientation: Bool { UIScreen.main.bounds.isPortraiteOrientation }
    
    private var _prefersHomeIndicatorAutoHidden = false
    open override var prefersHomeIndicatorAutoHidden: Bool {
        self._prefersHomeIndicatorAutoHidden
    }
    
    public func addChildWithDefaultPlayerViewController(
        secondaryViewController: UIViewController,
        isPlayerViewControllerPresented: Bool)
    {
        self.addChilds(
            playerViewController: PlayerViewController(),
            secondaryViewController: secondaryViewController,
            isPlayerViewControllerPresented: isPlayerViewControllerPresented)
        self._prefersHomeIndicatorAutoHidden = self.isPlayerViewControllerPresented && !self.isPortraiteOrientation
    }
    
    public func addChilds(
        playerViewController: UIViewController,
        secondaryViewController: UIViewController,
        isPlayerViewControllerPresented: Bool)
    {
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
    }
    
    private func setupPlayerViewConstraints(_ playerView: UIView, isPortraiteOrientation: Bool) {
        if isPortraiteOrientation {
            let playerHeightConstraint: NSLayoutConstraint
            if self.isPlayerViewControllerPresented {
                self.navigationController?.setNavigationBarHidden(false, animated: true)
                playerHeightConstraint = playerView.heightAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: Constant.playerAspectRatio)
            } else {
                playerHeightConstraint = playerView.heightAnchor.constraint(equalToConstant: 0)
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
                self.navigationController?.setNavigationBarHidden(true, animated: true)
                playerHeightConstraint = playerView.heightAnchor.constraint(equalTo: self.view.heightAnchor)
                topAnchor = self.view.topAnchor
            } else {
                playerHeightConstraint = playerView.heightAnchor.constraint(equalToConstant: 0)
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
            let streamsViewContainerBottomConstraint = secondaryView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            streamsViewContainerBottomConstraint.priority = .defaultHigh
            self.secondaryViewConstraints = [
                secondaryView.topAnchor.constraint(equalTo: self.playerViewController.view.bottomAnchor),
                secondaryView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                secondaryView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                streamsViewContainerBottomConstraint,
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
    
    private func setupContainers(isPortraiteOrientation: Bool) {
        self.setupPlayerViewConstraints(self.playerViewController.view, isPortraiteOrientation: isPortraiteOrientation)
        self.setupSecondaryViewConstraints(self.secondaryViewController.view, isPortraiteOrientation: isPortraiteOrientation)
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
        
        NSLayoutConstraint.deactivate(self.playerViewConstraints + self.secondaryViewConstraints)
        self.setupContainers(isPortraiteOrientation: size.isPortraiteOrientation)
        NSLayoutConstraint.activate(self.playerViewConstraints + self.secondaryViewConstraints)
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
