//
//  HHImageInfo.swift
//
//  Created by Haijian Huo on 8/3/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

@objc class HHImageInfo: NSObject {
    
    public var image: UIImage? // If nil, be sure to set either imageURL or canonicalImageURL.
    public var placeholderImage: UIImage? // Use this if all you have is a thumbnail and an imageURL.
    public var imageURL: URL?
    public var canonicalImageURL: URL? // since `imageURL` might be a filesystem URL from the local cache.
    public var altText: String?
    public var title: String?
    public var referenceRect: CGRect
    public var referenceView: UIView
    public var referenceContentMode: UIViewContentMode?
    public var referenceCornerRadius: CGFloat = 0
    public var userInfo = NSMutableDictionary()
    
    init(referenceRect: CGRect, referenceView: UIView) {
        self.referenceRect = referenceRect
        self.referenceView = referenceView
    }
    
    func displayableTitleAltTextSummary() -> String? {
        var text: String? = nil
        
        if let title = self.title {
            text = String(format:"%@", title)
        }
        else if let altText = self.altText {
            text = String(format:"%@", altText)
        }
        return text
    }
    
    func combinedTitleAndAltText() -> String {
        let text = NSMutableString()
        
        if let title = self.title {
            text.appendFormat("“%@”", title)
        }
        if let altText = self.altText {
            if altText != self.title {
                text.appendFormat("\n\n— — —\n\n%@", altText)
            }
        }
        return text as String
    }

//    - (NSMutableDictionary *)userInfo {
//    if (_userInfo == nil) {
//    _userInfo = [[NSMutableDictionary alloc] init];
//    }
//    return _userInfo;
//    }
    
//    - (NSString *)description {
//    return [NSString stringWithFormat:@"\
//    %@ %p \n\
//    imageURL: %@ \n\
//    referenceRect: (%g, %g) (%g, %g)",
//    
//    NSStringFromClass(self.class), self,
//    self.imageURL,
//    self.referenceRect.origin.x, self.referenceRect.origin.y, self.referenceRect.size.width, self.referenceRect.size.height
//    ];
//    }
//    
    func referenceRectCenter() -> CGPoint {
        return CGPoint(x: self.referenceRect.origin.x + self.referenceRect.size.width/2.0,
                       y: self.referenceRect.origin.y + self.referenceRect.size.height/2.0)
    }

}
