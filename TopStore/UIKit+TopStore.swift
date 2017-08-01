//
//  UIKit+TopStore.swift
//  TopStore
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

public extension UIView {
  @IBInspectable public var cornerRadius: CGFloat {
    get {
      return layer.cornerRadius
    }

    set {
      layer.cornerRadius = newValue
    }
  }
  @IBInspectable public var shadowRadius: CGFloat {
    get {
      return layer.shadowRadius
    }

    set {
      layer.shadowRadius = newValue
    }
  }
  @IBInspectable public var shadowOpacity: Float {
    get {
      return layer.shadowOpacity
    }

    set {
      layer.shadowOpacity = newValue
    }
  }
  @IBInspectable public var shadowColor: UIColor? {
    get {
      return layer.shadowColor != nil ? UIColor(cgColor: layer.shadowColor!) : nil
    }

    set {
      layer.shadowColor = newValue?.cgColor
    }
  }
  @IBInspectable public var shadowOffset: CGSize {
    get {
      return layer.shadowOffset
    }

    set {
      layer.shadowOffset = newValue
    }
  }
  @IBInspectable public var zPosition: CGFloat {
    get {
      return layer.zPosition
    }

    set {
      layer.zPosition = newValue
    }
  }
}

func viewController(forStoryboardName: String) -> UIViewController {
  return UIStoryboard(name: forStoryboardName, bundle: nil).instantiateInitialViewController()!
}

class TemplateImageView: UIImageView {
  @IBInspectable var templateImage: UIImage? {
    didSet {
      image = templateImage?.withRenderingMode(.alwaysTemplate)
    }
  }
}
