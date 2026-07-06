//
//  TrailEntry.swift
//  ScreenRadarKit
//
//  Created by Sanket Khatri on 01/07/26.
//

import Foundation

struct TrailEntry: Codable, Equatable {
    let screenName: String
    let timestamp: Date
    var duration: TimeInterval?
}
