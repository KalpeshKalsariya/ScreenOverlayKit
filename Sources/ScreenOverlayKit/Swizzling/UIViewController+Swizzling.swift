//
//  UIViewController+Swizzling.swift
//  ScreenOverlayKit
//
//  Created by Sanket Khatri on 05/06/26.
//

import UIKit
import ObjectiveC.runtime

extension UIViewController {

    /// Swizzles `viewDidAppear(_:)` and `viewDidDisappear(_:)` once,
    /// so ScreenOverlayKit can auto-detect screen transitions.
    static func enableScreenOverlayTracking() {
        _ = swizzleToken
    }

    // One-time swizzle token to avoid nested type capturing self
    private static let swizzleToken: Void = {
        // MARK: viewDidAppear
        swizzle(
            original: #selector(viewDidAppear(_:)),
            swizzled: #selector(overlayKit_viewDidAppear(_:))
        )

        // MARK: viewDidDisappear
        swizzle(
            original: #selector(viewDidDisappear(_:)),
            swizzled: #selector(overlayKit_viewDidDisappear(_:))
        )
    }()

    // MARK: - Private Swizzle Helper

    /// Exchanges the implementations of two instance methods on `UIViewController`.
    ///
    /// - Parameters:
    ///   - originalSelector: The selector whose implementation should be replaced.
    ///   - swizzledSelector: The selector providing the replacement implementation.
    private static func swizzle(
        original originalSelector: Selector,
        swizzled swizzledSelector: Selector
    ) {
        guard
            let original = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzled = class_getInstanceMethod(UIViewController.self, swizzledSelector)
        else { return }
        method_exchangeImplementations(original, swizzled)
    }

    // MARK: - Swizzled viewDidAppear

    /// Replacement for `viewDidAppear(_:)` that calls through to the original
    /// implementation, then notifies ScreenOverlayKit that this screen appeared.
    ///
    /// - Parameter animated: Whether the appearance was animated, forwarded to the original implementation.
    @objc private func overlayKit_viewDidAppear(_ animated: Bool) {
        overlayKit_viewDidAppear(animated) // calls original implementation
        DispatchQueue.main.async {
            ViewControllerTracker.shared.recordAppear(for: self)
            ViewControllerTracker.shared.refresh()
        }
    }

    // MARK: - Swizzled viewDidDisappear

    /// Replacement for `viewDidDisappear(_:)` that calls through to the original
    /// implementation, then notifies ScreenOverlayKit that this screen disappeared.
    ///
    /// - Parameter animated: Whether the disappearance was animated, forwarded to the original implementation.
    @objc private func overlayKit_viewDidDisappear(_ animated: Bool) {
        overlayKit_viewDidDisappear(animated) // calls original implementation
        DispatchQueue.main.async {
            ViewControllerTracker.shared.recordDisappear(for: self)
            ViewControllerTracker.shared.refresh()
        }
    }
}
