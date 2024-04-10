//
//  File.swift
//  
//
//  Created by Marcus Kida on 25.03.24.
//

import Foundation

public final class MastodonPoll: ObservableObject, Hashable {
    
    @Published public var votersCount: Int?
    @Published public var votesCount: Int
    @Published public var options: [MastodonPollOption] = []
    @Published public var multiple: Bool
    @Published public var expired: Bool
    @Published public var expiresAt: Date?
    @Published public var voted: Bool?
    
    public var id: String {
        poll.id
    }
    
    public let poll: Mastodon.Entity.Poll
    public weak var status: MastodonStatus?
    
    public init(poll: Mastodon.Entity.Poll, status: MastodonStatus?) {
        self.status = status
        self.poll = poll
        self.votersCount = poll.votersCount
        self.votesCount = poll.votesCount
        self.multiple = poll.multiple
        self.expired = poll.expired
        self.voted = poll.voted
        self.expiresAt = poll.expiresAt
        self.options = poll.options.map { $0.toMastodonPollOption(with: self) }
    }
    
    public static func == (lhs: MastodonPoll, rhs: MastodonPoll) -> Bool {
        lhs.poll == rhs.poll
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(poll)
    }
}

public extension Mastodon.Entity.Poll {
    func toMastodonPoll(status: MastodonStatus?) -> MastodonPoll {
        return .init(poll: self, status: status)
    }
}

public final class MastodonPollOption: ObservableObject, Hashable {
    
    public let poll: MastodonPoll
    public let option: Mastodon.Entity.Poll.Option
    @Published public var isSelected: Bool = false
    @Published public var votesCount: Int?
    @Published public var title: String
    @Published public var voted: Bool?
    public private(set) var optionIndex: Int? = nil
    
    public init(poll: MastodonPoll, option: Mastodon.Entity.Poll.Option, isSelected: Bool = false) {
        self.poll = poll
        self.option = option
        self.isSelected = isSelected
        self.votesCount = option.votesCount
        self.title = option.title
        self.optionIndex = poll.options.firstIndex(of: self)
        
        self.voted = {
            guard let ownVotes = poll.poll.ownVotes else { return false }
            guard let optionIndex else { return false }
            return ownVotes.contains(optionIndex)
        }()
    }
    
    public static func == (lhs: MastodonPollOption, rhs: MastodonPollOption) -> Bool {
        lhs.poll == rhs.poll && lhs.option == rhs.option && lhs.isSelected == rhs.isSelected
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(poll)
        hasher.combine(option)
        hasher.combine(isSelected)
    }
}

public extension Mastodon.Entity.Poll.Option {
    func toMastodonPollOption(with poll: MastodonPoll) -> MastodonPollOption {
        return .init(poll: poll, option: self)
    }
}
