//
//  MeViewController.swift
//  TopStore
//
//  Created by Haijian Huo on 8/1/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

class MeViewController: UIViewController {

    @IBOutlet weak var avatarPulseButton: HHPulseButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.avatarPulseButton.delegate = self
        
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
    
    func applicationDidBecomeActiveNotification(_ notification: NSNotification?) {
        
        self.avatarPulseButton.animate(start: true)
    }

}

extension MeViewController: HHPulseButtonDelegate {
    func pulseButton(view: HHPulseButton, buttonPressed sender: AnyObject) {
        print("buttonPressed")
    }
}
