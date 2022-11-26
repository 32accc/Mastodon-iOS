//
//  APIService+Block.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-2.
//

import UIKit
import Combine
import CoreData
import CoreDataStack
import CommonOSLog
import MastodonSDK

extension APIService {
    
    private struct MastodonBlockContext {
        let sourceUserID: MastodonUser.ID
        let targetUserID: MastodonUser.ID
        let targetUsername: String
        let isBlocking: Bool
        let isFollowing: Bool
    }
    
    public func toggleBlock(
        user: ManagedObjectRecord<MastodonUser>,
        authenticationBox: MastodonAuthenticationBox
    ) async throws -> Mastodon.Response.Content<Mastodon.Entity.Relationship> {
        let logger = Logger(subsystem: "APIService", category: "Block")
        
        let managedObjectContext = backgroundManagedObjectContext
        let blockContext: MastodonBlockContext = try await managedObjectContext.performChanges {
            guard let user = user.object(in: managedObjectContext),
                  let authentication = authenticationBox.authenticationRecord.object(in: managedObjectContext)
            else {
                throw APIError.implicit(.badRequest)
            }
            let me = authentication.user
            let isBlocking = user.blockingBy.contains(me)
            let isFollowing = user.followingBy.contains(me)
            // toggle block state
            user.update(isBlocking: !isBlocking, by: me)
            // update follow state implicitly
            if !isBlocking {
                // will do block action. set to unfollow
                user.update(isFollowing: false, by: me)
            }
            logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): [Local] update user[\(user.id)](\(user.username)) block state: \(!isBlocking)")
            return MastodonBlockContext(
                sourceUserID: me.id,
                targetUserID: user.id,
                targetUsername: user.username,
                isBlocking: isBlocking,
                isFollowing: isFollowing
            )
        }
        
        let result: Result<Mastodon.Response.Content<Mastodon.Entity.Relationship>, Error>
        do {
            if blockContext.isBlocking {
                let response = try await Mastodon.API.Account.unblock(
                    session: session,
                    domain: authenticationBox.domain,
                    accountID: blockContext.targetUserID,
                    authorization: authenticationBox.userAuthorization
                ).singleOutput()
                result = .success(response)
            } else {
                let response = try await Mastodon.API.Account.block(
                    session: session,
                    domain: authenticationBox.domain,
                    accountID: blockContext.targetUserID,
                    authorization: authenticationBox.userAuthorization
                ).singleOutput()
                result = .success(response)
            }
        } catch {
            result = .failure(error)
            logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): [Remote] update user[\(blockContext.targetUserID)](\(blockContext.targetUsername)) block failure: \(error.localizedDescription)")
        }
        
        try await managedObjectContext.performChanges {
            guard let user = user.object(in: managedObjectContext),
                  let authentication = authenticationBox.authenticationRecord.object(in: managedObjectContext)
            else { return }
            let me = authentication.user
            
            switch result {
            case .success(let response):
                let relationship = response.value
                Persistence.MastodonUser.update(
                    mastodonUser: user,
                    context: Persistence.MastodonUser.RelationshipContext(
                        entity: relationship,
                        me: me,
                        networkDate: response.networkDate
                    )
                )
                logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): [Remote] update user[\(blockContext.targetUserID)](\(blockContext.targetUsername)) block state: \(relationship.blocking)")
            case .failure:
                // rollback
                user.update(isBlocking: blockContext.isBlocking, by: me)
                user.update(isFollowing: blockContext.isFollowing, by: me)
                logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): [Remote] rollback user[\(blockContext.targetUserID)](\(blockContext.targetUsername)) block state")
            }
        }
        
        let response = try result.get()
        return response
    }
    
}
