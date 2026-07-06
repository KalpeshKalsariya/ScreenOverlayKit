//
//  SessionRecorder.swift
//  ScreenOverlayKit
//

import UIKit

/// Records the full hierarchy path of every screen visited during the current app session
/// (and the previous one) — no UI, just persisted data queryable through `ScreenOverlay`.
///
/// Each entry stores the complete breadcrumb path at the moment that screen appeared, e.g.
/// `"AppRootViewController → UITabBarController → ProfileViewController"`, rather than just
/// a bare screen name.
@MainActor
final class SessionRecorder {

    // MARK: - Singleton

    static let shared = SessionRecorder()

    // MARK: - Private Properties

    private let currentSessionKey = "com.screenoverlaykit.currentSessionPaths"
    private let previousSessionKey = "com.screenoverlaykit.previousSessionPaths"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// The currently tracked screen's identity token, used to dedupe repeated appearances.
    /// A `UIViewController` instance for automatic tracking, or a per-instance token for
    /// manually-tracked SwiftUI screens.
    private var currentScreenToken: AnyObject?

    /// Maps each screen's identity token to the `currentSessionPaths` index it was recorded at.
    ///
    /// A disappearing screen can't be paired with its entry by comparing against
    /// `currentScreenToken` — the *next* screen's `viewDidAppear` always fires (and updates
    /// `currentScreenToken`) before this screen's `viewDidDisappear` does, so `currentScreenToken`
    /// has already moved on by the time this screen's disappearance is recorded. This map lets
    /// `recordDisappearance` find the exact entry that belongs to the token it was given.
    private var entryIndexByToken: [ObjectIdentifier: Int] = [:]

    private var didStartSession = false

    // MARK: - Public Properties

    private(set) var currentSessionPaths: [SessionPathEntry] = []
    private(set) var previousSessionPaths: [SessionPathEntry] = []
    var trackScreenDuration = false

    /// The most recently recorded full path, e.g. `"Root → Tab → Nav → ProfileView"`.
    var currentPath: String? {
        currentSessionPaths.last?.path
    }

    /// The leaf screen name from `currentPath` (its last path component).
    var currentScreenName: String? {
        currentPath?.components(separatedBy: " → ").last
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    /// Starts a new session, rolling the previous session's paths into `previousSessionPaths`
    /// and clearing `currentSessionPaths`. Safe to call more than once — only the first call
    /// in a session has an effect.
    ///
    /// - Parameter trackScreenDuration: Whether subsequent entries should record (and print to
    ///   the console) how long each screen stayed on top.
    func startSession(trackScreenDuration: Bool) {
        self.trackScreenDuration = trackScreenDuration
        guard !didStartSession else { return }

        previousSessionPaths = loadSession(forKey: currentSessionKey)
        if !previousSessionPaths.isEmpty {
            save(previousSessionPaths, forKey: previousSessionKey)
        } else {
            previousSessionPaths = loadSession(forKey: previousSessionKey)
        }

        currentSessionPaths = []
        saveCurrentSession()
        didStartSession = true
    }

    /// Records that a view controller appeared, appending its current full hierarchy path if
    /// it is genuinely the new top-most screen.
    ///
    /// - Parameter viewController: The view controller that just appeared.
    func recordAppear(for viewController: UIViewController) {
        guard !isScreenOverlayController(viewController) else { return }
        guard ViewControllerTracker.shared.isTopViewController(viewController) else { return }

        recordAppearance(path: ViewControllerTracker.shared.currentHierarchyPath(), token: viewController)
    }

    /// Records that a manually-tracked screen appeared — used by SwiftUI's
    /// `.screenOverlayTrack(_:)` view modifier for screens with no backing `UIViewController`.
    /// The recorded path is the live UIKit hierarchy path with `screenName` appended, since
    /// UIKit can't see navigation that happens purely inside SwiftUI.
    ///
    /// - Parameters:
    ///   - screenName: The screen's display name.
    ///   - token: A stable per-screen-instance identity used to dedupe repeated appearances
    ///     and to pair this appearance with its matching disappearance.
    /// - Returns: `true` if a new session entry was recorded.
    @discardableResult
    func recordManualAppear(screenName: String, token: AnyObject) -> Bool {
        let basePath = ViewControllerTracker.shared.currentHierarchyPath()
        let path = basePath.isEmpty ? screenName : "\(basePath) → \(screenName)"
        return recordAppearance(path: path, token: token)
    }

    /// Seeds the session with the current top-most screen's full path when ScreenOverlayKit is
    /// enabled, so the session isn't empty before the first navigation happens.
    ///
    /// - Parameter viewControllers: The currently visible hierarchy, root-first.
    func seedInitialSession(with viewControllers: [UIViewController]) {
        guard currentSessionPaths.isEmpty else { return }
        guard let top = viewControllers.last(where: { !isScreenOverlayController($0) }) else { return }

        recordAppearance(path: ViewControllerTracker.shared.currentHierarchyPath(), token: top)
    }

    /// Records that a view controller disappeared, stamping how long it was on screen if
    /// `trackScreenDuration` is enabled.
    ///
    /// - Parameter viewController: The view controller that just disappeared.
    func recordDisappear(for viewController: UIViewController) {
        recordDisappearance(token: viewController)
    }

    /// Records that a manually-tracked screen disappeared — used by SwiftUI's
    /// `.screenOverlayTrack(_:)` view modifier.
    ///
    /// - Parameter token: The identity object passed to the matching `recordManualAppear` call.
    func recordManualDisappear(token: AnyObject) {
        recordDisappearance(token: token)
    }

    // MARK: - Private Helpers

    /// Appends a new session entry if `token` differs from the currently tracked screen, and
    /// notifies `ScreenOverlay.eventLogger` of the screen view.
    ///
    /// - Parameters:
    ///   - path: The new screen's full breadcrumb path.
    ///   - token: An identity object representing this screen instance.
    /// - Returns: `true` if a new entry was appended, `false` if it was a duplicate of the current screen.
    @discardableResult
    private func recordAppearance(path: String, token: AnyObject) -> Bool {
        guard currentScreenToken !== token else { return false }

        let previousScreenName = currentScreenName
        currentScreenToken = token
        currentSessionPaths.append(SessionPathEntry(path: path, timestamp: Date(), duration: nil))
        entryIndexByToken[ObjectIdentifier(token)] = currentSessionPaths.count - 1
        saveCurrentSession()

        let newScreenName = path.components(separatedBy: " → ").last ?? path
        ScreenOverlay.notifyScreenView(newScreenName, previousScreenName: previousScreenName)
        return true
    }

    /// Stamps the duration of the screen `token` belongs to, and prints how long it stayed on
    /// top — whether the user navigated forward, back, or dismissed it.
    ///
    /// - Parameter token: The identity object of the screen that disappeared.
    private func recordDisappearance(token: AnyObject) {
        guard trackScreenDuration else { return }
        guard let index = entryIndexByToken.removeValue(forKey: ObjectIdentifier(token)) else { return }
        guard currentSessionPaths.indices.contains(index) else { return }

        let entry = currentSessionPaths[index]
        let duration = Date().timeIntervalSince(entry.timestamp)
        currentSessionPaths[index].duration = duration
        saveCurrentSession()

        let screenName = entry.path.components(separatedBy: " → ").last ?? entry.path
        print("⏱️ ScreenOverlay → \(screenName) stayed \(Self.format(duration: duration))")
    }

    /// Formats a duration as a short human-readable string (e.g. `"<1s"`, `"12s"`, `"2m 5s"`).
    ///
    /// - Parameter duration: The duration, in seconds.
    /// - Returns: The formatted duration string.
    private static func format(duration: TimeInterval) -> String {
        guard duration >= 1 else { return "<1s" }

        let seconds = Int(duration.rounded())
        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes)m \(remainder)s"
    }

    /// Persists `currentSessionPaths` to `UserDefaults`.
    private func saveCurrentSession() {
        save(currentSessionPaths, forKey: currentSessionKey)
    }

    /// Encodes and stores a session under the given `UserDefaults` key.
    ///
    /// - Parameters:
    ///   - session: The session entries to persist.
    ///   - key: The `UserDefaults` key to store it under.
    private func save(_ session: [SessionPathEntry], forKey key: String) {
        guard let data = try? encoder.encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Loads and decodes a session from the given `UserDefaults` key.
    ///
    /// - Parameter key: The `UserDefaults` key to read from.
    /// - Returns: The decoded session entries, or an empty array if none was stored or decoding failed.
    private func loadSession(forKey key: String) -> [SessionPathEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let session = try? decoder.decode([SessionPathEntry].self, from: data)
        else { return [] }
        return session
    }

    /// Determines whether a view controller belongs to ScreenOverlayKit's own overlay UI (or the
    /// system), and should therefore be excluded from the session.
    ///
    /// - Parameter viewController: The view controller to check.
    /// - Returns: `true` if the view controller should be ignored.
    private func isScreenOverlayController(_ viewController: UIViewController) -> Bool {
        if viewController.view.window is PassthroughWindow {
            return true
        }

        let bundleIdentifier = Bundle(for: type(of: viewController)).bundleIdentifier
        return bundleIdentifier?.hasPrefix("com.apple.") == true
    }
}
