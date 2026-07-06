// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

/// ScreenRadarKit — a lightweight debug overlay that displays
/// the current UIViewController name on screen in real time.
///
/// Usage:
/// ```swift
/// // In AppDelegate or SceneDelegate:
/// #if DEBUG
/// ScreenRadar.enable()
/// #endif
/// ```
@objcMembers
public final class ScreenRadar: NSObject {

    // MARK: - Private

    private override init() {}

    // MARK: - Public API

    /// Enables the ScreenRadar overlay.
    /// Shows a floating label at the top of the screen
    /// with the current view controller's class name.
    ///
    /// - Note: Call this once, ideally in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
    ///   or `SceneDelegate.scene(_:willConnectTo:options:)`.
    ///   Wrap in `#if DEBUG` to ensure it is never shipped to production.
    @MainActor
    public static func enable(
        draggable: Bool = false,
        showTimeOnTrail: Bool = false
    ) {
        print("🚀 ScreenRadar enabled")
        DispatchQueue.main.async {
            TrailLogger.shared.startSession(showTimeOnTrail: showTimeOnTrail)
            OverlayWindow.shared.show(draggable: draggable)
            UIViewController.enableScreenRadarTracking()
            ViewControllerTracker.shared.refresh()
            ViewControllerTracker.shared.seedCurrentVisibleTrail()
        }
    }

    /// Hides and tears down the ScreenRadar overlay.
    @MainActor
    public static func disable() {
        print("🛑 ScreenRadar disabled")
        OverlayWindow.shared.hide()
    }
}
