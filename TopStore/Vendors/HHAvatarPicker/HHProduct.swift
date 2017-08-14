//
//  HHProduct.swift
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import ObjectMapper

class HHProduct: Mappable {

    var identifier: Int!
    var url_small: String!
    var url_large: String!
    var name: String!
    var price: Float = 0.0
    
    var timeId: String?
    
    required init?(map: Map) {
        
    }
    
    public func mapping(map: Map) {
        identifier <- map["id"]
        url_small <- map["image_url"]
        url_large <- map["images.1.url"]
        name <- map["name"]
        price <- map["category"]
    }
}
