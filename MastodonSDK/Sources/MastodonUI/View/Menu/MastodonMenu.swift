//
//  MastodonMenu.swift
//  
//
//  Created by MainasuK on 2022-1-26.
//

import UIKit
import MastodonLocalization

public protocol MastodonMenuDelegate: AnyObject {
    func menuAction(_ action: MastodonMenu.Action)
}

public enum MastodonMenu {
    public static func setupMenu(
        //TODO: Use dedicated struct instead of tuple
        items: [(actions: [Action], options: UIMenu.Options, preferredElementSize: UIMenu.ElementSize)],
        delegate: MastodonMenuDelegate
    ) -> UIMenu {
        var children: [UIMenuElement] = []

        for (actionGroup, options, preferredElementSize) in items {
            var submenuChildren: [UIMenuElement] = []
            for action in actionGroup {
                let element = action.build(delegate: delegate).menuElement
                submenuChildren.append(element)
            }
            let submenu = UIMenu(options: options, children: submenuChildren)
            submenu.preferredElementSize = preferredElementSize
            children.append(submenu)
        }
        
        return UIMenu(children: children)
    }

    public static func setupAccessibilityActions(
        actions: [[Action]],
        delegate: MastodonMenuDelegate
    ) -> [UIAccessibilityCustomAction] {
        var accessibilityActions: [UIAccessibilityCustomAction] = []
        for action in actions.flatMap({ $0 }) {
            let element = action.build(delegate: delegate)
            accessibilityActions.append(element.accessibilityCustomAction)
        }
        return accessibilityActions
    }
}

extension MastodonMenu {
    public enum Action {
        case translateStatus(TranslateStatusActionContext)
        case showOriginal
        case muteUser(MuteUserActionContext)
        case blockUser(BlockUserActionContext)
        case reportUser(ReportUserActionContext)
        case shareUser(ShareUserActionContext)
        case bookmarkStatus(BookmarkStatusActionContext)
        case hideReblogs(HideReblogsActionContext)
        case shareStatus
        case deleteStatus
        case editStatus
        case followUser(FollowUserActionContext)
        case blockDomain(BlockDomainActionContext)
        case boostStatus(BoostStatusActionContext)
        case favoriteStatus(FavoriteStatusActionContext)
        case copyLink
        case openInBrowser

        func build(delegate: MastodonMenuDelegate) -> LabeledAction {
            switch self {
            case .hideReblogs(let context):
                let title = context.showReblogs ? L10n.Common.Controls.Friendship.hideReblogs : L10n.Common.Controls.Friendship.showReblogs
                let reblogAction = LabeledAction(title: title, image: UIImage(systemName: "arrow.2.squarepath")) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }

                return reblogAction
            case .muteUser(let context):
                let title: String
                let image: UIImage?
                if context.isMuting {
                    title = L10n.Common.Controls.Friendship.unmuteUser(context.name)
                    image = UIImage(systemName: "speaker.wave.2")
                } else {
                    title = L10n.Common.Controls.Friendship.muteUser(context.name)
                    image = UIImage(systemName: "speaker.slash")
                }
                let muteAction = LabeledAction(title: title, image: image) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return muteAction
            case .blockUser(let context):
                let title: String
                let image: UIImage?
                if context.isBlocking {
                    title = L10n.Common.Controls.Friendship.unblockUser(context.name)
                    image = UIImage(systemName: "hand.raised.slash")
                } else {
                    title = L10n.Common.Controls.Friendship.blockUser(context.name)
                    image = UIImage(systemName: "hand.raised")
                }
                let blockAction = LabeledAction(title: title, image: image) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return blockAction
            case .reportUser(let context):
                let reportAction = LabeledAction(
                    title: L10n.Common.Controls.Actions.reportUser(context.name),
                    image: UIImage(systemName: "flag")
                ) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return reportAction
            case .shareUser(let context):
                let shareAction = LabeledAction(
                    title: L10n.Common.Controls.Actions.shareUser(context.name),
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return shareAction
            case .bookmarkStatus(let context):
                let title: String
                let image: UIImage?
                if context.isBookmarked {
                    title = L10n.Common.Controls.Actions.removeBookmark
                    image = UIImage(systemName: "bookmark.slash.fill")
                } else {
                    title = L10n.Common.Controls.Actions.bookmark
                    image = UIImage(systemName: "bookmark")
                }
                let action = LabeledAction(title: title, image: image) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return action
            case .shareStatus:
                let action = LabeledAction(
                    title: L10n.Common.Controls.Actions.sharePost,
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return action
            case .deleteStatus:
                let deleteAction = LabeledAction(
                    title: L10n.Common.Controls.Actions.delete,
                    image: UIImage(systemName: "minus.circle"),
                    attributes: .destructive
                ) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return deleteAction
            case let .translateStatus(context):
                let language = Locale.current.localizedString(forIdentifier: context.language) ?? L10n.Common.Controls.Actions.TranslatePost.unknownLanguage
                let translateAction = LabeledAction(
                    title: L10n.Common.Controls.Actions.TranslatePost.title(language),
                    image: UIImage(systemName: "character.book.closed")
                ) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }
                return translateAction
            case .showOriginal:
                let action = LabeledAction(
                    title: L10n.Common.Controls.Status.Translation.showOriginal,
                    image: UIImage(systemName: "character.book.closed")
                ) { [weak delegate] in
                    guard let delegate = delegate else { return }
                    delegate.menuAction(self)
                }

                return action
            case .editStatus:
                let editStatusAction = LabeledAction(
                    title: L10n.Common.Controls.Actions.editPost,
                    image: UIImage(systemName: "pencil")
                ) {
                    [weak delegate] in
                    guard let delegate else { return }
                    delegate.menuAction(self)
                }

                return editStatusAction
            case .followUser(let context):
                let title: String
                let image: UIImage?
                if context.isFollowing {
                    title = L10n.Common.Controls.Actions.unfollow(context.name)
                    image = UIImage(systemName: "person.fill.badge.minus")
                } else {
                    title = L10n.Common.Controls.Actions.follow(context.name)
                    image = UIImage(systemName: "person.fill.badge.plus")
                }
                let action = LabeledAction(title: title, image: image) { [weak delegate] in
                    guard let delegate else { return }
                    delegate.menuAction(self)
                }
                return action
            case .blockDomain(let context):
                    let title: String
                    let image: UIImage?
                    if context.isBlocking {
                        title = L10n.Common.Controls.Actions.unblockDomain(context.domain)
                        image = UIImage(systemName: "hand.raised.slash.fill")
                    } else {
                        title = L10n.Common.Controls.Actions.blockDomain(context.domain)
                        image = UIImage(systemName: "hand.raised.fill")
                    }
                    let action = LabeledAction(title: title, image: image) { [weak delegate] in
                        guard let delegate else { return }

                        delegate.menuAction(self)
                    }
                    return action

            case .boostStatus(let context):
                let title: String

                if context.isBoosted {
                    title = "Unboost"
                } else {
                    title = "Boost"
                }

                return LabeledAction(title: title, image: UIImage(systemName: "arrow.2.squarepath")) { [weak delegate] in
                    delegate?.menuAction(self)
                }
            case .favoriteStatus(let context):
                let title: String
                let image: UIImage?

                if context.isFavorited {
                    title = "Unfavorite"
                    image = UIImage(systemName: "star.slash")
                } else {
                    title = "Favorite"
                    image = UIImage(systemName: "star")
                }

                return LabeledAction(title: title, image: image) { [weak delegate] in
                    delegate?.menuAction(self)
                }

            case .copyLink:
                return LabeledAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { [weak delegate] in
                    delegate?.menuAction(self)
                }

            case .openInBrowser:
                return LabeledAction(title: "Open In Browser", image: UIImage(systemName: "safari")) { [weak delegate] in
                    delegate?.menuAction(self)
                }
            }
        }
    }
}

extension MastodonMenu {
    public struct MuteUserActionContext {
        public let name: String
        public let isMuting: Bool
        
        public init(name: String, isMuting: Bool) {
            self.name = name
            self.isMuting = isMuting
        }
    }
    
    public struct BlockUserActionContext {
        public let name: String
        public let isBlocking: Bool
        
        public init(name: String, isBlocking: Bool) {
            self.name = name
            self.isBlocking = isBlocking
        }
    }
    
    public struct BookmarkStatusActionContext {
        public let isBookmarked: Bool
        
        public init(isBookmarked: Bool) {
            self.isBookmarked = isBookmarked
        }
    }
    
    public struct ReportUserActionContext {
        public let name: String
        
        public init(name: String) {
            self.name = name
        }
    }
    
    public struct ShareUserActionContext {
        public let name: String
        
        public init(name: String) {
            self.name = name
        }
    }

    public struct HideReblogsActionContext {
        public let showReblogs: Bool

        public init(showReblogs: Bool) {
            self.showReblogs = showReblogs
        }
    }
    
    public struct TranslateStatusActionContext {
        public let language: String
        
        public init(language: String) {
            self.language = language
        }
    }

    public struct FollowUserActionContext {

        public let name: String
        public let isFollowing: Bool

        init(name: String, isFollowing: Bool) {
            self.name = name
            self.isFollowing = isFollowing
        }
    }

    public struct BlockDomainActionContext {
        public let domain: String
        public let isBlocking: Bool

        public init(domain: String, isBlocking: Bool) {
            self.domain = domain
            self.isBlocking = isBlocking
        }
    }

    public struct BoostStatusActionContext {
        public let isBoosted: Bool

        public init(isBoosted: Bool) {
            self.isBoosted = isBoosted
        }
    }

    public struct FavoriteStatusActionContext {
        public let isFavorited: Bool

        public init(isFavorited: Bool) {
            self.isFavorited = isFavorited
        }
    }

}
