import UIKit

/// A `UIWindow` that only captures touches on its own interactive subviews
/// (e.g. the draggable pill label). Every other touch falls through to the
/// app's real window beneath it, so the overlay never blocks UI interaction.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else { return nil }
        // Return nil for the window itself and its root VC view so those
        // "background" layers are invisible to the touch system.
        if hitView === self || hitView === rootViewController?.view { return nil }
        return hitView
    }
}
