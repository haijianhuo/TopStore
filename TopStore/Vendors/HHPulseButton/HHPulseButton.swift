//
//  HHPulseButton.swift
//
//  Created by Haijian Huo on 7/30/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

protocol HHPulseButtonDelegate: class {
    func pulseButton(view: HHPulseButton, buttonPressed sender: AnyObject)
}

@IBDesignable class HHPulseButton: UIView {

    var view: UIView!

    weak var delegate: HHPulseButtonDelegate?

    @IBOutlet weak var pulseView: UIView!
    
    @IBOutlet weak var imageView: UIImageView!
    
    private var isAnimating = false
    lazy private var pulseAnimation : CABasicAnimation = self.initAnimation()

    @IBInspectable var image: UIImage? {
        get {
            return imageView.image
        }
        set(image) {
            imageView.image = image
        }
    }

    
    override init(frame: CGRect) {
        // 1. setup any properties here
        
        super.init(frame: frame)
        xibSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        // 1. setup any properties here
        
        super.init(coder: aDecoder)
        xibSetup()
    }

    private func xibSetup() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.buttonPressed(_:)))
        
        self.imageView.isUserInteractionEnabled = true
        self.imageView.addGestureRecognizer(tapGestureRecognizer)
        
        //self.pulseView.layer.add(self.pulseAnimation, forKey: nil)

        
    }
    
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        print("self.bounds.size: \(self.bounds.size)")
        self.pulseView.layer.cornerRadius = self.bounds.size.width/2
        self.pulseView.clipsToBounds = true
        self.pulseView.backgroundColor = .blue // UIColor(red: 171/255.0, green: 178/255.0, blue: 186/255.0, alpha: 0.5)
        self.pulseView.alpha = 0.2
        
        self.imageView.layer.cornerRadius = self.bounds.size.width*0.9/2
        self.imageView.clipsToBounds = true
    }

    func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: String(describing: HHPulseButton.self), bundle: bundle)
        
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        return view
    }

    func initAnimation() -> CABasicAnimation {
        let anim  = CABasicAnimation(keyPath: "transform.scale")
        anim.duration = 1
        anim.fromValue = 1
        anim.toValue = 1.1
        anim.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        anim.autoreverses = true
        anim.repeatCount = .greatestFiniteMagnitude
        return anim
    }

    func buttonPressed(_ sender: AnyObject) {
        if self.isAnimating {
            return
        }
        self.isAnimating = true

        UIView.animate(withDuration: 0.2,
                       animations:{
                        self.imageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                        
        }, completion: { (t) -> Void in
            UIView.animate(withDuration: 0.2,
                           animations:{
                            self.imageView.transform = CGAffineTransform.identity
                            
            }, completion: { (t) -> Void in
                self.delegate?.pulseButton(view: self, buttonPressed: sender)
                self.isAnimating = false
            })

         })
    }
    

    public func animate(start : Bool) {
        if start {
            self.pulseView.layer.add(pulseAnimation, forKey: nil)
        } else {
            self.pulseView.layer.removeAllAnimations()
            self.pulseView.layer.add(pulseAnimation, forKey: nil)
        }
    }

}
