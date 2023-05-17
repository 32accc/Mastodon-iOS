//
//  UserView+Configuration.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-19.
//

import UIKit
import Combine
import MastodonUI
import CoreDataStack
import MastodonLocalization
import MastodonMeta
import MastodonCore
import Meta

extension UserView {
    public func configure(user: MastodonUser, delegate: UserViewDelegate?) {
        self.delegate = delegate
        viewModel.user = user

        Publishers.CombineLatest(
            user.publisher(for: \.avatar),
            UserDefaults.shared.publisher(for: \.preferredStaticAvatar)
        )
        .map { _ in user.avatarImageURL() }
        .assign(to: \.authorAvatarImageURL, on: viewModel)
        .store(in: &disposeBag)
        
        // author name
        Publishers.CombineLatest(
            user.publisher(for: \.displayName),
            user.publisher(for: \.emojis)
        )
        .map { _, emojis in
            do {
                let content = MastodonContent(content: user.displayNameWithFallback, emojis: emojis.asDictionary)
                let metaContent = try MastodonMetaContent.convert(document: content)
                return metaContent
            } catch {
                assertionFailure(error.localizedDescription)
                return PlaintextMetaContent(string: user.displayNameWithFallback)
            }
        }
        .assign(to: \.authorName, on: viewModel)
        .store(in: &disposeBag)
        // author username
        user.publisher(for: \.acct)
            .map { $0 as String? }
            .assign(to: \.authorUsername, on: viewModel)
            .store(in: &disposeBag)
        
        user.publisher(for: \.followersCount)
            .map { Int($0) }
            .assign(to: \.authorFollowers, on: viewModel)
            .store(in: &disposeBag)
        
        user.publisher(for: \.fields)
            .map { fields in
                let firstVerified = fields.first(where: { $0.verifiedAt != nil })
                return firstVerified?.value
            }
            .assign(to: \.authorVerifiedLink, on: viewModel)
            .store(in: &disposeBag)
    }
}
