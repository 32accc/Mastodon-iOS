// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation

extension Mastodon.Entity {

    /// StatusEdit
    ///
    /// - Since: 0.1.0
    /// - Version: 3.5.0
    /// # Last Update
    ///   2022/12/14
    /// # Reference
    ///  [Document](https://docs.joinmastodon.org/entities/statusedit/)
    public class StatusEdit: Codable {
        public class Poll: Codable {
            public class Option: Codable, Hashable {
                public let title: String
                
                public func hash(into hasher: inout Hasher) {
                    hasher.combine(title)
                }
                
                public static func == (lhs: Mastodon.Entity.StatusEdit.Poll.Option, rhs: Mastodon.Entity.StatusEdit.Poll.Option) -> Bool {
                    lhs.title == rhs.title
                }
            }
            public let options: [Option]
            public let title: String?
            
//            public static func == (lhs: Mastodon.Entity.StatusEdit.Poll, rhs: Mastodon.Entity.StatusEdit.Poll) -> Bool {
//                lhs.title == rhs.title && lhs.options == rhs.options
//            }
        }
        
        public let content: String
        public let spoilerText: String?
        public let sensitive: Bool
        public let createdAt: Date
        public let account: Account
        public let poll: Poll?
        public let mediaAttachments: [Attachment]?
        public let emojis: [Emoji]?

        enum CodingKeys: String, CodingKey {
            case content
            case spoilerText = "spoiler_text"
            case sensitive
            case createdAt = "created_at"
            case account
            case poll
            case mediaAttachments = "media_attachments"
            case emojis
        }

    }
}
