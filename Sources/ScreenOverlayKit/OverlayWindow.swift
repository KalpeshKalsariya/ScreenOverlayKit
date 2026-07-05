import UIKit

/// Owns the floating overlay window + pill label that displays the current screen name.
///
/// @MainActor: pure UIKit state touched only on the main thread.
/// NSObject: required for @objc gesture recognizer selectors.
@MainActor
final class OverlayWindow: NSObject {

    static let shared = OverlayWindow()

    private var window: PassthroughWindow?
    private var pillView: OverlayPillView?
    private var panGesture: UIPanGestureRecognizer?
    private var tapGesture: UITapGestureRecognizer?
    private weak var rootViewController: OverlayRootViewController?
    private var pendingDraggable = false

    private var sceneObserverToken: NSObjectProtocol?
    private var traitsObserverToken: NSObjectProtocol?

    /// Tracks whether the pill has ever been explicitly positioned (either by
    /// the initial layout pass or by a user drag). Used so text updates don't
    /// snap a dragged pill back to its default top-center position.
    private var hasPositioned = false

    private override init() {}

    // MARK: - Public API

    func show(draggable: Bool) {
        guard window == nil else { return }

        if let scene = Self.activeScene() {
            install(on: scene, draggable: draggable)
        } else if Self.hasSceneManifest() {
            print("🔎 ScreenOverlayKit: scene manifest found, waiting for UIScene activation")
            pendingDraggable = draggable
            sceneObserverToken = NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let self, self.window == nil,
                      let scene = note.object as? UIWindowScene else { return }
                self.removeSceneObserver()
                self.install(on: scene, draggable: self.pendingDraggable)
            }
        } else {
            // Legacy path: no scene manifest
            print("🔎 ScreenOverlayKit: no UIScene lifecycle, using legacy screen-based window")
            installLegacy(draggable: draggable)
        }
    }

    func update(text: String) {
        // Always dispatch to main; callers may come from background queues.
        DispatchQueue.main.async { [weak self] in
            guard let self, let pill = self.pillView, let window = self.window else { return }
            pill.setText(text)
            // Recompute size + reposition every update so the pill always
            // fits its (possibly new-length) text with correct padding.
            self.positionPill(pill, in: window)
        }
    }

    func hide() {
        removeSceneObserver()
        removeTraitsObserver()
        window?.isHidden = true
        window = nil
        pillView = nil
        panGesture = nil
        tapGesture = nil
        rootViewController = nil
        pendingDraggable = false
        hasPositioned = false
    }

    // MARK: - Scene Detection

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    private static func hasSceneManifest() -> Bool {
        Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") != nil
    }

    // MARK: - Install (Modern — UIWindowScene)

    private func install(on scene: UIWindowScene, draggable: Bool) {
        let overlayWindow = PassthroughWindow(windowScene: scene)
        // .alert + 1 keeps the pill visible above UIAlertController / action
        // sheets, which render in their own system window at .alert level
        // (2000) — higher than the .statusBar level this used previously.
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear

        let rootVC = OverlayRootViewController()
        overlayWindow.rootViewController = rootVC
        overlayWindow.isHidden = false

        // Layout happens after the window is visible so safeAreaInsets are valid.
        // We defer pill placement to viewDidLayoutSubviews via OverlayRootViewController.
        finishInstall(overlayWindow: overlayWindow, rootVC: rootVC, draggable: draggable)
    }

    // MARK: - Install (Legacy — UIScreen.main)

    private func installLegacy(draggable: Bool) {
        let overlayWindow = PassthroughWindow(frame: UIScreen.main.bounds)
        // Same rationale as the modern path — stay above alert-level windows.
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear

        let rootVC = OverlayRootViewController()
        overlayWindow.rootViewController = rootVC

        // Do NOT call makeKeyAndVisible — that steals key-window status from
        // the app's real window and breaks touch routing. Just un-hide it.
        overlayWindow.isHidden = false

        finishInstall(overlayWindow: overlayWindow, rootVC: rootVC, draggable: draggable)
    }

    // MARK: - Shared Setup

    private func finishInstall(overlayWindow: PassthroughWindow,
                               rootVC: OverlayRootViewController,
                               draggable: Bool) {
        let pill = OverlayPillView()
        pill.setText(ViewControllerTracker.currentScreenName())
        // Compute a real, non-zero frame from intrinsic content size BEFORE
        // the pill is inserted into the hierarchy. This is the key fix:
        // if the pill were added with frame == .zero, its implicit
        // autoresizing-mask width/height constraints would conflict with
        // the label's Auto Layout constraints on first layout pass,
        // producing "Unable to simultaneously satisfy constraints".
        pill.sizeToFit()
        // Interaction must stay enabled even when not draggable, so the tap
        // gesture (full-path popup) always works. Dragging is still gated
        // separately by the `draggable` flag below.
        pill.isUserInteractionEnabled = true
        rootVC.view.addSubview(pill)

        // Position pill after layout so safe-area insets are populated.
        // OverlayRootViewController calls back here via its layout hook.
        rootVC.onLayout = { [weak self, weak pill, weak overlayWindow] in
            guard let pill, let overlayWindow else { return }
            self?.positionPill(pill, in: overlayWindow)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        pill.addGestureRecognizer(tap)
        tapGesture = tap

        if draggable {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pill.addGestureRecognizer(pan)
            panGesture = pan
        }

        traitsObserverToken = NotificationCenter.default.addObserver(
            forName: .screenOverlayTraitsChanged,
            object: nil,
            queue: .main
        ) { [weak self, weak pill] _ in
            guard let pill else { return }
            self?.applyAppearance(to: pill)
        }

        applyAppearance(to: pill)

        self.window = overlayWindow
        self.pillView = pill
        self.rootViewController = rootVC
    }

    /// Resizes the pill to fit its current text, then positions it.
    /// - If the pill has never been positioned (or was reset), it's placed
    ///   top-center, respecting the safe area.
    /// - If the user already dragged it somewhere, later text updates keep
    ///   that same center point instead of snapping back to top-center.
    private func positionPill(_ pill: OverlayPillView, in window: UIWindow) {
        let previousCenter = pill.center
        pill.sizeToFit()

        if hasPositioned {
            pill.center = previousCenter
        } else {
            let safeTop = window.rootViewController?.view.safeAreaInsets.top ?? 0
            let topY = max(safeTop, 20) + pill.bounds.height / 2 + 4
            pill.center = CGPoint(x: window.bounds.width / 2, y: topY)
            hasPositioned = true
        }

        clampToBounds(pill, in: window)
    }

    /// Keeps the pill fully on-screen after a resize (e.g. a longer screen
    /// name at a dragged position near the edge could otherwise overflow).
    private func clampToBounds(_ view: UIView, in window: UIWindow) {
        let bounds = window.bounds
        let margin: CGFloat = 16
        let hw = view.bounds.width  / 2
        let hh = view.bounds.height / 2
        guard bounds.width > hw * 2 + margin * 2,
              bounds.height > hh * 2 + margin * 2 else { return }
        let x = min(max(view.center.x, hw + margin), bounds.width  - hw - margin)
        let y = min(max(view.center.y, hh + margin), bounds.height - hh - margin)
        view.center = CGPoint(x: x, y: y)
    }

    // MARK: - Appearance

    private func applyAppearance(to pill: OverlayPillView) {
        let isDark = pill.traitCollection.userInterfaceStyle == .dark
        pill.applyTheme(dark: isDark)
    }

    // MARK: - Observer Cleanup

    private func removeSceneObserver() {
        sceneObserverToken.map { NotificationCenter.default.removeObserver($0) }
        sceneObserverToken = nil
    }

    private func removeTraitsObserver() {
        traitsObserverToken.map { NotificationCenter.default.removeObserver($0) }
        traitsObserverToken = nil
    }

    // MARK: - Tap → Full Path

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        showFullPath()
    }

    /// Presents the full container → screen breadcrumb (nav stack, tab,
    /// modal presentation chain, etc.) for whatever is currently visible.
    ///
    /// Note: this is the view-controller *hierarchy* path, not a filesystem
    /// path — Swift's runtime doesn't expose the .swift source file a class
    /// was declared in unless each type opts in manually (e.g. stashing
    /// `#file` at declaration time), which isn't feasible to do automatically
    /// for arbitrary app code. The hierarchy path is the closest equivalent
    /// available without per-screen instrumentation.
    private func showFullPath() {
        guard let rootVC = rootViewController else { return }
        let path = ViewControllerTracker.fullPath()
        let singleLine = ViewControllerTracker.fullPathSingleLine()
        print("🧭 ScreenOverlay path → \(singleLine)")

        let alert = UIAlertController(
            title: "Current Screen Path",
            message: path,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = path
        })
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        rootVC.present(alert, animated: true)
    }

    // MARK: - Dragging

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let pill = gesture.view, let window = window else { return }
        let t = gesture.translation(in: window)
        pill.center = CGPoint(x: pill.center.x + t.x, y: pill.center.y + t.y)
        gesture.setTranslation(.zero, in: window)
        if gesture.state == .ended {
            hasPositioned = true
            snapToEdge(pill, in: window)
        }
    }

    private func snapToEdge(_ view: UIView, in window: UIWindow) {
        let bounds = window.bounds
        let margin: CGFloat = 16
        let hw = view.bounds.width  / 2
        let hh = view.bounds.height / 2
        let x = min(max(view.center.x, hw + margin), bounds.width  - hw - margin)
        let y = min(max(view.center.y, hh + margin), bounds.height - hh - margin)
        UIView.animate(withDuration: 0.25, delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.5) {
            view.center = CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Pill View

/// Self-sizing pill label with proper internal padding — no space-character hacks.
private final class OverlayPillView: UIView {

    private let label = UILabel()
    private let hPad: CGFloat = 12
    private let vPad: CGFloat = 6
    /// Caps pill width so very long controller names wrap onto a second line
    /// instead of stretching edge-to-edge or truncating with "...".
    private let maxWidth: CGFloat = 260

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = 12
        layer.masksToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = maxWidth - hPad * 2
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: vPad),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vPad),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hPad),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hPad),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth - hPad * 2)
        ])
    }

    /// Sets the label's text only. Deliberately does NOT force a layout pass
    /// here (no setNeedsLayout/layoutIfNeeded) — if this pill's frame is
    /// still .zero at call time (e.g. right after init, before sizeToFit()
    /// has run), forcing layout now would resolve the label's Auto Layout
    /// constraints against a 0×0 bounds and produce an unsatisfiable-
    /// constraints conflict. Sizing is the caller's responsibility via
    /// sizeToFit(), called only after this pill has a sensible frame context.
    func setText(_ text: String) {
        label.text = text
        invalidateIntrinsicContentSize()
    }

    func applyTheme(dark: Bool) {
        backgroundColor = (dark ? UIColor.white : UIColor(white: 0.1, alpha: 1)).withAlphaComponent(0.88)
        label.textColor  = dark ? .black : .white
        layer.borderColor = (dark
            ? UIColor.black.withAlphaComponent(0.08)
            : UIColor.white.withAlphaComponent(0.15)).cgColor
    }

    override var intrinsicContentSize: CGSize {
        let s = label.sizeThatFits(CGSize(width: maxWidth - hPad * 2, height: .greatestFiniteMagnitude))
        return CGSize(width: min(s.width, maxWidth - hPad * 2) + hPad * 2,
                      height: s.height + vPad * 2)
    }

    override func sizeToFit() {
        let center = self.center
        frame.size = intrinsicContentSize
        // Preserve center across a resize when the view already has a
        // meaningful position (avoids the pill jumping to top-left on resize).
        if center != .zero {
            self.center = center
        }
    }
}

// MARK: - Overlay Root View Controller

/// Marked as OverlayInternalViewController so the swizzle hook never reports
/// this VC as the "current screen" in the label.
private final class OverlayRootViewController: UIViewController, OverlayInternalViewController {

    /// Called once after the first layout pass so safe-area insets are valid.
    var onLayout: (() -> Void)?
    private var didLayout = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Only call once — pill position is user-draggable after first placement.
        guard !didLayout else { return }
        didLayout = true
        onLayout?()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        NotificationCenter.default.post(name: .screenOverlayTraitsChanged, object: nil)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let screenOverlayTraitsChanged = Notification.Name("ScreenOverlayKit.traitsChanged")
}
