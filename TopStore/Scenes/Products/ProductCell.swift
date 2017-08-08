//
//  ProductCell.swift
//  TopStore
//
//  Created by Haijian Huo on 3/30/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

@objc protocol ProductCellDelegate: class {
    
    @objc optional func addButtonDidTap(_ cell: ProductCell, _ sender: Any)
    
    @objc optional func photoButtonDidTap(_ cell: ProductCell, _ sender: Any)
}


class ProductCell: UICollectionViewCell {
    
    weak var delegate: ProductCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var photoButton: UIButton!

    @IBOutlet var imageView: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        self.delegate?.addButtonDidTap?(self, sender)
    }
    
    @IBAction func phototButtonTapped(_ sender: Any) {
        self.delegate?.photoButtonDidTap?(self, sender)
    }

}
