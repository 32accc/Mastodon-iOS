//
//  DiscoveryNewsViewModel+State.swift
//  Mastodon
//
//  Created by MainasuK on 2022-4-13.
//

import os.log
import Foundation
import GameplayKit
import MastodonSDK

extension DiscoveryNewsViewModel {
    class State: GKState {
        
        let logger = Logger(subsystem: "DiscoveryNewsViewModel.State", category: "StateMachine")

        let id = UUID()

        weak var viewModel: DiscoveryNewsViewModel?
        
        init(viewModel: DiscoveryNewsViewModel) {
            self.viewModel = viewModel
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            
            let from = previousState.flatMap { String(describing: $0) } ?? "nil"
            let to = String(describing: self)
            logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): \(from) -> \(to)")
        }
        
        @MainActor
        func enter(state: State.Type) {
            stateMachine?.enter(state)
        }
    }
}

extension DiscoveryNewsViewModel.State {
    class Initial: DiscoveryNewsViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type:
                return true
            default:
                return false
            }
        }
    }
    
    class Reloading: DiscoveryNewsViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Loading.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let _ = viewModel, let stateMachine = stateMachine else { return }
            
            stateMachine.enter(Loading.self)
        }
    }
    
    class Fail: DiscoveryNewsViewModel.State {
        
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Loading.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let _ = viewModel, let stateMachine = stateMachine else { return }

            // try reloading three seconds later
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                stateMachine.enter(Loading.self)
            }
        }
    }
    
    class Idle: DiscoveryNewsViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type, is Loading.Type:
                return true
            default:
                return false
            }
        }
    }
    
    class Loading: DiscoveryNewsViewModel.State {
        
        var offset: Int?
        
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Fail.Type:
                return true
            case is Idle.Type:
                return true
            case is NoMore.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            guard let viewModel else { return }
            
            switch previousState {
            case is Reloading:
                offset = nil
            default:
                break
            }
            
            let offset = self.offset
            let isReloading = offset == nil
            
            Task {
                do {
                    let response = try await viewModel.context.apiService.trendLinks(
                        domain: viewModel.authContext.mastodonAuthenticationBox.domain,
                        query: Mastodon.API.Trends.StatusQuery(
                            offset: offset,
                            limit: nil
                        ),
                        authenticationBox: viewModel.authContext.mastodonAuthenticationBox
                    )
                    let newOffset: Int? = {
                        guard let offset = response.link?.offset else { return nil }
                        return self.offset.flatMap { max($0, offset) } ?? offset
                    }()

                    let hasMore: Bool = {
                        guard let newOffset = newOffset else { return false }
                        return newOffset != self.offset     // not the same one
                    }()

                    self.offset = newOffset

                    var hasNewItemsAppend = false
                    var links = isReloading ? [] : viewModel.links
                    for link in response.value {
                        guard !links.contains(link) else { continue }
                        links.append(link)
                        hasNewItemsAppend = true
                    }

                    if hasNewItemsAppend, hasMore {
                        await enter(state: Idle.self)
                    } else {
                        await enter(state: NoMore.self)
                    }
                    viewModel.links = links
                    viewModel.didLoadLatest.send()
                } catch {
                    if let error = error as? Mastodon.API.Error, error.httpResponseStatus.code == 404 {
                        viewModel.isServerSupportEndpoint = false
                        await enter(state: NoMore.self)
                    } else {
                        await enter(state: Fail.self)
                    }

                    viewModel.didLoadLatest.send()
                }
            }   // end Task
        }   // end func
    }
    
    class NoMore: DiscoveryNewsViewModel.State {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Reloading.Type:
                return true
            default:
                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
        }
    }
}
