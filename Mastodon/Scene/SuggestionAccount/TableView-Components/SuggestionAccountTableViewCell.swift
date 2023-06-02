//
//  SuggestionAccountTableViewCell.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/21.
//

import Combine
import CoreData
import CoreDataStack
import Foundation
import MastodonSDK
import UIKit
import MetaTextKit
import MastodonMeta
import MastodonAsset
import MastodonLocalization
import MastodonUI
import MastodonCore

protocol SuggestionAccountTableViewCellDelegate: AnyObject, UserViewDelegate {}

final class SuggestionAccountTableViewCell: UITableViewCell {

    static let reuseIdentifier = "SuggestionAccountTableViewCell"

    var disposeBag = Set<AnyCancellable>()
    weak var delegate: SuggestionAccountTableViewCellDelegate?
    
    let userView: UserView
    let bioMetaLabel: MetaLabel
    private let contentStackView: UIStackView

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        userView = UserView()
        userView.translatesAutoresizingMaskIntoConstraints = false

        bioMetaLabel = MetaLabel()
        bioMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        bioMetaLabel.numberOfLines = 0
        bioMetaLabel.textAttributes = [
            .font: UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 15, weight: .regular)),
            .foregroundColor: UIColor.label
        ]
        bioMetaLabel.linkAttributes = [
            .font: UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold)),
            .foregroundColor: Asset.Colors.Brand.blurple.color
        ]
        bioMetaLabel.isUserInteractionEnabled = false

        contentStackView = UIStackView(arrangedSubviews: [userView, bioMetaLabel])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.alignment = .leading
        contentStackView.axis = .vertical

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(contentStackView)

        backgroundColor = .systemBackground

        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("We don't support ancient technology like Storyboards") }

    private func setupConstraints() {
        let constraints = [
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: 16),

            userView.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
            bioMetaLabel.widthAnchor.constraint(equalTo: contentStackView.widthAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        disposeBag.removeAll()
    }

    func configure(viewModel: SuggestionAccountTableViewCell.ViewModel) {
        userView.configure(user: viewModel.user, delegate: delegate)

        if viewModel.blockedUsers.contains(viewModel.user.id) {
            self.userView.setButtonState(.blocked)
        } else if viewModel.followedUsers.contains(viewModel.user.id) {
            self.userView.setButtonState(.unfollow)
        } else if viewModel.followRequestedUsers.contains(viewModel.user.id) {
            self.userView.setButtonState(.pending)
        } else if viewModel.user.locked {
            self.userView.setButtonState(.request)
        } else {
            self.userView.setButtonState(.follow)
        }

        let metaContent: MetaContent = {
            do {
                let mastodonContent = MastodonContent(content: viewModel.user.note ?? "", emojis: viewModel.user.emojis.asDictionary)
                return try MastodonMetaContent.convert(document: mastodonContent)
            } catch {
                assertionFailure()
                return PlaintextMetaContent(string: viewModel.user.note ?? "")
            }
        }()

        bioMetaLabel.configure(content: metaContent)
    }
}
