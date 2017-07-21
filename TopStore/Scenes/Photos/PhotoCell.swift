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
        
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layer.borderColor = UIColor.red.cgColor
   }
    
}
