//
//  HHImageCropViewController.swift
//
//  Created by Haijian Huo on 8/12/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit
import CoreGraphics

#if CGFLOAT_IS_DOUBLE
    let kK: CGFloat = 9
#else
    let  kK: CGFloat = 0;
#endif

let kResetAnimationDuration: TimeInterval = 0.4
let kLayoutImageScrollViewAnimationDuration: CGFloat = 0.25

/**
 Types of supported crop modes.
 */

enum HHImageCropMode: UInt {
    case circle
    case square
    case custom
}

/**
 The `HHImageCropViewControllerDelegate` protocol defines messages sent to a image crop view controller delegate when crop image was canceled or the original image was cropped.
 */
@objc protocol HHImageCropViewControllerDelegate: class {


    /**
     Tells the delegate that crop image has been canceled.
     */
    @objc optional func imageCropViewControllerDidCancelCrop(controller: HHImageCropViewController)
    
    /**
     Tells the delegate that the original image will be cropped.
     */
    @objc optional func imageCropViewController(controller: HHImageCropViewController, willCropImage originalImage: UIImage)
    
    /**
     Tells the delegate that the original image has been cropped. Additionally provides a crop rect used to produce image.
     */
    @objc optional func imageCropViewController(controller: HHImageCropViewController, didCropImage croppedImage: UIImage?, usingCropRect cropRect: CGRect)
    
    /**
     Tells the delegate that the original image has been cropped. Additionally provides a crop rect and a rotation angle used to produce image.
     */
    @objc optional func imageCropViewController(controller: HHImageCropViewController, didCropImage croppedImage: UIImage?, usingCropRect cropRect: CGRect, rotationAngle: CGFloat)

}


/**
 The `HHImageCropViewControllerDataSource` protocol is adopted by an object that provides a custom rect and a custom path for the mask.
 */
@objc protocol HHImageCropViewControllerDataSource: class {

    /**
     Asks the data source a custom rect for the mask.
     
     @param controller The crop view controller object to whom a rect is provided.
     
     @return A custom rect for the mask.
     
     @discussion Only valid if `cropMode` is `HHImageCropModeCustom`.
     */
    @objc func imageCropViewControllerCustomMaskRect(controller: HHImageCropViewController) -> CGRect
    
    /**
     Asks the data source a custom path for the mask.
     
     @param controller The crop view controller object to whom a path is provided.
     
     @return A custom path for the mask.
     
     @discussion Only valid if `cropMode` is `HHImageCropModeCustom`.
     */
    @objc func imageCropViewControllerCustomMaskPath(controller: HHImageCropViewController) -> UIBezierPath
    
    
    
    
    /**
     Asks the data source a custom rect in which the image can be moved.
     
     @param controller The crop view controller object to whom a rect is provided.
     
     @return A custom rect in which the image can be moved.
     
     @discussion Only valid if `cropMode` is `HHImageCropModeCustom`. If you want to support the rotation  when `cropMode` is `HHImageCropModeCustom` you must implement it. Will be marked as `required` in version `2.0.0`.
     */
    @objc optional func imageCropViewControllerCustomMovementRect(controller: HHImageCropViewController) -> CGRect
    
}


class HHImageCropViewController: UIViewController {
    
    ///-----------------------------
    /// @name Accessing the Delegate
    ///-----------------------------
    
    /**
     The receiver's delegate.
     
     @discussion A `HHImageCropViewControllerDelegate` delegate responds to messages sent by completing / canceling crop the image in the image crop view controller.
     */
    weak var delegate: HHImageCropViewControllerDelegate?
    
    /**
     The receiver's data source.
     
     @discussion A `HHImageCropViewControllerDataSource` data source provides a custom rect and a custom path for the mask.
     */
    weak var dataSource: HHImageCropViewControllerDataSource?
    
    ///--------------------------
    /// @name Accessing the Image
    ///--------------------------
    
    /**
     The image for cropping.
     */
    
    var _originalImage: UIImage?
    var originalImage: UIImage? {
        set {
            var shouldSet = false
            
            if let _originalImage = _originalImage {
                if !_originalImage.isEqual(newValue) {
                    shouldSet = true
                }
            }
            else {
                shouldSet = true
            }
            
            if shouldSet {
                _originalImage = newValue
                if (self.isViewLoaded && self.view.window != nil) {
                    self.displayImage()
                }
            }
        }
        get {
            return _originalImage
        }
    }
    
    /// -----------------------------------
    /// @name Accessing the Mask Attributes
    /// -----------------------------------
    
    /**
     The color of the layer with the mask. Default value is [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.7f].
     */
    var _maskLayerColor: UIColor?
    var maskLayerColor: UIColor {
        set {
            _maskLayerColor = newValue
        }
        get {
            let maskLayerColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.7)
            _maskLayerColor = maskLayerColor
            return maskLayerColor
        }
    }
    
    /**
     The line width used when stroking the path of the mask layer. Default value is 1.0.
     */
    var maskLayerLineWidth: CGFloat = 1.0
    
    /**
     The color to fill the stroked outline of the path of the mask layer, or nil for no stroking. Default valus is nil.
     */
    var maskLayerStrokeColor: UIColor?
    
    /**
     The rect of the mask.
     
     @discussion Updating each time before the crop view lays out its subviews.
     */
    private(set) var maskRect: CGRect = .zero
    
    /**
     The path of the mask.
     
     @discussion Updating each time before the crop view lays out its subviews.
     */
    var _maskPath: UIBezierPath?
    private(set) var maskPath: UIBezierPath? {
        
        set {
            var shouldSet = false
            
            if let _maskPath = _maskPath {
                if !_maskPath.isEqual(newValue) {
                    shouldSet = true
                }
            }
            else {
                shouldSet = true
            }
            
            if shouldSet {
                _maskPath = newValue
                if let _maskPath = _maskPath {
                    let clipPath = UIBezierPath(rect: self.rectForClipPath)
                    clipPath.append(_maskPath)
                    clipPath.usesEvenOddFillRule = true
                    let pathAnimation = CABasicAnimation(keyPath: "path")
                    pathAnimation.duration = CATransaction.animationDuration()
                    pathAnimation.timingFunction = CATransaction.animationTimingFunction()
                    self.maskLayer.add(pathAnimation, forKey: "path")
                    self.maskLayer.path = clipPath.cgPath
                }
            }
        }
        
        get {
            return _maskPath
        }
    
    }
    /// -----------------------------------
    /// @name Accessing the Crop Attributes
    /// -----------------------------------
    
    /**
     The mode for cropping. Default value is `HHImageCropModeCircle`.
     */
    var _cropMode: HHImageCropMode?
    var cropMode: HHImageCropMode? {
        set {
            var shouldSet = false
            if let _scropMode = _cropMode {
                if _scropMode != newValue  {
                    shouldSet = true
                }
            }
            else {
                shouldSet = true
            }

            if shouldSet {
                _cropMode = newValue
                if self.imageScrollView.zoomView != nil {
                    //[self reset:NO];
                }

            }
        }
        get {
            return _cropMode
        }
    }
    
    /**
     The crop rectangle.
     
     @discussion The value is calculated at run time.
     */
    private var _cropRect: CGRect?
    private(set) var cropRect: CGRect {
        set {
            _cropRect = newValue
        }
        get {
            if let cropRect = _cropRect {
                return cropRect
            }
            else {
                
                var cropRect: CGRect = .zero
                let zoomScale = 1.0 / self.imageScrollView.zoomScale
                
                cropRect.origin.x = round(self.imageScrollView.contentOffset.x * zoomScale)
                cropRect.origin.y = round(self.imageScrollView.contentOffset.y * zoomScale)
                cropRect.size.width = self.imageScrollView.bounds.width * zoomScale
                cropRect.size.height = self.imageScrollView.bounds.height * zoomScale
                
                let width = cropRect.width
                let height = cropRect.height
                let ceilWidth = ceil(width)
                let ceilHeight = ceil(height)
                
                if (fabs(ceilWidth - width) < pow(10, kK) * HH_EPSILON *  fabs(ceilWidth + width) || fabs(ceilWidth - width) < HH_MIN ||
                    fabs(ceilHeight - height) < pow(10, kK) * HH_EPSILON * fabs(ceilHeight + height) || fabs(ceilHeight - height) < HH_MIN) {
                    
                    cropRect.size.width = ceilWidth
                    cropRect.size.height = ceilHeight
                } else {
                    cropRect.size.width = floor(width)
                    cropRect.size.height = floor(height)
                }
                
                _cropRect = cropRect
                return cropRect
            }
        }

    }

    /**
     A value that specifies the current rotation angle of the image in radians.
     
     @discussion The value is calculated at run time.
     */
    private var _rotationAngle: CGFloat?
    private(set) var rotationAngle: CGFloat {
        set {
            if _rotationAngle != newValue {
                let rotation = (newValue - self.rotationAngle)
                let transform = self.imageScrollView.transform.rotated(by: rotation)
                self.imageScrollView.transform = transform
                _rotationAngle = newValue

            }
        }
        get {
            if let rotationAngle = _rotationAngle {
                return rotationAngle
            }
            else {
                let transform = self.imageScrollView.transform
                let rotationAngle = atan2(transform.b, transform.a)
                _rotationAngle = rotationAngle
                return rotationAngle
            }
        }
    }
    

    
    /**
     A floating-point value that specifies the current scale factor applied to the image.
     
     @discussion The value is calculated at run time.
     */
    var zoomScale: CGFloat {
        set {
            self.imageScrollView.zoomScale = newValue
        }
        get {
            return self.imageScrollView.zoomScale
        }
    }
    
    /**
     A Boolean value that determines whether the image will always fill the mask space. Default value is `NO`.
     */
    var _avoidEmptySpaceAroundImage: Bool = false
    var avoidEmptySpaceAroundImage: Bool {
        set {
            _avoidEmptySpaceAroundImage = newValue
            self.imageScrollView.aspectFill = newValue
        }
        get {
            return _avoidEmptySpaceAroundImage
        }
    }
    
    /**
     A Boolean value that determines whether the image will always bounce horizontally. Default value is `NO`.
     */
    var _alwaysBounceHorizontal: Bool = false
    var alwaysBounceHorizontal: Bool {
        set {
            _alwaysBounceHorizontal = newValue
            self.imageScrollView.alwaysBounceHorizontal = newValue
        }
        get {
            return _alwaysBounceHorizontal
        }
        
    }
    
    /**
     A Boolean value that determines whether the image will always bounce vertically. Default value is `NO`.
     */
    var _alwaysBounceVertical: Bool = false
    var alwaysBounceVertical: Bool {
        set {
            _alwaysBounceVertical = newValue
            self.imageScrollView.alwaysBounceVertical = newValue;
        }
        get {
            return _alwaysBounceVertical
        }
    }
    
    /**
     A Boolean value that determines whether the mask applies to the image after cropping. Default value is `NO`.
     */
    var applyMaskToCroppedImage: Bool = false
    
    /**
     A Boolean value that controls whether the rotaion gesture is enabled. Default value is `NO`.
     
     @discussion To support the rotation when `cropMode` is `HHImageCropModeCustom` you must implement the data source method `imageCropViewControllerCustomMovementRect:`.
     */
    var _rotationEnabled: Bool = true
    var rotationEnabled: Bool {
        set {
            _rotationEnabled = newValue
            self.rotationGestureRecognizer.isEnabled = newValue
        }
        get {
            return _rotationEnabled
        }
    }
    
    /// -------------------------------
    /// @name Accessing the UI Elements
    /// -------------------------------
    
    /**
     The Title Label.
     */
    private var _moveAndScaleLabel: UILabel?
    private(set) var moveAndScaleLabel: UILabel {
        set {
            _moveAndScaleLabel = newValue
        }
        get {
            if let moveAndScaleLabel = _moveAndScaleLabel {
                return moveAndScaleLabel
            }
            else {
                
                let moveAndScaleLabel = UILabel()
                moveAndScaleLabel.translatesAutoresizingMaskIntoConstraints = false
                moveAndScaleLabel.backgroundColor = .clear
                moveAndScaleLabel.text = "Move, Scale and Rotate"
                moveAndScaleLabel.textColor = .white
                moveAndScaleLabel.isOpaque = false
                //moveAndScaleLabel.isHidden = true
                _moveAndScaleLabel = moveAndScaleLabel
                return moveAndScaleLabel
            }
        }

    }
    
    
    
    /**
     The Cancel Button.
     */
    private var _cancelButton: UIButton?
    private(set) var cancelButton: UIButton {
        set {
            _cancelButton = newValue
        }
        get {
            if let cancelButton = _cancelButton {
                return cancelButton
            }
            else {
                let cancelButton = UIButton()
                cancelButton.translatesAutoresizingMaskIntoConstraints = false
                cancelButton.setTitle("Cancel", for: .normal)
                cancelButton.setTitleColor(.gray, for: .highlighted)
                cancelButton.addTarget(self, action: #selector(onCancelButtonTouch(_ :)), for: .touchUpInside)
                cancelButton.isOpaque = false
                _cancelButton = cancelButton
                return cancelButton
            }
        }
    }
    
    
    
    /**
     The Choose Button.
     */
    private var _chooseButton: UIButton?
    private(set) var chooseButton: UIButton {
        set {
            _chooseButton = newValue
        }
        get {
            if let chooseButton = _chooseButton {
                return chooseButton
            }
            else {
                let chooseButton = UIButton()
                chooseButton.translatesAutoresizingMaskIntoConstraints = false
                chooseButton.setTitle("Choose", for: .normal)
                chooseButton.setTitleColor(.gray, for: .highlighted)
                chooseButton.addTarget(self, action: #selector(onChooseButtonTouch(_ :)), for: .touchUpInside)
                chooseButton.isOpaque = false
                
                _chooseButton = chooseButton
                return chooseButton
            }
        }

    }
    
    /// -------------------------------------------
    /// @name Checking of the Interface Orientation
    /// -------------------------------------------
    
    /**
     Returns a Boolean value indicating whether the user interface is currently presented in a portrait orientation.
     
     @return YES if the interface orientation is portrait, otherwise returns NO.
     */
    //- (BOOL)isPortraitInterfaceOrientation;
    
    /// -------------------------------------
    /// @name Accessing the Layout Attributes
    /// -------------------------------------
    
    /**
     The inset of the circle mask rect's area within the crop view's area in portrait orientation. Default value is `15.0f`.
     */
    var portraitCircleMaskRectInnerEdgeInset: CGFloat = 15.0
    
    /**
     The inset of the square mask rect's area within the crop view's area in portrait orientation. Default value is `20.0f`.
     */
    var portraitSquareMaskRectInnerEdgeInset: CGFloat = 20.0
    
    /**
     The vertical space between the top of the 'Move and Scale' label and the top of the crop view in portrait orientation. Default value is `64.0f`.
     */
    var portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace: CGFloat = 64.0
    
    /**
     The vertical space between the bottom of the crop view and the bottom of the 'Cancel' button in portrait orientation. Default value is `21.0f`.
     */
    var portraitCropViewBottomAndCancelButtonBottomVerticalSpace: CGFloat = 21.0
    
    /**
     The vertical space between the bottom of the crop view and the bottom of the 'Choose' button in portrait orientation. Default value is `21.0f`.
     */
    var portraitCropViewBottomAndChooseButtonBottomVerticalSpace: CGFloat = 21.0
    
    /**
     The horizontal space between the leading of the 'Cancel' button and the leading of the crop view in portrait orientation. Default value is `13.0f`.
     */
    var portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace: CGFloat = 13.0
    
    /**
     The horizontal space between the trailing of the crop view and the trailing of the 'Choose' button in portrait orientation. Default value is `13.0f`.
     */
    var portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace: CGFloat = 13.0
    
    /**
     The inset of the circle mask rect's area within the crop view's area in landscape orientation. Default value is `45.0f`.
     */
    var landscapeCircleMaskRectInnerEdgeInset: CGFloat = 45.0
    
    /**
     The inset of the square mask rect's area within the crop view's area in landscape orientation. Default value is `45.0f`.
     */
    var landscapeSquareMaskRectInnerEdgeInset: CGFloat = 45.0
    
    /**
     The vertical space between the top of the 'Move and Scale' label and the top of the crop view in landscape orientation. Default value is `12.0f`.
     */
    var landscapeMoveAndScaleLabelTopAndCropViewTopVerticalSpace: CGFloat = 12.0
    
    /**
     The vertical space between the bottom of the crop view and the bottom of the 'Cancel' button in landscape orientation. Default value is `12.0f`.
     */
    var landscapeCropViewBottomAndCancelButtonBottomVerticalSpace: CGFloat = 12.0
    
    /**
     The vertical space between the bottom of the crop view and the bottom of the 'Choose' button in landscape orientation. Default value is `12.0f`.
     */
    var landscapeCropViewBottomAndChooseButtonBottomVerticalSpace: CGFloat = 12.0
    
    /**
     The horizontal space between the leading of the 'Cancel' button and the leading of the crop view in landscape orientation. Default value is `13.0f`.
     */
    var landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace: CGFloat = 13.0
    
    /**
     The horizontal space between the trailing of the crop view and the trailing of the 'Choose' button in landscape orientation. Default value is `13.0f`.
     */
    var landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace: CGFloat = 13.0
    
    // private
    
    private var originalNavigationControllerNavigationBarHidden: Bool = false
    private var originalNavigationControllerNavigationBarShadowImage: UIImage?
    private var originalNavigationControllerViewBackgroundColor: UIColor?
    private var originalStatusBarHidden: Bool = false
    

    private var _imageScrollView: HHImageScrollView?
    private var imageScrollView: HHImageScrollView {
        set {
            _imageScrollView = newValue
        }
        get {
            if let imageScrollView = _imageScrollView {
                return imageScrollView
            }
            else {
                let imageScrollView = HHImageScrollView()
                imageScrollView.clipsToBounds = false
                imageScrollView.aspectFill = self.avoidEmptySpaceAroundImage
                imageScrollView.alwaysBounceHorizontal = self.alwaysBounceHorizontal
                imageScrollView.alwaysBounceVertical = self.alwaysBounceVertical
                _imageScrollView = imageScrollView
                return imageScrollView
            }
        }
    }
    
    
    
    
    private var _overlayView: HHTouchView?
    private var overlayView: HHTouchView {
        set {
            _overlayView = newValue
        }
        get {
            if let overlayView = _overlayView {
                return overlayView
            }
            else {
                let overlayView = HHTouchView()
                overlayView.receiver = self.imageScrollView
                overlayView.layer.addSublayer(self.maskLayer)
                _overlayView = overlayView
                return overlayView
            }
        }
    }
    
    
    private var _maskLayer: CAShapeLayer?
    private var maskLayer: CAShapeLayer {
        set {
            _maskLayer = newValue
        }
        get {
            if let maskLayer = _maskLayer {
                return maskLayer
            }
            else {
                let maskLayer = CAShapeLayer()
                maskLayer.fillRule = kCAFillRuleEvenOdd
                maskLayer.fillColor = self.maskLayerColor.cgColor
                maskLayer.lineWidth = self.maskLayerLineWidth
                
                if let maskLayerStrokeColor = self.maskLayerStrokeColor {
                    maskLayer.strokeColor = maskLayerStrokeColor.cgColor
                }
                else {
                    maskLayer.strokeColor = nil
                }
                _maskLayer = maskLayer
                return maskLayer
            }
        }
    }
    
    
    private var rectForMaskPath: CGRect {
        get {
            if self.maskLayerStrokeColor == nil {
                return self.maskRect
            } else {
                let maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0
                return self.maskRect.insetBy(dx: maskLayerLineHalfWidth, dy: maskLayerLineHalfWidth)
            }
        }
    }
    
    private var rectForClipPath: CGRect {
        get {
            if self.maskLayerStrokeColor == nil {
                return self.overlayView.frame
            } else {
                let maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0
                return self.overlayView.frame.insetBy(dx: -maskLayerLineHalfWidth, dy: -maskLayerLineHalfWidth)
            }
        }
    }
    
    private var _doubleTapGestureRecognizer: UITapGestureRecognizer?
    private var doubleTapGestureRecognizer: UITapGestureRecognizer {
        set {
            _doubleTapGestureRecognizer = newValue
        }
        get {
            if let doubleTapGestureRecognizer = _doubleTapGestureRecognizer {
                return doubleTapGestureRecognizer
            }
            else {
                let doubleTapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleDoubleTap(_:)))
                
                doubleTapGestureRecognizer.delaysTouchesEnded = false
                doubleTapGestureRecognizer.numberOfTapsRequired = 2
                doubleTapGestureRecognizer.delegate = self

                _doubleTapGestureRecognizer = doubleTapGestureRecognizer
                return doubleTapGestureRecognizer
            }
        }

    }

    private var _rotationGestureRecognizer: UIRotationGestureRecognizer?
    private var rotationGestureRecognizer: UIRotationGestureRecognizer {
        set {
            _rotationGestureRecognizer = newValue
        }
        get {
            if let rotationGestureRecognizer = _rotationGestureRecognizer {
                return rotationGestureRecognizer
            }
            else {
                let rotationGestureRecognizer = UIRotationGestureRecognizer(target:self, action: #selector(handleRotation(_:)))
                rotationGestureRecognizer.delaysTouchesEnded = false
                rotationGestureRecognizer.delegate = self
                rotationGestureRecognizer.isEnabled = self.rotationEnabled
                _rotationGestureRecognizer = rotationGestureRecognizer
                return rotationGestureRecognizer
            }
        }
        
    }
    
    private var didSetupConstraints: Bool = false
    
    private var moveAndScaleLabelTopConstraint: NSLayoutConstraint?
    
    
    private var cancelButtonBottomConstraint: NSLayoutConstraint?
    private var cancelButtonLeadingConstraint: NSLayoutConstraint?
    private var chooseButtonBottomConstraint: NSLayoutConstraint?
    private var chooseButtonTrailingConstraint: NSLayoutConstraint?
    

    // MARK: - Lifecycle
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)   {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    convenience init(image: UIImage) {
        self.init()
        
        self.originalImage = image;
        self.avoidEmptySpaceAroundImage = false
        self.alwaysBounceVertical = false
        self.alwaysBounceHorizontal = false
        self.applyMaskToCroppedImage = false
        self.maskLayerLineWidth = 1.0
        self.rotationEnabled = false
        self.cropMode = .circle
        
        self.portraitCircleMaskRectInnerEdgeInset = 15.0
        self.portraitSquareMaskRectInnerEdgeInset = 20.0
        self.portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace = 64.0
        self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace = 21.0
        self.portraitCropViewBottomAndChooseButtonBottomVerticalSpace = 21.0
        self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace = 13.0
        self.portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace = 13.0
        
        self.landscapeCircleMaskRectInnerEdgeInset = 45.0
        self.landscapeSquareMaskRectInnerEdgeInset = 45.0
        self.landscapeMoveAndScaleLabelTopAndCropViewTopVerticalSpace = 12.0
        self.landscapeCropViewBottomAndCancelButtonBottomVerticalSpace = 12.0
        self.landscapeCropViewBottomAndChooseButtonBottomVerticalSpace = 12.0
        self.landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace = 13.0
        self.landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace = 13.0

    }
    
    convenience init(image: UIImage, cropMode: HHImageCropMode) {
        self.init(image: image)
        
        self.originalImage = image
        self.cropMode = cropMode
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = []
        self.automaticallyAdjustsScrollViewInsets = false

        
        self.view.backgroundColor = .black
        self.view.clipsToBounds = true
        
        self.view.addSubview(self.imageScrollView)
        self.view.addSubview(self.overlayView)
        self.view.addSubview(self.moveAndScaleLabel)
        self.view.addSubview(self.cancelButton)
        self.view.addSubview(self.chooseButton)
        
        self.view.addGestureRecognizer(self.doubleTapGestureRecognizer)
        self.view.addGestureRecognizer(self.rotationGestureRecognizer)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.originalNavigationControllerViewBackgroundColor = self.navigationController?.view.backgroundColor
        self.navigationController?.view.backgroundColor = .black
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.updateMaskRect()
        self.layoutImageScrollView()
        self.layoutOverlayView()
        self.updateMaskPath()
        self.view.setNeedsUpdateConstraints()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    
        if self.imageScrollView.zoomView == nil {
            self.displayImage()
        }
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
    
        if (!self.didSetupConstraints) {
            // ---------------------------
            // The label "Move and Scale".
            // ---------------------------
            
            let constraint = NSLayoutConstraint(item: self.moveAndScaleLabel, attribute: .centerX, relatedBy: .equal,
                toItem: self.view, attribute: .centerX, multiplier:1.0,
                constant:0.0)
            
            
            self.view.addConstraint(constraint)
            
            var constant = self.portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace
            let moveAndScaleLabelTopConstraint = NSLayoutConstraint(item:self.moveAndScaleLabel, attribute: .top, relatedBy: .equal,
                toItem: self.view, attribute: .top, multiplier: 1.0,
                constant: constant)
            self.view.addConstraint(moveAndScaleLabelTopConstraint)
            self.moveAndScaleLabelTopConstraint = moveAndScaleLabelTopConstraint
        
            // --------------------
            // The button "Cancel".
            // --------------------
            
            constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace
            let cancelButtonLeadingConstraint = NSLayoutConstraint(item:self.cancelButton, attribute: .leading, relatedBy: .equal,
                toItem: self.view, attribute: .leading, multiplier:1.0,
                constant:constant)
            self.view.addConstraint(cancelButtonLeadingConstraint)
            self.cancelButtonLeadingConstraint = cancelButtonLeadingConstraint
            
            constant = self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace
            let cancelButtonBottomConstraint = NSLayoutConstraint(item:self.view, attribute: .bottom, relatedBy: .equal,
                toItem: self.cancelButton, attribute: .bottom, multiplier:1.0,
                constant:constant)
            self.view.addConstraint(cancelButtonBottomConstraint)
            self.cancelButtonBottomConstraint = cancelButtonBottomConstraint
            
            // --------------------
            // The button "Choose".
            // --------------------
            
            constant = self.portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace
            let chooseButtonTrailingConstraint = NSLayoutConstraint(item:self.view,  attribute: .trailing, relatedBy: .equal,
                toItem: self.chooseButton, attribute: .trailing, multiplier:1.0,
                constant:constant)
            self.view.addConstraint(chooseButtonTrailingConstraint)
            self.chooseButtonTrailingConstraint = chooseButtonTrailingConstraint
            
            constant = self.portraitCropViewBottomAndChooseButtonBottomVerticalSpace
            let chooseButtonBottomConstraint = NSLayoutConstraint(item: self.view, attribute: .bottom, relatedBy: .equal,
                toItem: self.chooseButton, attribute: .bottom, multiplier:1.0,
                constant:constant)
            self.view.addConstraint(chooseButtonBottomConstraint)
            self.chooseButtonBottomConstraint = chooseButtonBottomConstraint
            
            self.didSetupConstraints = true
        } else {
            if self.isPortraitInterfaceOrientation() {
                self.moveAndScaleLabelTopConstraint?.constant = self.portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace
                self.cancelButtonBottomConstraint?.constant = self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace
                self.cancelButtonLeadingConstraint?.constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace
                self.chooseButtonBottomConstraint?.constant = self.portraitCropViewBottomAndChooseButtonBottomVerticalSpace
                self.chooseButtonTrailingConstraint?.constant = self.portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace
            } else {
                self.moveAndScaleLabelTopConstraint?.constant = self.landscapeMoveAndScaleLabelTopAndCropViewTopVerticalSpace
                self.cancelButtonBottomConstraint?.constant = self.landscapeCropViewBottomAndCancelButtonBottomVerticalSpace
                self.cancelButtonLeadingConstraint?.constant = self.landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace
                self.chooseButtonBottomConstraint?.constant = self.landscapeCropViewBottomAndChooseButtonBottomVerticalSpace
                self.chooseButtonTrailingConstraint?.constant = self.landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace
            }
        }
    }

    
    // MARK: - Action handling
    
    func onCancelButtonTouch(_ sender: UIBarButtonItem) {
        self.cancelCrop()
    }
    
    func onChooseButtonTouch(_ sender: UIBarButtonItem) {
        self.cropImage()
    }
    
    func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        self.reset(animated: true)
    }
    
    func handleRotation(_ gestureRecognizer: UIRotationGestureRecognizer) {
        
        self.rotationAngle = self.rotationAngle + gestureRecognizer.rotation
        
        gestureRecognizer.rotation = 0

        if gestureRecognizer.state == .ended {
            UIView.animate(withDuration: TimeInterval(kLayoutImageScrollViewAnimationDuration), delay: 0.0, options: .beginFromCurrentState, animations: {
                self.layoutImageScrollView()
            }, completion: nil)
            
            
        }
    }

    // MARK:  Public
    
    func isPortraitInterfaceOrientation() -> Bool {
        return self.view.bounds.size.height > self.view.bounds.size.width
    }

    // MARK: Private
    
    func reset(animated: Bool) {
        if (animated) {
            UIView.beginAnimations("rsk_reset", context: nil)
            UIView.setAnimationCurve(.easeInOut)
            UIView.setAnimationDuration(kResetAnimationDuration)
            UIView.setAnimationBeginsFromCurrentState(true)
        }
        
        self.resetRotation()
        self.resetFrame()
        self.resetZoomScale()
        self.resetContentOffset()
        
        if animated {
            UIView.commitAnimations()
        }
    }
    
    func resetContentOffset() {
        
        guard let zoomView = self.imageScrollView.zoomView else { return }
        
        let boundsSize = self.imageScrollView.bounds.size
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
        
        self.imageScrollView.contentOffset = contentOffset
    }
    
    func resetFrame() {
        self.layoutImageScrollView()
    }
    
    func resetRotation() {
        self.rotationAngle = 0.0
    }
    
    func resetZoomScale() {
        guard let originalImage = self.originalImage else { return }
        
        var zoomScale: CGFloat
        if (self.view.bounds.width > self.view.bounds.height) {
            zoomScale = self.view.bounds.height / originalImage.size.height
        } else {
            zoomScale = self.view.bounds.width / originalImage.size.width;
        }
        self.imageScrollView.zoomScale = zoomScale
    }
    
    func intersectionPointsOfLineSegment(lineSegment: HHLineSegment, withRect rect:CGRect) -> [Any] {
        let top = HHLineSegmentMake(start: CGPoint(x: rect.minX, y: rect.minY),
                                    end: CGPoint(x: rect.maxX, y: rect.minY))
        
        let right = HHLineSegmentMake(start: CGPoint(x: rect.maxX, y: rect.minY),
                                      end: CGPoint(x: rect.maxX, y: rect.maxY))
        
        let bottom = HHLineSegmentMake(start: CGPoint(x: rect.minX, y: rect.maxY),
                                       end: CGPoint(x: rect.maxX, y: rect.maxY))
        
        let left = HHLineSegmentMake(start: CGPoint(x: rect.minX, y: rect.minY),
                                     end: CGPoint(x: rect.minX, y: rect.maxY))
        
        let p0 = HHLineSegmentIntersection(ls1: top, ls2: lineSegment)
        let p1 = HHLineSegmentIntersection(ls1: right, ls2: lineSegment)
        let p2 = HHLineSegmentIntersection(ls1: bottom, ls2: lineSegment)
        let p3 = HHLineSegmentIntersection(ls1: left, ls2: lineSegment)
        
        var intersectionPoints = [Any]()
        if (!HHPointIsNull(point: p0)) {
            intersectionPoints.append(p0)
        }
        if (!HHPointIsNull(point: p1)) {
            intersectionPoints.append(p1)
        }
        if (!HHPointIsNull(point: p2)) {
            intersectionPoints.append(p2)
        }
        if (!HHPointIsNull(point: p3)) {
            intersectionPoints.append(p3)
        }
        return intersectionPoints
    }
    
    func displayImage() {
        guard let originalImage = self.originalImage else { return }
        self.imageScrollView.displayImage(image: originalImage)
        self.reset(animated: false)
    }
    
    func layoutImageScrollView() {
        
        guard let cropMode = self.cropMode else { return }
        
        var frame: CGRect = .zero
        
        // The bounds of the image scroll view should always fill the mask area.
        switch (cropMode) {
        case .square:
            if (self.rotationAngle == 0.0) {
                frame = self.maskRect
            } else {
                // Step 1: Rotate the left edge of the initial rect of the image scroll view clockwise around the center by `rotationAngle`.
                let initialRect = self.maskRect
                let rotationAngle = self.rotationAngle
                
                let leftTopPoint = CGPoint(x: initialRect.origin.x, y: initialRect.origin.y)
                let leftBottomPoint = CGPoint(x: initialRect.origin.x, y: initialRect.origin.y + initialRect.size.height)
                let leftLineSegment = HHLineSegmentMake(start: leftTopPoint, end: leftBottomPoint)
                
                let pivot = HHRectCenterPoint(rect: initialRect)
                
                var alpha = fabs(rotationAngle)
                let rotatedLeftLineSegment = HHLineSegmentRotateAroundPoint(line: leftLineSegment, pivot: pivot, angle: alpha)
                
                // Step 2: Find the points of intersection of the rotated edge with the initial rect.
                var points = self.intersectionPointsOfLineSegment(lineSegment: rotatedLeftLineSegment, withRect: initialRect)
                
                // Step 3: If the number of intersection points more than one
                // then the bounds of the rotated image scroll view does not completely fill the mask area.
                // Therefore, we need to update the frame of the image scroll view.
                // Otherwise, we can use the initial rect.
                if (points.count > 1) {
                    // We have a right triangle.
                    
                    // Step 4: Calculate the altitude of the right triangle.
                    if ((alpha > .pi/2) && (alpha < .pi)) {
                        alpha = alpha - .pi/2;
                    } else if ((alpha > (.pi + .pi/2)) && (alpha < (.pi + .pi))) {
                        alpha = alpha - (.pi + .pi/2)
                    }
                    let sinAlpha = sin(alpha)
                    let cosAlpha = cos(alpha)
                    let hypotenuse = HHPointDistance(p1: (points[0] as AnyObject).cgPointValue, p2: (points[1] as AnyObject).cgPointValue)
                    let altitude: CGFloat = hypotenuse * sinAlpha * cosAlpha
                    
                    // Step 5: Calculate the target width.
                    let initialWidth = initialRect.width
                    let targetWidth = initialWidth + altitude * 2
                    
                    // Step 6: Calculate the target frame.
                    let scale = targetWidth / initialWidth
                    let center = HHRectCenterPoint(rect: initialRect)
                    frame = HHRectScaleAroundPoint(rect: initialRect, point: center, sx: scale, sy: scale)
                    
                    // Step 7: Avoid floats.
                    frame.origin.x = round(frame.minX)
                    frame.origin.y = round(frame.minY)
                    frame = frame.integral
                } else {
                    // Step 4: Use the initial rect.
                    frame = initialRect
                }
            }
        case .circle:
            frame = self.maskRect
        case .custom:
            if self.dataSource?.imageCropViewControllerCustomMovementRect != nil {
                frame = (self.dataSource?.imageCropViewControllerCustomMovementRect?(controller: self))!
            } else {
                // Will be changed to `CGRectNull` in version `2.0.0`.
                frame = self.maskRect
            }
        }
        
        let transform = self.imageScrollView.transform
        self.imageScrollView.transform = .identity
        self.imageScrollView.frame = frame
        self.imageScrollView.transform = transform
    }
    
    func layoutOverlayView() {
        let frame = CGRect(x: 0, y: 0, width: self.view.bounds.width * 2, height: self.view.bounds.height * 2)
        self.overlayView.frame = frame
    }
    
    func updateMaskRect() {
        
        guard let cropMode = self.cropMode else { return }

        switch cropMode {
        case .circle:
            let viewWidth = self.view.bounds.width
            let viewHeight = self.view.bounds.height
            
            var diameter: CGFloat
            if self.isPortraitInterfaceOrientation() {
                diameter = min(viewWidth, viewHeight) - self.portraitCircleMaskRectInnerEdgeInset * 2
            } else {
                diameter = min(viewWidth, viewHeight) - self.landscapeCircleMaskRectInnerEdgeInset * 2
            }
            
            let maskSize = CGSize(width: diameter, height: diameter)
            
            self.maskRect = CGRect(x: (viewWidth - maskSize.width) * 0.5,
                                   y: (viewHeight - maskSize.height) * 0.5,
                                   width: maskSize.width,
                                   height: maskSize.height)
            
        case .square:
            let viewWidth = self.view.bounds.width
            let viewHeight = self.view.bounds.height
            
            var length: CGFloat
            if self.isPortraitInterfaceOrientation() {
                length = min(viewWidth, viewHeight) - self.portraitSquareMaskRectInnerEdgeInset * 2
            } else {
                length = min(viewWidth, viewHeight) - self.landscapeSquareMaskRectInnerEdgeInset * 2
            }
            
            let maskSize = CGSize(width: length, height: length)
            
            self.maskRect = CGRect(x: (viewWidth - maskSize.width) * 0.5,
                                   y: (viewHeight - maskSize.height) * 0.5,
                                   width: maskSize.width,
                                   height: maskSize.height)
        case .custom:
            self.maskRect = (self.dataSource?.imageCropViewControllerCustomMaskRect(controller: self))!
        }
    }
    
    func updateMaskPath() {
        guard let cropMode = self.cropMode else { return }

        switch (cropMode) {
        case .circle:
            self.maskPath = UIBezierPath(ovalIn: self.rectForMaskPath)
        case .square:
            self.maskPath = UIBezierPath(rect: self.rectForMaskPath)
        case .custom:
            self.maskPath = (self.dataSource?.imageCropViewControllerCustomMaskPath(controller: self))!
        }
    }
    
    func croppedImage(image: UIImage, cropRect: CGRect, scale imageScale: CGFloat, orientation imageOrientation: UIImageOrientation) -> UIImage? {
        if let images = image.images {
            var croppedImages = [UIImage]()
            for image in images {
                if let croppedImage = self.croppedImage(image: image, cropRect:cropRect, scale:imageScale, orientation:imageOrientation) {
                    croppedImages.append(croppedImage)
                }
            }
            return UIImage.animatedImage(with: croppedImages, duration: image.duration)
        }
        else {
            if let croppedCGImage = image.cgImage?.cropping(to: cropRect) {
                let croppedImage = UIImage(cgImage: croppedCGImage, scale: imageScale, orientation: imageOrientation)
                return croppedImage
            }
            return nil
        }
    }
    
    func croppedImage(image: UIImage, cropMode: HHImageCropMode, cropRect: CGRect,  rotationAngle: CGFloat, zoomScale: CGFloat, maskPath: UIBezierPath, applyMaskToCroppedImage: Bool) -> UIImage? {
        
        var cropRect = cropRect
        
        // Step 1: check and correct the crop rect.
        let imageSize = image.size
        let x = cropRect.minX
        let y = cropRect.minY
        let width = cropRect.width
        let height = cropRect.height
        
        var imageOrientation = image.imageOrientation
        if (imageOrientation == .right || imageOrientation == .rightMirrored) {
            cropRect.origin.x = y
            cropRect.origin.y = round(imageSize.width - cropRect.width - x)
            cropRect.size.width = height
            cropRect.size.height = width
        } else if (imageOrientation == .left || imageOrientation == .leftMirrored) {
            cropRect.origin.x = round(imageSize.height - cropRect.height - y)
            cropRect.origin.y = x
            cropRect.size.width = height
            cropRect.size.height = width
        } else if (imageOrientation == .down || imageOrientation == .downMirrored) {
            cropRect.origin.x = round(imageSize.width - cropRect.width - x)
            cropRect.origin.y = round(imageSize.height - cropRect.height - y);
        }
        
        let imageScale = image.scale
        cropRect = cropRect.applying(CGAffineTransform(scaleX: imageScale, y: imageScale))
        
        // Step 2: create an image using the data contained within the specified rect.
        var croppedImage = self.croppedImage(image: image, cropRect: cropRect, scale: imageScale, orientation: imageOrientation)
        
        // Step 3: fix orientation of the cropped image.
        if let image = croppedImage {
            croppedImage = image.fixOrientation()
            imageOrientation = image.imageOrientation
        }
        
        // Step 4: If current mode is `HHImageCropModeSquare` and the image is not rotated
        // or mask should not be applied to the image after cropping and the image is not rotated,
        // we can return the cropped image immediately.
        // Otherwise, we must further process the image.
        if ((cropMode == .square || !applyMaskToCroppedImage) && rotationAngle == 0.0) {
            // Step 5: return the cropped image immediately.
            return croppedImage
        } else {
            // Step 5: create a new context.
            let maskSize = maskPath.bounds.integral.size
            let contextSize = CGSize(width: ceil(maskSize.width / zoomScale),
                                     height: ceil(maskSize.height / zoomScale))
            UIGraphicsBeginImageContextWithOptions(contextSize, false, imageScale)
            
            // Step 6: apply the mask if needed.
            if (applyMaskToCroppedImage) {
                // 6a: scale the mask to the size of the crop rect.
                let maskPathCopy = maskPath.copy() as! UIBezierPath
                let scale = 1 / zoomScale
                maskPathCopy.apply(CGAffineTransform(scaleX: scale, y: scale))
                
                // 6b: move the mask to the top-left.
                let translation = CGPoint(x: -maskPathCopy.bounds.minX,
                                          y: -maskPathCopy.bounds.minY);
                maskPathCopy.apply(CGAffineTransform(translationX: translation.x, y: translation.y))
                
                // 6c: apply the mask.
                maskPathCopy.addClip()
            }
            
            // Step 7: rotate the cropped image if needed.
            if (rotationAngle != 0) {
                if let image = croppedImage {
                    croppedImage = image.rotateByAngle(angleInRadians: rotationAngle)
                }
            }
            
            // Step 8: draw the cropped image.
            if let image = croppedImage {
                let point = CGPoint(x: round((contextSize.width - image.size.width) * 0.5),
                                    y: round((contextSize.height - image.size.height) * 0.5))
                image.draw(at: point)
            }
            
            // Step 9: get the cropped image affter processing from the context.
            croppedImage = UIGraphicsGetImageFromCurrentImageContext()
            
            // Step 10: remove the context.
            UIGraphicsEndImageContext()
            
            if let image = croppedImage {
                croppedImage = UIImage(cgImage: image.cgImage!, scale: imageScale, orientation:imageOrientation)
            }
            
            // Step 11: return the cropped image affter processing.
            return croppedImage
        }
    }
    
    func cropImage() {
        
        guard let originalImage = self.originalImage, let cropMode = self.cropMode, let maskPath = self.maskPath else { return }

        self.delegate?.imageCropViewController?(controller: self, willCropImage: originalImage)
        
        let cropRect = self.cropRect
        let rotationAngle = self.rotationAngle
        let zoomScale = self.imageScrollView.zoomScale
        let applyMaskToCroppedImage = self.applyMaskToCroppedImage
        
        DispatchQueue.global().async {
            let croppedImage = self.croppedImage(image: originalImage, cropMode: cropMode, cropRect: cropRect, rotationAngle: rotationAngle, zoomScale: zoomScale, maskPath: maskPath, applyMaskToCroppedImage: applyMaskToCroppedImage)
            
            DispatchQueue.main.async {
                self.delegate?.imageCropViewController?(controller: self, didCropImage: croppedImage, usingCropRect: cropRect, rotationAngle: rotationAngle)
                self.delegate?.imageCropViewController?(controller: self, didCropImage: croppedImage, usingCropRect: cropRect)
            }
        }
        
    }
    
    func cancelCrop() {
        self.delegate?.imageCropViewControllerDidCancelCrop?(controller: self)
    }

}

// MARK: HHImageCropViewController

extension HHImageCropViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true

    }
}
