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

    // MARK: - Event Logging

    /// The object that receives ScreenOverlayKit's screen-view and custom-event notifications.
    ///
    /// Assign an object conforming to `ScreenOverlayEventLogger` to forward events to Firebase
    /// Analytics (or any other backend) — see `ScreenOverlayEventLogger` for a worked example.
    /// ScreenOverlayKit itself has no dependency on any analytics SDK. Held weakly; the caller
    /// owns the logger's lifetime.
    @MainActor
    public static weak var eventLogger: ScreenOverlayEventLogger?

    /// Logs a custom event through the registered `eventLogger`.
    ///
    /// Use this for anything beyond automatic screen-view tracking — button taps, form
    /// submissions, feature usage, etc. If no `eventLogger` is set, this only prints to the console.
    ///
    /// - Parameters:
    ///   - name: The event's name (e.g. `"button_tapped"`).
    ///   - parameters: Optional event parameters (e.g. `["button": "checkout"]`).
    @objc(logEventWithName:parameters:)
    @MainActor
    public static func logEvent(name: String, parameters: [String: Any]? = nil) {
        if let parameters {
            print("🔔 ScreenOverlayKit event → \(name) \(parameters)")
        } else {
            print("🔔 ScreenOverlayKit event → \(name)")
        }
        eventLogger?.screenOverlayDidLogEvent(name, parameters: parameters)
    }

    /// Forwards a screen-view notification to `eventLogger`. Called internally whenever the
    /// trail records a new screen, from both the UIKit swizzling path and `.screenOverlayTrack(_:)`.
    ///
    /// - Parameters:
    ///   - screenName: The new screen's name.
    ///   - previousScreenName: The screen that was visible immediately before this one, if any.
    @MainActor
    static func notifyScreenView(_ screenName: String, previousScreenName: String?) {
        eventLogger?.screenOverlayDidLogScreenView(screenName, previousScreenName: previousScreenName)
    }

    // MARK: - Current Screen Lookup

    /// The name of the current top-most tracked screen, without presenting any UI.
    ///
    /// Reflects whichever screen was most recently recorded — whether from automatic UIKit
    /// tracking or `.screenOverlayTrack(_:)` in SwiftUI. Use this to tag a Firebase (or any
    /// other) event with the active screen, instead of tapping the overlay to open the trail sheet.
    ///
    /// - Note: Returns `nil` until `enable()` has recorded at least one screen.
    @MainActor
    public static var currentScreenName: String? {
        TrailLogger.shared.currentScreenName
    }

    /// A single-line breadcrumb of the current view controller hierarchy — e.g.
    /// `"AppRootViewController → UITabBarController → ProfileViewController"` — without
    /// presenting any UI or printing to the console.
    ///
    /// This walks the live UIKit hierarchy, so (like `printHierarchy`) it only reflects
    /// `UIViewController` containers — it won't see navigation that happens purely inside
    /// SwiftUI. For a name that also covers `.screenOverlayTrack(_:)` screens, use `currentScreenName`.
    ///
    /// - Returns: The breadcrumb string.
    @objc(currentHierarchyPath)
    @MainActor
    public static func currentHierarchyPath() -> String {
        ViewControllerTracker.shared.currentHierarchyPath()
    }

    // MARK: - Public API

    /// Enables the ScreenOverlay overlay.
    ///
    /// Shows a floating pill label at the top of the screen with the current view controller's
    /// class name, and starts recording the screen trail used by the tap-to-view hierarchy sheet.
    ///
    /// - Parameters:
    ///   - draggable: When `true`, the overlay label can be dragged anywhere on screen
    ///     and snaps to the nearest edge on release. Defaults to `false`.
    ///   - showTimeOnTrail: When `true`, the trail sheet also shows how long the app
    ///     spent on each screen. Defaults to `false`.
    ///
    /// - Note: Call this once, ideally in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`,
    ///   `SceneDelegate.scene(_:willConnectTo:options:)`, or a SwiftUI view's `.onAppear`.
    ///   Wrap in `#if DEBUG` to ensure it is never shipped to production.
    @objc(enableWithDraggable:showTimeOnTrail:)
    @MainActor
    public static func enable(
        draggable: Bool = false,
        showTimeOnTrail: Bool = false
    ) {
        print("🚀 ScreenOverlayKit enabled")
        DispatchQueue.main.async {
            TrailLogger.shared.startSession(showTimeOnTrail: showTimeOnTrail)
            OverlayManager.shared.show(draggable: draggable)
            UIViewController.enableScreenOverlayTracking()
            ViewControllerTracker.shared.refresh()
            ViewControllerTracker.shared.seedCurrentVisibleTrail()
        }
    }

    /// Objective-C convenience for `enable(draggable:showTimeOnTrail:)` using its default
    /// options (`draggable: false, showTimeOnTrail: false`) — Objective-C has no concept of
    /// default parameter values. Swift callers should use `enable(draggable:showTimeOnTrail:)` directly.
    @objc(enable)
    @MainActor
    public static func enableWithDefaultOptions() {
        enable()
    }

    /// Hides and tears down the ScreenOverlay overlay.
    @MainActor
    public static func disable() {
        print("🛑 ScreenOverlayKit disabled")
        OverlayManager.shared.hide()
    }
}
