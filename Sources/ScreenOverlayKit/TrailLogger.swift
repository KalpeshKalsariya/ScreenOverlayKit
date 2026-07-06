//
//  TrailLogger.swift
//  ScreenOverlayKit
//
//  Created by Sanket Khatri on 01/07/26.
//

import UIKit

/// Records the sequence of screens visited during the current app session
/// (and the previous one), and exports that trail as text/files.
@MainActor
final class TrailLogger {

    // MARK: - Singleton

    static let shared = TrailLogger()

    // MARK: - Private Properties

    private let currentTrailKey = "com.screenoverlaykit.currentTrail"
    private let previousTrailKey = "com.screenoverlaykit.previousTrail"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var currentViewController: UIViewController?
    private var didStartSession = false

    // MARK: - Public Properties

    private(set) var currentTrail: [TrailEntry] = []
    private(set) var previousTrail: [TrailEntry] = []
    var showTimeOnTrail = false

    var currentScreenName: String? {
        currentTrail.last?.screenName
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    /// Starts a new trail session, rolling the previous session's trail into
    /// `previousTrail` and clearing `currentTrail`. Safe to call more than
    /// once — only the first call in a session has an effect.
    ///
    /// - Parameter showTimeOnTrail: Whether subsequent trail entries should
    ///   record how long each screen stayed on top.
    func startSession(showTimeOnTrail: Bool) {
        self.showTimeOnTrail = showTimeOnTrail
        guard !didStartSession else { return }

        previousTrail = loadTrail(forKey: currentTrailKey)
        if !previousTrail.isEmpty {
            save(previousTrail, forKey: previousTrailKey)
        } else {
            previousTrail = loadTrail(forKey: previousTrailKey)
        }

        currentTrail = []
        saveCurrentTrail()
        didStartSession = true
    }

    /// Records that a view controller appeared, appending it to the current
    /// trail if it is genuinely the new top-most screen.
    ///
    /// - Parameter viewController: The view controller that just appeared.
    func recordAppear(for viewController: UIViewController) {
        guard !isScreenOverlayController(viewController) else { return }
        guard ViewControllerTracker.shared.isTopViewController(viewController) else { return }

        if append(viewController) {
            saveCurrentTrail()
        }
    }

    /// Seeds the trail with the view controllers already visible when
    /// ScreenOverlayKit is enabled, so the trail isn't empty for the first screen.
    ///
    /// - Parameter viewControllers: The currently visible hierarchy, root-first.
    func seedInitialTrail(with viewControllers: [UIViewController]) {
        guard currentTrail.isEmpty else { return }

        viewControllers
            .filter { !isScreenOverlayController($0) }
            .forEach { append($0) }

        saveCurrentTrail()
    }

    /// Records that a view controller disappeared, stamping how long it was
    /// on screen if `showTimeOnTrail` is enabled.
    ///
    /// - Parameter viewController: The view controller that just disappeared.
    func recordDisappear(for viewController: UIViewController) {
        guard showTimeOnTrail else { return }
        guard currentViewController === viewController else { return }
        guard let lastIndex = currentTrail.indices.last else { return }

        currentTrail[lastIndex].duration = Date().timeIntervalSince(currentTrail[lastIndex].timestamp)
        saveCurrentTrail()
    }

    /// Clears the current trail and restarts it from whatever screen is
    /// currently on top, so the trail never appears completely empty.
    func clearTrailRestartingFromCurrentScreen() {
        currentTrail.removeAll()

        if currentViewController == nil {
            currentViewController = ViewControllerTracker.shared.topScreenViewController()
        }

        if let currentViewController {
            currentTrail.append(
                TrailEntry(
                    screenName: String(describing: type(of: currentViewController)),
                    timestamp: Date(),
                    duration: nil
                )
            )
        }

        saveCurrentTrail()
    }

    /// Clears the previous session's saved trail.
    func clearPreviousTrail() {
        previousTrail.removeAll()
        UserDefaults.standard.removeObject(forKey: previousTrailKey)
    }

    /// Prints the current session's trail to the console.
    func printTrail() {
        print(exportText())
    }

    /// Builds a human-readable text export of the current session's trail.
    ///
    /// - Returns: The formatted trail text.
    func exportText() -> String {
        exportText(
            sessionName: "Current",
            trail: currentTrail,
            currentIndex: currentTrail.indices.last
        )
    }

    /// Writes the current session's trail to a temporary text file for sharing.
    ///
    /// - Returns: The file URL, or `nil` if writing failed.
    func exportCurrentSessionFileURL() -> URL? {
        exportFileURL(
            sessionName: "Current",
            trail: currentTrail,
            currentIndex: currentTrail.indices.last
        )
    }

    /// Writes the previous session's trail to a temporary text file for sharing.
    ///
    /// - Returns: The file URL, or `nil` if writing failed.
    func exportPreviousSessionFileURL() -> URL? {
        exportFileURL(
            sessionName: "Previous",
            trail: previousTrail,
            currentIndex: nil
        )
    }

    // MARK: - Private Helpers

    /// Builds the human-readable text export for an arbitrary trail/session.
    ///
    /// - Parameters:
    ///   - sessionName: Label shown in the export header (e.g. "Current", "Previous").
    ///   - trail: The entries to render.
    ///   - currentIndex: The index of the entry that is still the active screen, if any.
    /// - Returns: The formatted trail text.
    private func exportText(
        sessionName: String,
        trail: [TrailEntry],
        currentIndex: Int?
    ) -> String {
        var lines: [String] = [
            "📋 ScreenOverlayKit Trail Export",
            "Project: \(Self.projectName)",
            "Session: \(sessionName)",
            "Generated: \(Self.displayDateFormatter.string(from: Date()))",
            ""
        ]

        if trail.isEmpty {
            lines.append("No screens recorded in this session.")
            return lines.joined(separator: "\n")
        }

        for (index, entry) in trail.enumerated() {
            lines.append(formattedLine(for: entry, index: index, isCurrent: index == currentIndex))
        }

        return lines.joined(separator: "\n")
    }

    /// Writes a trail's text export to a temporary file.
    ///
    /// - Parameters:
    ///   - sessionName: Label used in both the export header and the file name.
    ///   - trail: The entries to export.
    ///   - currentIndex: The index of the entry that is still the active screen, if any.
    /// - Returns: The written file's URL, or `nil` if the write failed.
    private func exportFileURL(
        sessionName: String,
        trail: [TrailEntry],
        currentIndex: Int?
    ) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenOverlayKitTrail-\(Self.sanitizedProjectName)-\(sessionName).txt")

        do {
            let text = exportText(
                sessionName: sessionName,
                trail: trail,
                currentIndex: currentIndex
            )
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("❌ ScreenOverlayKit: Failed to create trail export file: \(error)")
            return nil
        }
    }

    /// Formats a single trail entry as one aligned line of text.
    ///
    /// - Parameters:
    ///   - entry: The entry to format.
    ///   - index: The entry's position in the trail, used for the leading number.
    ///   - isCurrent: Whether this entry is the currently active screen.
    /// - Returns: The formatted line.
    private func formattedLine(for entry: TrailEntry, index: Int, isCurrent: Bool) -> String {
        let number = String(format: "%02d.", index + 1)
        let title = "\(number) \(entry.screenName)"
        let suffix: String

        if isCurrent {
            suffix = "← current"
        } else if showTimeOnTrail, let duration = entry.duration {
            suffix = format(duration: duration)
        } else if showTimeOnTrail {
            suffix = "<1s"
        } else {
            suffix = ""
        }

        guard !suffix.isEmpty else { return title }
        let padding = max(1, 32 - title.count)
        return title + String(repeating: " ", count: padding) + suffix
    }

    /// Formats a duration as a short human-readable string (e.g. `"<1s"`, `"12s"`, `"2m 5s"`).
    ///
    /// - Parameter duration: The duration, in seconds.
    /// - Returns: The formatted duration string.
    private func format(duration: TimeInterval) -> String {
        guard duration >= 1 else { return "<1s" }

        let seconds = Int(duration.rounded())
        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes)m \(remainder)s"
    }

    /// Persists `currentTrail` to `UserDefaults`.
    private func saveCurrentTrail() {
        save(currentTrail, forKey: currentTrailKey)
    }

    /// Appends a view controller to the current trail if it differs from the
    /// last recorded view controller.
    ///
    /// - Parameter viewController: The view controller to record.
    /// - Returns: `true` if a new entry was appended, `false` if it was a duplicate.
    @discardableResult
    private func append(_ viewController: UIViewController) -> Bool {
        guard currentViewController !== viewController else { return false }

        currentViewController = viewController
        currentTrail.append(
            TrailEntry(
                screenName: String(describing: type(of: viewController)),
                timestamp: Date(),
                duration: nil
            )
        )
        return true
    }

    /// Encodes and stores a trail under the given `UserDefaults` key.
    ///
    /// - Parameters:
    ///   - trail: The trail to persist.
    ///   - key: The `UserDefaults` key to store it under.
    private func save(_ trail: [TrailEntry], forKey key: String) {
        guard let data = try? encoder.encode(trail) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Loads and decodes a trail from the given `UserDefaults` key.
    ///
    /// - Parameter key: The `UserDefaults` key to read from.
    /// - Returns: The decoded trail, or an empty array if none was stored or decoding failed.
    private func loadTrail(forKey key: String) -> [TrailEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let trail = try? decoder.decode([TrailEntry].self, from: data)
        else { return [] }
        return trail
    }

    /// Determines whether a view controller belongs to ScreenOverlayKit's own
    /// UI (or the system), and should therefore be excluded from the trail.
    ///
    /// - Parameter viewController: The view controller to check.
    /// - Returns: `true` if the view controller should be ignored.
    private func isScreenOverlayController(_ viewController: UIViewController) -> Bool {
        if viewController is TrailBottomSheet || viewController.view.window is PassthroughWindow {
            return true
        }

        let bundleIdentifier = Bundle(for: type(of: viewController)).bundleIdentifier
        return bundleIdentifier?.hasPrefix("com.apple.") == true
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// The host app's display name, used in trail exports.
    private static var projectName: String {
        let infoDictionary = Bundle.main.infoDictionary
        return infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "Unknown App"
    }

    /// `projectName` sanitized to alphanumeric components, safe for use in a file name.
    private static var sanitizedProjectName: String {
        projectName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
