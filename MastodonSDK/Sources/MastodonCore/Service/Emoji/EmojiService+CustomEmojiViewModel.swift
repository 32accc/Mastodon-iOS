//
//  EmojiService+CustomEmojiViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-3-15.
//

import Foundation
import Combine
import GameplayKit
import MastodonSDK
import MastodonCommon

extension EmojiService {
    public final class CustomEmojiViewModel {
        
        var disposeBag = Set<AnyCancellable>()
        
        // input
        public let domain: String
        public weak var service: EmojiService?
        
        // output
        private(set) lazy var stateMachine: GKStateMachine = {
            // exclude timeline middle fetcher state
            let stateMachine = GKStateMachine(states: [
                LoadState.Initial(viewModel: self),
                LoadState.Loading(viewModel: self),
                LoadState.Fail(viewModel: self),
                LoadState.Finish(viewModel: self),
            ])
            stateMachine.enter(LoadState.Initial.self)
            return stateMachine
        }()
        public let emojis = CurrentValueSubject<[Mastodon.Entity.Emoji], Never>([])
        public let emojiDict = CurrentValueSubject<[String: [Mastodon.Entity.Emoji]], Never>([:])
        public let emojiMapping = CurrentValueSubject<[String: String], Never>([:])
        public let emojiTrie = CurrentValueSubject<Trie<Character>?, Never>(nil)
        
        private var learnedEmoji: Set<String> = Set()
        
        init(domain: String, service: EmojiService) {
            self.domain = domain
            self.service = service
            
            emojis
                .map { Dictionary(grouping: $0, by: { $0.shortcode }) }
                .assign(to: \.value, on: emojiDict)
                .store(in: &disposeBag)

            emojiDict
                .map { dict in
                    var mapping: [String: String] = [:]
                    for (key, values) in dict {
                        guard let emoji = values.first else { continue }
                        mapping[key] = emoji.url
                    }
                    return mapping
                }
                .assign(to: \.value, on: emojiMapping)
                .store(in: &disposeBag)
            
            emojis
                .map { emojis -> Trie<Character>? in
                    guard !emojis.isEmpty else { return nil }
                    var trie: Trie<Character> = Trie()
                    for emoji in emojis {
                        let key = emoji.shortcode.lowercased()
                        trie.inserted(Array(key).slice, value: emoji)
                    }
                    return trie
                }
                .assign(to: \.value, on: emojiTrie)
                .store(in: &disposeBag)
        }
        
        func emoji(shortcode: String) -> Mastodon.Entity.Emoji? {
            if !learnedEmoji.contains(shortcode) {
                learnedEmoji.insert(shortcode)
                
                DispatchQueue.global().async {
                    UITextChecker.learnWord(shortcode)
                    UITextChecker.learnWord(":" + shortcode + ":")
                }
            }

            return emojiDict.value[shortcode]?.first
        }
        
    }
}
