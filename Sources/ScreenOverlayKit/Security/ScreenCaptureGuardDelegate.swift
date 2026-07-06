//
//  ScreenCaptureGuardDelegate.swift
//  ScreenOverlayKit
//

import Foundation

/// Adopt this protocol to be notified of screenshot, screen-recording, and screen-mirroring
/// events detected by `ScreenCaptureGuard`. All methods are optional.
@objc public protocol ScreenCaptureGuardDelegate: AnyObject {

    /// Called when the user takes a screenshot.
    ///
    /// - Note: iOS has no API to prevent or intercept a screenshot before it's saved — this
    ///   fires after the fact. Use it for analytics or an on-screen warning, not prevention.
    @objc optional func screenCaptureGuardDidDetectScreenshot()

    /// Called when screen recording or mirroring (AirPlay, external display) starts or stops.
    ///
    /// - Parameter isCaptured: `true` if the screen is now being recorded or mirrored.
    @objc optional func screenCaptureGuard(didChangeCaptureState isCaptured: Bool)
}
