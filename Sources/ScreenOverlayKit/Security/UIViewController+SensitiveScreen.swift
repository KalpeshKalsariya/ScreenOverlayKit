//
//  UIViewController+SensitiveScreen.swift
//  ScreenOverlayKit
//

import UIKit

public extension UIViewController {

    /// Marks this view controller's `view` as sensitive, so `ScreenCaptureGuard` automatically
    /// blurs it during a screenshot, screen recording/mirroring, or app-backgrounding event.
    ///
    /// Call once, typically from `viewDidLoad()`:
    /// ```swift
    /// override func viewDidLoad() {
    ///     super.viewDidLoad()
    ///     markScreenAsSensitiveOverlay()
    /// }
    /// ```
    ///
    /// - Note: Requires `ScreenCaptureGuard.shared.startMonitoring()` to have been called
    ///   somewhere at launch — marking a screen sensitive doesn't start monitoring by itself.
    @MainActor
    func markScreenAsSensitiveOverlay() {
        SensitiveScreenRegistry.shared.register(view)
    }

    /// Reverses `markScreenAsSensitiveOverlay()`, removing any active blur immediately.
    @MainActor
    func unmarkScreenAsSensitiveOverlay() {
        SensitiveScreenRegistry.shared.unregister(view)
    }
}
