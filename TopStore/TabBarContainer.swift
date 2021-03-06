//
//  TabBarContainer.swift
//  TopStore
//
//  Created by Haijian Huo on 8/6/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

enum TabBarButtonName: Int {
    case product = 0
    case photo
    case cart
}

class TabBarContainer: UIViewController {

    @IBOutlet var tabButtons: [MIBadgeButton]!
    
    let tabBarButtonImages = ["Box", "Photo", "Cart"]
    var currentTag: Int = 0

    var mainTabBarController: MainTabBarController {
        get {
            let ctrl = childViewControllers.first(where: { $0 is MainTabBarController })
            return ctrl as! MainTabBarController
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for button in tabButtons {
            let image = UIImage(named: tabBarButtonImages[button.tag])?.withRenderingMode(.alwaysTemplate)
            button.setImage(image, for: .normal)
            button.tintColor = (button.tag == self.currentTag) ? nil : .lightGray
            button.badgeEdgeInsets = UIEdgeInsetsMake(15, 0, 0, 15)
        }
    }
    
    @IBAction func tabButtonTapped(_ sender: UIButton) {
        
        if sender.tag == self.currentTag || sender.tag >= (self.mainTabBarController.tabBar.items?.count)! {
            return
        }
        
        DispatchQueue.main.async {
            for button in self.tabButtons {
                button.tintColor = (button.tag == sender.tag) ? nil : .lightGray
            }
        }
        
        self.mainTabBarController.selectedIndex = sender.tag
        self.currentTag = sender.tag

    }
    
    func tabBarButton(name: TabBarButtonName) -> MIBadgeButton? {
        if name.rawValue >= (self.mainTabBarController.tabBar.items?.count)! {
            return nil
        }
        return tabButtons[name.rawValue]
    }
    

}
