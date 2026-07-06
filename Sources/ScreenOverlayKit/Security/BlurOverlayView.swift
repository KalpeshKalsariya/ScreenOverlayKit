//
//  BlurOverlayView.swift
//  ScreenOverlayKit
//

import UIKit

/// A full-bleed blur view placed over sensitive content by `SensitiveScreenRegistry` when a
/// screenshot, screen recording, or app-backgrounding event is detected.
final class BlurOverlayView: UIVisualEffectView {

    /// Creates a blur view using the system material effect.
    convenience init() {
        self.init(effect: UIBlurEffect(style: .systemMaterial))
    }
}
