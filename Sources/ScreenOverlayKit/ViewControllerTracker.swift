//
//  ViewControllerTracker.swift
//  ScreenRadarKit
//
//  Created by Sanket Khatri on 05/06/26.
//

import UIKit

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
        print("📱 ScreenRadar → \(screenName)")
        OverlayWindow.shared.update(text: screenName)
    }

    /// Prints the full view controller hierarchy to the console.
    func printHierarchy() {
        guard let rootVC = rootViewController() else {
            print("""

            ==========================
            📡 ScreenRadar Hierarchy
            ==========================
            No Root View Controller Found
            ==========================

            """)
            return
        }

        print("""

        ==========================
        📡 ScreenRadar Hierarchy
        ==========================

        """)

        printViewController(rootVC, indent: "")

        print("""

        ==========================

        """)
    }

    func recordAppear(for viewController: UIViewController) {
        TrailLogger.shared.recordAppear(for: viewController)
    }

    func recordDisappear(for viewController: UIViewController) {
        TrailLogger.shared.recordDisappear(for: viewController)
    }

    func isTopViewController(_ viewController: UIViewController) -> Bool {
        topViewController() === viewController
    }

    func seedCurrentVisibleTrail() {
        TrailLogger.shared.seedInitialTrail(with: visibleTrail())
    }

    func topScreenViewController() -> UIViewController? {
        topViewController()
    }

    // MARK: - Private Helpers

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
