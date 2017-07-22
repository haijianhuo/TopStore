//
//  CartCell.swift
//  TopStore
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class CartCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!

    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var photoView: UIImageView!
    
    @IBOutlet weak var photoButton: UIButton!
    
    var disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag() // because life cicle of every cell ends on prepare for reuse
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
