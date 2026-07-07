//
//  ViewControllerTracker.swift
//  ScreenOverlayKit
//
//  Created by Sanket Khatri on 05/06/26.
//

import UIKit

/// Resolves the currently visible `UIViewController` from the app's window
/// hierarchy, and coordinates updates to the overlay label and session recorder.
@MainActor
final class ViewControllerTracker {

    // MARK: - Singleton

    static let shared = ViewControllerTracker()

    private init() {}

    // MARK: - Private Properties

    /// The screen name last printed/rendered by `refresh()`, so redundant calls for a screen
    /// that's already current (e.g. every container in the hierarchy firing `viewDidAppear`
    /// together at launch) don't re-print/re-render it.
    private var lastReportedScreenName: String?

    // MARK: - Public Methods

    /// Refreshes the overlay label with the current top view controller name, and prints the
    /// full hierarchy — the same thing tapping the overlay label does — so every screen change
    /// shows its complete context in the console without waiting for a tap.
    ///
    /// No-ops if the resolved top screen hasn't changed since the last call — `refresh()` is
    /// called from every view controller's `viewDidAppear` in the hierarchy, and several of
    /// them (e.g. a wrapping `UINavigationController`/`UITabBarController`) can all resolve to
    /// the same top-most screen in a single burst, most notably at launch.
    func refresh() {
        guard let vc = topViewController() else { return }
        let screenName = Self.screenName(for: vc)
        guard screenName != lastReportedScreenName else { return }

        lastReportedScreenName = screenName
        print("📱 ScreenOverlay → \(screenName)")
        printHierarchy()
        OverlayManager.shared.update(text: screenName)
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

    /// Forwards a screen-appeared event to `SessionRecorder`.
    ///
    /// - Parameter viewController: The view controller that just appeared.
    func recordAppear(for viewController: UIViewController) {
        SessionRecorder.shared.recordAppear(for: viewController)
    }

    /// Forwards a screen-disappeared event to `SessionRecorder`.
    ///
    /// - Parameter viewController: The view controller that just disappeared.
    func recordDisappear(for viewController: UIViewController) {
        SessionRecorder.shared.recordDisappear(for: viewController)
    }

    /// Records that a manually-tracked SwiftUI screen appeared, updating the overlay label and
    /// console log (including the full hierarchy, same as `refresh()`) in addition to the
    /// session — used by the `.screenOverlayTrack(_:)` view modifier.
    ///
    /// - Parameters:
    ///   - screenName: The screen's display name.
    ///   - token: A stable per-screen-instance identity used to dedupe repeated appearances and
    ///     to pair this appearance with its matching disappearance.
    func recordManualAppear(screenName: String, token: AnyObject) {
        guard SessionRecorder.shared.recordManualAppear(screenName: screenName, token: token) else { return }
        print("📱 ScreenOverlay → \(screenName)")
        printHierarchy()
        OverlayManager.shared.update(text: screenName)
    }

    /// Records that a manually-tracked SwiftUI screen disappeared — used by the
    /// `.screenOverlayTrack(_:)` view modifier.
    ///
    /// - Parameter token: The identity object passed to the matching `recordManualAppear` call.
    func recordManualDisappear(token: AnyObject) {
        SessionRecorder.shared.recordManualDisappear(token: token)
    }

    /// Checks whether a given view controller is currently the top-most visible screen.
    ///
    /// - Parameter viewController: The view controller to check.
    /// - Returns: `true` if it is the current top view controller.
    func isTopViewController(_ viewController: UIViewController) -> Bool {
        topViewController() === viewController
    }

    /// Seeds the session recorder with whatever hierarchy is currently visible,
    /// so the very first screen is recorded.
    func seedCurrentVisibleSession() {
        SessionRecorder.shared.seedInitialSession(with: visibleScreens())
    }

    /// Returns the current top-most visible view controller.
    ///
    /// - Returns: The current top view controller, if one could be resolved.
    func topScreenViewController() -> UIViewController? {
        topViewController()
    }

    /// Builds a single-line breadcrumb of the currently visible hierarchy — e.g.
    /// `"AppRootViewController → UITabBarController → UINavigationController → ProfileViewController"` —
    /// without printing anything to the console or presenting any UI. Use this to tag
    /// analytics events (Firebase or otherwise) with the current screen context on demand.
    ///
    /// - Returns: The breadcrumb string, or a placeholder if no root view controller could be resolved.
    func currentHierarchyPath() -> String {
        guard let rootVC = rootViewController() else {
            return "No Root View Controller Found"
        }
        return hierarchyPathComponents(from: rootVC).joined(separator: " → ")
    }

    /// Resolves a friendly screen name for a view controller.
    ///
    /// SwiftUI screens hosted via `UIHostingController<ContentView>` are stripped down to just
    /// their wrapped view's name (`ContentView`) for readability.
    ///
    /// - Parameter viewController: The view controller to name.
    /// - Returns: The friendly screen name.
    static func screenName(for viewController: UIViewController) -> String {
        let rawName = String(describing: type(of: viewController))

        guard rawName.hasPrefix("UIHostingController<"), rawName.hasSuffix(">") else {
            return rawName
        }

        let wrappedName = rawName
            .dropFirst("UIHostingController<".count)
            .dropLast()

        return wrappedName.isEmpty ? rawName : String(wrappedName)
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
        let name = Self.screenName(for: viewController)
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
                print("\(indent)   • \(Self.screenName(for: vc))")
            }
            if let visible = navigation.visibleViewController {
                print("\(indent)   Visible:")
                printViewController(visible, indent: indent + "   ")
            }
        }

        if let container = viewController as? ScreenOverlayContainerViewController,
           let visibleChild = container.screenOverlayVisibleChildViewController {
            print("\(indent)   Visible Child:")
            printViewController(visibleChild, indent: indent + "   ")
        }

        if let presented = viewController.presentedViewController {
            print("\(indent)   Presented:")
            printViewController(presented, indent: indent + "   ")
        }
    }

    /// Recursively builds the breadcrumb components for `currentHierarchyPath()` by descending
    /// through tab selection, navigation stack, and presentation, one name per container.
    ///
    /// - Parameter viewController: The view controller to start from.
    /// - Returns: The breadcrumb names, root-first.
    private func hierarchyPathComponents(from viewController: UIViewController) -> [String] {
        var components = [Self.screenName(for: viewController)]

        if let tabBar = viewController as? UITabBarController, let selected = tabBar.selectedViewController {
            components += hierarchyPathComponents(from: selected)
        } else if let navigation = viewController as? UINavigationController, let visible = navigation.visibleViewController {
            components += hierarchyPathComponents(from: visible)
        } else if let container = viewController as? ScreenOverlayContainerViewController,
                  let visibleChild = container.screenOverlayVisibleChildViewController {
            components += hierarchyPathComponents(from: visibleChild)
        } else if let presented = viewController.presentedViewController {
            components += hierarchyPathComponents(from: presented)
        }

        return components
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

        if let container = vc as? ScreenOverlayContainerViewController, container.screenOverlayVisibleChildViewController != nil {
            return topViewController(from: container.screenOverlayVisibleChildViewController)
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
    private func visibleScreens(
        from viewController: UIViewController? = nil
    ) -> [UIViewController] {
        guard let vc = viewController ?? rootViewController() else { return [] }

        if let navigation = vc as? UINavigationController {
            var screens = navigation.viewControllers
            if let presented = navigation.visibleViewController?.presentedViewController {
                screens.append(contentsOf: visibleScreens(from: presented))
            }
            return screens
        }

        if let tabBar = vc as? UITabBarController {
            guard let selected = tabBar.selectedViewController else { return [tabBar] }
            return visibleScreens(from: selected)
        }

        if let container = vc as? ScreenOverlayContainerViewController {
            guard let visibleChild = container.screenOverlayVisibleChildViewController else { return [container] }
            return visibleScreens(from: visibleChild)
        }

        if let presented = vc.presentedViewController {
            return [vc] + visibleScreens(from: presented)
        }

        return [vc]
    }
}
