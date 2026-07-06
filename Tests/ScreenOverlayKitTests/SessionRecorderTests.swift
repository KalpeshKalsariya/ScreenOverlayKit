import XCTest
@testable import ScreenOverlayKit

/// Regression coverage for `SessionRecorder`'s screen-duration tracking.
///
/// UIKit's real call order for a navigation is: the *new* screen's `viewDidAppear` fires
/// before the *old* screen's `viewDidDisappear` — so `currentScreenToken` has already moved on
/// to the new screen by the time the old one's disappearance is recorded. These tests reproduce
/// that exact ordering to make sure the outgoing screen's duration still gets stamped and printed.
@MainActor
final class SessionRecorderTests: XCTestCase {

    // `SessionRecorder.shared` is a singleton with no public reset, and its session-clearing
    // state (`didStartSession`, etc.) is `private` — not reachable even via `@testable import`,
    // which only lifts `internal` access, not `private`. So each test uses UUID-suffixed screen
    // names to stay isolated from whatever earlier tests already left in `currentSessionPaths`.

    func testDisappearingScreenIsStampedEvenAfterTheNextScreenHasAlreadyAppeared() {
        let recorder = SessionRecorder.shared
        recorder.startSession(trackScreenDuration: true)

        let suffix = UUID().uuidString
        let screenA = NSObject()
        let screenB = NSObject()

        // Matches real UIKit ordering: B appears (setting currentScreenToken = B)
        // *before* A's disappearance is ever reported.
        recorder.recordManualAppear(screenName: "ScreenA-\(suffix)", token: screenA)
        recorder.recordManualAppear(screenName: "ScreenB-\(suffix)", token: screenB)
        recorder.recordManualDisappear(token: screenA)

        let entryForA = recorder.currentSessionPaths.first { $0.path.hasSuffix("ScreenA-\(suffix)") }
        XCTAssertNotNil(entryForA?.duration, "ScreenA's duration should be stamped once it disappears, even though ScreenB already appeared first")
    }

    func testCurrentlyVisibleScreenIsNotStampedByAPriorDisappearance() {
        let recorder = SessionRecorder.shared
        recorder.startSession(trackScreenDuration: true)

        let suffix = UUID().uuidString
        let screenA = NSObject()
        let screenB = NSObject()

        recorder.recordManualAppear(screenName: "ScreenA-\(suffix)", token: screenA)
        recorder.recordManualAppear(screenName: "ScreenB-\(suffix)", token: screenB)
        recorder.recordManualDisappear(token: screenA)

        let entryForB = recorder.currentSessionPaths.first { $0.path.hasSuffix("ScreenB-\(suffix)") }
        XCTAssertNil(entryForB?.duration, "ScreenB is still on screen — it shouldn't have a duration yet")
    }
}
