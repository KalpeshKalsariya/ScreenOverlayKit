//
//  ScreenCaptureGuard.swift
//  ScreenOverlayKit
//

import UIKit
import Combine

/// Detects screenshots, screen recording/mirroring, and app backgrounding, and automatically
/// blurs any screen registered as sensitive — see `UIViewController.markScreenAsSensitiveOverlay()`
/// (UIKit) and `.sensitiveScreenOverlay()` (SwiftUI).
///
/// Unlike `ScreenOverlay` (a debug-only visualization tool), `ScreenCaptureGuard` is designed to
/// run in **production** — it protects real users' sensitive on-screen content from screenshots,
/// screen recordings, and App Switcher snapshots. Call `startMonitoring()` unconditionally
/// (not wrapped in `#if DEBUG`), typically at app launch.
///
/// `ScreenCaptureGuard` conforms to `ObservableObject` so SwiftUI's `.sensitiveScreenOverlay()`
/// can react to `isBlurring` directly; UIKit screens are blurred through `SensitiveScreenRegistry`
/// instead, driven by the same state changes.
@MainActor
public final class ScreenCaptureGuard: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = ScreenCaptureGuard()

    private override init() {
        super.init()
    }

    // MARK: - Public Properties

    /// Whether sensitive screens should currently show their blur overlay — `true` while the
    /// screen is being recorded/mirrored, momentarily after a screenshot, or while the app is
    /// inactive/backgrounded.
    @Published public private(set) var isBlurring = false

    /// Whether the screen is currently being recorded or mirrored (screen recording, AirPlay,
    /// or an external display).
    public private(set) var isScreenCaptured = false

    /// Receives screenshot and screen-recording/mirroring notifications. Held weakly.
    @objc public weak var delegate: ScreenCaptureGuardDelegate?

    // MARK: - Private Properties

    private var isMonitoring = false

    // MARK: - Public Methods

    /// Starts observing screenshots, screen recording/mirroring, and app backgrounding, blurring
    /// every screen registered as sensitive whenever one of those is active. Safe to call more
    /// than once — only the first call has an effect.
    @objc public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        isScreenCaptured = UIScreen.main.isCaptured

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleScreenshotTaken),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleScreenCaptureChanged),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        if isScreenCaptured {
            setBlurring(true)
        }
    }

    /// Stops all monitoring and removes any active blur.
    @objc public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        NotificationCenter.default.removeObserver(self)
        setBlurring(false)
    }

    // MARK: - Notification Handlers

    /// Handles `UIApplication.userDidTakeScreenshotNotification` by notifying the delegate,
    /// logging the event, and briefly flashing the sensitive-screen blur.
    @objc private func handleScreenshotTaken() {
        print("📸 ScreenOverlayKit: Screenshot detected")
        delegate?.screenCaptureGuardDidDetectScreenshot?()
        ScreenOverlay.logEvent(
            name: "screenshot_taken",
            parameters: ["screen": ScreenOverlay.currentScreenName ?? "Unknown"]
        )

        setBlurring(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.isScreenCaptured else { return }
            self.setBlurring(false)
        }
    }

    /// Handles `UIScreen.capturedDidChangeNotification` by updating `isScreenCaptured`,
    /// notifying the delegate, logging the event, and toggling the sensitive-screen blur.
    @objc private func handleScreenCaptureChanged() {
        let captured = UIScreen.main.isCaptured
        isScreenCaptured = captured

        print(captured
            ? "🔴 ScreenOverlayKit: Screen recording/mirroring started"
            : "⏹️ ScreenOverlayKit: Screen recording/mirroring stopped")

        delegate?.screenCaptureGuard?(didChangeCaptureState: captured)
        ScreenOverlay.logEvent(
            name: captured ? "screen_recording_started" : "screen_recording_ended",
            parameters: ["screen": ScreenOverlay.currentScreenName ?? "Unknown"]
        )

        setBlurring(captured)
    }

    /// Handles the app resigning active by blurring sensitive screens before the system takes
    /// the App Switcher snapshot.
    @objc private func handleWillResignActive() {
        setBlurring(true)
    }

    /// Handles the app becoming active again by removing the blur, unless screen
    /// recording/mirroring is still active.
    @objc private func handleDidBecomeActive() {
        guard !isScreenCaptured else { return }
        setBlurring(false)
    }

    // MARK: - Private Helpers

    /// Updates `isBlurring` (driving SwiftUI's `.sensitiveScreenOverlay()`) and shows/hides the
    /// blur overlay on every UIKit view registered via `SensitiveScreenRegistry`.
    ///
    /// - Parameter blurring: Whether sensitive screens should be blurred.
    private func setBlurring(_ blurring: Bool) {
        isBlurring = blurring
        if blurring {
            SensitiveScreenRegistry.shared.showBlur()
        } else {
            SensitiveScreenRegistry.shared.hideBlur()
        }
    }
}
