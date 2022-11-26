//
//  APIService+Following.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-11-2.
//

import UIKit
import Combine
import CoreData
import CoreDataStack
import CommonOSLog
import MastodonSDK

extension APIService {
    
    public func following(
        userID: Mastodon.Entity.Account.ID,
        maxID: String?,
        authenticationBox: MastodonAuthenticationBox
    ) async throws -> Mastodon.Response.Content<[Mastodon.Entity.Account]> {
        let domain = authenticationBox.domain
        let authorization = authenticationBox.userAuthorization
        
        let query = Mastodon.API.Account.FollowingQuery(
            maxID: maxID,
            limit: nil
        )
        
        let response = try await Mastodon.API.Account.following(
            session: session,
            domain: domain,
            userID: userID,
            query: query,
            authorization: authorization
        ).singleOutput()
        
        let managedObjectContext = self.backgroundManagedObjectContext
        try await managedObjectContext.performChanges {
            let me = authenticationBox.authenticationRecord.object(in: managedObjectContext)?.user
            
            for entity in response.value {
                let result = Persistence.MastodonUser.createOrMerge(
                    in: managedObjectContext,
                    context: Persistence.MastodonUser.PersistContext(
                        domain: domain,
                        entity: entity,
                        cache: nil,
                        networkDate: response.networkDate
                    )
                )
                
                if let me = me {
                    let user = result.user
                    user.update(isFollowing: true, by: me)
                }
            }
            
        }
        
        return response
    }
    
}
