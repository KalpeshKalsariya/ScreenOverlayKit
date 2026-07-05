import UIKit

/// Resolves which `UIViewController` is currently visible on screen by
/// walking down the window's view controller hierarchy.
///
/// Supports both modern UIWindowScene apps and legacy UIScreen-based apps.
@MainActor
enum ViewControllerTracker {

    /// The topmost visible view controller across all connected scenes,
    /// falling back to legacy UIScreen key window for apps without a scene manifest.
    static func topMostViewController() -> UIViewController? {
        guard let root = keyWindow()?.rootViewController else { return nil }
        return topMost(from: root)
    }

    /// Human-readable name for whatever is currently on screen, e.g. "ProfileViewController".
    static func currentScreenName() -> String {
        guard let vc = topMostViewController() else { return "Unknown" }
        return String(describing: type(of: vc))
    }

    /// A readable tree showing every container from the window's root down to
    /// whatever is actually visible right now.
    static func fullPath() -> String {
        guard let root = keyWindow()?.rootViewController else { return "Unknown" }
        var lines: [String] = []
        buildPath(from: root, depth: 0, into: &lines)
        return lines.joined(separator: "\n")
    }

    /// Same breadcrumb as `fullPath()`, flattened onto a single arrow-separated
    /// line — easier to read/search/filter in the Xcode console than a
    /// multi-line block.
    static func fullPathSingleLine() -> String {
        guard let root = keyWindow()?.rootViewController else { return "Unknown" }
        var names: [String] = []
        collectSingleLine(from: root, into: &names)
        return names.joined(separator: " → ")
    }

    // MARK: - Private

    /// Finds the real app key window — skips the ScreenOverlayKit passthrough
    /// window itself so we never resolve a VC from our own overlay.
    /// Falls back to UIScreen.main.bounds-based window lookup for legacy apps.
    ///
    /// `isKeyWindow` isn't always reliable at the exact moment this is called
    /// (multi-window scenes, timing around presentations, etc.), so if no
    /// window is currently marked key we fall back to the topmost visible,
    /// non-overlay window at the standard app window level.
    private static func keyWindow() -> UIWindow? {
        let sceneWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        let candidates = (sceneWindows.isEmpty ? UIApplication.shared.windows : sceneWindows)
            .filter { window in
                !(window is PassthroughWindow)
                    && !(window.rootViewController is OverlayInternalViewController)
                    && !window.isHidden
            }

        if let key = candidates.first(where: { $0.isKeyWindow }) {
            return key
        }
        // No window is currently marked key — prefer one at the standard
        // app window level (skips status-bar-level or other system windows).
        if let normalLevel = candidates.first(where: { $0.windowLevel == .normal }) {
            return normalLevel
        }
        return candidates.first
    }

    /// Recursively drills into navigation/tab/split/page containers and presented
    /// view controllers to find the one actually visible to the user.
    private static func topMost(from vc: UIViewController) -> UIViewController {
        // Presented modal always takes visual priority
        if let presented = vc.presentedViewController {
            return topMost(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        if let split = vc as? UISplitViewController {
            // On compact (iPhone) the secondary is collapsed; use the primary.
            // On regular (iPad) the last VC is the detail column.
            let target = split.isCollapsed ? split.viewControllers.first : split.viewControllers.last
            if let target { return topMost(from: target) }
        }
        if let page = vc as? UIPageViewController,
           let current = page.viewControllers?.first {
            return topMost(from: current)
        }
        // Custom single-child containers (coordinator-based apps)
        if vc.children.count == 1, let onlyChild = vc.children.first {
            return topMost(from: onlyChild)
        }
        return vc
    }

    private static func collectSingleLine(from vc: UIViewController, depth: Int = 0, into names: inout [String]) {
        guard depth < 50 else { return }  // safety guard against pathological/cyclic hierarchies
        names.append(String(describing: type(of: vc)))

        if let presented = vc.presentedViewController {
            collectSingleLine(from: presented, depth: depth + 1, into: &names)
            return
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            collectSingleLine(from: visible, depth: depth + 1, into: &names)
            return
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            collectSingleLine(from: selected, depth: depth + 1, into: &names)
            return
        }
        if let split = vc as? UISplitViewController {
            let target = split.isCollapsed ? split.viewControllers.first : split.viewControllers.last
            if let target { collectSingleLine(from: target, depth: depth + 1, into: &names) }
            return
        }
        if let page = vc as? UIPageViewController,
           let current = page.viewControllers?.first {
            collectSingleLine(from: current, depth: depth + 1, into: &names)
            return
        }
        if vc.children.count == 1, let onlyChild = vc.children.first {
            collectSingleLine(from: onlyChild, depth: depth + 1, into: &names)
        }
    }

    private static func buildPath(from vc: UIViewController, depth: Int, into lines: inout [String]) {
        let indent = String(repeating: "  ", count: depth)
        let prefix = depth == 0 ? "" : "└─ "
        lines.append("\(indent)\(prefix)\(String(describing: type(of: vc)))")

        if let presented = vc.presentedViewController {
            lines.append("\(indent)  (presents modally)")
            buildPath(from: presented, depth: depth + 1, into: &lines)
            return
        }
        if let nav = vc as? UINavigationController {
            if nav.viewControllers.count > 1 {
                let stack = nav.viewControllers.map { String(describing: type(of: $0)) }.joined(separator: " → ")
                lines.append("\(indent)   stack: \(stack)")
            }
            if let visible = nav.visibleViewController {
                buildPath(from: visible, depth: depth + 1, into: &lines)
            }
            return
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            buildPath(from: selected, depth: depth + 1, into: &lines)
            return
        }
        if let split = vc as? UISplitViewController {
            let target = split.isCollapsed ? split.viewControllers.first : split.viewControllers.last
            if let target { buildPath(from: target, depth: depth + 1, into: &lines) }
            return
        }
        if let page = vc as? UIPageViewController,
           let current = page.viewControllers?.first {
            buildPath(from: current, depth: depth + 1, into: &lines)
            return
        }
        if vc.children.count == 1, let onlyChild = vc.children.first {
            buildPath(from: onlyChild, depth: depth + 1, into: &lines)
        }
    }
}
