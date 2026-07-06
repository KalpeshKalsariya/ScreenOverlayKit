// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

/// ScreenOverlayKit — a lightweight debug overlay that displays
/// the current `UIViewController` name on screen in real time.
///
/// Usage:
/// ```swift
/// // In AppDelegate or SceneDelegate:
/// #if DEBUG
/// ScreenOverlay.enable()
/// #endif
/// ```
@objcMembers
public final class ScreenOverlay: NSObject {

    // MARK: - Private

    /// Prevents external instantiation — `ScreenOverlay` is used purely as a static namespace.
    private override init() {}

    // MARK: - Public API

    /// Enables the ScreenOverlay overlay.
    ///
    /// Shows a floating pill label at the top of the screen with the current
    /// view controller's class name, and starts recording the screen trail
    /// used by the tap-to-view hierarchy sheet.
    ///
    /// - Parameters:
    ///   - draggable: When `true`, the overlay label can be dragged anywhere on screen
    ///     and snaps to the nearest edge on release. Defaults to `false`.
    ///   - showTimeOnTrail: When `true`, the trail sheet also shows how long the app
    ///     spent on each screen. Defaults to `false`.
    ///
    /// - Note: Call this once, ideally in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
    ///   or `SceneDelegate.scene(_:willConnectTo:options:)`.
    ///   Wrap in `#if DEBUG` to ensure it is never shipped to production.
    @MainActor
    public static func enable(
        draggable: Bool = false,
        showTimeOnTrail: Bool = false
    ) {
        print("🚀 ScreenOverlayKit enabled")
        DispatchQueue.main.async {
            TrailLogger.shared.startSession(showTimeOnTrail: showTimeOnTrail)
            OverlayWindow.shared.show(draggable: draggable)
            UIViewController.enableScreenOverlayTracking()
            ViewControllerTracker.shared.refresh()
            ViewControllerTracker.shared.seedCurrentVisibleTrail()
        }
    }

    /// Hides and tears down the ScreenOverlay overlay.
    @MainActor
    public static func disable() {
        print("🛑 ScreenOverlayKit disabled")
        OverlayWindow.shared.hide()
    }
}
