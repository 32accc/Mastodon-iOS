//
//  APIService+Notification.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/13.
//

import Combine
import CoreData
import CoreDataStack
import Foundation
import MastodonSDK
import OSLog

extension APIService {
    
    public enum MastodonNotificationScope: String, Hashable, CaseIterable {
        case everything
        case mentions
        
        public var includeTypes: [MastodonNotificationType]? {
            switch self {
            case .everything:       return nil
            case .mentions:         return [.mention, .status]
            }
        }
        
        public var excludeTypes: [MastodonNotificationType]? {
            switch self {
            case .everything:       return nil
            case .mentions:         return [.follow, .followRequest, .reblog, .favourite, .poll]
            }
        }
        
        public var _excludeTypes: [Mastodon.Entity.Notification.NotificationType]? {
            switch self {
            case .everything:       return nil
            case .mentions:         return [.follow, .followRequest, .reblog, .favourite, .poll]
            }
        }
    }
    
    public func notifications(
        maxID: Mastodon.Entity.Status.ID?,
        scope: MastodonNotificationScope,
        authenticationBox: MastodonAuthenticationBox
    ) async throws -> Mastodon.Response.Content<[Mastodon.Entity.Notification]> {
        let authorization = authenticationBox.userAuthorization
        
        let query = Mastodon.API.Notifications.Query(
            maxID: maxID,
            types: {
                switch scope {
                case .everything:
                    return [
                        .follow,
                        .followRequest,
                        .mention,
                        .reblog,
                        .favourite,
                        .poll,
                        .status,
                        .moderationWarning
                    ]
                case .mentions:
                    return [
                        .mention,
                        .status,
                    ]
                }
            }(),
            excludeTypes: {
                switch scope {
                case .everything:
                    return nil
                case .mentions:
                    return [.follow, .followRequest, .reblog, .favourite, .poll]
                }
            }()
        )
        
        let response = try await Mastodon.API.Notifications.getNotifications(
            session: session,
            domain: authenticationBox.domain,
            query: query,
            authorization: authorization
        ).singleOutput()
        
        return response
    }
}

extension APIService {
    
    public func notification(
        notificationID: Mastodon.Entity.Notification.ID,
        authenticationBox: MastodonAuthenticationBox
    ) async throws -> Mastodon.Response.Content<Mastodon.Entity.Notification> {
        let domain = authenticationBox.domain
        let authorization = authenticationBox.userAuthorization
        
        let response = try await Mastodon.API.Notifications.getNotification(
            session: session,
            domain: domain,
            notificationID: notificationID,
            authorization: authorization
        ).singleOutput()
        
        return response
    }

}
