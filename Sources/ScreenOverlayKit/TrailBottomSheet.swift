//
//  TrailBottomSheet.swift
//  ScreenRadarKit
//
//  Created by Sanket Khatri on 01/07/26.
//

import UIKit

@MainActor
final class TrailBottomSheet: UIViewController {

    // MARK: - Private Properties

    private let dimmingView = UIView()
    private let sheetView = UIView()
    private let stackView = UIStackView()
    private let scrollView = UIScrollView()
    private weak var exportButton: UIButton?
    private weak var clearCurrentButton: UIButton?
    private weak var clearPreviousButton: UIButton?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        configureViews()
        reloadTrail()
    }

    // MARK: - Setup

    private func configureViews() {
        view.backgroundColor = .clear

        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.36)
        view.addSubview(dimmingView)

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        dimmingView.addGestureRecognizer(dismissTap)

        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .light ? .systemBackground : .secondarySystemBackground
        }
        sheetView.layer.cornerRadius = 18
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.clipsToBounds = true
        view.addSubview(sheetView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Screen Trail"
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.accessibilityLabel = "Close"
        closeButton.contentHorizontalAlignment = .trailing
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let exportButton = UIButton(type: .system)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        exportButton.tintColor = .systemBlue
        exportButton.accessibilityLabel = "Export"
        exportButton.contentHorizontalAlignment = .leading
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        self.exportButton = exportButton

        let header = UIStackView(arrangedSubviews: [exportButton, titleLabel, closeButton])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .fill

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10

        scrollView.addSubview(stackView)

        let clearButton = UIButton(type: .system)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setTitle("Clear Current Trail", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        clearButton.setTitleColor(.systemRed, for: .normal)
        clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
        clearButton.layer.cornerRadius = 8
        clearButton.clipsToBounds = true
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearCurrentButton = clearButton

        let clearPreviousButton = UIButton(type: .system)
        clearPreviousButton.translatesAutoresizingMaskIntoConstraints = false
        clearPreviousButton.setTitle("Clear Previous Trail", for: .normal)
        clearPreviousButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        clearPreviousButton.setTitleColor(.systemBlue, for: .normal)
        clearPreviousButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        clearPreviousButton.layer.cornerRadius = 8
        clearPreviousButton.clipsToBounds = true
        clearPreviousButton.addTarget(self, action: #selector(clearPreviousTapped), for: .touchUpInside)
        self.clearPreviousButton = clearPreviousButton

        let clearActions = UIStackView(arrangedSubviews: [clearButton, clearPreviousButton])
        clearActions.translatesAutoresizingMaskIntoConstraints = false
        clearActions.axis = .horizontal
        clearActions.alignment = .fill
        clearActions.distribution = .fillEqually
        clearActions.spacing = 10

        let screenshotLabel = UILabel()
        screenshotLabel.translatesAutoresizingMaskIntoConstraints = false
        screenshotLabel.text = "Export before clearing if this trail may help debug a crash or broken flow."
        screenshotLabel.font = .systemFont(ofSize: 12, weight: .regular)
        screenshotLabel.textColor = .secondaryLabel
        screenshotLabel.numberOfLines = 0

        sheetView.addSubview(header)
        sheetView.addSubview(scrollView)
        sheetView.addSubview(clearActions)
        sheetView.addSubview(screenshotLabel)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.72),

            header.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            header.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: 18),

            exportButton.widthAnchor.constraint(equalToConstant: 44),
            exportButton.heightAnchor.constraint(equalToConstant: 36),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            scrollView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            clearActions.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            clearActions.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            clearActions.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 14),
            clearActions.heightAnchor.constraint(equalToConstant: 44),

            screenshotLabel.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 20),
            screenshotLabel.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -20),
            screenshotLabel.topAnchor.constraint(equalTo: clearActions.bottomAnchor, constant: 10),
            screenshotLabel.bottomAnchor.constraint(equalTo: sheetView.safeAreaLayoutGuide.bottomAnchor, constant: -14)
        ])
    }

    private func reloadTrail() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        addSection(
            title: "Current Session",
            entries: TrailLogger.shared.currentTrail,
            emptyText: "No current trail yet.",
            showsCurrentIndicator: true
        )
        addSection(
            title: "Previous Session",
            entries: TrailLogger.shared.previousTrail,
            emptyText: "No previous trail yet. Relaunch the app to save one.",
            showsCurrentIndicator: false
        )

        updateClearActions()
    }

    private func updateClearActions() {
        let hasPreviousTrail = !TrailLogger.shared.previousTrail.isEmpty
        clearPreviousButton?.isHidden = !hasPreviousTrail

        if hasPreviousTrail {
            clearCurrentButton?.setTitle("Clear Current Trail", for: .normal)
        } else {
            clearCurrentButton?.setTitle("Clear Trail", for: .normal)
        }
    }

    private func addSection(
        title: String,
        entries: [TrailEntry],
        emptyText: String,
        showsCurrentIndicator: Bool
    ) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(titleLabel)

        guard !entries.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = emptyText
            emptyLabel.font = .systemFont(ofSize: 14)
            emptyLabel.textColor = .tertiaryLabel
            emptyLabel.numberOfLines = 0
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        for (index, entry) in entries.enumerated().reversed() {
            stackView.addArrangedSubview(
                row(
                    index: index,
                    entry: entry,
                    isCurrent: showsCurrentIndicator && index == entries.count - 1
                )
            )
        }
    }

    private func row(index: Int, entry: TrailEntry, isCurrent: Bool) -> UIView {
        let numberLabel = UILabel()
        numberLabel.text = String(format: "%02d.", index + 1)
        numberLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: isCurrent ? .bold : .regular)
        numberLabel.textColor = isCurrent ? .label : .secondaryLabel
        numberLabel.setContentHuggingPriority(.required, for: .horizontal)

        let nameLabel = UILabel()
        nameLabel.text = entry.screenName
        nameLabel.font = .systemFont(ofSize: 15, weight: isCurrent ? .bold : .regular)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = detailText(for: entry, isCurrent: isCurrent)
        detailLabel.font = .systemFont(ofSize: 13, weight: isCurrent ? .bold : .regular)
        detailLabel.textColor = isCurrent ? .systemBlue : .secondaryLabel
        detailLabel.setContentHuggingPriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [numberLabel, nameLabel, detailLabel])
        rowStack.axis = .horizontal
        rowStack.alignment = .firstBaseline
        rowStack.spacing = 8
        return rowStack
    }

    private func detailText(for entry: TrailEntry, isCurrent: Bool) -> String {
        if isCurrent {
            return "← current"
        }

        guard TrailLogger.shared.showTimeOnTrail, let duration = entry.duration else {
            return TrailLogger.shared.showTimeOnTrail && !isCurrent ? "<1s" : ""
        }

        guard duration >= 1 else { return "<1s" }

        let seconds = Int(duration.rounded())
        if seconds < 60 {
            return "\(seconds)s"
        }

        return "\(seconds / 60)m \(seconds % 60)s"
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func clearTapped() {
        TrailLogger.shared.clearTrailRestartingFromCurrentScreen()
        reloadTrail()
    }

    @objc private func clearPreviousTapped() {
        TrailLogger.shared.clearPreviousTrail()
        reloadTrail()
    }

    @objc private func exportTapped() {
        let actionSheet = UIAlertController(
            title: "Export Trail",
            message: nil,
            preferredStyle: .actionSheet
        )

        actionSheet.addAction(
            UIAlertAction(title: "Export Current Session", style: .default) { [weak self] _ in
                self?.share(fileURL: TrailLogger.shared.exportCurrentSessionFileURL())
            }
        )

        let previousAction = UIAlertAction(title: "Export Previous Session", style: .default) { [weak self] _ in
            self?.share(fileURL: TrailLogger.shared.exportPreviousSessionFileURL())
        }
        previousAction.isEnabled = !TrailLogger.shared.previousTrail.isEmpty
        actionSheet.addAction(previousAction)

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        actionSheet.popoverPresentationController?.sourceView = exportButton
        actionSheet.popoverPresentationController?.sourceRect = exportButton?.bounds ?? .zero
        actionSheet.popoverPresentationController?.permittedArrowDirections = [.up, .down]

        present(actionSheet, animated: true)
    }

    private func share(fileURL: URL?) {
        guard let fileURL else { return }

        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.sourceView = view
        activityViewController.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.maxY - 44,
            width: 1,
            height: 1
        )

        present(activityViewController, animated: true)
    }
}
