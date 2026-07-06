//
//  PassthroughWindow.swift
//  ScreenOverlayKit
//
//  Created by Sanket Khatri on 05/06/26.
//

import UIKit

/// A UIWindow subclass that passes all touch events through to the app beneath,
/// except for views explicitly added to the overlay (e.g., the label).
@MainActor
final class PassthroughWindow: UIWindow {

    /// Passes touches through to the app below unless they land on a view the
    /// overlay explicitly added (e.g., the pill label), rather than the bare root view.
    ///
    /// - Parameters:
    ///   - point: The touch location, in the window's coordinate system.
    ///   - event: The event associated with the touch.
    /// - Returns: The overlay view that should receive the touch, or `nil` to let it pass through.
    override func hitTest(
        _ point: CGPoint,
        with event: UIEvent?
    ) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        // If the hit lands on the bare root view, pass through to the app below
        if hitView == rootViewController?.view {
            return nil
        }

        return hitView
    }
}
