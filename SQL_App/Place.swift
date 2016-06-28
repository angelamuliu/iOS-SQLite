//
//  Place.swift
//  SQL_App
//
//  Created by Angela Liu on 6/27/16.
//  Copyright © 2016 amliu. All rights reserved.
//

import Foundation


// Possible todos... parse tags to be an array or something
class Place {
    
    var id:Int
    var longitude: Float
    var latitude: Float
    var category: String
    var subcategory: String
    var name: String
    var address: String
    var phone: String
    var open_hour: String
    var close_hour: String
    var image_url: String
    var tags: String
    
    init(id: Int, longitude: Float, latitude: Float, category: String?, subcategory: String?, name: String?, address: String?, phone: String?, open_hour: String?, close_hour: String?, image_url: String?, tags: String?) {
        self.id = id
        self.longitude = longitude
        self.latitude = latitude
        self.category = category != nil ? category! : "unset"
        self.subcategory = subcategory != nil ? subcategory! : "unset"
        self.name = name != nil ? name! : "unset"
        self.address = address != nil ? address! : "unset"
        self.phone = phone != nil ? phone! : "unset"
        self.open_hour = open_hour != nil ? open_hour! : "unset"
        self.close_hour = close_hour != nil ? close_hour! : "unset"
        self.image_url = image_url != nil ? image_url! : "unset"
        self.tags = tags != nil ? tags! : ""
    }
    
}