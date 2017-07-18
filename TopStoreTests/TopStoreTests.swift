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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testProductViewModel() {
        
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

        // removeRow
        count = viewModel.products.count
        
        let expectation_removeRow = self.expectation(description: "count decreased by 1")
        let observer_removeRow = viewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if self.viewModel.products.count == count - 1 {
                print("count before and after delete: \(count), \(self.viewModel.products.count)")
                expectation_removeRow.fulfill()
            }
        })
        
        self.viewModel.removeRow(at: IndexPath(row: 0, section: 0))
        
        wait(for: [expectation_removeRow], timeout: 2)
        observer_removeRow.dispose()
        
        // updateRow
        let added = self.viewModel.products[0].added
        
        let expectation_updateRow = self.expectation(description: "added flag toogles")
        let observer_updateRow = viewModel.productsUpdated.asObservable().subscribe(onNext: { (element) in
            if !added == self.viewModel.products[0].added {
                print("added flag before and after update: \(added), \(self.viewModel.products[0].added)")
                expectation_updateRow.fulfill()
            }
        })
        
        self.viewModel.updateRow(added: !added, at: IndexPath(row: 0, section: 0))
        
        wait(for: [expectation_updateRow], timeout: 2)
        observer_updateRow.dispose()

    }
    
}
