//
//  HHPhotoCell.swift
//
//  Created by Haijian Huo on 3/30/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

class HHPhotoCell: UICollectionViewCell {
    
    var imageView: UIImageView!
    
    var didSetupConstraints = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.borderColor = UIColor.red.cgColor
        
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(imageView)
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if (!self.didSetupConstraints) {
            self.contentView.addConstraint(NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal,
                                                              toItem: self.contentView, attribute: .top, multiplier:1.0,
                                                              constant:0.0))
            self.contentView.addConstraint(NSLayoutConstraint(item: imageView, attribute: .bottom, relatedBy: .equal,
                                                              toItem: self.contentView, attribute: .bottom, multiplier:1.0,
                                                              constant:0.0))
            self.contentView.addConstraint(NSLayoutConstraint(item: imageView, attribute: .leading, relatedBy: .equal,
                                                              toItem: self.contentView, attribute: .leading, multiplier:1.0,
                                                              constant:0.0))
            self.contentView.addConstraint(NSLayoutConstraint(item: imageView, attribute: .trailing, relatedBy: .equal,
                                                              toItem: self.contentView, attribute: .trailing, multiplier:1.0,
                                                              constant:0.0))
            
            self.didSetupConstraints = true
            
        }
    }
    
}
