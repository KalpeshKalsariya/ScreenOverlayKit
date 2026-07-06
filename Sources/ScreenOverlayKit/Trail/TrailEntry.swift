//
//  TrailEntry.swift
//  ScreenOverlayKit
//
//  Created by Sanket Khatri on 01/07/26.
//

import Foundation

/// A single recorded step in the screen trail: one screen that was visited,
/// when it appeared, and (optionally) how long it stayed on screen.
struct TrailEntry: Codable, Equatable {
    /// The visited view controller's class name.
    let screenName: String
    /// The moment this screen became the top-most visible view controller.
    let timestamp: Date
    /// How long the screen remained on top, once it has been left. `nil` while still current.
    var duration: TimeInterval?
}
