//
//  UIImage+HHImageCropper.swift
//  BoxAvatar
//
//  Created by Haijian Huo on 8/13/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    
    func fixOrientation() -> UIImage {
        // No-op if the orientation is already correct.
        if (self.imageOrientation == .up) {
            return self
        }
        
        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform: CGAffineTransform = .identity
        
        switch (self.imageOrientation) {
        case .down , .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: self.size.height)
            transform = transform.rotated(by: .pi);
        case .left , .leftMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0);
            transform = transform.rotated(by: .pi/2)
        case .right , .rightMirrored:
            transform = transform.translatedBy(x: 0, y: self.size.height);
            transform = transform.rotated(by: -.pi/2)
        case .up , .upMirrored:
            break
        }
        
        switch (self.imageOrientation) {
        case .upMirrored , .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored , .rightMirrored:
            transform = transform.translatedBy(x: self.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up , .down, .left , .right:
            break
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        let ctx = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0, space: self.cgImage!.colorSpace!, bitmapInfo: self.cgImage!.bitmapInfo.rawValue)
        
        ctx!.concatenate(transform)
        switch (self.imageOrientation) {
        case .left , .leftMirrored , .right, .rightMirrored:
            ctx!.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: self.size.height, height: self.size.width))
        default:
            ctx!.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        }
        
        // And now we just create a new UIImage from the drawing context.
        let cgimg = ctx!.makeImage()
        let img = UIImage(cgImage: cgimg!)
        //CGContextRelease(ctx);
        //CGImageRelease(cgimg);
        
        return img
    }
    
    func rotateByAngle(angleInRadians: CGFloat) -> UIImage? {
        // Calculate the size of the rotated image.
        let rotatedView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.size.width, height: self.size.height))
        
        rotatedView.transform = CGAffineTransform(rotationAngle: angleInRadians)
        
        let rotatedViewSize = rotatedView.frame.size
        
        // Create a bitmap-based graphics context.
        UIGraphicsBeginImageContextWithOptions(rotatedViewSize, false, self.scale)
        
        let context = UIGraphicsGetCurrentContext()
        
        // Move the origin of the user coordinate system in the context to the middle.
        context!.translateBy(x: rotatedViewSize.width / 2, y: rotatedViewSize.height / 2)
        
        // Rotates the user coordinate system in the context.
        context!.rotate(by: angleInRadians)
        
        // Flip the handedness of the user coordinate system in the context.
        context!.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the image into the context.
        context!.draw(self.cgImage!, in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }

}
