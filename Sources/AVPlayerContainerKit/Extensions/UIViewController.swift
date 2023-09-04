//
//  UIViewController.swift
//

import UIKit

extension UIViewController {
    /**
     [Creating a custom container view controller](
     https://developer.apple.com/documentation/uikit/view_controllers/creating_a_custom_container_view_controller).
     */
    func insertChild(
        _ childController: UIViewController,
        layout: (_ parentView: UIView, _ childView: UIView) -> Void)
    {
        self.addChild(childController)
        self.view.addSubview(childController.view)
        layout(self.view, childController.view)
        childController.didMove(toParent: self)
    }
}
