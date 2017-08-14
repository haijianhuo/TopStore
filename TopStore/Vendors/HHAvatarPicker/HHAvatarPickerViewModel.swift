//
//  HHAvatarPickerViewModel.swift
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import RxSwift
import ObjectMapper
import Alamofire
import ReachabilitySwift

class HHAvatarPickerViewModel {
    
    var products = [HHProduct]([])
    var productsUpdated = Variable<Bool>(false)
    
    var query: String = ""
    var nextPage = 1
    var loadingPage = false
    
    let reachability = Reachability()
    
    func loadNextPage() {
        if self.loadingPage {
            return
        }
        
        self.loadingPage = true
        
        loadPage(query: self.query, page: self.nextPage)
    }
    
    func loadPage(query: String, page: Int) {
        //print("query,page:\(query), \(page)")
        if page == 1 {
            self.query = query
            self.nextPage = 1
        }
        
        if query.characters.count == 0 {
            self.products.removeAll()
            self.loadingPage = false
            self.productsUpdated.value = true
            return
        }
        
        guard let url = self.url(for: query, page: page) else {
            self.products.removeAll()
            self.loadingPage = false
            self.productsUpdated.value = true
            return
        }
        
        if let reachability = self.reachability {
            if !reachability.isReachable {
                self.loadingPage = false
                return
            }
        }
        
        Alamofire.request(url).responseJSON { response in
            guard let dict = response.result.value as? [String: Any] else {
                self.loadingPage = false
                return
            }
            guard let items = dict["photos"] as? [[String: Any]] else {
                self.loadingPage = false
                return
            }
            
            let products = Mapper<HHProduct>().mapArray(JSONArray: items)
            if page == 1 {
                self.products.removeAll()
            }
            self.products.append(contentsOf: products)
            self.nextPage += 1
            self.loadingPage = false
            self.productsUpdated.value = true
        }
    }
    
    private func url(for query: String?, page: Int) -> URL? {
        guard let query = query, !query.isEmpty else { return nil }
        
        let params = [
            "consumer_key": "uVZmwDBD2Ztt7X5AYBVujoem4BQHs7eGnLRzL6eQ",
            "image_size": "3,5",
            "rpp": "48", // The number of results to return. Can not be over 100, default 20.
            "term": query,
            "license_type": "0",
            "page": String(page)
        ]
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.500px.com"
        urlComponents.path = "/v1/photos/search"
        
        
        urlComponents.queryItems = params.map { key, value in URLQueryItem(name: key, value: value) }
        return urlComponents.url
    }
}
