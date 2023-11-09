//
//  PollItem.swift
//  
//
//  Created by MainasuK on 2022-1-12.
//

import Foundation
import CoreData
import CoreDataStack
import MastodonSDK

public enum PollItem: Hashable {
    case option(record: ManagedObjectRecord<PollOption>)
    case history(option: Mastodon.Entity.StatusEdit.Poll.Option)
}
