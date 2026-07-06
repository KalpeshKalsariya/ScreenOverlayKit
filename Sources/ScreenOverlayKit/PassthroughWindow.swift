//
//  PassthroughWindow.swift
//  ScreenRadarKit
//
//  Created by Sanket Khatri on 05/06/26.
//

import UIKit

/// A UIWindow subclass that passes all touch events through to the app beneath,
/// except for views explicitly added to the overlay (e.g., the label).
@MainActor
final class PassthroughWindow: UIWindow {

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
