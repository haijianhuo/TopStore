//
//  CartViewModel.swift
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
import CoreData
import JSQCoreDataKit

class CartViewModel: NSObject {
    static let shared = CartViewModel()
    
    var stack: CoreDataStack!

    var products = [Product]([])
    var productsUpdated = Variable<Bool>(false)

    let reachability = Reachability()!

    fileprivate override init() {
        super.init()
        
        let storeType = StoreType.sqlite(self.dataURL())
        let model = CoreDataModel(name: "TopStore", bundle: Bundle.main, storeType: storeType)
        let factory = CoreDataStackFactory(model: model)
        
        factory.createStack(onQueue: nil) { (result: StackResult) in
            switch result {
            case .success(let s):
                self.stack = s
            case .failure(let err):
                assertionFailure("Error creating stack: \(err)")
            }
        }
    }

    func clearCart() {
        self.products.removeAll()
        self.productsUpdated.value = true
    }

    func addToCart(_ product: Product) {
        self.products.insert(product, at: 0)
        self.productsUpdated.value = true
    }

    func removeRow(at indexPath: IndexPath, productsUpdated: Bool = true) {
        self.products.remove(at: indexPath.row)
        if productsUpdated {
            self.productsUpdated.value = true
        }
    }


    
    func dataURL() -> URL {
        let url = applicationSupportDirectoryURL()
        let dataUrl = url.appendingPathComponent("Data")
        
        do {
            try FileManager.default.createDirectory(atPath: dataUrl.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        return dataUrl
    }
    
    
    func applicationSupportDirectoryURL() -> URL {
        do {
            let searchPathDirectory = FileManager.SearchPathDirectory.applicationSupportDirectory
            
            return try FileManager.default.url(for: searchPathDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        }
        catch {
            fatalError("*** Error finding default directory: \(error)")
        }
    }

}

