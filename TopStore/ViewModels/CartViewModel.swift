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
import Reachability
import CoreData
import JSQCoreDataKit

class CartViewModel: NSObject
{
    private struct Static
    {
        static var instance: CartViewModel?
    }
    
    class var shared: CartViewModel
    {
        if Static.instance == nil
        {
            Static.instance = CartViewModel()
        }
        
        return Static.instance!
    }
    
    func destroy()
    {
        print("\(#function), \(type(of: self)) *Log*")
        CartViewModel.Static.instance = nil
    }
    
    var stack: CoreDataStack!
    
    var products = [Product]([])
    var productsUpdated = Variable<Bool>(false)
    
    var totalAmount = Variable<Float>(0)

    let reachability = Reachability()!
    
    fileprivate override init() {
        super.init()
        
        print("\(#function), \(type(of: self)) *Log*")


        let storeType = StoreType.sqlite(self.dataURL())
        let model = CoreDataModel(name: "TopStore", bundle: Bundle.main, storeType: storeType)
        let factory = CoreDataStackFactory(model: model)
        
        factory.createStack(onQueue: nil) { (result: StackResult) in
            switch result {
            case .success(let s):
                self.stack = s
                self.products = self.fetchProductData()
                self.updateTotalAmount()
            case .failure(let err):
                assertionFailure("Error creating stack: \(err)")
            }
        }
    }
    
    deinit {
        print("\(#function), \(type(of: self)) *Log*")
    }

    func clearCart() {
        self.removeAllProductData()
        self.products.removeAll()
        self.productsUpdated.value = true
        self.updateTotalAmount()
    }
    
    func addToCart(_ product: Product, productsUpdated: Bool = true) {
        product.timeId = self.timeId()
        self.insertProductData(product)
        self.products.insert(product, at: 0)
        if productsUpdated {
            self.productsUpdated.value = true
        }
        self.updateTotalAmount()
    }
    
    func removeRow(at indexPath: IndexPath, productsUpdated: Bool = true) {
        if let timeId = self.products[indexPath.row].timeId {
            self.removeProductData(timeId: timeId)
        }
        
        self.products.remove(at: indexPath.row)
        if productsUpdated {
            self.productsUpdated.value = true
        }
        self.updateTotalAmount()
    }
    
    private func updateTotalAmount() {
        self.totalAmount.value = products.map({$0.price}).reduce(0, +)
    }
    
    private func fetchProductData() -> [Product] {
        print("\(#function), \(type(of: self)) *Log*")
        var array = [Product]()
        
        let backgroundChildContext = stack.childContext(concurrencyType: .privateQueueConcurrencyType)
        
        do {
            let fetchRequest = ProductData.fetchRequest
            
            let objects = try backgroundChildContext.fetch(fetchRequest)
            for each in objects {
                if let product = each.toProduct() {
                    array.append(product)
                }
            }
            return array
        } catch let error as NSError {
            print("Error: \(error.localizedDescription)")
            return array
        }
    }
    
    private func removeAllProductData() {
        let backgroundChildContext = self.stack.childContext(concurrencyType: .privateQueueConcurrencyType)
        
        backgroundChildContext.performAndWait {
            do {
                let objects = try backgroundChildContext.fetch(ProductData.fetchRequest)
                for each in objects {
                    backgroundChildContext.delete(each)
                }
                saveContext(backgroundChildContext)
            } catch {
                print("Error deleting objects: \(error)")
            }
        }
    }
    
    
    private func insertProductData(_ product: Product) {
        let backgroundChildContext = self.stack.childContext(concurrencyType: .privateQueueConcurrencyType)
        
        _ = ProductData(context: backgroundChildContext, timeId: product.timeId, identifier: 0, url_small: product.url_small, url_large: product.url_large, name: product.name, price: Double(product.price), created: Date())
        saveContext(backgroundChildContext)
    }
    
    private func removeProductData(timeId: String) {
        let backgroundChildContext = stack.childContext(concurrencyType: .privateQueueConcurrencyType)
        
        let fetchRequest = ProductData.fetchRequest
        fetchRequest.predicate = NSPredicate(format: "timeId == %@", timeId)
        do {
            let array = try backgroundChildContext.fetch(fetchRequest)
            for object in array {
                backgroundChildContext.delete(object)
            }
            saveContext(backgroundChildContext)
            
        } catch let error as NSError {
            print("fetchRequest: \(error.description)")
        }
        
    }
    
    
    private func dataURL() -> URL {
        let url = applicationSupportDirectoryURL()
        let dataUrl = url.appendingPathComponent("Data")
        
        do {
            try FileManager.default.createDirectory(atPath: dataUrl.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        return dataUrl
    }
    
    
    private func applicationSupportDirectoryURL() -> URL {
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
    
    private func timeId() -> String {
        return String(format: "%0.0f", Date().timeIntervalSince1970)
    }
    
}
