//
//  Setting.swift
//  CoreDataStack
//
//  Created by ihugo on 2021/4/9.
//

import CoreData
import Foundation

public final class Setting: NSManagedObject {
    
    @NSManaged public var domain: String
    @NSManaged public var userID: String

//    @NSManaged public var appearanceRaw: String
    @NSManaged public var preferredTrueBlackDarkMode: Bool
    @NSManaged public var preferredStaticAvatar: Bool
    @NSManaged public var preferredStaticEmoji: Bool
    @NSManaged public var preferredUsingDefaultBrowser: Bool
    
    @NSManaged public private(set) var createdAt: Date
    @NSManaged public private(set) var updatedAt: Date
    
    @NSManaged private var rawRecentLanguages: Data?
    @objc dynamic public var recentLanguages: [String] {
        get {
            if let data = rawRecentLanguages, let result = try? JSONDecoder().decode([String].self, from: data) {
                return result
            }
            return []
        }
        set {
            rawRecentLanguages = try? JSONEncoder().encode(Array(newValue.prefix(3)))
        }
    }
    
    // one-to-many relationships
    @NSManaged public var subscriptions: Set<Subscription>?
}

extension Setting {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        setPrimitiveValue(now, forKey: #keyPath(Setting.createdAt))
        setPrimitiveValue(now, forKey: #keyPath(Setting.updatedAt))
    }
    
    @discardableResult
    public static func insert(
        into context: NSManagedObjectContext,
        property: Property
    ) -> Setting {
        let setting: Setting = context.insertObject()
//        setting.appearanceRaw = property.appearanceRaw
        setting.domain = property.domain
        setting.userID = property.userID
        return setting
    }
    
//    public func update(appearanceRaw: String) {
//        guard appearanceRaw != self.appearanceRaw else { return }
//        self.appearanceRaw = appearanceRaw
//        didUpdate(at: Date())
//    }

    public func update(preferredTrueBlackDarkMode: Bool) {
        guard preferredTrueBlackDarkMode != self.preferredTrueBlackDarkMode else { return }
        self.preferredTrueBlackDarkMode = preferredTrueBlackDarkMode
        didUpdate(at: Date())
    }

    public func update(preferredStaticAvatar: Bool) {
        guard preferredStaticAvatar != self.preferredStaticAvatar else { return }
        self.preferredStaticAvatar = preferredStaticAvatar
        didUpdate(at: Date())
    }

    public func update(preferredStaticEmoji: Bool) {
        guard preferredStaticEmoji != self.preferredStaticEmoji else { return }
        self.preferredStaticEmoji = preferredStaticEmoji
        didUpdate(at: Date())
    }

    public func update(preferredUsingDefaultBrowser: Bool) {
        guard preferredUsingDefaultBrowser != self.preferredUsingDefaultBrowser else { return }
        self.preferredUsingDefaultBrowser = preferredUsingDefaultBrowser
        didUpdate(at: Date())
    }
    
    public func didUpdate(at networkDate: Date) {
        self.updatedAt = networkDate
    }
    
}

extension Setting {
    public struct Property {
        public let domain: String
        public let userID: String
//        public let appearanceRaw: String

        public init(
            domain: String,
            userID: String
//            appearanceRaw: String
        ) {
            self.domain = domain
            self.userID = userID
//            self.appearanceRaw = appearanceRaw
        }
    }
}

extension Setting: Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(keyPath: \Setting.createdAt, ascending: false)]
    }
}

extension Setting {
    public static func predicate(domain: String, userID: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@ AND %K == %@",
                           #keyPath(Setting.domain), domain,
                           #keyPath(Setting.userID), userID
        )
    }
    
}
