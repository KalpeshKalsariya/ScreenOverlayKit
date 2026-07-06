//
//  View+ScreenOverlayTracking.swift
//  ScreenOverlayKit
//

import SwiftUI

public extension View {

    /// Tracks this view as a distinct screen in the ScreenOverlayKit overlay, console log, and session.
    ///
    /// ScreenOverlayKit's automatic tracking is UIKit-based (it swizzles `viewDidAppear`/
    /// `viewDidDisappear`), so it only sees the `UIHostingController` wrapping your SwiftUI
    /// content — it can't see screens pushed or presented purely within SwiftUI's own
    /// navigation (`NavigationStack`, `.sheet`, etc). Attach this modifier to each such screen
    /// to have it show up individually, the same way a `UIViewController` would.
    ///
    /// ```swift
    /// struct ProfileView: View {
    ///     var body: some View {
    ///         Text("Profile")
    ///             .screenOverlayTrack("ProfileView")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter name: The screen's display name, shown in the overlay label, console log, and session.
    /// - Returns: A view that reports its appearance/disappearance to ScreenOverlayKit.
    func screenOverlayTrack(_ name: String) -> some View {
        modifier(ScreenOverlayTrackingModifier(screenName: name))
    }
}

/// Reports a SwiftUI view's appearance/disappearance to `ViewControllerTracker`, mirroring
/// what UIKit's swizzled `viewDidAppear`/`viewDidDisappear` do for view controllers.
private struct ScreenOverlayTrackingModifier: ViewModifier {
    let screenName: String

    /// A stable per-screen-instance identity, preserved by SwiftUI across re-renders of the
    /// same view. Used to dedupe repeated `onAppear` calls and to pair an appearance with its
    /// matching disappearance.
    @State private var identityToken = NSObject()

    /// Attaches appear/disappear reporting to the content view.
    ///
    /// - Parameter content: The view being modified.
    /// - Returns: The content view, unmodified visually.
    func body(content: Content) -> some View {
        content
            .onAppear {
                ViewControllerTracker.shared.recordManualAppear(screenName: screenName, token: identityToken)
            }
            .onDisappear {
                ViewControllerTracker.shared.recordManualDisappear(token: identityToken)
            }
    }
}
