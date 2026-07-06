//
//  ViewControllerTracker.swift
//  ScreenOverlayKit
//
//  Created by Sanket Khatri on 05/06/26.
//

import UIKit

/// Resolves the currently visible `UIViewController` from the app's window
/// hierarchy, and coordinates updates to the overlay label and trail logger.
@MainActor
final class ViewControllerTracker {

    // MARK: - Singleton

    static let shared = ViewControllerTracker()

    private init() {}

    // MARK: - Public Methods

    /// Refreshes the overlay label with the current top view controller name.
    func refresh() {
        guard let vc = topViewController() else { return }
        let screenName = String(describing: type(of: vc))
        print("📱 ScreenOverlay → \(screenName)")
        OverlayWindow.shared.update(text: screenName)
    }

    /// Prints the full view controller hierarchy to the console.
    func printHierarchy() {
        guard let rootVC = rootViewController() else {
            print("""

            ==========================
            📡 ScreenOverlayKit Hierarchy
            ==========================
            No Root View Controller Found
            ==========================

            """)
            return
        }

        print("""

        ==========================
        📡 ScreenOverlayKit Hierarchy
        ==========================

        """)

        printViewController(rootVC, indent: "")

        print("""

        ==========================

        """)
    }

    /// Forwards a screen-appeared event to `TrailLogger`.
    ///
    /// - Parameter viewController: The view controller that just appeared.
    func recordAppear(for viewController: UIViewController) {
        TrailLogger.shared.recordAppear(for: viewController)
    }

    /// Forwards a screen-disappeared event to `TrailLogger`.
    ///
    /// - Parameter viewController: The view controller that just disappeared.
    func recordDisappear(for viewController: UIViewController) {
        TrailLogger.shared.recordDisappear(for: viewController)
    }

    /// Checks whether a given view controller is currently the top-most visible screen.
    ///
    /// - Parameter viewController: The view controller to check.
    /// - Returns: `true` if it is the current top view controller.
    func isTopViewController(_ viewController: UIViewController) -> Bool {
        topViewController() === viewController
    }

    /// Seeds the trail logger with whatever hierarchy is currently visible,
    /// so the very first screen shows up in the trail.
    func seedCurrentVisibleTrail() {
        TrailLogger.shared.seedInitialTrail(with: visibleTrail())
    }

    /// Returns the current top-most visible view controller.
    ///
    /// - Returns: The current top view controller, if one could be resolved.
    func topScreenViewController() -> UIViewController? {
        topViewController()
    }

    // MARK: - Private Helpers

    /// Recursively prints a view controller and its children (tab selection,
    /// navigation stack, presented view controller) to the console.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to print.
    ///   - indent: The indentation prefix used for nested output.
    private func printViewController(
        _ viewController: UIViewController,
        indent: String
    ) {
        let name = String(describing: type(of: viewController))
        print("\(indent)↳ \(name)")

        if let tabBar = viewController as? UITabBarController {
            if let selected = tabBar.selectedViewController {
                print("\(indent)   Selected Tab:")
                printViewController(selected, indent: indent + "   ")
            }
        }

        if let navigation = viewController as? UINavigationController {
            print("\(indent)   Navigation Stack:")
            for vc in navigation.viewControllers {
                let vcName = String(describing: type(of: vc))
                print("\(indent)   • \(vcName)")
            }
            if let visible = navigation.visibleViewController {
                print("\(indent)   Visible:")
                printViewController(visible, indent: indent + "   ")
            }
        }

        if let presented = viewController.presentedViewController {
            print("\(indent)   Presented:")
            printViewController(presented, indent: indent + "   ")
        }
    }

    /// Resolves the app's current root view controller from its key (or
    /// otherwise visible) window, ignoring the ScreenOverlayKit overlay window.
    ///
    /// - Returns: The resolved root view controller, if any.
    private func rootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow && !($0 is PassthroughWindow) })?
                .rootViewController
                ?? UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { !$0.isHidden && !($0 is PassthroughWindow) })?
                .rootViewController
        }

        return UIApplication.shared.windows
            .first(where: { $0.isKeyWindow && !($0 is PassthroughWindow) })?
            .rootViewController
            ?? UIApplication.shared.windows
            .first(where: { !$0.isHidden && !($0 is PassthroughWindow) })?
            .rootViewController
    }

    /// Recursively descends through navigation/tab/presentation containers to
    /// find the actual top-most visible view controller.
    ///
    /// - Parameter viewController: The view controller to start from, or `nil` to start from the root.
    /// - Returns: The resolved top-most view controller, if any.
    private func topViewController(
        from viewController: UIViewController? = nil
    ) -> UIViewController? {
        let vc = viewController ?? rootViewController()

        if let navigation = vc as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }

        if let tabBar = vc as? UITabBarController {
            return topViewController(from: tabBar.selectedViewController)
        }

        if let presented = vc?.presentedViewController {
            return topViewController(from: presented)
        }

        return vc
    }

    /// Recursively builds the list of view controllers that make up the
    /// currently visible chain (navigation stack, selected tab, presented chain).
    ///
    /// - Parameter viewController: The view controller to start from, or `nil` to start from the root.
    /// - Returns: The visible view controllers, root-first.
    private func visibleTrail(
        from viewController: UIViewController? = nil
    ) -> [UIViewController] {
        guard let vc = viewController ?? rootViewController() else { return [] }

        if let navigation = vc as? UINavigationController {
            var trail = navigation.viewControllers
            if let presented = navigation.visibleViewController?.presentedViewController {
                trail.append(contentsOf: visibleTrail(from: presented))
            }
            return trail
        }

        if let tabBar = vc as? UITabBarController {
            guard let selected = tabBar.selectedViewController else { return [tabBar] }
            return visibleTrail(from: selected)
        }

        if let presented = vc.presentedViewController {
            return [vc] + visibleTrail(from: presented)
        }

        return [vc]
    }
}
