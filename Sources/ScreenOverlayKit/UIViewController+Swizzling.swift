//
//  UIViewController+Swizzling.swift
//  ScreenRadarKit
//
//  Created by Sanket Khatri on 05/06/26.
//

import UIKit
import ObjectiveC.runtime

extension UIViewController {

    /// Swizzles `viewDidAppear(_:)` and `viewDidDisappear(_:)` once,
    /// so ScreenRadar can auto-detect screen transitions.
    static func enableScreenRadarTracking() {
        _ = swizzleToken
    }

    // One-time swizzle token to avoid nested type capturing self
    private static let swizzleToken: Void = {
        // MARK: viewDidAppear
        swizzle(
            original: #selector(viewDidAppear(_:)),
            swizzled: #selector(sr_viewDidAppear(_:))
        )

        // MARK: viewDidDisappear
        swizzle(
            original: #selector(viewDidDisappear(_:)),
            swizzled: #selector(sr_viewDidDisappear(_:))
        )
    }()

    // MARK: - Private Swizzle Helper

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

    @objc private func sr_viewDidAppear(_ animated: Bool) {
        sr_viewDidAppear(animated) // calls original implementation
        DispatchQueue.main.async {
            ViewControllerTracker.shared.recordAppear(for: self)
            ViewControllerTracker.shared.refresh()
        }
    }

    // MARK: - Swizzled viewDidDisappear

    @objc private func sr_viewDidDisappear(_ animated: Bool) {
        sr_viewDidDisappear(animated) // calls original implementation
        DispatchQueue.main.async {
            ViewControllerTracker.shared.recordDisappear(for: self)
            ViewControllerTracker.shared.refresh()
        }
    }
}
