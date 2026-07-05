import UIKit

extension UIViewController {

    /// Swaps `viewDidAppear(_:)` and `viewDidDisappear(_:)` with our tracking
    /// implementations exactly once per process, so every view controller in
    /// the app reports automatically — no manual calls needed at each screen.
    static func so_swizzleLifecycleMethods() {
        swizzle(original: #selector(viewDidAppear(_:)),    swizzled: #selector(so_viewDidAppear(_:)))
        swizzle(original: #selector(viewDidDisappear(_:)), swizzled: #selector(so_viewDidDisappear(_:)))
    }

    // MARK: - Private

    private static func swizzle(original: Selector, swizzled: Selector) {
        guard
            let originalMethod = class_getInstanceMethod(UIViewController.self, original),
            let swizzledMethod  = class_getInstanceMethod(UIViewController.self, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /// After the swap this name resolves to the original `viewDidAppear` implementation.
    @objc private func so_viewDidAppear(_ animated: Bool) {
        so_viewDidAppear(animated)
        ScreenOverlay.viewControllerDidAppear(self)
    }

    /// After the swap this name resolves to the original `viewDidDisappear` implementation.
    @objc private func so_viewDidDisappear(_ animated: Bool) {
        so_viewDidDisappear(animated)
        ScreenOverlay.viewControllerDidDisappear(self)
    }
}
