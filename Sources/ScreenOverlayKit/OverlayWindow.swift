  //
 //  OverlayWindow.swift
 //  ScreenRadarKit
 //
 //  Created by Sanket Khatri on 05/06/26.
 //

 import UIKit

 @MainActor
 final class OverlayWindow {
     
     // MARK: - Singleton

     static let shared = OverlayWindow()

     // MARK: - Private Properties

     private var window: PassthroughWindow?
     private let label = PaddingLabel(
         contentInsets: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
     )

     /// Tracks the label's center during a pan so we can offset correctly.
     private var dragStartCenter: CGPoint = .zero

     /// UserDefaults key for persisting the label position across launches.
     private let positionKey = "com.screenradar.overlayPosition"

     private init() {}

     // MARK: - Public Methods

     func show(draggable: Bool = false) {
         guard window == nil else { return }

         let overlayWindow: PassthroughWindow

         if #available(iOS 13.0, *) {
             guard let windowScene = UIApplication.shared
                 .connectedScenes
                 .compactMap({ $0 as? UIWindowScene })
                 .first else {
                 print("❌ ScreenRadar: No UIWindowScene found")
                 return
             }
             overlayWindow = PassthroughWindow(windowScene: windowScene)
         } else {
             overlayWindow = PassthroughWindow(frame: UIScreen.main.bounds)
         }

         overlayWindow.frame = UIScreen.main.bounds
         overlayWindow.backgroundColor = .clear
         overlayWindow.windowLevel = .alert + 1000

         let rootVC = UIViewController()
         rootVC.view.backgroundColor = .clear

         configureLabel(draggable: draggable)
         rootVC.view.addSubview(label)

         // Position the label after the view is laid out
         rootVC.view.layoutIfNeeded()
         placeLabel(in: rootVC.view)

         overlayWindow.rootViewController = rootVC
         self.window = overlayWindow
         overlayWindow.isHidden = false
     }

     func update(text: String) {
         label.text = text

         // Re-size to fit new text, keeping the same center position
         let currentCenter = label.center
         resizeLabel(in: label.superview)
         label.center = currentCenter

         // Re-clamp in case the text got longer and would go off-screen
         if let superview = label.superview {
             label.center = clampedCenter(
                 label.center,
                 labelSize: label.frame.size,
                 in: superview
             )
         }
     }

     func hide() {
         window?.isHidden = true
         window = nil
     }

     // MARK: - Setup

     private func configureLabel(draggable: Bool) {
         // Frame-based — Auto Layout removed to support free dragging
         label.translatesAutoresizingMaskIntoConstraints = true
         label.text = "ScreenRadar"
         label.textAlignment = .center
         label.numberOfLines = 2
         label.lineBreakMode = .byTruncatingTail
         label.textColor = UIColor { trait in
             trait.userInterfaceStyle == .light ? .white : .black
         }
         label.backgroundColor = UIColor { trait in
             trait.userInterfaceStyle == .light
                 ? UIColor.black.withAlphaComponent(0.55)
                 : UIColor.white.withAlphaComponent(0.75)
         }
         label.font = .systemFont(ofSize: 13, weight: .semibold)
         label.layer.cornerRadius = 6
         label.clipsToBounds = true
         label.isUserInteractionEnabled = true
         label.frame.size = CGSize(width: 140, height: 30)

         // Tap → print hierarchy
         let tap = UITapGestureRecognizer(
             target: self,
             action: #selector(labelTapped)
         )

         label.addGestureRecognizer(tap)
         
         guard draggable else { return }

         // Pan → drag label
         let pan = UIPanGestureRecognizer(
             target: self,
             action: #selector(labelPanned(_:))
         )

         // Tap requires pan to fail first so single taps aren't eaten
         tap.require(toFail: pan)
         label.addGestureRecognizer(pan)
     }

     /// Places the label at the saved position, or defaults to top-center.
     private func placeLabel(in view: UIView) {
         resizeLabel(in: view)

         if let saved = loadSavedPosition() {
             // Validate the saved point is still on-screen
             // (screen size can change e.g. new device, rotation)
             label.center = clampedCenter(
                 saved,
                 labelSize: label.frame.size,
                 in: view
             )
         } else {
             // Default: top-center, below safe area
             let safeTop = view.safeAreaInsets.top
             label.center = CGPoint(
                 x: view.bounds.midX,
                 y: safeTop + 8 + label.frame.height / 2
             )
         }
     }

     private func resizeLabel(in view: UIView?) {
         let horizontalScreenPadding: CGFloat = 20
         let minimumWidth: CGFloat = 120
         let maxWidth = max(
             minimumWidth,
             (view?.bounds.width ?? UIScreen.main.bounds.width) - horizontalScreenPadding * 2
         )
         let fittingSize = label.sizeThatFits(
             CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
         )
         let maxHeight = ceil(label.font.lineHeight * 2) + label.contentInsets.top + label.contentInsets.bottom

         label.frame.size = CGSize(
             width: min(max(fittingSize.width, minimumWidth), maxWidth),
             height: min(max(fittingSize.height, 30), maxHeight)
         )
     }

     // MARK: - Gesture Handlers

     @objc private func labelTapped() {
         ViewControllerTracker.shared.printHierarchy()
         TrailLogger.shared.printTrail()
         presentTrailBottomSheet()
     }

     private func presentTrailBottomSheet() {
         guard let rootViewController = window?.rootViewController,
               rootViewController.presentedViewController == nil
         else { return }

         let trailBottomSheet = TrailBottomSheet()
         trailBottomSheet.modalPresentationStyle = .overFullScreen
         rootViewController.present(trailBottomSheet, animated: true)
     }

     @objc private func labelPanned(_ gesture: UIPanGestureRecognizer) {
         guard let superview = label.superview else { return }

         switch gesture.state {

         case .began:
             dragStartCenter = label.center
             // Slightly enlarge while dragging for tactile feedback
             UIView.animate(withDuration: 0.15) {
                 self.label.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                 self.label.backgroundColor = UIColor { trait in
                     trait.userInterfaceStyle == .light
                         ? UIColor.black.withAlphaComponent(0.88)
                         : UIColor.white.withAlphaComponent(0.88)
                 }
             }

         case .changed:
             let translation = gesture.translation(in: superview)
             let newCenter = CGPoint(
                 x: dragStartCenter.x + translation.x,
                 y: dragStartCenter.y + translation.y
             )
             label.center = clampedCenter(
                 newCenter,
                 labelSize: label.frame.size,
                 in: superview
             )

         case .ended, .cancelled:
             // Snap to nearest edge (left or right) for a clean look
             let snappedCenter = snappedToEdge(
                 label.center,
                 labelSize: label.frame.size,
                 in: superview
             )

             UIView.animate(
                 withDuration: 0.35,
                 delay: 0,
                 usingSpringWithDamping: 0.7,
                 initialSpringVelocity: 0.5
             ) {
                 self.label.center = snappedCenter
                 self.label.transform = .identity
                 self.label.backgroundColor = UIColor { trait in
                     trait.userInterfaceStyle == .light
                         ? UIColor.black.withAlphaComponent(0.55)
                         : UIColor.white.withAlphaComponent(0.75)
                 }
             }

             savePosition(snappedCenter)

         default:
             break
         }
     }

     // MARK: - Position Helpers

     /// Keeps the label fully within the safe area of the superview.
     private func clampedCenter(
         _ center: CGPoint,
         labelSize: CGSize,
         in view: UIView
     ) -> CGPoint {
         let insets = view.safeAreaInsets
         let halfW = labelSize.width / 2
         let halfH = labelSize.height / 2
         let padding: CGFloat = 20

         let minX = halfW + padding
         let maxX = view.bounds.width - halfW - padding
         let minY = insets.top + halfH + padding
         let maxY = view.bounds.height - insets.bottom - halfH - padding

         return CGPoint(
             x: min(max(center.x, minX), maxX),
             y: min(max(center.y, minY), maxY)
         )
     }

     /// After the user lifts their finger, snaps the label to the nearest
     /// Top center, bottom center, left or right edge, keeping the vertical position where it was dropped.
     private func snappedToEdge(
         _ center: CGPoint,
         labelSize: CGSize,
         in view: UIView
     ) -> CGPoint {
         let halfW = labelSize.width / 2
         let halfH = labelSize.height / 2
         let padding: CGFloat = 16
         let insets = view.safeAreaInsets

         let distLeft   = center.x
         let distRight  = view.bounds.width - center.x
         let distTop    = center.y
         let distBottom = view.bounds.height - center.y

         let minDist = min(distLeft, distRight, distTop, distBottom)

         switch minDist {
         case distTop:
             return CGPoint(
                 x: view.bounds.midX,
                 y: insets.top + halfH + padding
             )
         case distBottom:
             return CGPoint(
                 x: view.bounds.midX,
                 y: view.bounds.height - insets.bottom - halfH - padding
             )
         case distLeft:
             return CGPoint(
                 x: halfW + padding,
                 y: min(max(center.y, insets.top + halfH + padding), view.bounds.height - insets.bottom - halfH - padding)
             )
         default: // distRight
             return CGPoint(
                 x: view.bounds.width - halfW - padding,
                 y: min(max(center.y, insets.top + halfH + padding), view.bounds.height - insets.bottom - halfH - padding)
             )
         }
     }
     
     // MARK: - Persistence

     private func savePosition(_ center: CGPoint) {
         let dict: [String: CGFloat] = ["x": center.x, "y": center.y]
         UserDefaults.standard.set(dict, forKey: positionKey)
     }

     private func loadSavedPosition() -> CGPoint? {
         guard let dict = UserDefaults.standard.dictionary(forKey: positionKey),
               let x = dict["x"] as? CGFloat,
               let y = dict["y"] as? CGFloat
         else { return nil }
         return CGPoint(x: x, y: y)
     }
 }

 private final class PaddingLabel: UILabel {
     let contentInsets: UIEdgeInsets

     init(contentInsets: UIEdgeInsets) {
         self.contentInsets = contentInsets
         super.init(frame: .zero)
     }

     required init?(coder: NSCoder) {
         self.contentInsets = .zero
         super.init(coder: coder)
     }

     override func drawText(in rect: CGRect) {
         super.drawText(in: rect.inset(by: contentInsets))
     }

     override func textRect(
         forBounds bounds: CGRect,
         limitedToNumberOfLines numberOfLines: Int
     ) -> CGRect {
         let insetBounds = bounds.inset(by: contentInsets)
         let textRect = super.textRect(
             forBounds: insetBounds,
             limitedToNumberOfLines: numberOfLines
         )

         return textRect.inset(
             by: UIEdgeInsets(
                 top: -contentInsets.top,
                 left: -contentInsets.left,
                 bottom: -contentInsets.bottom,
                 right: -contentInsets.right
             )
         )
     }

     override func sizeThatFits(_ size: CGSize) -> CGSize {
         let insetSize = CGSize(
             width: max(0, size.width - contentInsets.left - contentInsets.right),
             height: max(0, size.height - contentInsets.top - contentInsets.bottom)
         )
         let fittingSize = super.sizeThatFits(insetSize)

         return CGSize(
             width: fittingSize.width + contentInsets.left + contentInsets.right,
             height: fittingSize.height + contentInsets.top + contentInsets.bottom
         )
     }
 }
