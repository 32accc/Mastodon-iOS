// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonSDK
import MastodonLocalization
import CoreDataStack

enum SearchResultOverviewSection: Hashable {
    case `default`
    case suggestions
}

enum SearchResultOverviewItem: Hashable {
    case `default`(DefaultSectionEntry)
    case suggestion(SuggestionSectionEntry)
    
    enum DefaultSectionEntry: Hashable {
        case posts(String)
        case people(String)
        case profile(String, String)
        case openLink(String)

        var title: String {
            switch self {
                case .posts(let text):
                    return L10n.Scene.Search.Searching.posts(text)
                case .people(let username):
                    return L10n.Scene.Search.Searching.people(username)
                case .profile(let username, let instanceName):
                    return L10n.Scene.Search.Searching.profile(username, instanceName)
                case .openLink(_):
                    return L10n.Scene.Search.Searching.url
            }
        }

        var icon: UIImage? {
            switch self {
                case .posts(_):
                    return UIImage(systemName: "number")
                case .people(_):
                    return UIImage(systemName: "person.2")
                case .profile(_, _):
                    return UIImage(systemName: "person.crop.circle")
                case .openLink(_):
                    return UIImage(systemName: "link")
            }
        }
    }

    enum SuggestionSectionEntry: Hashable {
        case hashtag(tag: Mastodon.Entity.Tag)
        case profile(user: Mastodon.Entity.Account)

        var title: String? {
            if case let .hashtag(tag) = self {
                return tag.name
            } else {
                return nil
            }
        }

        var icon: UIImage? {
            if case .hashtag(_) = self {
                return UIImage(systemName: "number")
            } else {
                return nil
            }
        }
    }
}
