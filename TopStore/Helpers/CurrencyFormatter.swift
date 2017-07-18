//
//  CurrencyFormatter.swift
//  TopStore
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation

enum CurrencyFormatter {
  static let dollarsFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    return formatter
  }()
}

extension NumberFormatter {
  
  ///Convenience method to prevent having to cast floats to NSNumbers every single time.
  func rw_string(from float: Float) -> String? {
    return self.string(from: NSNumber(value: float))
  }
}
