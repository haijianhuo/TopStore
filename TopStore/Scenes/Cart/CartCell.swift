//
//  CartCell.swift
//  TopStore
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

@objc protocol CartCellDelegate: class {

    @objc optional func deleteButtonDidTap(_ cell: CartCell, _ sender: Any)
    
    @objc optional func photoButtonDidTap(_ cell: CartCell, _ sender: Any)
}

class CartCell: UITableViewCell {

    weak var delegate: CartCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!

    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var photoView: UIImageView!
    
    @IBOutlet weak var photoButton: UIButton!
    
    @IBAction func deleteButtonTapped(_ sender: Any) {
        self.delegate?.deleteButtonDidTap?(self, sender)
    }
    
    @IBAction func phototButtonTapped(_ sender: Any) {
        self.delegate?.photoButtonDidTap?(self, sender)
    }
}
