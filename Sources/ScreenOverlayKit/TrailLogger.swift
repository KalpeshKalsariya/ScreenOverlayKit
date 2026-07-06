//
//  TrailLogger.swift
//  ScreenRadarKit
//
//  Created by Sanket Khatri on 01/07/26.
//

import UIKit

@MainActor
final class TrailLogger {

    // MARK: - Singleton

    static let shared = TrailLogger()

    // MARK: - Private Properties

    private let currentTrailKey = "com.screenradar.currentTrail"
    private let previousTrailKey = "com.screenradar.previousTrail"
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

    func recordAppear(for viewController: UIViewController) {
        guard !isScreenRadarController(viewController) else { return }
        guard ViewControllerTracker.shared.isTopViewController(viewController) else { return }

        if append(viewController) {
            saveCurrentTrail()
        }
    }

    func seedInitialTrail(with viewControllers: [UIViewController]) {
        guard currentTrail.isEmpty else { return }

        viewControllers
            .filter { !isScreenRadarController($0) }
            .forEach { append($0) }

        saveCurrentTrail()
    }

    func recordDisappear(for viewController: UIViewController) {
        guard showTimeOnTrail else { return }
        guard currentViewController === viewController else { return }
        guard let lastIndex = currentTrail.indices.last else { return }

        currentTrail[lastIndex].duration = Date().timeIntervalSince(currentTrail[lastIndex].timestamp)
        saveCurrentTrail()
    }

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

    func clearPreviousTrail() {
        previousTrail.removeAll()
        UserDefaults.standard.removeObject(forKey: previousTrailKey)
    }

    func printTrail() {
        print(exportText())
    }

    func exportText() -> String {
        exportText(
            sessionName: "Current",
            trail: currentTrail,
            currentIndex: currentTrail.indices.last
        )
    }

    func exportCurrentSessionFileURL() -> URL? {
        exportFileURL(
            sessionName: "Current",
            trail: currentTrail,
            currentIndex: currentTrail.indices.last
        )
    }

    func exportPreviousSessionFileURL() -> URL? {
        exportFileURL(
            sessionName: "Previous",
            trail: previousTrail,
            currentIndex: nil
        )
    }

    private func exportText(
        sessionName: String,
        trail: [TrailEntry],
        currentIndex: Int?
    ) -> String {
        var lines: [String] = [
            "📋 ScreenRadar Trail Export",
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

    private func exportFileURL(
        sessionName: String,
        trail: [TrailEntry],
        currentIndex: Int?
    ) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenRadarTrail-\(Self.sanitizedProjectName)-\(sessionName).txt")

        do {
            let text = exportText(
                sessionName: sessionName,
                trail: trail,
                currentIndex: currentIndex
            )
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("❌ ScreenRadar: Failed to create trail export file: \(error)")
            return nil
        }
    }

    // MARK: - Private Helpers

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

    private func saveCurrentTrail() {
        save(currentTrail, forKey: currentTrailKey)
    }

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

    private func save(_ trail: [TrailEntry], forKey key: String) {
        guard let data = try? encoder.encode(trail) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func loadTrail(forKey key: String) -> [TrailEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let trail = try? decoder.decode([TrailEntry].self, from: data)
        else { return [] }
        return trail
    }

    private func isScreenRadarController(_ viewController: UIViewController) -> Bool {
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

    private static var projectName: String {
        let infoDictionary = Bundle.main.infoDictionary
        return infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "Unknown App"
    }

    private static var sanitizedProjectName: String {
        projectName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
