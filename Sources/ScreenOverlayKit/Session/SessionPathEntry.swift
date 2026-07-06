//
//  SessionPathEntry.swift
//  ScreenOverlayKit
//

import Foundation

/// A single recorded screen visit: the full hierarchy breadcrumb it was reached through,
/// when it appeared, and (optionally) how long it stayed on screen.
struct SessionPathEntry: Codable, Equatable {
    /// The full breadcrumb path at the moment this screen appeared, e.g.
    /// `"AppRootViewController → UITabBarController → ProfileViewController"`.
    let path: String
    /// The moment this screen became the top-most visible screen.
    let timestamp: Date
    /// How long the screen remained on top, once it has been left. `nil` while still current.
    var duration: TimeInterval?
}
