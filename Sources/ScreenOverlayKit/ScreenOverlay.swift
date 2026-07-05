import UIKit

/// Public entry point for ScreenOverlayKit.
///
/// Call `ScreenOverlay.enable()` once (typically wrapped in `#if DEBUG`) and
/// a floating label will appear showing the class name of whichever
/// `UIViewController` is currently visible on screen. Detection is automatic
/// via `viewDidAppear` / `viewDidDisappear` swizzling — no per-screen setup required.
@MainActor
public enum ScreenOverlay {

    private static var isEnabled = false
    private static let didSwizzle: Void = {
        UIViewController.so_swizzleLifecycleMethods()
    }()

    /// Enables the overlay.
    /// - Parameter draggable: if `true`, the label can be dragged and snaps to the nearest edge on release.
    public static func enable(draggable: Bool = false) {
        guard !isEnabled else { return }
        isEnabled = true
        _ = didSwizzle
        OverlayWindow.shared.show(draggable: draggable)
        refresh()
        print("🚀 ScreenOverlayKit enabled")
    }

    /// Disables and removes the overlay.
    public static func disable() {
        guard isEnabled else { return }
        isEnabled = false
        OverlayWindow.shared.hide()
        print("🛑 ScreenOverlayKit disabled")
    }

    // MARK: - Internal Hooks (called from UIViewController+Swizzling)

    /// Called whenever any view controller's `viewDidAppear` fires.
    /// Uses the appearing VC directly — avoids re-walking the hierarchy which
    /// can return "Unknown" or a container name during launch / transitions.
    static func viewControllerDidAppear(_ vc: UIViewController) {
        guard isEnabled else { return }

        // Never report our own internal overlay VC as the current screen
        guard !isOverlayInternal(vc) else { return }

        // Skip pure containers — their child's viewDidAppear fires immediately after
        guard !(vc is UINavigationController),
              !(vc is UITabBarController),
              !(vc is UIPageViewController),
              !(vc is UISplitViewController) else { return }

        let name = screenName(for: vc)
        OverlayWindow.shared.update(text: name)
        print("📱 ScreenOverlay → \(name)  |  path: \(ViewControllerTracker.fullPathSingleLine())")
    }

    /// Called whenever any view controller's `viewDidDisappear` fires.
    /// Guards against the nav-push thrash that briefly shows "Unknown":
    /// only refreshes for real dismissals (modal gone) or pops (nav stack).
    static func viewControllerDidDisappear(_ vc: UIViewController) {
        guard isEnabled else { return }
        guard !isOverlayInternal(vc) else { return }

        // presentingViewController is still set at viewDidDisappear time for a dismiss
        let wasModal = vc.presentingViewController != nil
        // navigationController is still set at viewDidDisappear time for a pop
        let wasNavPop = vc.navigationController != nil

        guard wasModal || wasNavPop else { return }

        // Small delay so the hierarchy has fully settled before we walk it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard Self.isEnabled else { return }
            Self.refresh()
        }
    }

    // MARK: - Private

    /// Returns `true` for any VC that belongs to ScreenOverlayKit itself —
    /// either identified by the `OverlayInternalViewController` marker
    /// protocol directly, or because it was presented ON TOP of one (e.g. the
    /// "full path" UIAlertController presented from our own overlay root VC).
    /// Without the second check, that alert's own viewDidAppear/viewDidDisappear
    /// would be picked up by the global swizzle and overwrite the pill's text
    /// with "UIAlertController", and it wouldn't reliably get restored after dismiss.
    private static func isOverlayInternal(_ vc: UIViewController) -> Bool {
        if vc is OverlayInternalViewController { return true }
        if let presenter = vc.presentingViewController, presenter is OverlayInternalViewController {
            return true
        }
        return false
    }

    static func refresh() {
        let name = ViewControllerTracker.currentScreenName()
        OverlayWindow.shared.update(text: name)
    }

    /// Strips `UIHostingController<ContentView>` → `ContentView` for SwiftUI screens.
    private static func screenName(for vc: UIViewController) -> String {
        let raw = String(describing: type(of: vc))
        if raw.hasPrefix("UIHostingController<"), raw.hasSuffix(">") {
            let start = raw.index(raw.startIndex, offsetBy: "UIHostingController<".count)
            let end   = raw.index(before: raw.endIndex)
            return String(raw[start..<end])
        }
        return raw
    }
}

// MARK: - Internal VC Marker Protocol

/// Conform any ViewController that belongs to ScreenOverlayKit to this protocol.
/// The swizzle hooks check for it and skip reporting — prevents the overlay's
/// own root VC from ever appearing as the "current screen" in the label.
protocol OverlayInternalViewController: AnyObject {}
