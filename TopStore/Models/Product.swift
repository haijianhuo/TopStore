//
//  Product.swift
//  TopStore
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import ObjectMapper

class Product: Mappable {

    var identifier: Int!
    var url: String!
    var name: String!
    var price: Float = 0.0
    var added: Bool = false
    
    required init?(map: Map) {
        
    }
    
    public func mapping(map: Map) {
        identifier <- map["id"]
        url <- map["image_url"]
        name <- map["name"]
        price <- map["category"]
    }
}
