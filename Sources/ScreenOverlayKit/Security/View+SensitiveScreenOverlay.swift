//
//  View+SensitiveScreenOverlay.swift
//  ScreenOverlayKit
//

import SwiftUI
import UIKit

public extension View {

    /// Marks this view as sensitive, so it's automatically blurred while `ScreenCaptureGuard`
    /// reports the screen as captured (screenshot, screen recording/mirroring, or app
    /// backgrounding/App Switcher).
    ///
    /// ```swift
    /// struct CardNumberView: View {
    ///     var body: some View {
    ///         Text("4242 4242 4242 4242")
    ///             .sensitiveScreenOverlay()
    ///     }
    /// }
    /// ```
    ///
    /// - Note: Requires `ScreenCaptureGuard.shared.startMonitoring()` to have been called
    ///   somewhere at launch — marking a view sensitive doesn't start monitoring by itself.
    ///
    /// - Returns: A view that blurs itself in response to `ScreenCaptureGuard.shared.isBlurring`.
    func sensitiveScreenOverlay() -> some View {
        modifier(SensitiveScreenOverlayModifier())
    }
}

/// Blurs its content whenever `ScreenCaptureGuard.shared.isBlurring` is `true`.
private struct SensitiveScreenOverlayModifier: ViewModifier {
    @ObservedObject private var captureGuard = ScreenCaptureGuard.shared

    /// Applies a blur and a covering scrim whenever the capture guard reports `isBlurring`.
    ///
    /// Uses only iOS 13-compatible APIs (no `Material`/closure-based `.overlay`, both iOS 15+),
    /// matching ScreenOverlayKit's minimum deployment target.
    ///
    /// - Parameter content: The view being modified.
    /// - Returns: The content, blurred and covered while `isBlurring` is `true`.
    func body(content: Content) -> some View {
        content
            .blur(radius: captureGuard.isBlurring ? 20 : 0)
            .overlay(
                Color(UIColor.systemBackground)
                    .opacity(captureGuard.isBlurring ? 0.7 : 0)
                    .allowsHitTesting(captureGuard.isBlurring)
            )
            .animation(.easeInOut(duration: 0.15), value: captureGuard.isBlurring)
    }
}
