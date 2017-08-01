//
//  MainTabBarController.swift
//  TopStore
//
//  Created by Haijian Huo on 7/22/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        for viewController in self.viewControllers! {
            if viewController.isKind(of: UINavigationController.self) {
                _ = viewController.childViewControllers[0].view
            }
            else {
                _ = viewController.view
            }
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
