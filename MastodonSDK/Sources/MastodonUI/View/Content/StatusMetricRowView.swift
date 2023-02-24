// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonAsset

public final class StatusMetricRowView: UIButton {
    let icon: UIImageView
    let textLabel: UILabel
    let detailLabel: UILabel
    let chevron: UIImageView

    private var disposableConstraints: [NSLayoutConstraint] = []
    private var isVerticalAxis: Bool?

    public init(iconImage: UIImage? = nil, text: String? = nil, detailText: String? = nil) {

        icon = UIImageView(image: iconImage?.withRenderingMode(.alwaysTemplate))
        icon.tintColor = Asset.Colors.Label.secondary.color
        icon.translatesAutoresizingMaskIntoConstraints = false

        textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17, weight: .regular))
        textLabel.textColor = Asset.Colors.Label.primary.color
        textLabel.numberOfLines = 0
        textLabel.text = text

        detailLabel = UILabel()
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.text = detailText
        detailLabel.textColor = Asset.Colors.Label.secondary.color
        detailLabel.numberOfLines = 0
        detailLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17, weight: .regular))

        chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = Asset.Colors.Label.tertiary.color

        super.init(frame: .zero)

        addSubview(icon)
        addSubview(textLabel)
        addSubview(detailLabel)
        addSubview(chevron)

        accessibilityTraits.insert(.button)

        setupConstraints()
        traitCollectionDidChange(nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let isVerticalAxis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory

        if isVerticalAxis {
            detailLabel.textAlignment = .natural
        } else {
            switch traitCollection.layoutDirection {
            case .leftToRight, .unspecified: detailLabel.textAlignment = .right
            case .rightToLeft: detailLabel.textAlignment = .left
            @unknown default:
                break
            }
        }

        guard isVerticalAxis != self.isVerticalAxis else { return }
        self.isVerticalAxis = isVerticalAxis
        NSLayoutConstraint.deactivate(disposableConstraints)

        if isVerticalAxis {
            disposableConstraints = [
                textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 11),

                detailLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
                detailLabel.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 8),
                bottomAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 11),

                chevron.leadingAnchor.constraint(greaterThanOrEqualTo: textLabel.trailingAnchor, constant: 12),
                chevron.leadingAnchor.constraint(greaterThanOrEqualTo: detailLabel.trailingAnchor, constant: 12),
            ]
        } else {
            disposableConstraints = [
                textLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 11),
                textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                bottomAnchor.constraint(greaterThanOrEqualTo: textLabel.bottomAnchor, constant: 11),

                detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textLabel.trailingAnchor, constant: 8),

                detailLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 11),
                detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                bottomAnchor.constraint(greaterThanOrEqualTo: detailLabel.bottomAnchor, constant: 11),

                chevron.leadingAnchor.constraint(equalTo: detailLabel.trailingAnchor, constant: 12),
            ]
        }
        NSLayoutConstraint.activate(disposableConstraints)
    }

    var margin: CGFloat = 0 {
        didSet {
            layoutMargins = UIEdgeInsets(horizontal: margin, vertical: 0)
        }
    }

    private func setupConstraints() {
        icon.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        chevron.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        let constraints = [
            icon.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10),
            icon.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            textLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
            icon.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
            icon.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            bottomAnchor.constraint(greaterThanOrEqualTo: icon.bottomAnchor, constant: 10),

            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            layoutMarginsGuide.trailingAnchor.constraint(equalTo: chevron.trailingAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    public override var isHighlighted: Bool {
        get { super.isHighlighted }
        set {
            super.isHighlighted = newValue
            if newValue {
                backgroundColor = Asset.Colors.selectionHighlight.color
            } else {
                backgroundColor = .clear
            }
        }
    }

    public override var accessibilityLabel: String? {
        get { textLabel.text }
        set {}
    }

    public override var accessibilityValue: String? {
        get { detailLabel.text }
        set {}
    }
}
