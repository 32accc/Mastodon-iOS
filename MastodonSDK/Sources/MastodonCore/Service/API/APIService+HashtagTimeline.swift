//
//  APIService+HashtagTimeline.swift
//  Mastodon
//
//  Created by BradGao on 2021/3/30.
//

import Foundation
import Combine
import CoreData
import CoreDataStack
import CommonOSLog
import MastodonSDK

extension APIService {
    
    public func hashtagTimeline(
        domain: String,
        sinceID: Mastodon.Entity.Status.ID? = nil,
        maxID: Mastodon.Entity.Status.ID? = nil,
        limit: Int = onceRequestStatusMaxCount,
        local: Bool? = nil,
        hashtag: String,
        authenticationBox: MastodonAuthenticationBox
    ) async throws -> Mastodon.Response.Content<[Mastodon.Entity.Status]> {
        let domain = authenticationBox.domain
        let authorization = authenticationBox.userAuthorization

        let query = Mastodon.API.Timeline.HashtagTimelineQuery(
            maxID: maxID,
            sinceID: sinceID,
            minID: nil,     // prefer sinceID
            limit: limit,
            local: local,
            onlyMedia: false
        )

        let response = try await Mastodon.API.Timeline.hashtag(
            session: session,
            domain: domain,
            query: query,
            hashtag: hashtag,
            authorization: authorization
        ).singleOutput()
        
        let managedObjectContext = self.backgroundManagedObjectContext
        try await managedObjectContext.performChanges {
            let me = authenticationBox.authenticationRecord.object(in: managedObjectContext)?.user
            
            for entity in response.value {
                _ = Persistence.Status.createOrMerge(
                    in: managedObjectContext,
                    context: Persistence.Status.PersistContext(
                        domain: domain,
                        entity: entity,
                        me: me,
                        statusCache: nil,
                        userCache: nil,
                        networkDate: response.networkDate
                    )
                )
            }
        }

        return response
    }
    
}

