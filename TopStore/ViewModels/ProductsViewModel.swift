//
//  ProductsViewModel.swift
//  TopStore
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import RxSwift
import ObjectMapper
import Alamofire
import ReachabilitySwift

class ProductsViewModel {
    
    var avatar = Variable<UIImage?>(nil)

    var products = [Product]([])
    var productsUpdated = Variable<Bool>(false)
    
    var query: String = ""
    var nextPage = 1
    var loadingPage = false
    
    let reachability = Reachability()
    let cartViewModel = CartViewModel.shared
    let meViewModel = MeViewModel.shared

    init() {
        print("\(#function), \(type(of: self)) *Log*")
        self.avatar = meViewModel.avatar
    }
    
    deinit {
        print("\(#function), \(type(of: self)) *Log*")
    }

    func addToCart(_ product: Product) {
        cartViewModel.addToCart(product)
    }
    
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
        
        if query.count == 0 {
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
            guard let items = dict["hits"] as? [[String: Any]] else {
                self.loadingPage = false
                return
            }
            
            let products = Mapper<Product>().mapArray(JSONArray: items)
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
            "key": "9640291-0f83fe015c9bf829242f12fcc",
            "q": query,
            "per_page": "40",
            "page": String(page)
        ]
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "pixabay.com"
        urlComponents.path = "/api/"
        
        
        urlComponents.queryItems = params.map { key, value in URLQueryItem(name: key, value: value) }
        return urlComponents.url
    }
}
