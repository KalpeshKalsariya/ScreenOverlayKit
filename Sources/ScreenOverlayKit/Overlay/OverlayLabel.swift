//
//  OverlayLabel.swift
//  ScreenOverlayKit
//

import UIKit

/// The floating pill label `OverlayManager` displays the current screen name in.
///
/// Owns its own light/dark-mode-aware pill styling and draws its text inset by
/// `contentInsets`, so callers can just set `text` and call `updateSize(forMaxWidth:)`.
final class OverlayLabel: UILabel {

    // MARK: - Appearance Constants

    /// The pill's background color while at rest (not being dragged), adapting to light/dark mode.
    static let restingBackgroundColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor.black.withAlphaComponent(0.55)
            : UIColor.white.withAlphaComponent(0.75)
    }

    /// The pill's background color while being actively dragged, adapting to light/dark mode.
    static let draggingBackgroundColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor.black.withAlphaComponent(0.88)
            : UIColor.white.withAlphaComponent(0.88)
    }

    /// The minimum width the pill is allowed to shrink to.
    static let minimumWidth: CGFloat = 120

    // MARK: - Private Properties

    private let contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

    // MARK: - Init

    /// Creates the pill label and applies its default appearance.
    init() {
        super.init(frame: .zero)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }

    // MARK: - Appearance

    /// Applies the pill's default text/background styling and starting size.
    private func configureAppearance() {
        // Frame-based — Auto Layout removed to support free dragging
        translatesAutoresizingMaskIntoConstraints = true
        textAlignment = .center
        numberOfLines = 2
        lineBreakMode = .byTruncatingTail
        textColor = UIColor { trait in
            trait.userInterfaceStyle == .light ? .white : .black
        }
        backgroundColor = Self.restingBackgroundColor
        font = .systemFont(ofSize: 13, weight: .semibold)
        layer.cornerRadius = 6
        clipsToBounds = true
        isUserInteractionEnabled = true
        frame.size = CGSize(width: 140, height: 30)
    }

    // MARK: - Sizing

    /// Resizes the label to fit its current text, clamped between `minimumWidth` and `maxWidth`.
    ///
    /// - Parameter maxWidth: The maximum width available (typically the screen width minus padding).
    func updateSize(forMaxWidth maxWidth: CGFloat) {
        let clampedMaxWidth = max(Self.minimumWidth, maxWidth)
        let fittingSize = sizeThatFits(
            CGSize(width: clampedMaxWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        let maxHeight = ceil(font.lineHeight * 2) + contentInsets.top + contentInsets.bottom

        frame.size = CGSize(
            width: min(max(fittingSize.width, Self.minimumWidth), clampedMaxWidth),
            height: min(max(fittingSize.height, 30), maxHeight)
        )
    }

    // MARK: - Padding Overrides

    /// Draws the text inset by `contentInsets` instead of filling the full bounds.
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    /// Computes the text rect within the inset bounds, then expands it back
    /// out so the label reserves space for the padding.
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

    /// Computes the size that fits the text plus `contentInsets`.
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
