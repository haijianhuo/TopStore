//
//  BlackUserData.swift
//  Moxin
//
//  Created by Haijian Huo on 1/29/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import CoreData
import JSQCoreDataKit

public final class ProductData: NSManagedObject, CoreDataEntityProtocol {

    public static let defaultSortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]

    // MARK: Properties
    
    @NSManaged public var identifier: Int
    @NSManaged public var url_small: String
    @NSManaged public var url_large: String
    @NSManaged public var name: String
    @NSManaged public var price: Double
    @NSManaged public var created: Date

    
    // MARK: Init

    public init(context: NSManagedObjectContext,
                identifier: Int,
                url_small: String,
                url_large: String,
                name: String,
                price: Double,
                created: Date) {
        super.init(entity: ProductData.entity(context: context), insertInto: context)
        self.identifier = identifier
        self.url_small = url_small
        self.url_large = url_large
        self.name = name
        self.price = price
        self.created = created
    }

    @objc
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
