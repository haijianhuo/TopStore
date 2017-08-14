//
//  MeViewModel.swift
//  TopStore
//
//  Created by Haijian Huo on 8/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import RxSwift

class MeViewModel: NSObject
{
    private struct Static
    {
        static var instance: MeViewModel?
    }
    
    class var shared: MeViewModel
    {
        if Static.instance == nil
        {
            Static.instance = MeViewModel()
        }
        
        return Static.instance!
    }
    
    func destroy()
    {
        MeViewModel.Static.instance = nil
        print("\(#function), \(type(of: self)) *Log*")

    }
    
    var avatar = Variable<UIImage?>(nil)

    fileprivate override init() {
        super.init()
        
        print("\(#function), \(type(of: self)) *Log*")
        
        var image = getSavedImage(named: "avatar.png")
        if image == nil {
            image = UIImage(named: "Avatar")
        }
        self.avatar.value = image
    }
    
    deinit {
        print("\(#function), \(type(of: self)) *Log*")
    }

    func saveImage(image: UIImage) -> Bool {
        guard let data = UIImageJPEGRepresentation(image, 1) ?? UIImagePNGRepresentation(image) else {
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            try data.write(to: directory.appendingPathComponent("avatar.png")!)
            self.avatar.value = image
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }

    private func getSavedImage(named: String) -> UIImage? {
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent(named).path)
        }
        return nil
    }

}
