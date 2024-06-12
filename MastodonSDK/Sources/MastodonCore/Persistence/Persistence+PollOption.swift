//
//  Persistence+MastodonPollOption.swift
//
//
//  Created by MainasuK on 2021-12-9.
//

import CoreData
import CoreDataStack
import Foundation
import MastodonSDK

extension Persistence.PollOption {
    
    public struct PersistContext {
        public let index: Int
        public let poll: PollLegacy
        public let entity: Mastodon.Entity.Poll.Option
        public let me: MastodonUser?
        public let networkDate: Date
        
        public init(
            index: Int,
            poll: PollLegacy,
            entity: Mastodon.Entity.Poll.Option,
            me: MastodonUser?,
            networkDate: Date
        ) {
            self.index = index
            self.poll = poll
            self.entity = entity
            self.me = me
            self.networkDate = networkDate
        }
    }
    
    public struct PersistResult {
        public let option: PollOptionLegacy
        public let isNewInsertion: Bool
        
        public init(
            option: PollOptionLegacy,
            isNewInsertion: Bool
        ) {
            self.option = option
            self.isNewInsertion = isNewInsertion
        }
    }
    
    // the bare Poll.Option entity not supports merge from entity.
    // use merge entry on MastodonPoll with exists option objects
    public static func persist(
        in managedObjectContext: NSManagedObjectContext,
        context: PersistContext
    ) -> PersistResult {
        let option = create(in: managedObjectContext, context: context)
        return PersistResult(option: option, isNewInsertion: true)
    }
    
}

extension Persistence.PollOption {
    
    @discardableResult
    public static func create(
        in managedObjectContext: NSManagedObjectContext,
        context: PersistContext
    ) -> PollOptionLegacy {
        let property = PollOptionLegacy.Property(
            poll: context.poll,
            index: context.index,
            entity: context.entity,
            networkDate: context.networkDate
        )
        let option = PollOptionLegacy.insert(into: managedObjectContext, property: property)
        update(option: option, context: context)
        return option
    }
    
    public static func merge(
        option: PollOptionLegacy,
        context: PersistContext
    ) {
        guard context.networkDate > option.updatedAt else { return }
        let property = PollOptionLegacy.Property(
            poll: context.poll,
            index: context.index,
            entity: context.entity,
            networkDate: context.networkDate
        )
        option.update(property: property)
        update(option: option, context: context)
    }
    
    private static func update(
        option: PollOptionLegacy,
        context: PersistContext
    ) {
        // Do nothing
    }   // end func update

}