//
//  MeViewController.swift
//  TopStore
//
//  Created by Haijian Huo on 8/1/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit
import CircleMenu
import PopupDialog
import RxCocoa
import RxSwift

class MeViewController: UIViewController {

    @IBOutlet weak var avatarPulseButton: HHPulseButton!
    
    var disposeBag = DisposeBag()

    let viewModel = MeViewModel.shared

    fileprivate var circleMenu: CircleMenu?

    let items: [(icon: String, color: UIColor)] = [
        ("camera", UIColor(red:0.19, green:0.57, blue:1, alpha:1)),
        ("icon_search", UIColor(red:0.22, green:0.74, blue:0, alpha:1)),
        ("photo_library", UIColor(red:1, green:0.39, blue:0, alpha:1)),
        ]
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.avatarPulseButton.image = viewModel.avatar.value

        self.setupCircleMenu(self.items.count)
        
        self.avatarPulseButton.delegate = self
        
        self.bind()
        
        if let image = UIImage(named:"photo_background") {
            self.view.backgroundColor = UIColor(patternImage: image)
        }
        
        NotificationCenter.default.addObserver(self, selector:#selector(applicationDidBecomeActiveNotification(_:)), name:NSNotification.Name.UIApplicationDidBecomeActive, object:nil)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.avatarPulseButton.animate(start: true)
    }
    

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.avatarPulseButton.animate(start: false)
        
    }
    
    @objc func applicationDidBecomeActiveNotification(_ notification: NSNotification?) {
        
        self.avatarPulseButton.animate(start: true)
    }

    func bind() {
        self.viewModel.avatar.asObservable().subscribe(onNext: { [weak self] (image) in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.avatarPulseButton.image = image
            }
        }).disposed(by: disposeBag)
    }

    // MARK: - Circle Menu
    
    func setupCircleMenu(_ buttonsCount: Int) {
        let buttonSize: CGFloat = 50
        let distance: CGFloat = 80
        let bottomMargin: CGFloat = 5
        self.circleMenu = CircleMenu(
            frame: CGRect(x: (self.view.frame.size.width - buttonSize)/2, y: self.view.frame.size.height - buttonSize/2 - distance - bottomMargin, width: buttonSize, height: buttonSize),
            normalIcon:"icon_menu",
            selectedIcon:"icon_close",
            buttonsCount: buttonsCount,
            duration: 0.5,
            distance: Float(distance))
        
        if let circleMenu = self.circleMenu {
            circleMenu.delegate = self
            circleMenu.layer.cornerRadius = circleMenu.frame.size.width / 2.0
            circleMenu.alpha = 0
            
            self.view.addSubview(circleMenu)
            circleMenu.translatesAutoresizingMaskIntoConstraints = false
            
            // added constraints
            
            let centerXConstraint = NSLayoutConstraint(item: circleMenu, attribute: .centerX, relatedBy: .equal, toItem: self.avatarPulseButton,
                                                   attribute: .centerX, multiplier: 1, constant: 0)
            
            let centerYConstraint = NSLayoutConstraint(item: circleMenu, attribute: .centerY, relatedBy: .equal, toItem: self.avatarPulseButton,
                                                      attribute: .centerY, multiplier: 1, constant: 0)
            
            
            let heightConstraint = NSLayoutConstraint(item: circleMenu, attribute: .height, relatedBy: .equal, toItem: nil,
                                                       attribute: .height, multiplier: 1, constant: buttonSize)
            
            let widthConstraint = NSLayoutConstraint(item: circleMenu, attribute: .width, relatedBy: .equal, toItem: nil,
                                                        attribute: .width, multiplier: 1, constant: buttonSize)
            
            self.view.addConstraints([centerXConstraint, centerYConstraint, heightConstraint , widthConstraint])

        }
    }

    func showCircleMenu() {
        guard let circleMenu = self.circleMenu else { return }
        if circleMenu.alpha == 0 {
            DispatchQueue.main.async {
                circleMenu.alpha = 1
                if !circleMenu.buttonsIsShown() {
                    circleMenu.sendActions(for: .touchUpInside)
                }
            }
        }
    }
    
}

// MARK: - HHPulseButtonDelegate

extension MeViewController: HHPulseButtonDelegate {
    func pulseButton(view: HHPulseButton, buttonPressed sender: AnyObject) {
        view.animate(start: false)
        self.showCircleMenu()
    }
}

// MARK: - CircleMenuDelegate

extension MeViewController: CircleMenuDelegate
{
    
    func circleMenu(_ circleMenu: CircleMenu, willDisplay button: UIButton, atIndex: Int) {
        
        button.backgroundColor = items[atIndex].color
        
        button.setImage(UIImage(named: items[atIndex].icon), for: .normal)
        
        // set highlited image
        let highlightedImage  = UIImage(named: items[atIndex].icon)?.withRenderingMode(.alwaysTemplate)
        button.setImage(highlightedImage, for: .highlighted)
//        button.tintColor = UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.3)

    }
    
    func circleMenu(_ circleMenu: CircleMenu, buttonDidSelected button: UIButton, atIndex: Int) {
        
        self.menuCollapsed(circleMenu)
        
        let controller = HHAvatarPicker()
        controller.delegate = self
        
        switch atIndex {
        case 0:
            controller.avatarPickerMode = .camera
        case 1:
            controller.avatarPickerMode = .search
        case 2:
            controller.avatarPickerMode = .photo
        default:
            break
        }
        
        self.present(controller, animated: true, completion: nil)
    }

    func menuCollapsed(_ circleMenu: CircleMenu) {
        DispatchQueue.main.async {
            circleMenu.alpha = 0
            self.avatarPulseButton.animate(start: true)
        }
    }

}

// MARK: - HHAvatarPickerDelegate

extension MeViewController: HHAvatarPickerDelegate
{
    func photoPickerDidPickImage(_ image: UIImage?, controller: HHAvatarPicker) {
        if let image = image {
            self.avatarPulseButton.image = image
            _ = viewModel.saveImage(image: image)
        }
    }
}


