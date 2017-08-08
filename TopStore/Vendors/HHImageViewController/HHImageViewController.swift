//
//  HHImageViewController.swift
//
//  Created by Haijian Huo on 8/3/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit
import CoreGraphics
import CircleMenu
import Kingfisher

// HHImageViewControllerDelegate

@objc protocol HHImageViewControllerDelegate: class {
    /**
     Called after the imageViewController has finished dismissing.
     */
    @objc optional func imageViewerDidDismiss(_ imageViewController: HHImageViewController) -> Bool
    
    /**
     Tells the delegate the circle menu is about to draw a button for a particular index.
     
     - parameter imageViewController: The imageViewController object informing the delegate of this impending event.
     - parameter button:     A circle menu button object that circle menu is going to use when drawing the row. Don't change button.tag
     - parameter atIndex:    An button index.
     */
    @objc optional func imageViewController(_ imageViewController: HHImageViewController, willDisplay button: UIButton, atIndex: Int) -> Bool
    
    /**
     Tells the delegate that the specified index is now selected.
     
     - parameter imageViewController: The imageViewController object informing the delegate of this impending event.
     - parameter button:     A selected circle menu button. Don't change button.tag
     - parameter atIndex:    Selected button index
     */
    @objc optional func imageViewController(_ imageViewController: HHImageViewController, buttonDidSelected button: UIButton, atIndex: Int, image: UIImage?) -> Bool

}

enum HHImageViewControllerMode: Int {
    case image = 0
}

enum HHImageViewControllerTransition: Int {
    case fromOriginalPosition = 0
    case fromOffscreen = 1
}

struct HHImageViewControllerBackgroundOptions : OptionSet {
    let rawValue: Int
    
    static let none  = HHImageViewControllerBackgroundOptions(rawValue: 0)
    static let scaled = HHImageViewControllerBackgroundOptions(rawValue: 1 << 0)
}

// Public Constants
let HHImageViewController_DefaultAlphaForBackgroundDimmingOverlay: CGFloat = 0.66
let HHImageViewController_DefaultBackgroundBlurRadius: CGFloat = 2.0

class HHImageViewController: UIViewController {

    weak var delegate: HHImageViewControllerDelegate?

    private(set) var imageInfo: HHImageInfo!
    private(set) var image: UIImage?
    private(set) var mode: HHImageViewControllerMode!
    private(set) var backgroundOptions: HHImageViewControllerBackgroundOptions!

    var showCircleMenuOnStart = false
    
    // Private Constants
    private let HHImageViewController_MinimumBackgroundScaling: CGFloat = 0.94
    private let HHImageViewController_TargetZoomForDoubleTap: CGFloat = 3.0
    private let HHImageViewController_MaxScalingForExpandingOffscreenStyleTransition: CGFloat = 1.25
    private let HHImageViewController_TransitionAnimationDuration: CGFloat = 0.3
    private let HHImageViewController_MinimumFlickDismissalVelocity: CGFloat = 800.0
    
    private struct HHImageViewControllerStartingInfo {
        var startingReferenceFrameForThumbnail: CGRect = .zero
        var startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation: CGRect = .zero
        var startingReferenceCenterForThumbnail: CGPoint = .zero
        var startingInterfaceOrientation: UIInterfaceOrientation = .portrait
        var presentingViewControllerPresentedFromItsUnsupportedOrientation: Bool = false
    }
    
    
    fileprivate struct HHImageViewControllerFlags {
        var isAnimatingAPresentationOrDismissal: Bool = false
        var isDismissing: Bool = false
        var isTransitioningFromInitialModalToInteractiveState: Bool = false
        var viewHasAppeared: Bool = false
        var isRotating: Bool = false
        var isPresented: Bool = false
        var rotationTransformIsDirty: Bool = false
        var imageIsFlickingAwayForDismissal: Bool = false
        var isDraggingImage: Bool = false
        var scrollViewIsAnimatingAZoom: Bool = false
        var imageIsBeingReadFromDisk: Bool = false
        var isManuallyResizingTheScrollViewFrame: Bool = false
        var imageDownloadFailed: Bool = false
    }
    
    // General Info

    private(set) var transition: HHImageViewControllerTransition?
    
    
    private var startingInfo = HHImageViewControllerStartingInfo()
    fileprivate var flags = HHImageViewControllerFlags()
    
    // Autorotation
    private(set) var lastUsedOrientation: UIInterfaceOrientation?
    private(set) var currentSnapshotRotationTransform: CGAffineTransform!
    
    // Views
    private(set) var progressContainer = UIView()
    private(set) var outerContainerForScrollView: UIView?
    private(set) var snapshotView: UIView?
    private(set) var blackBackdrop = UIView()
    private(set) var imageView = UIImageView()
    private(set) var scrollView = UIScrollView()
    private(set) var textView: UITextView?
    private(set) var progressView = UIProgressView(progressViewStyle: .default)
    private(set) var spinner = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    
    // Gesture Recognizers
    private(set) var singleTapperPhoto: UITapGestureRecognizer!
    private(set) var doubleTapperPhoto: UITapGestureRecognizer!
    private(set) var singleTapperText: UITapGestureRecognizer!
    private(set) var longPresserPhoto: UILongPressGestureRecognizer!
    private(set) var panRecognizer: UIPanGestureRecognizer!
    
    // UIDynamics
    private(set) var animator: UIDynamicAnimator!
    private(set) var attachmentBehavior: UIAttachmentBehavior?
    private(set) var imageDragStartingPoint: CGPoint?
    private(set) var imageDragOffsetFromActualTranslation: UIOffset?
    private(set) var imageDragOffsetFromImageCenter: UIOffset?
    
    // Image Downloading
    private(set) var imageDownloadDataTask: URLSessionDataTask?
    private(set) var downloadProgressTimer: Timer?

    private var circleMenu: CircleMenu?
    
    private var isStatusBarHidden = UIApplication.shared.isStatusBarHidden
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.delegate?.imageViewController?(self, willDisplay: UIButton(), atIndex: 0) != nil {
                self.setupCircleMenu()
        }
        
        if (self.mode == .image) {
            self.viewDidLoadForImageMode()
        }

    }
    
    deinit {
        //print("\(#function), \(type(of: self)) *Log*")
    }
    
    override func viewDidLayoutSubviews() {
        self.updateLayoutsForCurrentOrientation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.lastUsedOrientation != UIApplication.shared.statusBarOrientation {
            self.lastUsedOrientation = UIApplication.shared.statusBarOrientation
            self.flags.rotationTransformIsDirty = true
            self.updateLayoutsForCurrentOrientation()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.flags.viewHasAppeared = true
    }
    
    override var prefersStatusBarHidden: Bool {
        return self.isStatusBarHidden
    }
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        self.lastUsedOrientation = toInterfaceOrientation
        self.flags.rotationTransformIsDirty = true
        self.flags.isRotating = true
    }
    
    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        self.cancelCurrentImageDrag(animated: false)
        self.updateLayoutsForCurrentOrientation()
        self.updateDimmingViewForCurrentZoomScale(animated: false)
        
        let dispatchTime = DispatchTime.now()
        DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
            self.flags.isRotating = false
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.flags.rotationTransformIsDirty = true
        self.flags.isRotating = true
        
        coordinator.animate(alongsideTransition: { [weak self] (context) in
            guard let `self` = self else { return }
            self.cancelCurrentImageDrag(animated: false)
            self.updateLayoutsForCurrentOrientation()
            self.updateDimmingViewForCurrentZoomScale(animated: false)

        }, completion: { [weak self] (context) in
            guard let `self` = self else { return }
            self.lastUsedOrientation = UIApplication.shared.statusBarOrientation
            var flags = self.flags
            flags.isRotating = false
            self.flags = flags
            }
        )
    }
    

// MARK: - Public
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)   {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    convenience init(imageInfo: HHImageInfo, mode: HHImageViewControllerMode, backgroundStyle backgroundOptions: HHImageViewControllerBackgroundOptions) {
        self.init()
        
        NotificationCenter.default.addObserver(self, selector:#selector(deviceOrientationDidChange(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object:nil)
        
        self.imageInfo = imageInfo
        self.currentSnapshotRotationTransform = .identity
        self.mode = mode
        self.backgroundOptions = backgroundOptions
        if self.mode == .image {
            self.setupImageAndDownloadIfNecessary(imageInfo: imageInfo)
        }

    }
    
    func interfaceOrientation(from deviceOrientation: UIDeviceOrientation) ->UIInterfaceOrientation {
        
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .portrait
        }
    }
    
    
    func deviceOrientationDidChange(_ notification: NSNotification?) {
    
        /*
         viewWillTransitionToSize:withTransitionCoordinator: is not called when rotating from
         one landscape orientation to the other (or from one portrait orientation to another).
         This makes it difficult to preserve the desired behavior of JTSImageViewController.
         We want the background snapshot to maintain the illusion that it never rotates. The
         only other way to ensure that the background snapshot stays in the correct orientation
         is to listen for this notification and respond when we've detected a landscape-to-landscape rotation.
         */
        
        guard let lastUsedOrientation = self.lastUsedOrientation else { return }
        let deviceOrientation = UIDevice.current.orientation
        
        
        let landscapeToLandscape = UIDeviceOrientationIsLandscape(deviceOrientation) && UIInterfaceOrientationIsLandscape(lastUsedOrientation)
        
        
        let portraitToPortrait = UIDeviceOrientationIsPortrait(deviceOrientation) && UIInterfaceOrientationIsPortrait(lastUsedOrientation)
        
        if landscapeToLandscape || portraitToPortrait {
            let newInterfaceOrientation = self.interfaceOrientation(from: deviceOrientation)
            
            
            if (newInterfaceOrientation != self.lastUsedOrientation) {
                self.lastUsedOrientation = newInterfaceOrientation;
                self.flags.rotationTransformIsDirty = true
                self.flags.isRotating = true
                
                UIView.animate(withDuration: 0.6,
                               animations:{ [weak self] in
                                guard let `self` = self else { return }
                                self.cancelCurrentImageDrag(animated: false)
                                self.updateLayoutsForCurrentOrientation()
                                self.updateDimmingViewForCurrentZoomScale(animated: false)
                                
                }, completion: { [weak self] (finished) in
                    guard let `self` = self else { return }
                    var flags = self.flags
                    flags.isRotating = false
                    self.flags = flags
                })

            }
        }
    }

    func show(from viewController: UIViewController,
        transition: HHImageViewControllerTransition) {
            
            self.transition = transition
            
            if (self.mode == .image) {
                self.showImageViewerByExpandingFromOriginalPositionFromViewController(viewController: viewController)
            }
    }

    func dismiss(animated: Bool) {
    
        // Early Return!
        if !self.flags.isPresented {
            return
        }
        
        self.flags.isPresented = false
        
        if (self.mode == .image) {
            
            if self.flags.imageIsFlickingAwayForDismissal {
                self.dismissByCleaningUpAfterImageWasFlickedOffscreen()
            }
            else if (self.transition == .fromOffscreen) {
                self.dismissByExpandingImageToOffscreenPosition()
            }
            else {
                let startingRectForThumbnailIsNonZero = !self.startingInfo.startingReferenceFrameForThumbnail.equalTo(CGRect.zero)
                    
                 let useCollapsingThumbnailStyle = (startingRectForThumbnailIsNonZero
                    && self.image != nil
                    && self.transition != .fromOffscreen)
                
                if (useCollapsingThumbnailStyle) {
                    self.dismissByCollapsingImageBackToOriginalPosition()
                } else {
                    self.dismissByExpandingImageToOffscreenPosition()
                }
            }
        }
    }

// MARK: - Setup
    
    func setupCircleMenu() {
        let buttonSize: CGFloat = 50
        let distance: CGFloat = 80
        let bottomMargin: CGFloat = 5
        self.circleMenu = CircleMenu(
            frame: CGRect(x: (self.view.frame.size.width - buttonSize)/2, y: self.view.frame.size.height - buttonSize/2 - distance - bottomMargin, width: buttonSize, height: buttonSize),
            normalIcon:"icon_menu",
            selectedIcon:"icon_close",
            buttonsCount: 4,
            duration: 0.5,
            distance: Float(distance))
        
        if let circleMenu = self.circleMenu {
            circleMenu.delegate = self
            circleMenu.layer.cornerRadius = circleMenu.frame.size.width / 2.0
            circleMenu.alpha = 0
            
            circleMenu.autoresizingMask = [.flexibleRightMargin, .flexibleLeftMargin, .flexibleTopMargin]
            self.view.addSubview(circleMenu)
        }
    }
    
    func setupImageAndDownloadIfNecessary(imageInfo: HHImageInfo) {
        if let image = imageInfo.image {
            self.image = image;
        }
        else {
            self.image = imageInfo.placeholderImage
            
            let fromDisk = imageInfo.imageURL?.absoluteString.hasPrefix("file://")
            
            self.flags.imageIsBeingReadFromDisk = fromDisk!
            
            let task = self.downloadImage(for: imageInfo.imageURL!, completion: { [weak self] (image) in
                guard let `self` = self else {return }
                
                self.cancelProgressTimer()
                if image != nil {
                    if self.isViewLoaded {
                        self.updateInterfaceWithImage(image: image)
                    } else {
                        self.image = image
                    }
                } else if (self.image == nil) {
                    self.flags.imageDownloadFailed = true
                    
                    let dispatchTime = DispatchTime.now() + 0.5
                    DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
                        if (self.flags.isPresented && !self.flags.isAnimatingAPresentationOrDismissal) {
                            self.dismiss(animated: true)
                        }
                    }
                    
                    // If we're still presenting, at the end of presentation we'll auto dismiss.
                }
            })
            self.imageDownloadDataTask = task
            
            self.startProgressTimer()
        }
    }
    
    func viewDidLoadForImageMode() {
    
        self.view.backgroundColor = .black
        self.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        //self.blackBackdrop = [[UIView alloc] initWithFrame:CGRectInset(self.view.bounds, -512, -512)];
        
        self.blackBackdrop.frame = self.view.bounds.insetBy(dx: -512, dy: -512)
        self.blackBackdrop.backgroundColor = .black
        self.blackBackdrop.alpha = 0
        self.view.addSubview(self.blackBackdrop)

        //self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
        self.scrollView.frame = self.view.bounds
        self.scrollView.delegate = self
        self.scrollView.zoomScale = 1.0
        self.scrollView.maximumZoomScale = 8.0
        self.scrollView.isScrollEnabled = false
        self.scrollView.isAccessibilityElement = true
        self.scrollView.accessibilityLabel = self.accessibilityLabel
        self.view.addSubview(self.scrollView)
        
        let referenceFrameInWindow = self.imageInfo.referenceView.convert(self.imageInfo.referenceRect, to: nil)
        
        let referenceFrameInMyView = self.view.convert(referenceFrameInWindow, from: nil)
        
        //self.imageView = [[UIImageView alloc] initWithFrame:referenceFrameInMyView];
        self.imageView.frame = referenceFrameInMyView
        self.imageView.layer.cornerRadius = self.imageInfo.referenceCornerRadius
        self.imageView.contentMode = .scaleAspectFill
        self.imageView.isUserInteractionEnabled = true
        self.imageView.isAccessibilityElement = false
        self.imageView.clipsToBounds = true
        self.imageView.layer.allowsEdgeAntialiasing = true
        
        // We'll add the image view to either the scroll view
        // or the parent view, based on the transition style
        // used in the "show" method.
        // After that transition completes, the image view will be
        // added to the scroll view.
        
        self.setupImageModeGestureRecognizers()
        
        //self.progressContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 128.0f, 128.0f)];
        self.progressContainer.frame = CGRect(x: 0, y: 0, width: 128.0, height: 128.0)
        self.view.addSubview(self.progressContainer)
        
        //self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        
        self.progressView.progress = 0
        self.progressView.tintColor = .white
        self.progressView.trackTintColor = .darkGray
        var progressFrame = self.progressView.frame
        progressFrame.size.width = 128.0
        self.progressView.frame = progressFrame
        self.progressView.center = CGPoint(x: 64.0, y: 64.0)
        self.progressView.alpha = 0
        self.progressContainer.addSubview(self.progressView)
        
        //self.spinner = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        self.spinner.center = CGPoint(x: 64.0, y: 64.0)
        self.spinner.startAnimating()
        
        self.progressContainer.addSubview(self.spinner)
        self.progressContainer.alpha = 0
        
        self.animator = UIDynamicAnimator(referenceView: self.scrollView)
        if let image = self.image {
            self.updateInterfaceWithImage(image: image)
        }
        
    }
    
    
    func setupImageModeGestureRecognizers() {
    
        self.doubleTapperPhoto = UITapGestureRecognizer(target: self, action: #selector(imageDoubleTapped(_:)))
        self.doubleTapperPhoto.numberOfTapsRequired = 2
        self.doubleTapperPhoto.delegate = self
        
        
        self.longPresserPhoto = UILongPressGestureRecognizer(target: self, action: #selector(imageLongPressed(_:)))
        self.longPresserPhoto.delegate = self
        
        self.singleTapperPhoto = UITapGestureRecognizer(target: self, action: #selector(imageSingleTapped(_:)))

        
        self.singleTapperPhoto.require(toFail: self.doubleTapperPhoto)
        self.singleTapperPhoto.require(toFail: self.longPresserPhoto)
        self.singleTapperPhoto.delegate = self;
        
        self.view.addGestureRecognizer(self.singleTapperPhoto)
        self.view.addGestureRecognizer(self.doubleTapperPhoto)
        self.view.addGestureRecognizer(self.longPresserPhoto)
        
        self.panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(dismissingPanGestureRecognizerPanned(_:)))
        self.panRecognizer.maximumNumberOfTouches = 1
        self.panRecognizer.delegate = self
        self.scrollView.addGestureRecognizer(self.panRecognizer)
    }
    
    
// MARK: - Presentation
    
    func showImageViewerByExpandingFromOriginalPositionFromViewController(viewController: UIViewController) {
        
        self.flags.isAnimatingAPresentationOrDismissal = true
        self.view.isUserInteractionEnabled = false
        
        self.snapshotView = self.snapshotFromParentmostViewController(viewController: viewController)
        
        guard let snapshotView = self.snapshotView else {
            return
        }
        
        self.view.insertSubview(snapshotView, at:0)
        
        self.startingInfo.startingInterfaceOrientation = UIApplication.shared.statusBarOrientation
        
        self.lastUsedOrientation = UIApplication.shared.statusBarOrientation
        let referenceFrameInWindow = self.imageInfo.referenceView.convert(self.imageInfo.referenceRect, to: nil)
        
        self.startingInfo.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation = self.view.convert(referenceFrameInWindow, from:nil)
        
        if let referenceContentMode = self.imageInfo.referenceContentMode {
            self.imageView.contentMode = referenceContentMode
        }
        
        // This will be moved into the scroll view after
        // the transition finishes.
        self.view.addSubview(self.imageView)
        
        viewController.present(self, animated: false, completion: { [weak self] in
            guard let `self` = self else { return }
            if UIApplication.shared.statusBarOrientation != self.startingInfo.startingInterfaceOrientation {
                self.startingInfo.presentingViewControllerPresentedFromItsUnsupportedOrientation = true
            }
            let referenceFrameInMyView = self.view.convert(referenceFrameInWindow, from: nil)
            self.startingInfo.startingReferenceFrameForThumbnail = referenceFrameInMyView
            self.imageView.frame = referenceFrameInMyView
            self.imageView.layer.cornerRadius = self.imageInfo.referenceCornerRadius
            self.updateScrollViewAndImageViewForCurrentMetrics()
            let mustRotateDuringTransition = (UIApplication.shared.statusBarOrientation != self.startingInfo.startingInterfaceOrientation)
            
            if mustRotateDuringTransition {
                let newStartingRect = snapshotView.convert(self.startingInfo.startingReferenceFrameForThumbnail, to:self.view)
                self.imageView.frame = newStartingRect
                self.updateScrollViewAndImageViewForCurrentMetrics()
                self.imageView.transform = snapshotView.transform
                let centerInRect = CGPoint(x: self.startingInfo.startingReferenceFrameForThumbnail.origin.x
                    + self.startingInfo.startingReferenceFrameForThumbnail.size.width/2.0,
                                           y: self.startingInfo.startingReferenceFrameForThumbnail.origin.y
                                            + self.startingInfo.startingReferenceFrameForThumbnail.size.height/2.0);
                self.imageView.center = centerInRect
            }
            
            let duration = self.HHImageViewController_TransitionAnimationDuration
            
            
            // Have to dispatch ahead two runloops,
            // or else the image view changes above won't be
            // committed prior to the animations below.
            //
            // Dispatching only one runloop ahead doesn't fix
            // the issue on certain devices.
            //
            // This issue also seems to be triggered by only
            // certain kinds of interactions with certain views,
            // especially when a UIButton is the reference
            // for the JTSImageInfo.
            //
            
            //DispatchQueue.main.async {

            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                
                let cornerRadiusAnimation = CABasicAnimation(keyPath: "cornerRadius")
                
                cornerRadiusAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                
                cornerRadiusAnimation.fromValue = self.imageView.layer.cornerRadius
                cornerRadiusAnimation.toValue = 0.0
                cornerRadiusAnimation.duration = CFTimeInterval(duration)
                self.imageView.layer.add(cornerRadiusAnimation, forKey:"cornerRadius")
                self.imageView.layer.cornerRadius = 0.0
                
                UIView.animate(withDuration: TimeInterval(duration), delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: { [weak self] in
                    guard let `self` = self else { return }
                    self.flags.isTransitioningFromInitialModalToInteractiveState = true
                    
                    var scaling: CGFloat
                    if !self.backgroundOptions.contains(.scaled)  {
                        scaling = 1.0
                    } else {
                        scaling = self.HHImageViewController_MinimumBackgroundScaling
                    }
                    
                    snapshotView.transform = snapshotView.transform.concatenating(CGAffineTransform(scaleX: scaling, y: scaling))
                    
                    if !self.isStatusBarHidden {
                        self.isStatusBarHidden = true
                        self.setNeedsStatusBarAppearanceUpdate()
                    }
                    
                    if self.backgroundOptions.contains(.scaled) {
                        self.addMotionEffectsToSnapshotView()
                    }
                    self.blackBackdrop.alpha = self.alphaForBackgroundDimmingOverlay()
                    
                    if (mustRotateDuringTransition) {
                        self.imageView.transform = .identity;
                    }
                    
                    var endFrameForImageView: CGRect
                    if let image = self.image {
                        endFrameForImageView = self.resizedFrameForAutorotatingImageView(imageSize: image.size)
                    } else {
                        endFrameForImageView = self.resizedFrameForAutorotatingImageView(imageSize: self.imageInfo.referenceRect.size)
                    }
                    self.imageView.frame = endFrameForImageView
                    
                    let endCenterForImageView = CGPoint(x: self.view.bounds.size.width/2.0, y: self.view.bounds.size.height/2.0)
                    self.imageView.center = endCenterForImageView
                    
                    if (self.image == nil) {
                        self.progressContainer.alpha = 1.0
                    }
                    }, completion: { [weak self] (finished) in
                        guard let `self` = self else { return }
                        self.flags.isManuallyResizingTheScrollViewFrame = true
                        self.scrollView.frame = self.view.bounds;
                        self.flags.isManuallyResizingTheScrollViewFrame = false
                        self.scrollView.addSubview(self.imageView)
                        
                        self.flags.isTransitioningFromInitialModalToInteractiveState = false
                        self.flags.isAnimatingAPresentationOrDismissal = false
                        self.flags.isPresented = true
                        
                        self.updateScrollViewAndImageViewForCurrentMetrics()
                        
                        if (self.flags.imageDownloadFailed) {
                            //[weakSelf dismiss:YES];
                        } else {
                            self.view.isUserInteractionEnabled = true
                        }
                })
            }
            //}
        })

    }
    
    
// MARK: - Dismissal
    
    func dismissByCollapsingImageBackToOriginalPosition() {
    
        self.view.isUserInteractionEnabled = false
        self.flags.isAnimatingAPresentationOrDismissal = true
        self.flags.isDismissing = true
        
        let imageFrame = self.view.convert(self.imageView.frame, from:self.scrollView)
        
        self.imageView.autoresizingMask = []
        
        self.imageView.transform = .identity
        self.imageView.layer.transform = CATransform3DIdentity
        self.imageView.removeFromSuperview()
        self.imageView.frame = imageFrame;
        self.view.addSubview(self.imageView)
        self.scrollView.removeFromSuperview()
        //self.scrollView = nil
        
        
        // Have to dispatch after or else the image view changes above won't be
        // committed prior to the animations below. A single dispatch_async(dispatch_get_main_queue()
        // wouldn't work under certain scrolling conditions, so it has to be an ugly
        // two runloops ahead.
        
        DispatchQueue.main.async { [weak self] in
            
            guard let `self` = self else { return }
            
            self.closeCircelButtonIfNeeded()

            let duration = self.HHImageViewController_TransitionAnimationDuration
            
            let cornerRadiusAnimation = CABasicAnimation(keyPath: "cornerRadius")
            cornerRadiusAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            
            cornerRadiusAnimation.fromValue = 0.0
            cornerRadiusAnimation.toValue = self.imageInfo.referenceCornerRadius
            cornerRadiusAnimation.duration = CFTimeInterval(duration)
            self.imageView.layer.add(cornerRadiusAnimation, forKey: "cornerRadius")
            self.imageView.layer.cornerRadius = self.imageInfo.referenceCornerRadius
            
            UIView.animate(withDuration: TimeInterval(duration), delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: { [weak self] in
                guard let `self` = self else { return }
                if let circleMenu = self.circleMenu {
                    circleMenu.alpha = 0
                }
                
                if let snapshotView = self.snapshotView {
                    snapshotView.transform = self.currentSnapshotRotationTransform
                }
                
                self.removeMotionEffectsFromSnapshotView()
                self.blackBackdrop.alpha = 0
                
                let mustRotateDuringTransition = UIApplication.shared.statusBarOrientation != self.startingInfo.startingInterfaceOrientation
                
                if (mustRotateDuringTransition) {
                    var newEndingRect: CGRect
                    var centerInRect = CGPoint.zero
                    if (self.startingInfo.presentingViewControllerPresentedFromItsUnsupportedOrientation) {
                        let rectToConvert = self.startingInfo.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation
                        if let rectForCentering = self.snapshotView?.convert(rectToConvert, to: self.view) {
                        
                            centerInRect = CGPoint(x: rectForCentering.origin.x+rectForCentering.size.width/2.0,
                                               y: rectForCentering.origin.y+rectForCentering.size.height/2.0)
                        }
                        
                        newEndingRect = self.startingInfo.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation
                    } else {
                        newEndingRect = self.startingInfo.startingReferenceFrameForThumbnail;
                        if let rectForCentering = self.snapshotView?.convert(self.startingInfo.startingReferenceFrameForThumbnail, to: self.view) {
                            centerInRect = CGPoint(x: rectForCentering.origin.x+rectForCentering.size.width/2.0,
                                               y: rectForCentering.origin.y+rectForCentering.size.height/2.0)
                        }
                    }
                    self.imageView.frame = newEndingRect;
                    self.imageView.transform = self.currentSnapshotRotationTransform;
                    self.imageView.center = centerInRect;
                } else {
                    if (self.startingInfo.presentingViewControllerPresentedFromItsUnsupportedOrientation) {
                        self.imageView.frame = self.startingInfo.startingReferenceFrameForThumbnailInPresentingViewControllersOriginalOrientation
                    } else {
                        self.imageView.frame = self.startingInfo.startingReferenceFrameForThumbnail;
                    }
                    
                }
            }) { [weak self] (finished) in
                guard let `self` = self else { return }
                self.presentingViewController?.dismiss(animated: false, completion: { [weak self] in
                    guard let `self` = self else { return }
                    _ = self.delegate?.imageViewerDidDismiss?(self)
                })
            }
        }

        
    }
    
    func dismissByCleaningUpAfterImageWasFlickedOffscreen() {
    
        self.view.isUserInteractionEnabled = false
        self.flags.isAnimatingAPresentationOrDismissal = true
        self.flags.isDismissing = true
        
        self.closeCircelButtonIfNeeded()

        let duration = HHImageViewController_TransitionAnimationDuration
        
        UIView.animate(withDuration: TimeInterval(duration), delay:0, options: [.beginFromCurrentState, .curveEaseInOut], animations: { [weak self] in
            guard let `self` = self else { return }
            
            if let circleMenu = self.circleMenu {
                circleMenu.alpha = 0
            }
            
            if let snapshotView = self.snapshotView {
                snapshotView.transform = self.currentSnapshotRotationTransform
            }
            
            self.removeMotionEffectsFromSnapshotView()
            
            self.blackBackdrop.alpha = 0
            self.scrollView.alpha = 0
        }, completion: { [weak self] (finished) in
            guard let `self` = self else { return }
            self.presentingViewController?.dismiss(animated: false, completion: { [weak self] in
                guard let `self` = self else { return }
                _ = self.delegate?.imageViewerDidDismiss?(self)
            })
        })
        
    }
    
    func dismissByExpandingImageToOffscreenPosition() {
    
        self.view.isUserInteractionEnabled = false
        self.flags.isAnimatingAPresentationOrDismissal = true
        self.flags.isDismissing = true
        
        let duration = HHImageViewController_TransitionAnimationDuration
        
        UIView.animate(withDuration: TimeInterval(duration), delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: { [weak self] in
            guard let `self` = self else { return }
            
            if let snapshotView = self.snapshotView {
                snapshotView.transform = self.currentSnapshotRotationTransform
            }
            self.removeMotionEffectsFromSnapshotView()
            
            self.blackBackdrop.alpha = 0
            
            self.scrollView.alpha = 0
            let scaling = self.HHImageViewController_MaxScalingForExpandingOffscreenStyleTransition
            self.scrollView.transform = CGAffineTransform(scaleX: scaling, y: scaling)
        }) { [weak self] (finished) in
            guard let `self` = self else { return }
            self.presentingViewController?.dismiss(animated: false, completion: { [weak self] in
                guard let `self` = self else { return }
                _ = self.delegate?.imageViewerDidDismiss?(self)
            })
        }
        
    }

// MARK: - Snapshots
    
    func snapshotFromParentmostViewController(viewController: UIViewController) -> UIView? {
        guard let presentingViewController = self.parentmostViewController(from: viewController) else {return nil }
        
        let snapshot = presentingViewController.view.snapshotView(afterScreenUpdates: true)
        snapshot?.clipsToBounds = false
        return snapshot
    }
    
    func parentmostViewController(from viewController: UIViewController) -> UIViewController? {
        var presentingViewController = viewController.view.window?.rootViewController
        while (presentingViewController?.presentedViewController != nil) {
            presentingViewController = presentingViewController?.presentedViewController
        }
        return presentingViewController
    }
    
    func cancelCurrentImageDrag(animated: Bool) {
        
        self.animator.removeAllBehaviors()
        
        self.attachmentBehavior = nil
        self.flags.isDraggingImage = false
        if !animated {
            self.imageView.transform = .identity
            self.imageView.center = CGPoint(x: self.scrollView.contentSize.width/2.0, y: self.scrollView.contentSize.height/2.0);
        } else {
            
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.7,initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState],
                           animations: { [weak self] in
                            guard let `self` = self else { return }
                            
                            if !self.flags.isDraggingImage {
                                self.imageView.transform = .identity;
                                if !self.scrollView.isDragging && !self.scrollView.isDecelerating {
                                    self.imageView.center = CGPoint(x: self.scrollView.contentSize.width/2.0, y: self.scrollView.contentSize.height/2.0)
                                    self.updateScrollViewAndImageViewForCurrentMetrics()
                                }
                            }
                }, completion: nil)
        }
    }

    func updateLayoutsForCurrentOrientation() {
    
        guard let snapshotView = self.snapshotView
        else {
            return
        }
        if self.mode == .image {
            self.updateScrollViewAndImageViewForCurrentMetrics()
            self.progressContainer.center = CGPoint(x: self.view.bounds.size.width/2.0,  y: self.view.bounds.size.height/2.0)
        }
        
        var transform: CGAffineTransform = .identity
        
        if self.startingInfo.startingInterfaceOrientation == .portrait {
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: .pi/2.0)
                break;
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: -.pi/2.0)
                break;
            case .portrait:
                transform = .identity;
                break;
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: .pi)
                break;
            default:
                break;
            }
        }
        else if self.startingInfo.startingInterfaceOrientation == .portraitUpsideDown {
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: -.pi/2.0)
                break;
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: .pi/2.0)
                break;
            case .portrait:
                transform = CGAffineTransform(rotationAngle: .pi)
                break;
            case .portraitUpsideDown:
                transform = .identity;
                break;
            default:
                break;
            }
        }
        else if self.startingInfo.startingInterfaceOrientation == .landscapeLeft {
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                transform = .identity;
                break;
            case .landscapeRight:
                transform = CGAffineTransform(rotationAngle: .pi)
                break;
            case .portrait:
                transform = CGAffineTransform(rotationAngle: -.pi/2.0)
                break;
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: .pi/2.0)
                break;
            default:
                break;
            }
        }
        else if self.startingInfo.startingInterfaceOrientation == .landscapeRight {
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                transform = CGAffineTransform(rotationAngle: .pi)
                break;
            case .landscapeRight:
                transform = .identity;
                break;
            case .portrait:
                transform = CGAffineTransform(rotationAngle: .pi/2.0)
                break;
            case .portraitUpsideDown:
                transform = CGAffineTransform(rotationAngle: -.pi/2.0)
                break;
            default:
                break;
            }
        }
        
        snapshotView.center = CGPoint(x: self.view.bounds.size.width/2.0, y: self.view.bounds.size.height/2.0)
        
        
        if self.flags.rotationTransformIsDirty {
            self.flags.rotationTransformIsDirty = false
            self.currentSnapshotRotationTransform = transform
            if self.flags.isPresented {
                if self.mode == .image {
                    self.scrollView.frame = self.view.bounds
                }
                var targetScaling :CGFloat
                if !self.backgroundOptions.contains(.scaled) {
                    targetScaling = 1.0
                } else {
                    targetScaling = HHImageViewController_MinimumBackgroundScaling
                }
                
                snapshotView.transform = transform.concatenating(CGAffineTransform(scaleX: targetScaling, y: targetScaling))
            } else {
                snapshotView.transform = transform
            }
        }
    }

// MARK: - Update Dimming View for Zoom Scale
    
    func updateDimmingViewForCurrentZoomScale(animated: Bool) {

        let zoomScale = self.scrollView.zoomScale
        
        let targetAlpha = (zoomScale > 1) ? 1.0 : self.alphaForBackgroundDimmingOverlay()
        
        let duration: CGFloat = (animated) ? 0.35 : 0
        
        UIView.animate(withDuration: TimeInterval(duration), delay: 0, options: [.curveLinear, .beginFromCurrentState],
                       animations: { [weak self] in
                        guard let `self` = self else { return }
                        
                        self.blackBackdrop.alpha = targetAlpha
            }, completion: nil)
    }

// MARK: - Options Delegate Convenience
    
    func alphaForBackgroundDimmingOverlay() -> CGFloat {
        return HHImageViewController_DefaultAlphaForBackgroundDimmingOverlay
    }
    
    func backgroundBlurRadius() -> CGFloat {
        return HHImageViewController_DefaultBackgroundBlurRadius
    }
    
    func backgroundColorForImageView() -> UIColor {
        
        return .clear
    }

    func updateScrollViewAndImageViewForCurrentMetrics() {

        if !self.flags.isAnimatingAPresentationOrDismissal {
            self.flags.isManuallyResizingTheScrollViewFrame = true
            self.scrollView.frame = self.view.bounds
            self.flags.isManuallyResizingTheScrollViewFrame = false
        }
        
        let usingOriginalPositionTransition = self.transition == .fromOriginalPosition
        
        
        let suppressAdjustments = (usingOriginalPositionTransition && self.flags.isAnimatingAPresentationOrDismissal)
        
        if !suppressAdjustments {
            if let image = self.image {
                self.imageView.frame = self.resizedFrameForAutorotatingImageView(imageSize:  image.size)
            } else {
                self.imageView.frame = self.resizedFrameForAutorotatingImageView(imageSize: self.imageInfo.referenceRect.size)
            }
            self.scrollView.contentSize = self.imageView.frame.size
            self.scrollView.contentInset = self.contentInsetForScrollView(targetZoomScale: self.scrollView.zoomScale)
        }
    }

    func contentInsetForScrollView(targetZoomScale: CGFloat) -> UIEdgeInsets {
        guard let image = self.image
            else {
                return .zero
        }

        var inset: UIEdgeInsets = .zero
        let boundsHeight = self.scrollView.bounds.size.height
        let boundsWidth = self.scrollView.bounds.size.width
        let contentHeight = (image.size.height > 0) ? image.size.height : boundsHeight
        let contentWidth = (image.size.width > 0) ? image.size.width : boundsWidth
        var minContentHeight: CGFloat
        var minContentWidth: CGFloat
        if (contentHeight > contentWidth) {
            if (boundsHeight/boundsWidth < contentHeight/contentWidth) {
                minContentHeight = boundsHeight
                minContentWidth = contentWidth * (minContentHeight / contentHeight)
            } else {
                minContentWidth = boundsWidth
                minContentHeight = contentHeight * (minContentWidth / contentWidth)
            }
        } else {
            if (boundsWidth/boundsHeight < contentWidth/contentHeight) {
                minContentWidth = boundsWidth
                minContentHeight = contentHeight * (minContentWidth / contentWidth)
            } else {
                minContentHeight = boundsHeight
                minContentWidth = contentWidth * (minContentHeight / contentHeight)
            }
        }
        let myHeight = self.view.bounds.size.height
        let myWidth = self.view.bounds.size.width
        minContentWidth *= targetZoomScale
        minContentHeight *= targetZoomScale
        if (minContentHeight > myHeight && minContentWidth > myWidth) {
            inset = .zero
        } else {
            var verticalDiff = boundsHeight - minContentHeight
            var horizontalDiff = boundsWidth - minContentWidth
            verticalDiff = (verticalDiff > 0) ? verticalDiff : 0
            horizontalDiff = (horizontalDiff > 0) ? horizontalDiff : 0
            inset.top = verticalDiff/2.0
            inset.bottom = verticalDiff/2.0
            inset.left = horizontalDiff/2.0
            inset.right = horizontalDiff/2.0
        }
        return inset
    }

    func resizedFrameForAutorotatingImageView(imageSize: CGSize) -> CGRect {
        
        var frame = self.view.bounds
        let screenWidth = frame.size.width * self.scrollView.zoomScale;
        let screenHeight = frame.size.height * self.scrollView.zoomScale
        var targetWidth = screenWidth
        var targetHeight = screenHeight
        var nativeHeight = screenHeight
        var nativeWidth = screenWidth
        if (imageSize.width > 0 && imageSize.height > 0) {
            nativeHeight = (imageSize.height > 0) ? imageSize.height : screenHeight
            nativeWidth = (imageSize.width > 0) ? imageSize.width : screenWidth
        }
        if (nativeHeight > nativeWidth) {
            if (screenHeight/screenWidth < nativeHeight/nativeWidth) {
                targetWidth = screenHeight / (nativeHeight / nativeWidth)
            } else {
                targetHeight = screenWidth / (nativeWidth / nativeHeight)
            }
        } else {
            if (screenWidth/screenHeight < nativeWidth/nativeHeight) {
                targetHeight = screenWidth / (nativeWidth / nativeHeight)
            } else {
                targetWidth = screenHeight / (nativeHeight / nativeWidth)
            }
        }
        frame.size = CGSize(width: targetWidth, height: targetHeight)
        frame.origin = CGPoint(x: 0, y: 0)
        return frame;
    }
    
// MARK: - Motion Effects
    
    func addMotionEffectsToSnapshotView() {
        
        guard let snapshotView = self.snapshotView else { return }
        
        let verticalEffect = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        verticalEffect.minimumRelativeValue = 12
        verticalEffect.maximumRelativeValue = -12
        
        
        let horizontalEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        horizontalEffect.minimumRelativeValue = 12
        horizontalEffect.maximumRelativeValue = -12
        
        
        let effectGroup = UIMotionEffectGroup()
        effectGroup.motionEffects = [horizontalEffect, verticalEffect]
        
        snapshotView.addMotionEffect(effectGroup)
    }
    
    func removeMotionEffectsFromSnapshotView() {
        guard let snapshotView = self.snapshotView else { return }
        for effect in snapshotView.motionEffects {
            snapshotView.removeMotionEffect(effect)
        }
    }


// MARK: - Interface Updates
    
    func updateInterfaceWithImage(image: UIImage?) {
        guard let image = image else {
            return
        }
        self.image = image
        self.imageView.image = image
        self.progressContainer.alpha = 0
        
        self.imageView.backgroundColor = self.backgroundColorForImageView()
        
        // Don't update the layouts during a drag.
        if !self.flags.isDraggingImage {
            self.updateLayoutsForCurrentOrientation()
        }
        
        if self.showCircleMenuOnStart {
            self.perform(#selector(showCircleMenu), with: nil, afterDelay: 0.3)
        }
    }

    func showCircleMenu() {
        guard let circleMenu = self.circleMenu else { return }
        if circleMenu.alpha == 0 {
            
            DispatchQueue.main.async {
                self.view.bringSubview(toFront: circleMenu)
                circleMenu.alpha = 1
                if !circleMenu.buttonsIsShown() {
                    circleMenu.sendActions(for: .touchUpInside)
                }
            }
            //DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            //}
        }
    }
    
// MARK: - Gesture Recognizer Actions
    
    func imageDoubleTapped(_ sender: UITapGestureRecognizer) {
    
        if (self.flags.scrollViewIsAnimatingAZoom) {
            return
        }
        
        let rawLocation = sender.location(in: sender.view)
        
        let point = self.scrollView.convert(rawLocation, from: sender.view)
        
        var targetZoomRect: CGRect
        var targetInsets: UIEdgeInsets
        if (self.scrollView.zoomScale == 1.0) {
            let zoomWidth = self.view.bounds.size.width / HHImageViewController_TargetZoomForDoubleTap
            
            let zoomHeight = self.view.bounds.size.height / HHImageViewController_TargetZoomForDoubleTap
            
            targetZoomRect = CGRect(x: point.x - (zoomWidth/2.0), y: point.y - (zoomHeight/2.0), width: zoomWidth, height: zoomHeight)
            
            targetInsets = self.contentInsetForScrollView(targetZoomScale: HHImageViewController_TargetZoomForDoubleTap)
        } else {
            let zoomWidth = self.view.bounds.size.width * self.scrollView.zoomScale
            let zoomHeight = self.view.bounds.size.height * self.scrollView.zoomScale
            targetZoomRect = CGRect(x: point.x - (zoomWidth/2.0), y: point.y - (zoomHeight/2.0), width: zoomWidth, height: zoomHeight)
            targetInsets = self.contentInsetForScrollView(targetZoomScale: 1.0)
        }
        self.view.isUserInteractionEnabled = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let `self` = self else { return }
            self.scrollView.contentInset = targetInsets
            self.view.isUserInteractionEnabled = true;
            self.flags.scrollViewIsAnimatingAZoom = false
        }
        
        self.scrollView.zoom(to: targetZoomRect, animated:true)
        CATransaction.commit()
    }
    
    func imageSingleTapped(_ sender: Any) {
        if (self.flags.scrollViewIsAnimatingAZoom) {
            return
        }
        
        if let circleMenu = self.circleMenu {
            if circleMenu.alpha != 0 {
                self.closeCircelButtonIfNeeded()
                return
            }
        }
        
        self.dismiss(animated: true)
    }
    
    func imageLongPressed(_ sender: UILongPressGestureRecognizer) {
 
        if (self.flags.scrollViewIsAnimatingAZoom) {
            return
        }
        
        self.showCircleMenu()

    }

    func dismissingPanGestureRecognizerPanned(_ panner: UIPanGestureRecognizer) {
    
        if (self.flags.scrollViewIsAnimatingAZoom || self.flags.isAnimatingAPresentationOrDismissal) {
            return
        }
        
        let translation = panner.translation(in: panner.view)
        let locationInView = panner.location(in: panner.view)
        let velocity = panner.velocity(in: panner.view)
        let vectorDistance = CGFloat(sqrtf(powf(Float(velocity.x), 2) + powf(Float(velocity.y), 2)))
        
        if (panner.state == .began) {
            self.flags.isDraggingImage = self.imageView.frame.contains(locationInView)
            if (self.flags.isDraggingImage) {
                self.startImageDragging(panGestureLocationInView: locationInView, translationOffset: UIOffset.zero)
            }
        }
        else if (panner.state == .changed) {
            if (self.flags.isDraggingImage) {
                if var newAnchor = self.imageDragStartingPoint, let imageDragOffsetFromActualTranslation = self.imageDragOffsetFromActualTranslation, let attachmentBehavior = self.attachmentBehavior {
                    newAnchor.x += translation.x + imageDragOffsetFromActualTranslation.horizontal
                    newAnchor.y += translation.y + imageDragOffsetFromActualTranslation.vertical
                    attachmentBehavior.anchorPoint = newAnchor
                }
            } else {
                self.flags.isDraggingImage = self.imageView.frame.contains(locationInView);
                if (self.flags.isDraggingImage) {
                    let translationOffset = UIOffsetMake(-1*translation.x, -1*translation.y)
                    self.startImageDragging(panGestureLocationInView: locationInView, translationOffset: translationOffset)
                }
            }
        }
        else {
            if (vectorDistance > HHImageViewController_MinimumFlickDismissalVelocity) {
                if (self.flags.isDraggingImage) {
                    self.dismissImageWithFlick(velocity: velocity)
                } else {
                    self.dismiss(animated: true)
                }
            }
            else {
                self.cancelCurrentImageDrag(animated: true)
            }
        }
    }

    
// MARK: - Dynamic Image Dragging
    
    func startImageDragging(panGestureLocationInView: CGPoint, translationOffset: UIOffset) {
        self.imageDragStartingPoint = panGestureLocationInView
        self.imageDragOffsetFromActualTranslation = translationOffset
        guard let anchor = self.imageDragStartingPoint else { return }
        
        let imageCenter = self.imageView.center
        
        let offset = UIOffsetMake(panGestureLocationInView.x-imageCenter.x, panGestureLocationInView.y-imageCenter.y)
        
        self.imageDragOffsetFromImageCenter = offset
        
        let attachmentBehavior = UIAttachmentBehavior(item: self.imageView,  offsetFromCenter: offset, attachedToAnchor: anchor)
        
        self.attachmentBehavior = attachmentBehavior
        self.animator.addBehavior(attachmentBehavior)
        let modifier = UIDynamicItemBehavior(items: [self.imageView])
        
        modifier.angularResistance = self.appropriateAngularResistanceForView(view: self.imageView)
        
        modifier.density = self.appropriateDensityForView(view: self.imageView)
        self.animator.addBehavior(modifier)
    }
    
    func dismissImageWithFlick(velocity: CGPoint) {
        
        guard let imageDragOffsetFromImageCenter = self.imageDragOffsetFromImageCenter,
                let attachmentBehavior = self.attachmentBehavior
        else { return }
        
        self.flags.imageIsFlickingAwayForDismissal = true
        
        let push = UIPushBehavior(items: [self.imageView], mode: .instantaneous)
        push.pushDirection = CGVector(dx: velocity.x*0.1, dy: velocity.y*0.1)
        
        push.setTargetOffsetFromCenter(imageDragOffsetFromImageCenter, for: self.imageView)
        push.action = { [weak self] in
            guard let `self` = self else { return }
            if self.imageViewIsOffscreen() {
                self.animator.removeAllBehaviors()
                self.attachmentBehavior = nil
                self.imageView.removeFromSuperview()
                self.dismiss(animated: true)
            }
        }
        
        self.animator.removeBehavior(attachmentBehavior)
        self.animator.addBehavior(push)
    }
    
    func appropriateAngularResistanceForView(view: UIView) -> CGFloat {
        let height = view.bounds.size.height
        let width = view.bounds.size.width
        let actualArea = height * width
        let referenceArea = self.view.bounds.size.width * self.view.bounds.size.height;
        let factor = referenceArea / actualArea
        let defaultResistance: CGFloat = 4.0 // Feels good with a 1x1 on 3.5 inch displays. We'll adjust this to match the current display.
        let screenWidth = UIScreen.main.bounds.size.width
        let screenHeight = UIScreen.main.bounds.size.height
        let resistance = defaultResistance * ((320.0 * 480.0) / (screenWidth * screenHeight))
        return resistance * factor
    }
    
    func appropriateDensityForView(view: UIView) -> CGFloat {
        let height = view.bounds.size.height
        let width = view.bounds.size.width
        let actualArea = height * width
        let referenceArea = self.view.bounds.size.width * self.view.bounds.size.height
        let factor = referenceArea / actualArea
        let defaultDensity: CGFloat = 0.5; // Feels good on 3.5 inch displays. We'll adjust this to match the current display.
        let screenWidth = UIScreen.main.bounds.size.width
        let screenHeight = UIScreen.main.bounds.size.height
        let appropriateDensity = defaultDensity * ((320.0 * 480.0) / (screenWidth * screenHeight))
        return appropriateDensity * factor
    }
    
    func imageViewIsOffscreen() -> Bool {
        let visibleRect = self.scrollView.convert(self.view.bounds, from:self.view)
        
        return (self.animator.items(in: visibleRect).count == 0)
    }
    
    func targetDismissalPoint(startingCenter: CGPoint, velocity: CGPoint) -> CGPoint {
        return CGPoint(x: startingCenter.x + velocity.x/3.0 , y: startingCenter.y + velocity.y/3.0)
    }
    
// MARK: circle button
    
    func closeCircelButtonIfNeeded() {
        guard let circleMenu = self.circleMenu else { return }
        if circleMenu.buttonsIsShown() {
            circleMenu.sendActions(for: .touchUpInside)
            circleMenu.alpha = 0
            
        }
    }
    
// MARK: - Progress Bar
    
    func startProgressTimer() {
        
        self.downloadProgressTimer = Timer(timeInterval: 0.05, target: self, selector: #selector(progressTimerFired(_ :)), userInfo: nil, repeats: true)
        
        if let downloadProgressTimer = self.downloadProgressTimer {
            RunLoop.main.add(downloadProgressTimer, forMode: .commonModes)
        }
        
    }
    
    func cancelProgressTimer() {
        guard let downloadProgressTimer = self.downloadProgressTimer else { return }
        downloadProgressTimer.invalidate()
        self.downloadProgressTimer = nil
    }
    
    func progressTimerFired(_ timer: Timer) {
        
        guard let imageDownloadDataTask = self.imageDownloadDataTask else { return }
        
        var progress: Float = 0

        let bytesExpected = imageDownloadDataTask.countOfBytesExpectedToReceive
        
        if (bytesExpected > 0 && !self.flags.imageIsBeingReadFromDisk) {
            
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveLinear], animations: { [weak self] in
                guard let `self` = self else { return }
                self.spinner.alpha = 0
                self.progressView.alpha = 1
            }, completion: nil)
            
            progress = Float(imageDownloadDataTask.countOfBytesReceived / bytesExpected)
        }
        self.progressView.progress = progress
    }

// MARK: file download
    
    func downloadImage(for imageURL: URL, completion: @escaping ((UIImage?) -> Swift.Void)) -> URLSessionDataTask? {
    
        let request = URLRequest(url: imageURL)
        let sesh = URLSession.shared
        
        let dataTask = sesh.dataTask(with: request, completionHandler: { (data, response, error) in
            
            DispatchQueue.global().async {
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                if let image = UIImage(data: data) {
                    ImageCache.default.store(image, forKey: imageURL.absoluteString)
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
                else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
                
            }
        })
        
        dataTask.resume()
        
        return dataTask
    }
    
}

// MARK: - UIScrollViewDelegate

extension HHImageViewController: UIScrollViewDelegate
{
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        
        if self.flags.imageIsFlickingAwayForDismissal {
            return
        }
        
        scrollView.contentInset = self.contentInsetForScrollView(targetZoomScale: scrollView.zoomScale)
        
        if !self.scrollView.isScrollEnabled {
            self.scrollView.isScrollEnabled = true
        }
        
        if !self.flags.isAnimatingAPresentationOrDismissal && !self.flags.isManuallyResizingTheScrollViewFrame {
            self.updateDimmingViewForCurrentZoomScale(animated: true)
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if self.flags.imageIsFlickingAwayForDismissal {
            return
        }
        
        self.scrollView.isScrollEnabled = (scale > 1)
        self.scrollView.contentInset = self.contentInsetForScrollView(targetZoomScale: scale)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if self.flags.imageIsFlickingAwayForDismissal {
            return
        }
        
        let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView.panGestureRecognizer.view)
        
        if (scrollView.zoomScale == 1 && (Swift.abs(velocity.x) > 1600 || Swift.abs(velocity.y) > 1600 ) ) {
            self.dismiss(animated: true)
        }
    }
    
}


// MARK: - UIGestureRecognizerDelegate

extension HHImageViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
     
        var shouldReceiveTouch = true
        
        if (shouldReceiveTouch && gestureRecognizer == self.panRecognizer) {
            shouldReceiveTouch = (self.scrollView.zoomScale == 1 && !self.flags.scrollViewIsAnimatingAZoom)
        }
        return shouldReceiveTouch
    }
}


// MARK: - CircleMenuDelegate

extension HHImageViewController: CircleMenuDelegate
{

    func circleMenu(_ circleMenu: CircleMenu, willDisplay button: UIButton, atIndex: Int) {
        
        _ = self.delegate?.imageViewController?(self, willDisplay: button, atIndex: atIndex)
        
    }
    
    func circleMenu(_ circleMenu: CircleMenu, buttonDidSelected button: UIButton, atIndex: Int) {
        //print("button did selected: \(atIndex)")
        _ = self.delegate?.imageViewController?(self, buttonDidSelected: button, atIndex: atIndex, image: self.image)
        
        self.dismiss(animated: true)
    }
    
    func menuCollapsed(_ circleMenu: CircleMenu) {
        DispatchQueue.main.async {
            circleMenu.alpha = 0
        }
    }
}

