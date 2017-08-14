//
//  HHAvatarPicker.swift
//
//  Created by Haijian Huo on 7/19/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import Kingfisher
import KRPullLoader
import SwiftyDrop
import ReachabilitySwift
import PopupDialog
import PKHUD

enum HHAvatarPickerMode {
    case search
    case photo
    case camera
}


@objc protocol HHAvatarPickerDelegate: class {
    
    /**
     Tells the delegate that the original image has been cropped. Additionally provides a crop rect used to produce image.
     */
    @objc optional func photoPickerDidPickImage(_ image: UIImage?, controller: HHAvatarPicker)
}

class HHAvatarPicker: UIViewController {

    weak var delegate: HHAvatarPickerDelegate?
    var picker: UIImagePickerController?
    
    var avatarPickerMode: HHAvatarPickerMode = .search
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var closeButton: UIButton!
    
    let reachability = Reachability()

    var disposeBag = DisposeBag()
    
    let viewModel = HHAvatarPickerViewModel()

    @IBOutlet weak var coverView: UIView!
    
    var selectedIndexPath: IndexPath?
    var visibleIndexPath: IndexPath?

    var willRotate = false
    var needRefresh = false
    
    let items: [(icon: String, color: UIColor)] = [
        ("photo_select", UIColor(red:0.22, green:0.74, blue:0, alpha:1))
    ]

//    let items: [(icon: String, color: UIColor)] = [
//        ("icon_home", UIColor(red:0.19, green:0.57, blue:1, alpha:1)),
//        ("icon_search", UIColor(red:0.22, green:0.74, blue:0, alpha:1)),
//        ("notifications-btn", UIColor(red:0.96, green:0.23, blue:0.21, alpha:1)),
//        ("settings-btn", UIColor(red:0.51, green:0.15, blue:1, alpha:1)),
//        ("nearby-btn", UIColor(red:1, green:0.39, blue:0, alpha:1)),
//        ]

    let loadMoreView = KRPullLoadView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.coverView.backgroundColor = .lightGray
        self.coverView.isHidden = true
        
        self.searchBar.isHidden = self.avatarPickerMode != .search
        self.closeButton.isHidden = self.searchBar.isHidden
        
        ImageCache.default.maxCachePeriodInSecond = -1

        // Do any additional setup after loading the view.
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.allowsMultipleSelection = false
        
        self.collectionView.backgroundColor = .clear
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "photo_background")!)
        
        self.loadMoreView.delegate = self
        self.collectionView.addPullLoadableView(self.loadMoreView, type: .loadMore)

        self.searchBar.delegate = self

        bind()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        let backgroundView = UIView(frame:self.collectionView.bounds)
        backgroundView.addGestureRecognizer(tap)
        self.collectionView.backgroundView = backgroundView
     }
    
    deinit {
        self.collectionView.removePullLoadableView(self.loadMoreView)
    }
    
    func showPhotoLibrary() {
        if self.picker != nil {
            return
        }
        HUD.show(.progress)
        let picker = UIImagePickerController()
        self.picker = picker
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }
    
    func shootPhoto() {
        if self.picker != nil {
            return
        }
        
        let picker = UIImagePickerController()
        self.picker = picker
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            HUD.show(.progress)

            picker.allowsEditing = false
            picker.sourceType = UIImagePickerControllerSourceType.camera
            picker.cameraDevice = .front

            picker.cameraCaptureMode = .photo
            picker.modalPresentationStyle = .fullScreen
            picker.delegate = self
            present(picker,animated: true,completion: nil)
        } else {
            let popup = PopupDialog(title: "Camera Not Found", message: nil, buttonAlignment: .horizontal, transitionStyle: .zoomIn, gestureDismissal: true) {
            }
            
            let buttonOne = CancelButton(title: "OK") {
            }
            
            popup.addButtons([buttonOne])
            self.present(popup, animated: true, completion: nil)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.willRotate = true
        
        if (self.isViewLoaded && (self.view.window != nil)) {
            let indexPaths = self.collectionView.indexPathsForVisibleItems
            if indexPaths.count > 0 {
                let sortedArray = indexPaths.sorted {$0.row < $1.row}
                if let indexPath = sortedArray.first {
                    self.showCoverView(true)
                    coordinator.animate(alongsideTransition: nil, completion: {
                        _ in
                        self.collectionView.collectionViewLayout.invalidateLayout()
                        self.collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                        self.willRotate = false
                        self.showCoverView(false)
                    })
                }
            }
            else {
                self.showCoverView(true)
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.showCoverView(false)
            }
        }
        else {
            self.needRefresh = true
            coordinator.animate(alongsideTransition: nil, completion: {
                _ in
                self.willRotate = false
            })

        }
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.needRefresh {
            self.showCoverView(true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.needRefresh {
            self.needRefresh = false
            self.collectionView.collectionViewLayout.invalidateLayout()
            if let indexPath = self.selectedIndexPath {
                DispatchQueue.main.async {
                    self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
                }
            }
            self.showCoverView(false)
        }
        
        switch self.avatarPickerMode {
        case .camera:
            self.shootPhoto()
        case .photo:
            self.showPhotoLibrary()
        default:
            break
        }
        
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.view.endEditing(true)
    }

    func showCoverView(_ show :Bool) {
        if show {
            self.coverView.isHidden = false
            self.coverView.alpha = 1
        }
        else {
            UIView.animate(withDuration: 1.3, animations: {
                self.coverView.alpha = 0
            }, completion: { (finished) in
                self.coverView.isHidden = true
            })
        }
    }
    
    func bind() {
        
        self.viewModel.productsUpdated.asObservable().subscribe(onNext: { [weak self] (element) in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }).addDisposableTo(disposeBag)
        
    }
    
    func handleTap(_ sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UICollectionViewDataSource

extension HHAvatarPicker: UICollectionViewDataSource
{
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.viewModel.products.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HHPhotoCell", for: indexPath) as! HHPhotoCell
        let item = self.viewModel.products[indexPath.row]
        
        cell.layer.borderWidth = indexPath == self.selectedIndexPath ? 2 : 0
        
        if let url = URL(string: item.url_small) {
            _ = cell.imageView.kf.setImage(with: url,
                                           placeholder: UIImage(named: "Placeholder"),
                                           options: [.transition(ImageTransition.fade(1))],
                                           progressBlock: nil,
                                           completionHandler: nil)
            
        }
        else {
            cell.imageView.image = UIImage(named: "Placeholder")
        }
        return cell
    }
    
    func zoomImage(imageView: UIImageView, imageUrl: String?) {
        
        guard let image = imageView.image else { return }
        guard let referenceView = imageView.superview else { return }
        
        let imageInfo = HHImageInfo(referenceRect: imageView.frame, referenceView: referenceView)
        
        if let imageUrl = imageUrl {
            if let image = ImageCache.default.retrieveImageInDiskCache(forKey: imageUrl, options: nil) {
                imageInfo.image = image
            }
            else {
                imageInfo.imageURL = URL(string: imageUrl)
            }
        }
        else {
            imageInfo.image = image
        }
        
        
        let imageViewer = HHImageViewController(imageInfo: imageInfo, mode: .image, backgroundStyle: .scaled)
        imageViewer.delegate = self
        imageViewer.showCircleMenuOnStart = true
        imageViewer.show(from: self, transition: .fromOriginalPosition)
    }
    
    func fixImageOrientation(src: UIImage?) -> UIImage? {
        
        guard let src = src else { return nil }

        if src.imageOrientation == .up {
            return src
        }
        
        var transform: CGAffineTransform = .identity
        
        switch src.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: src.size.width, y: src.size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: src.size.width, y: 0)
            transform = transform.rotated(by: .pi/2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: src.size.height)
            transform = transform.rotated(by: -.pi/2)
            break
        case .up, .upMirrored:
            break
        }
        
        switch src.imageOrientation {
        case .upMirrored, .downMirrored:
            transform.translatedBy(x: src.size.width, y: 0)
            transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform.translatedBy(x: src.size.height, y: 0)
            transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        }
        
        let ctx = CGContext(data: nil, width: Int(src.size.width), height: Int(src.size.height), bitsPerComponent: src.cgImage!.bitsPerComponent, bytesPerRow: 0, space: src.cgImage!.colorSpace!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        ctx.concatenate(transform)
        
        switch src.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            
            ctx.draw(src.cgImage!, in: CGRect(x: 0, y: 0, width: src.size.height, height: src.size.width))
        default:
            ctx.draw(src.cgImage!, in: CGRect(x: 0, y: 0, width: src.size.width, height: src.size.height))

        }
        
        let cgimg = ctx.makeImage()!
        let img:UIImage = UIImage.init(cgImage: cgimg)
        return img
    }
}

// MARK: - UICollectionViewDelegate

extension HHAvatarPicker: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        self.view.endEditing(true)
        
        var indexPaths = [indexPath]
        if let lastIndexPath = self.selectedIndexPath {
            if lastIndexPath != indexPath {
                indexPaths.append(lastIndexPath)
            }
        }
        self.selectedIndexPath = indexPath
        collectionView.reloadItems(at: indexPaths)
        
        let dispatchTime = DispatchTime.now() + 0.2
        DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
            let item = self.viewModel.products[indexPath.row]
            if let cell = collectionView.cellForItem(at: indexPath) as? HHPhotoCell {
                self.zoomImage(imageView: cell.imageView, imageUrl: item.url_large)
            }
        }
    }

}

// MARK: - UICollectionViewDelegateFlowLayout

extension HHAvatarPicker : UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var cellsPerRow:CGFloat
        let cellPadding:CGFloat = 2
        if UIDevice.current.userInterfaceIdiom == .pad {
            cellsPerRow = 6
        }
        else {
            cellsPerRow = collectionView.frame.size.width > collectionView.frame.size.height ? 8 : 4
        }

        let widthMinusPadding = collectionView.frame.size.width - cellPadding * (cellsPerRow - 1)
        
        let eachSide = widthMinusPadding / cellsPerRow
        return CGSize(width: eachSide, height: eachSide)
    }
}

// MARK: - HHImageViewControllerDelegate

extension HHAvatarPicker: HHImageViewControllerDelegate
{
    func imageViewController(_ imageViewController: HHImageViewController, willDisplay button: UIButton, atIndex: Int) -> Int {
        button.backgroundColor = items[atIndex].color
        
        button.setImage(UIImage(named: items[atIndex].icon), for: .normal)
        
        // set highlited image
        let highlightedImage  = UIImage(named: items[atIndex].icon)?.withRenderingMode(.alwaysTemplate)
        button.setImage(highlightedImage, for: .highlighted)
        button.tintColor = UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.3)
        return items.count
    }
    
    func imageViewController(_ imageViewController: HHImageViewController, buttonDidSelected button: UIButton, atIndex: Int, image: UIImage?) -> Bool {
        if atIndex == 0 {
            if let image = image {
                let controller = HHImageCropViewController(image: image, cropMode: .circle)
                controller.delegate = self
                controller.rotationEnabled = true
                self.present(controller, animated: true, completion: nil)
            }
        }
        return true
    }
    
}

// MARK: - UISearchBarDelegate

extension HHAvatarPicker: UISearchBarDelegate
{
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        if let reachability = self.reachability {
            if !reachability.isReachable {
                Drop.down("Can Not Search\nNo Internet connection available.", state: .error, duration: 2.0)
                return
            }
        }

        DispatchQueue.global().async {
            self.selectedIndexPath = nil
            self.viewModel.loadPage(query: self.searchBar.text!, page: 1)
        }
    }
}

// MARK: - KRPullLoadViewDelegate

extension HHAvatarPicker: KRPullLoadViewDelegate {
    
    func pullLoadView(_ pullLoadView: KRPullLoadView, didChangeState state: KRPullLoaderState, viewType type: KRPullLoaderType) {
        if type == .loadMore {
            switch state {
            case let .loading(completionHandler):
                DispatchQueue.main.async {
                    completionHandler()
                }
                
                DispatchQueue.global().async {
                    self.viewModel.loadNextPage()
                }
            default: break
            }
            return
        }
        
        switch state {
        case .none:
            pullLoadView.messageLabel.text = ""
            
        case let .pulling(offset, threshould):
            if offset.y > threshould {
                pullLoadView.messageLabel.text = "Pull more. offset: \(Int(offset.y)), threshould: \(Int(threshould)))"
            } else {
                pullLoadView.messageLabel.text = "Release to refresh. offset: \(Int(offset.y)), threshould: \(Int(threshould)))"
            }
        case let .loading(completionHandler):
            pullLoadView.messageLabel.text = "Updating..."
            DispatchQueue.main.async {
                completionHandler()
            }
        }
    }
}

// MARK: RSKImageCropViewControllerDelegate

extension HHAvatarPicker: HHImageCropViewControllerDelegate
{
    
    func imageCropViewControllerDidCancelCrop(controller: HHImageCropViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func imageCropViewController(controller: HHImageCropViewController, didCropImage croppedImage: UIImage?, usingCropRect cropRect: CGRect) {
        controller.dismiss(animated: true, completion: {
            self.dismiss(animated: true, completion: {
                if let photoPickerDidPickImage = self.delegate?.photoPickerDidPickImage {
                    photoPickerDidPickImage(croppedImage, self)
                }
            })
        })
    }
}

// MARK: UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension HHAvatarPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        HUD.hide()
        
        if let chosenImage = self.fixImageOrientation(src: info[UIImagePickerControllerOriginalImage] as? UIImage) {
            picker.dismiss(animated:true, completion: {
                    let controller = HHImageCropViewController(image: chosenImage, cropMode: .circle)
                    controller.delegate = self
                    controller.rotationEnabled = true
                    self.present(controller, animated: true, completion: nil)
            })
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        HUD.hide()

        picker.dismiss(animated: true, completion: {
            self.dismiss(animated: true, completion: nil)
        })
    }

}
