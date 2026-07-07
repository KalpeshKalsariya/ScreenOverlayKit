//
//  ScreenOverlayContainerViewController.swift
//  ScreenOverlayKit
//

import UIKit

/// Conform a custom tab bar / container view controller to this so ScreenOverlayKit's automatic
/// detection can see through it to whichever child is actually visible — the same way it already
/// does for `UITabBarController` (`selectedViewController`) and `UINavigationController`
/// (`visibleViewController`).
///
/// Without this, a custom container (e.g. one built with child view controller containment
/// instead of `UITabBarController`) is a dead end for ScreenOverlayKit's hierarchy walk — the
/// overlay label, the tap-to-print hierarchy, and session-path recording would all report the
/// container itself instead of whatever screen is actually on screen inside it.
///
/// ```swift
/// final class TabVC: UIViewController {
///     var arrayNavigationVC = [UINavigationController]()
///     var selectedIndex = 0
/// }
///
/// extension TabVC: ScreenOverlayContainerViewController {
///     var screenOverlayVisibleChildViewController: UIViewController? {
///         arrayNavigationVC.indices.contains(selectedIndex) ? arrayNavigationVC[selectedIndex] : nil
///     }
/// }
/// ```
@MainActor
public protocol ScreenOverlayContainerViewController: UIViewController {
    /// The child view controller currently visible on screen. Return `nil` if none is
    /// determinable (ScreenOverlayKit will fall back to reporting this container itself).
    var screenOverlayVisibleChildViewController: UIViewController? { get }
}
