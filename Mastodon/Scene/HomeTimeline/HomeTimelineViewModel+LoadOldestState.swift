//
//  HomeTimelineViewModel+LoadOldestState.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/2/5.
//

import Foundation
import GameplayKit
import MastodonSDK
import MastodonCore

extension HomeTimelineViewModel {
    class LoadOldestState: GKState {

        let id = UUID()
        
        weak var viewModel: HomeTimelineViewModel?
        
        init(viewModel: HomeTimelineViewModel) {
            self.viewModel = viewModel
        }
        
        @MainActor
        func enter(state: LoadOldestState.Type) {
            stateMachine?.enter(state)
        }
    }
}

extension HomeTimelineViewModel.LoadOldestState {
    class Initial: HomeTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            guard let viewModel = viewModel else { return false }
            guard !viewModel.dataController.records.isEmpty else { return false }
            return stateClass == Loading.self
        }
    }
    
    class Loading: HomeTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return stateClass == Fail.self || stateClass == Idle.self || stateClass == NoMore.self
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            
            guard let viewModel = viewModel, let stateMachine = stateMachine else { return }
            
            guard let lastFeedRecord = viewModel.dataController.records.last else {
                stateMachine.enter(Idle.self)
                return
            }
            
            Task {
                guard let maxID = lastFeedRecord.status?.id else {
                    await self.enter(state: Fail.self)
                    return
                }

                do {
                    await AuthenticationServiceProvider.shared.fetchAccounts(apiService: viewModel.context.apiService)

                    let response: Mastodon.Response.Content<[Mastodon.Entity.Status]>

                    switch viewModel.timelineContext {
                    case .home:
                        response = try await viewModel.context.apiService.homeTimeline(
                            maxID: maxID,
                            authenticationBox: viewModel.authContext.mastodonAuthenticationBox
                        )
                    case .public:
                        response = try await viewModel.context.apiService.publicTimeline(
                            query: .init(local: true, maxID: maxID),
                            authenticationBox: viewModel.authContext.mastodonAuthenticationBox
                        )
                    }

                    let statuses = response.value
                    // enter no more state when no new statuses
                    if statuses.isEmpty || (statuses.count == 1 && statuses[0].id == maxID) {
                        await self.enter(state: NoMore.self)
                    } else {
                        await self.enter(state: Idle.self)
                    }

                } catch {
                    await self.enter(state: Fail.self)
                }
            }   // end Task
        }
    }
    
    class Fail: HomeTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return stateClass == Loading.self || stateClass == Idle.self
        }
    }
    
    class Idle: HomeTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return stateClass == Loading.self
        }
    }

    class NoMore: HomeTimelineViewModel.LoadOldestState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            // reset state if needs
            return stateClass == Idle.self
        }
        
        override func didEnter(from previousState: GKState?) {
            guard let viewModel = viewModel else { return }
            guard let diffableDataSource = viewModel.diffableDataSource else {
                assertionFailure()
                return
            }
            DispatchQueue.main.async {
                var snapshot = diffableDataSource.snapshot()
                snapshot.deleteItems([.bottomLoader])
                diffableDataSource.apply(snapshot)
            }
        }
    }
}
