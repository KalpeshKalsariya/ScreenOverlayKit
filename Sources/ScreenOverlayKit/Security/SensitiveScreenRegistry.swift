//
//  SensitiveScreenRegistry.swift
//  ScreenOverlayKit
//

import UIKit

/// Tracks every `UIView` registered as sensitive and shows/hides a `BlurOverlayView` over each
/// of them on command from `ScreenCaptureGuard`.
///
/// Views are held weakly (`NSHashTable`), and their blur overlays are held weakly too
/// (`NSMapTable`) — since a blur overlay is a subview of the view it protects, the view
/// hierarchy itself keeps it alive while shown, and both entries clear themselves automatically
/// once a registered view deallocates. No manual cleanup bookkeeping is required.
@MainActor
final class SensitiveScreenRegistry {

    // MARK: - Singleton

    static let shared = SensitiveScreenRegistry()

    // MARK: - Private Properties

    private let sensitiveViews = NSHashTable<UIView>.weakObjects()
    private let blurOverlays = NSMapTable<UIView, BlurOverlayView>(keyOptions: .weakMemory, valueOptions: .weakMemory)

    private init() {}

    // MARK: - Public Methods

    /// Registers a view as sensitive, so it gets blurred whenever `showBlur()` is called.
    ///
    /// - Parameter view: The view to protect.
    func register(_ view: UIView) {
        sensitiveViews.add(view)
    }

    /// Unregisters a view, removing any active blur immediately.
    ///
    /// - Parameter view: The view to stop protecting.
    func unregister(_ view: UIView) {
        sensitiveViews.remove(view)
        removeBlur(from: view)
    }

    /// Adds a blur overlay to every currently-registered sensitive view.
    func showBlur() {
        for view in sensitiveViews.allObjects {
            addBlur(to: view)
        }
    }

    /// Removes the blur overlay from every currently-registered sensitive view.
    func hideBlur() {
        for view in sensitiveViews.allObjects {
            removeBlur(from: view)
        }
    }

    // MARK: - Private Helpers

    /// Adds a blur overlay covering `view`, unless one is already present.
    ///
    /// - Parameter view: The view to cover.
    private func addBlur(to view: UIView) {
        guard blurOverlays.object(forKey: view) == nil else { return }

        let blur = BlurOverlayView()
        blur.frame = view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blur)
        blurOverlays.setObject(blur, forKey: view)
    }

    /// Removes `view`'s blur overlay, if any.
    ///
    /// - Parameter view: The view to uncover.
    private func removeBlur(from view: UIView) {
        blurOverlays.object(forKey: view)?.removeFromSuperview()
        blurOverlays.removeObject(forKey: view)
    }
}
