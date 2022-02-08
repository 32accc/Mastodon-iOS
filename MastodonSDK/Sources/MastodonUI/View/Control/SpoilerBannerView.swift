//
//  SpoilerBannerView.swift
//  
//
//  Created by MainasuK on 2022-2-8.
//

import UIKit
import MastodonAsset
import MetaTextKit

public final class SpoilerBannerView: UIView {
    
    static let cornerRadius: CGFloat = 8
    static let containerMargin: CGFloat = 14
    
    public let containerView = UIView()
    
    public let label = MetaLabel(style: .statusSpoilerBanner)
    
    public let hideLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.Colors.Label.primary.color
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .regular))
        label.numberOfLines = 0
        label.text = "Hide"     // TODO: i18n
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _init()
    }
    
}

extension SpoilerBannerView {
    
    private func _init() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        containerView.backgroundColor = .secondarySystemBackground
        
        containerView.layoutMargins = UIEdgeInsets(
            top: StatusVisibilityView.containerMargin,
            left: StatusVisibilityView.containerMargin,
            bottom: StatusVisibilityView.containerMargin,
            right: StatusVisibilityView.containerMargin
        )
        
        let labelContainer = UIStackView()
        labelContainer.axis = .horizontal
        labelContainer.spacing = 16
        labelContainer.alignment = .center
        
        labelContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(labelContainer)
        NSLayoutConstraint.activate([
            labelContainer.topAnchor.constraint(equalTo: containerView.layoutMarginsGuide.topAnchor),
            labelContainer.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor),
            labelContainer.trailingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.trailingAnchor),
            labelContainer.bottomAnchor.constraint(equalTo: containerView.layoutMarginsGuide.bottomAnchor),
        ])
        
        labelContainer.addArrangedSubview(label)
        labelContainer.addArrangedSubview(hideLabel)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hideLabel.setContentHuggingPriority(.required - 1, for: .horizontal)
        hideLabel.setContentCompressionResistancePriority(.required - 1, for: .horizontal)
        
        label.isUserInteractionEnabled = false
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        containerView.layer.masksToBounds = false
        containerView.layer.cornerCurve = .continuous
        containerView.layer.cornerRadius = StatusVisibilityView.cornerRadius
    }
    
}
