//
//  APIService+Search.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/3/31.
//

import Foundation
import Combine
import MastodonSDK

extension APIService {
 
    public func search(
        query: Mastodon.API.V2.Search.Query,
        authenticationBox: MastodonAuthenticationBox
    ) async throws -> Mastodon.Response.Content<Mastodon.Entity.SearchResult> {
        let domain = authenticationBox.domain
        let authorization = authenticationBox.userAuthorization

        let response = try await Mastodon.API.V2.Search.search(
            session: session,
            domain: domain,
            query: query,
            authorization: authorization
        ).singleOutput()
            
        let managedObjectContext = self.backgroundManagedObjectContext
        try await managedObjectContext.performChanges {
            let me = authenticationBox.authentication.user(in: managedObjectContext)
            
            // user
            for entity in response.value.accounts {
                _ = Persistence.MastodonUser.createOrMerge(
                    in: managedObjectContext,
                    context: Persistence.MastodonUser.PersistContext(
                        domain: domain,
                        entity: entity,
                        cache: nil,
                        networkDate: response.networkDate
                    )
                )
            }

        }   // ent try await managedObjectContext.performChanges { … } 
        
        return response
    }

}
