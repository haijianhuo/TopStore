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
import PKHUD

class ProductsViewModel {
    
    var products = [Product]([])
    var productsUpdated = Variable<Bool>(false)

    var query: String = ""
    var nextPage = 1
    var loadingPage = false
    
    let reachability = Reachability()!

    func updateRow(added: Bool, at indexPath: IndexPath, productsUpdated: Bool = true) {
        let item = self.products[indexPath.row]
        item.added = added
        if productsUpdated {
            self.productsUpdated.value = true
        }
    }

    func removeRow(at indexPath: IndexPath, productsUpdated: Bool = true) {
        self.products.remove(at: indexPath.row)
        if productsUpdated {
            self.productsUpdated.value = true
        }
    }

    func loadNextPage() {
        if self.loadingPage {
            return
        }
        
        self.loadingPage = true
        
        loadPage(query: self.query, page: self.nextPage)
    }

    func loadPage(query: String, page: Int) {
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
        
        if !reachability.isReachable {
            DispatchQueue.main.async {
                HUD.flash(.label("Internet is not reachable"), delay: 2.0) { _ in
                    print("Internet is not reachable.")
                }
            }
            self.loadingPage = false
            return
        }

        Alamofire.request(url).responseJSON { response in
            guard let dict = response.result.value as? [String: Any] else { return }
            guard let items = dict["photos"] as? [[String: Any]] else { return }
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
            "consumer_key": "uVZmwDBD2Ztt7X5AYBVujoem4BQHs7eGnLRzL6eQ",
            "image_size": "3,5",
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

