//
//  µ.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/2/3.
//

import Foundation
import Combine
import CoreData
import CoreDataStack
import MastodonSDK

public extension Foundation.Notification.Name {
    static let userFetched = Notification.Name(rawValue: "org.joinmastodon.app.user-fetched")
}

extension APIService {
    
    public func homeTimeline(
        sinceID: Mastodon.Entity.Status.ID? = nil,
        maxID: Mastodon.Entity.Status.ID? = nil,
        limit: Int = onceRequestStatusMaxCount,
        local: Bool? = nil,
        authenticationBox: MastodonAuthenticationBox
    ) async throws -> Mastodon.Response.Content<[Mastodon.Entity.Status]> {
        let domain = authenticationBox.domain
        let authorization = authenticationBox.userAuthorization
        let query = Mastodon.API.Timeline.HomeTimelineQuery(
            maxID: maxID,
            sinceID: sinceID,
            minID: nil,     // prefer sinceID
            limit: limit,
            local: local
        )
        
        let response = try await Mastodon.API.Timeline.home(
            session: session,
            domain: domain,
            query: query,
            authorization: authorization
        ).singleOutput()
        
        let managedObjectContext = self.backgroundManagedObjectContext

        // FIXME: This is a dirty hack to make the performance-stuff work.
        // Problem is, that we don't persist the user on disk anymore. So we have to fetch
        // it when we need it to display on the home timeline.
        // We need this (also) for the Account-list, but it might be the wrong place. App Startup might be more appropriate
        for authentication in AuthenticationServiceProvider.shared.authentications {
            _ = try await? accountInfo(domain: authentication.domain,
                                       userID: authentication.userID,
                                       authorization: Mastodon.API.OAuth.Authorization(accessToken: authentication.userAccessToken)).value
        }

        NotificationCenter.default.post(name: .userFetched, object: nil)
        
        try await managedObjectContext.performChanges {
            guard let me = authenticationBox.authentication.user(in: managedObjectContext) else {
                assertionFailure()
                return
            }
            
            // persist status
            var statuses: [Status] = []
            for entity in response.value {
                let result = Persistence.Status.createOrMerge(
                    in: managedObjectContext,
                    context: Persistence.Status.PersistContext(
                        domain: domain,
                        entity: entity,
                        me: me,
                        statusCache: nil,       // TODO: add cache
                        userCache: nil,         // TODO: add cache
                        networkDate: response.networkDate
                    )
                )
                statuses.append(result.status)
            }
            
            // locate anchor status
            let anchorStatus: Status? = {
                guard let maxID = maxID else { return nil }
                let request = Status.sortedFetchRequest
                request.predicate = Status.predicate(domain: domain, id: maxID)
                request.fetchLimit = 1
                return try? managedObjectContext.fetch(request).first
            }()
            
            // update hasMore flag for anchor status
            let acct = Feed.Acct.mastodon(domain: authenticationBox.domain, userID: authenticationBox.userID)
            if let anchorStatus = anchorStatus,
               let feed = anchorStatus.feed(kind: .home, acct: acct) {
                feed.update(hasMore: false)
            }
            
            // persist Feed relationship
            let sortedStatuses = statuses.sorted(by: { $0.createdAt < $1.createdAt })
            let oldestStatus = sortedStatuses.first
            for status in sortedStatuses {
                let _feed = status.feed(kind: .home, acct: acct)
                if let feed = _feed {
                    feed.update(updatedAt: response.networkDate)
                } else {
                    let feedProperty = Feed.Property(
                        acct: acct,
                        kind: .home,
                        hasMore: false,
                        createdAt: status.createdAt,
                        updatedAt: response.networkDate
                    )
                    let feed = Feed.insert(into: managedObjectContext, property: feedProperty)
                    status.attach(feed: feed)
                    
                    // set hasMore on oldest status if is new feed
                    if status === oldestStatus {
                        feed.update(hasMore: true)
                    }
                }
            }
        }
        
        return response
    }
    
}
