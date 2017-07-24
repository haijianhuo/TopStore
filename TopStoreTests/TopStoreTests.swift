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
import ObjectMapper

// tests for ProductsViewModel and CartViewModel

class TopStoreTests: XCTestCase {
    
    var viewModel: ProductsViewModel!
    var cartViewModel: CartViewModel!
    var testProduct: Product!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        viewModel = ProductsViewModel()
        cartViewModel = CartViewModel.shared
        cartViewModel.clearCart()

        if let product = Product(JSONString: "{}") {
            product.identifier = 163606345
            product.url_small = "https://drscdn.500px.org/photo/163606345/m%3D1170_k%3D1_a%3D1/v2?client_application_id=40471&webp=true&sig=97f2ad47dcde9022cda41556c59ca504814f630335ade7e052cf60b95f6025ce"
            product.url_large = "https://drscdn.500px.org/photo/163606345/w%3D280_h%3D280/v2?client_application_id=40471&webp=true&v=3&sig=ee6f4ff5da669eeb48b9ca01d76d955931c9e8b3349460ae621ba1e6632d5989"
            product.name = "Cottage cheese with blueberries"
            product.price = 23
            testProduct = product
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        cartViewModel.destroy()
        viewModel = nil
        
        super.tearDown()
    }
    
    // enter search text to load first page
    func test_loadPage() {
        
        let searchText = "Cookie"
        
        let expectation = self.expectation(description: "name contains search text")
        let observer = viewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.viewModel.products.count > 0 {
                if let i = self.viewModel.products.index(where: { $0.name.contains(searchText) }) {
                    print("found product contains: \(self.viewModel.products[i].name)")
                    expectation.fulfill()
                }
            }
        })
        
        self.viewModel.loadPage(query: searchText, page: 1)
        
        wait(for: [expectation], timeout: 2)
        observer.dispose()
    }
    
    // loadNextPage
    func test_loadNextPage() {
        
        let searchText = "Cookie"
        viewModel.query = searchText
        viewModel.nextPage = 2
        
        let expectation = self.expectation(description: "name contains search text")
        let observer = viewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.viewModel.products.count > 0 {
                if let i = self.viewModel.products.index(where: { $0.name.contains(searchText) }) {
                    print("found product contains: \(self.viewModel.products[i].name)")
                    expectation.fulfill()
                }
            }
        })
        
        self.viewModel.loadNextPage()
        
        wait(for: [expectation], timeout: 2)
        observer.dispose()
    }
    
    // addToCart from product search
    func test_addToCart() {
        
        viewModel.products.append(testProduct)
        
        let count = cartViewModel.products.count
        
        let expectation = self.expectation(description: "count increase by 1")
        let observer = cartViewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.cartViewModel.products.count == count + 1 {
                print("count before and after add: \(count), \(self.cartViewModel.products.count)")
                expectation.fulfill()
            }
        })
        
        self.viewModel.addToCart(viewModel.products[0])
        
        wait(for: [expectation], timeout: 2)
        observer.dispose()
    }
    

    // removeRow from cart
    func test_removeRow() {
        
        cartViewModel.addToCart(testProduct, productsUpdated: false)

        let count = cartViewModel.products.count
        
        let expectation = self.expectation(description: "count decreased by 1")
        let observer = cartViewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.cartViewModel.products.count == count - 1 {
                print("count before and after delete: \(count), \(self.cartViewModel.products.count)")
                expectation.fulfill()
            }
        })
        
        cartViewModel.removeRow(at: IndexPath.init(row: 0, section: 0))
        wait(for: [expectation], timeout: 2)
        observer.dispose()
    }
    
    // clearCart
    func test_clearCart() {

        cartViewModel.addToCart(testProduct, productsUpdated: false)
        
        let count = cartViewModel.products.count
        
        let expectation = self.expectation(description: "count equals 0")
        let observer = cartViewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if count > 0 && self.cartViewModel.products.count == 0 {
                print("count before and after clear: \(count), \(self.cartViewModel.products.count)")
                expectation.fulfill()
            }
        })
        
        self.cartViewModel.clearCart()
        wait(for: [expectation], timeout: 2)
        observer.dispose()
    }
    
    // test of loading saved shopping cart on app start
    func test_loadCart() {

        cartViewModel.addToCart(testProduct, productsUpdated: false)
        
        cartViewModel.destroy()
        cartViewModel = CartViewModel.shared
        let count = cartViewModel.products.count
        print("load saved cart count: \(count)")
        XCTAssert(count == 1)
        
    }
    
}
