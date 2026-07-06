//
//  ScreenOverlayEventLogger.swift
//  ScreenOverlayKit
//

import Foundation

/// Adopt this protocol and assign an instance to `ScreenOverlay.eventLogger` to forward
/// ScreenOverlayKit's screen views and custom events to your analytics backend of choice
/// (Firebase Analytics, Mixpanel, Amplitude, your own logging pipeline, etc).
///
/// ScreenOverlayKit has no dependency on any analytics SDK — it only calls this protocol,
/// so you decide where the data goes and which SDK version you use.
///
/// ```swift
/// import FirebaseAnalytics
///
/// final class FirebaseScreenOverlayLogger: NSObject, ScreenOverlayEventLogger {
///     func screenOverlayDidLogScreenView(_ screenName: String, previousScreenName: String?) {
///         Analytics.logEvent(AnalyticsEventScreenView, parameters: [
///             AnalyticsParameterScreenName: screenName
///         ])
///     }
///
///     func screenOverlayDidLogEvent(_ name: String, parameters: [String: Any]?) {
///         Analytics.logEvent(name, parameters: parameters)
///     }
/// }
///
/// // Somewhere at launch, alongside `ScreenOverlay.enable()`:
/// let logger = FirebaseScreenOverlayLogger()
/// ScreenOverlay.eventLogger = logger
/// ```
@objc public protocol ScreenOverlayEventLogger: AnyObject {

    /// Called whenever a new screen becomes the top-most visible screen — both for
    /// automatically-tracked UIKit screens and screens tracked manually via
    /// `.screenOverlayTrack(_:)` in SwiftUI.
    ///
    /// - Parameters:
    ///   - screenName: The new screen's name.
    ///   - previousScreenName: The screen that was visible immediately before this one, if any.
    @objc(screenOverlayDidLogScreenView:previousScreenName:)
    func screenOverlayDidLogScreenView(_ screenName: String, previousScreenName: String?)

    /// Called whenever a custom event is logged via `ScreenOverlay.logEvent(name:parameters:)`.
    ///
    /// - Parameters:
    ///   - name: The event's name (e.g. `"button_tapped"`).
    ///   - parameters: Optional event parameters.
    @objc(screenOverlayDidLogEvent:parameters:)
    func screenOverlayDidLogEvent(_ name: String, parameters: [String: Any]?)
}
