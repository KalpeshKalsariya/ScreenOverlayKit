import XCTest
import UIKit
@testable import ScreenOverlayKit

/// Exercises the blur-on-sensitive-screen pipeline end-to-end: registering a view,
/// simulating the OS events `ScreenCaptureGuard` reacts to, and asserting the blur
/// overlay actually gets added to / removed from the registered view.
///
/// - Note: `UIScreen.main.isCaptured` is a read-only, OS-reported value that can't be forced
///   `true` from a test — so the live "screen recording started" → blur path can't be fully
///   simulated here. That path is verified manually (see the PR/README instructions): start a
///   Simulator screen recording while a sensitive screen is visible and confirm it blurs.
@MainActor
final class ScreenCaptureGuardTests: XCTestCase {

    override func tearDown() async throws {
        ScreenCaptureGuard.shared.stopMonitoring()
        ScreenCaptureGuard.shared.delegate = nil
        try await super.tearDown()
    }

    // MARK: - SensitiveScreenRegistry

    func testRegisteredViewGetsBlurredAndUnblurred() {
        let view = UIView()
        SensitiveScreenRegistry.shared.register(view)

        SensitiveScreenRegistry.shared.showBlur()
        XCTAssertTrue(view.subviews.contains { $0 is BlurOverlayView }, "Expected a BlurOverlayView to be added")

        SensitiveScreenRegistry.shared.hideBlur()
        XCTAssertFalse(view.subviews.contains { $0 is BlurOverlayView }, "Expected the BlurOverlayView to be removed")

        SensitiveScreenRegistry.shared.unregister(view)
    }

    func testUnregisteredViewIsNeverBlurred() {
        let view = UIView()
        SensitiveScreenRegistry.shared.register(view)
        SensitiveScreenRegistry.shared.unregister(view)

        SensitiveScreenRegistry.shared.showBlur()
        XCTAssertFalse(view.subviews.contains { $0 is BlurOverlayView }, "An unregistered view should never be blurred")
    }

    func testUnregisterRemovesAnActiveBlurImmediately() {
        let view = UIView()
        SensitiveScreenRegistry.shared.register(view)
        SensitiveScreenRegistry.shared.showBlur()
        XCTAssertTrue(view.subviews.contains { $0 is BlurOverlayView })

        SensitiveScreenRegistry.shared.unregister(view)
        XCTAssertFalse(view.subviews.contains { $0 is BlurOverlayView })
    }

    // MARK: - ScreenCaptureGuard: app backgrounding / App Switcher

    func testAppResigningActiveBlursSensitiveViews() {
        let view = UIView()
        SensitiveScreenRegistry.shared.register(view)
        ScreenCaptureGuard.shared.startMonitoring()

        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)

        XCTAssertTrue(ScreenCaptureGuard.shared.isBlurring)
        XCTAssertTrue(view.subviews.contains { $0 is BlurOverlayView })

        SensitiveScreenRegistry.shared.unregister(view)
    }

    func testAppBecomingActiveRemovesBlurWhenNotCaptured() {
        let view = UIView()
        SensitiveScreenRegistry.shared.register(view)
        ScreenCaptureGuard.shared.startMonitoring()

        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(ScreenCaptureGuard.shared.isBlurring)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertFalse(ScreenCaptureGuard.shared.isBlurring)
        XCTAssertFalse(view.subviews.contains { $0 is BlurOverlayView })

        SensitiveScreenRegistry.shared.unregister(view)
    }

    // MARK: - ScreenCaptureGuard: screenshot

    func testScreenshotFlashesBlurThenHidesAutomatically() {
        let view = UIView()
        SensitiveScreenRegistry.shared.register(view)
        ScreenCaptureGuard.shared.startMonitoring()

        NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        XCTAssertTrue(ScreenCaptureGuard.shared.isBlurring, "Blur should show immediately on screenshot")
        XCTAssertTrue(view.subviews.contains { $0 is BlurOverlayView })

        let unblurred = expectation(description: "blur auto-hides after the screenshot flash")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            XCTAssertFalse(ScreenCaptureGuard.shared.isBlurring)
            XCTAssertFalse(view.subviews.contains { $0 is BlurOverlayView })
            unblurred.fulfill()
        }
        wait(for: [unblurred], timeout: 2)

        SensitiveScreenRegistry.shared.unregister(view)
    }

    // MARK: - ScreenCaptureGuardDelegate

    func testDelegateIsNotifiedOfScreenshot() {
        final class Spy: NSObject, ScreenCaptureGuardDelegate {
            var screenshotDetected = false
            func screenCaptureGuardDidDetectScreenshot() {
                screenshotDetected = true
            }
        }

        let spy = Spy()
        ScreenCaptureGuard.shared.delegate = spy
        ScreenCaptureGuard.shared.startMonitoring()

        NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)

        XCTAssertTrue(spy.screenshotDetected)
    }

    func testDelegateIsNotifiedOfCaptureStateChange() {
        final class Spy: NSObject, ScreenCaptureGuardDelegate {
            var lastState: Bool?
            func screenCaptureGuard(didChangeCaptureState isCaptured: Bool) {
                lastState = isCaptured
            }
        }

        let spy = Spy()
        ScreenCaptureGuard.shared.delegate = spy
        ScreenCaptureGuard.shared.startMonitoring()

        NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: nil)

        XCTAssertNotNil(spy.lastState, "Delegate should be notified with the current capture state")
    }
}
