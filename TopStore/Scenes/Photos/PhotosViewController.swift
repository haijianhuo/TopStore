//
//  PhotosViewController.swift
//  TopStore
//
//  Created by Haijian Huo on 7/19/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import Kingfisher
import KRPullLoader

class PhotosViewController: UIViewController {

    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var disposeBag = DisposeBag()
    
    let viewModel = ProductsViewModel()

    @IBOutlet weak var coverView: UIView!
    
    var selectedIndexPath: IndexPath?
    var visibleIndexPath: IndexPath?

    var willRotate = false
    var needRefresh = false
    
    let items: [(icon: String, color: UIColor)] = [
        ("shopping_add", UIColor(red:0.19, green:0.57, blue:1, alpha:1))
    ]

//    let items: [(icon: String, color: UIColor)] = [
//        ("icon_home", UIColor(red:0.19, green:0.57, blue:1, alpha:1)),
//        ("icon_search", UIColor(red:0.22, green:0.74, blue:0, alpha:1)),
//        ("notifications-btn", UIColor(red:0.96, green:0.23, blue:0.21, alpha:1)),
//        ("settings-btn", UIColor(red:0.51, green:0.15, blue:1, alpha:1)),
//        ("nearby-btn", UIColor(red:1, green:0.39, blue:0, alpha:1)),
//        ]

    override func viewDidLoad() {
        super.viewDidLoad()

        self.coverView.backgroundColor = .lightGray
        self.coverView.isHidden = true
        
        ImageCache.default.maxCachePeriodInSecond = -1

        // Do any additional setup after loading the view.
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.allowsMultipleSelection = false
        
        self.collectionView.backgroundColor = .clear
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "photo_background")!)
        
        let loadMoreView = KRPullLoadView()
        loadMoreView.delegate = self
        collectionView.addPullLoadableView(loadMoreView, type: .loadMore)

        self.searchBar.delegate = self

        bind()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        let backgroundView = UIView(frame:self.collectionView.bounds)
        backgroundView.addGestureRecognizer(tap)
        self.collectionView.backgroundView = backgroundView
        
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
    
}

// MARK: - UICollectionViewDataSource

extension PhotosViewController: UICollectionViewDataSource
{
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.viewModel.products.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
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
    
}

// MARK: - UICollectionViewDelegate

extension PhotosViewController: UICollectionViewDelegate
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
            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
                self.zoomImage(imageView: cell.imageView, imageUrl: item.url_large)
            }
        }
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
        imageViewer.show(from: self, transition: .fromOriginalPosition)
    }

}

// MARK: - UICollectionViewDelegateFlowLayout

extension PhotosViewController : UICollectionViewDelegateFlowLayout {
    
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

extension PhotosViewController: HHImageViewControllerDelegate
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
        //print("button did selected: \(atIndex)")
        
        if atIndex == 0 {
            if let selectedIndexPath = self.selectedIndexPath {
                let product = self.viewModel.products[selectedIndexPath.row]
                self.viewModel.addToCart(product)
            }
        }

        return true
    }
}

// MARK: - UISearchBarDelegate

extension PhotosViewController: UISearchBarDelegate
{
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        DispatchQueue.global().async {
            self.selectedIndexPath = nil
            self.viewModel.loadPage(query: self.searchBar.text!, page: 1)
        }
    }
}

// MARK: - KRPullLoadViewDelegate

extension PhotosViewController: KRPullLoadViewDelegate {
    
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

