//
//  Mastodon+Entity+Preferences.swift
//  
//
//  Created by MainasuK Cirno on 2021/1/29.
//

import Foundation

extension Mastodon.Entity {
    /// Preferences
    ///
    /// - Since: 2.8.0
    /// - Version: 3.3.0
    /// # Last Update
    ///   2021/1/29
    /// # Reference
    ///  [Document](https://docs.joinmastodon.org/entities/preferences/)
    public struct Preferences: Codable {
        public let postingDefaultVisibility: Visibility
        public let postingDefaultSensitive: Bool
        public let postingDefaultLanguage: String?      // (ISO 639-1 language two-letter code)
        public let readingExpandMedia: ExpandMedia
        public let readingExpandSpoilers: Bool

        enum CodingKeys: String, CodingKey {
            case postingDefaultVisibility = "posting:default:visibility"
            case postingDefaultSensitive = "posting:default:sensitive"
            case postingDefaultLanguage = "posting:default:language"
            case readingExpandMedia = "reading:expand:media"
            case readingExpandSpoilers = "reading:expand:spoilers"
        }
    }
}

extension Mastodon.Entity.Preferences {
    public static let `default` = Mastodon.Entity.Preferences(
        postingDefaultVisibility: .public,
        postingDefaultSensitive: false,
        postingDefaultLanguage: "en",
        readingExpandMedia: .default,
        readingExpandSpoilers: false
    )
}

extension Mastodon.Entity.Preferences {
    public typealias Visibility = Mastodon.Entity.Source.Privacy
}

extension Mastodon.Entity.Preferences {
    public enum ExpandMedia: RawRepresentable, Codable, Equatable {
        case `default`
        case showAll
        case hideAll
        
        case _other(String)
        
        public init?(rawValue: String) {
            switch rawValue {
            case "default":                 self = .default
            case "show_all":                self = .showAll
            case "hide_all":                self = .hideAll
            default:                        self = ._other(rawValue)
            }
        }
        
        public var rawValue: String {
            switch self {
            case .default:                      return "default"
            case .showAll:                      return "show_all"
            case .hideAll:                      return "hide_all"
            case ._other(let value):            return value
            }
        }
    }
}
