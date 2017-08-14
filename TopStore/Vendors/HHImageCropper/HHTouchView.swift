//
//  HHTouchView.swift
//  BoxAvatar
//
//  Created by Haijian Huo on 8/13/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

class HHTouchView: UIView {

   weak var receiver: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.point(inside: point, with: event) {
            return self.receiver
        }
        return nil
    }
}
