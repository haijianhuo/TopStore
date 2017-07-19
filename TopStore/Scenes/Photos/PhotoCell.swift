//
//  PhotoCell.swift
//  TopStore
//
//  Created by Haijian Huo on 3/30/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

class PhotoCell: UICollectionViewCell {
    
    @IBOutlet var imageView: UIImageView!
        
    override var isSelected: Bool {
        willSet {
            self.layer.borderWidth = newValue ? 2 : 0
        }
    }

}
