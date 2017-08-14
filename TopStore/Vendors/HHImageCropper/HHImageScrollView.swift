//
//  HHImageScrollView.swift
//  BoxAvatar
//
//  Created by Haijian Huo on 8/13/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit

class HHImageScrollView: UIScrollView {

    var zoomView: UIImageView?
    var aspectFill: Bool = false
    
    private var imageSize: CGSize?
    private var pointToCenterAfterResize: CGPoint = .zero
    private var scaleToRestoreAfterResize: CGFloat = 0
    private var sizeChanging: Bool = false
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.aspectFill = false
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.bouncesZoom = true
        self.scrollsToTop = false
        self.decelerationRate = UIScrollViewDecelerationRateFast
        self.delegate = self
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        self.centerZoomView()
    }
    
    func setAspectFill(aspectFill: Bool) {
        if self.aspectFill != aspectFill {
            self.aspectFill = aspectFill
            if self.zoomView != nil {
                self.setMaxMinZoomScalesForCurrentBounds()
                if (self.zoomScale < self.minimumZoomScale) {
                    self.zoomScale = self.minimumZoomScale
                }
            }
        }
    }
    
    override var frame: CGRect {
        willSet {
            self.sizeChanging = !newValue.size.equalTo(self.frame.size)
            
            if (self.sizeChanging) {
                self.prepareToResize()
            }
        }
        didSet {
            if (self.sizeChanging) {
                self.recoverFromResizing()
            }
            self.centerZoomView()
        }
    }
    
    // MARK: - Center zoomView within scrollView
    
    fileprivate func centerZoomView() {
        
        guard let zoomView = self.zoomView else { return }
        
        // center zoomView as it becomes smaller than the size of the screen
        
        // we need to use contentInset instead of contentOffset for better positioning when zoomView fills the screen
        if (self.aspectFill) {
            var top: CGFloat = 0
            var left: CGFloat = 0
            
            // center vertically
            if (self.contentSize.height < self.bounds.height) {
                top = (self.bounds.height - self.contentSize.height) * 0.5
            }
            
            // center horizontally
            if (self.contentSize.width < self.bounds.width) {
                left = (self.bounds.width - self.contentSize.width) * 0.5
            }
            
            self.contentInset = UIEdgeInsetsMake(top, left, top, left);
        } else {
            var frameToCenter = zoomView.frame
            
            // center horizontally
            if (frameToCenter.width < self.bounds.width) {
                frameToCenter.origin.x = (self.bounds.width - frameToCenter.width) * 0.5
            } else {
                frameToCenter.origin.x = 0
            }
            
            // center vertically
            if (frameToCenter.height < self.bounds.height) {
                frameToCenter.origin.y = (self.bounds.height - frameToCenter.height) * 0.5
            } else {
                frameToCenter.origin.y = 0
            }
            
            zoomView.frame = frameToCenter
        }
    }
    
    // MARK: - Configure scrollView to display new image
    
    func displayImage(image: UIImage) {
        // clear view for the previous image
        
        self.zoomView?.removeFromSuperview()
        self.zoomView = nil
        
        // reset our zoomScale to 1.0 before doing any further calculations
        self.zoomScale = 1.0
        
        // make views to display the new image
        let zoomView = UIImageView(image: image)
        
        self.addSubview(zoomView)
        self.zoomView = zoomView
        
        self.configureForImageSize(imageSize: image.size)
    }
    
    private func configureForImageSize(imageSize: CGSize) {
        
        self.imageSize = imageSize
        self.contentSize = imageSize
        self.setMaxMinZoomScalesForCurrentBounds()
        self.setInitialZoomScale()
        self.setInitialContentOffset()
        self.contentInset = .zero
    }
    
    private func setMaxMinZoomScalesForCurrentBounds() {
        
        guard let imageSize = self.imageSize else { return }
        
        let boundsSize = self.bounds.size
        
        // calculate min/max zoomscale
        let xScale = boundsSize.width  / imageSize.width    // the scale needed to perfectly fit the image width-wise
        let yScale = boundsSize.height / imageSize.height   // the scale needed to perfectly fit the image height-wise
        var minScale: CGFloat = 0
        if (!self.aspectFill) {
            minScale = min(xScale, yScale) // use minimum of these to allow the image to become fully visible
        } else {
            minScale = max(xScale, yScale) // use maximum of these to allow the image to fill the screen
        }
        var maxScale = max(xScale, yScale)
        
        // Image must fit/fill the screen, even if its size is smaller.
        let xImageScale = maxScale * imageSize.width / boundsSize.width
        let yImageScale = maxScale * imageSize.height / boundsSize.height
        var maxImageScale = max(xImageScale, yImageScale)
        
        maxImageScale = max(minScale, maxImageScale)
        maxScale = max(maxScale, maxImageScale)
        
        // don't let minScale exceed maxScale. (If the image is smaller than the screen, we don't want to force it to be zoomed.)
        if (minScale > maxScale) {
            minScale = maxScale;
        }
        
        self.maximumZoomScale = maxScale
        self.minimumZoomScale = minScale
    }
    
    private func setInitialZoomScale() {
        
        guard let imageSize = self.imageSize else { return }

        let boundsSize = self.bounds.size
        let xScale = boundsSize.width  / imageSize.width    // the scale needed to perfectly fit the image width-wise
        let yScale = boundsSize.height / imageSize.height   // the scale needed to perfectly fit the image height-wise
        let scale = max(xScale, yScale)
        self.zoomScale = scale
    }
    
    private func setInitialContentOffset() {
        
        guard let zoomView = self.zoomView else { return }
        
        let boundsSize = self.bounds.size
        let frameToCenter = zoomView.frame
        
        var contentOffset: CGPoint = .zero
        if (frameToCenter.width > boundsSize.width) {
            contentOffset.x = (frameToCenter.width - boundsSize.width) * 0.5
        } else {
            contentOffset.x = 0
        }
        if (frameToCenter.height > boundsSize.height) {
            contentOffset.y = (frameToCenter.height - boundsSize.height) * 0.5
        } else {
            contentOffset.y = 0
        }
        
        self.setContentOffset(contentOffset, animated: false)
    }
    
    // MARK:
    // MARK: Methods called during rotation to preserve the zoomScale and the visible portion of the image
    
    // MARK: Rotation support
    
    private func prepareToResize() {
        
        guard let zoomView = self.zoomView else { return }

        let boundsCenter = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        pointToCenterAfterResize = self.convert(boundsCenter, to: zoomView)
        
        self.scaleToRestoreAfterResize = self.zoomScale
        
        // If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
        // allowable scale when the scale is restored.
        if Float(self.scaleToRestoreAfterResize) <= Float(self.minimumZoomScale) + Float.ulpOfOne {
            self.scaleToRestoreAfterResize = 0
        }
    }
    
    private func recoverFromResizing() {
        
        guard let zoomView = self.zoomView else { return }

        self.setMaxMinZoomScalesForCurrentBounds()
        
        // Step 1: restore zoom scale, first making sure it is within the allowable range.
        let maxZoomScale = max(self.minimumZoomScale, scaleToRestoreAfterResize)
        self.zoomScale = min(self.maximumZoomScale, maxZoomScale)
        
        // Step 2: restore center point, first making sure it is within the allowable range.
        
        // 2a: convert our desired center point back to our own coordinate space
        let boundsCenter = self.convert(self.pointToCenterAfterResize, from: zoomView)
        
        // 2b: calculate the content offset that would yield that center point
        var offset = CGPoint(x: boundsCenter.x - self.bounds.size.width / 2.0,
                             y: boundsCenter.y - self.bounds.size.height / 2.0)
        
        // 2c: restore offset, adjusted to be within the allowable range
        let maxOffset = self.maximumContentOffset()
        let minOffset = self.minimumContentOffset()
        
        var realMaxOffset = min(maxOffset.x, offset.x)
        offset.x = max(minOffset.x, realMaxOffset)
        
        realMaxOffset = min(maxOffset.y, offset.y)
        offset.y = max(minOffset.y, realMaxOffset)
        
        self.contentOffset = offset
    }
    
    private func maximumContentOffset() -> CGPoint {
        let contentSize = self.contentSize
        let boundsSize = self.bounds.size
        return CGPoint(x: contentSize.width - boundsSize.width, y: contentSize.height - boundsSize.height)
    }
    
    private func minimumContentOffset() -> CGPoint {
        return .zero
    }
}

// MARK: UIScrollViewDelegate

extension HHImageScrollView: UIScrollViewDelegate
{
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.zoomView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.centerZoomView()
    }

}
