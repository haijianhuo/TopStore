//
//  TopStoreTests.swift
//  TopStoreTests
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import XCTest
@testable import TopStore
import RxSwift

class TopStoreTests: XCTestCase {
    
    var viewModel = ProductsViewModel()
    var cartViewModel = CartViewModel.shared
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testProductViewModelAndCartViewModel() {
        
        // loadPage
        let searchText = "Cookie"
        
        let expectation_loadPage = self.expectation(description: "name contains search text")
        
        let observer_loadPage = viewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.viewModel.products.count > 0 {
                if let i = self.viewModel.products.index(where: { $0.name.contains(searchText) }) {
                    print("product: \(self.viewModel.products[i].name)")
                    expectation_loadPage.fulfill()
                }
            }
        })
        
        self.viewModel.loadPage(query: searchText, page: 1)
        
        wait(for: [expectation_loadPage], timeout: 2)
        observer_loadPage.dispose()
        
        // loadNextPage
        var count = viewModel.products.count
        let expectation_loadNextPage = self.expectation(description: "count increased")
        let observer_loadNextPage = viewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.viewModel.products.count > count {
                print("count before and after load: \(count), \(self.viewModel.products.count)")
                expectation_loadNextPage.fulfill()
            }
        })
        
        self.viewModel.loadNextPage()
        
        wait(for: [expectation_loadNextPage], timeout: 2)
        observer_loadNextPage.dispose()
        
        // addToCart from product search
        count = cartViewModel.products.count
        
        let expectation_addToCart = self.expectation(description: "count increase by 1")
        let observer_addToCart = cartViewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.cartViewModel.products.count == count + 1 {
                print("count before and after add: \(count), \(self.cartViewModel.products.count)")
                expectation_addToCart.fulfill()
            }
        })
        
        self.viewModel.addToCart(viewModel.products[0])
        
        wait(for: [expectation_addToCart], timeout: 2)
        observer_addToCart.dispose()
        
        // removeRow from cart
        count = cartViewModel.products.count
        
        let expectation_removeRow = self.expectation(description: "count decreased by 1")
        let observer_removeRow = cartViewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.cartViewModel.products.count == count - 1 {
                print("count before and after delete: \(count), \(self.cartViewModel.products.count)")
                expectation_removeRow.fulfill()
            }
        })
        
        self.cartViewModel.removeRow(at: IndexPath.init(row: 0, section: 0))
        wait(for: [expectation_removeRow], timeout: 2)
        observer_removeRow.dispose()
        
        // clearCart
        self.cartViewModel.addToCart(viewModel.products[0], productsUpdated: false)
        
        count = cartViewModel.products.count
        
        let expectation_clearCart = self.expectation(description: "count equals 0")
        let observer_clearCart = cartViewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if count > 0 && self.cartViewModel.products.count == 0 {
                print("count before and after clear: \(count), \(self.cartViewModel.products.count)")
                expectation_clearCart.fulfill()
            }
        })
        
        self.cartViewModel.clearCart()
        wait(for: [expectation_clearCart], timeout: 2)
        observer_clearCart.dispose()
        
    }
    
}
