//
//  ProductsViewController.swift
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

class ProductsViewController: UIViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var avatarPulseButton: HHPulseButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var coverView: UIView!
    
    var disposeBag = DisposeBag()
    
    let viewModel = ProductsViewModel()
    
    var selectedIndexPath: IndexPath?
    var visibleIndexPath: IndexPath?
    
    var willRotate = false
    var needRefresh = false
    
    let items: [(icon: String, color: UIColor)] = [
        ("shopping_add", UIColor(red:0.19, green:0.57, blue:1, alpha:1))
        ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.coverView.backgroundColor = .lightGray
        self.coverView.isHidden = true
        
        self.avatarPulseButton.delegate = self
        
        if let image = UIImage(named:"photo_background") {
            self.view.backgroundColor = UIColor(patternImage: image)
        }
        
        ImageCache.default.maxCachePeriodInSecond = -1
        
        // Do any additional setup after loading the view.
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.allowsMultipleSelection = false
        
        let loadMoreView = KRPullLoadView()
        loadMoreView.delegate = self
        collectionView.addPullLoadableView(loadMoreView, type: .loadMore)

        
        self.searchBar.delegate = self

        bind()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        
        let backgroundView = UIView(frame:self.collectionView.bounds)
        backgroundView.addGestureRecognizer(tap)
        self.collectionView.backgroundView = backgroundView
        
        NotificationCenter.default.addObserver(self, selector:#selector(applicationDidBecomeActiveNotification(_:)), name:NSNotification.Name.UIApplicationDidBecomeActive, object:nil)

    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.avatarPulseButton.animate(start: false)
        
    }

    func applicationDidBecomeActiveNotification(_ notification: NSNotification?) {
        
        self.avatarPulseButton.animate(start: true)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.willRotate = true
        
        if (self.isViewLoaded && (self.view.window != nil)) {
            let indexPaths = self.collectionView.indexPathsForVisibleItems
            if indexPaths.count > 0 {
                let sortedArray = indexPaths.sorted {$0.row < $1.row}
                if let indexPath = sortedArray.first {
                    coordinator.animate(alongsideTransition: nil, completion: {
                        _ in
                        self.showCoverView(true)
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
        
        self.avatarPulseButton.animate(start: true)

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
            UIView.animate(withDuration: 1.8, animations: {
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
    
    func addConfirm(_ product: Product) {
        let alert = UIAlertController(title: "Add to Cart?", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Add", style: .destructive) { _ in
            self.viewModel.addToCart(product)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }

    func handleTap(_ sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
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
    

}

// MARK: - UICollectionViewDataSource

extension ProductsViewController: UICollectionViewDataSource
{
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.viewModel.products.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as! ProductCell
        let product = self.viewModel.products[indexPath.row]
        
        cell.titleLabel.text = product.name
        cell.priceLabel.text = CurrencyFormatter.dollarsFormatter.rw_string(from: product.price)

        if let url = URL(string: product.url_small) {
            _ = cell.imageView.kf.setImage(with: url,
                                           placeholder: UIImage(named: "Placeholder"),
                                           options: [.transition(ImageTransition.fade(1))],
                                           progressBlock: nil,
                                           completionHandler: nil)
            
        }
        else {
            cell.imageView.image = UIImage(named: "Placeholder")
        }
        //cell.delegate = self
        return cell
    }
    
}

// MARK: - UICollectionViewDelegate

extension ProductsViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        self.view.endEditing(true)
        
        self.selectedIndexPath = indexPath
        
        let item = self.viewModel.products[indexPath.row]
        if let cell = collectionView.cellForItem(at: indexPath) as? ProductCell {
            self.zoomImage(imageView: cell.imageView, imageUrl: item.url_large)
        }

    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ProductsViewController : UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var cellsPerRow:CGFloat
        let cellPadding:CGFloat = 2
        if UIDevice.current.userInterfaceIdiom == .pad {
            cellsPerRow = 2
        }
        else {
            cellsPerRow = collectionView.frame.size.width > collectionView.frame.size.height ? 2 : 1
        }
        
        let widthMinusPadding = collectionView.frame.size.width - cellPadding * (cellsPerRow - 1)
        let eachSide = widthMinusPadding / cellsPerRow
        return CGSize(width: eachSide, height: eachSide/2)
    }
}


// MARK: - HHPulseButtonDelegate

extension ProductsViewController: HHPulseButtonDelegate {
    func pulseButton(view: HHPulseButton, buttonPressed sender: AnyObject) {
        let vc = viewController(forStoryboardName: "Me")
        DispatchQueue.main.async {
            self.present(vc, animated: true, completion: nil)
        }
    }
}

// MARK: - HHImageViewControllerDelegate

extension ProductsViewController: HHImageViewControllerDelegate
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

extension ProductsViewController: UISearchBarDelegate
{
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        DispatchQueue.global().async {
            self.selectedIndexPath = nil
            self.viewModel.loadPage(query: self.searchBar.text!, page: 1)
        }
    }
}

// MARK: - ProductCellDelegate

//extension ProductsViewController: ProductCellDelegate
//{
//    func addButtonDidTap(_ cell: ProductCell, _ sender: Any) {
//        self.view.endEditing(true)
//        
//        if let indexPath = self.collectionView.indexPath(for: cell) {
//            self.selectedIndexPath = indexPath
//            let product = self.viewModel.products[indexPath.row]
//            self.addConfirm(product)
//        }
//    }
//    
//    func photoButtonDidTap(_ cell: ProductCell, _ sender: Any) {
//         if let indexPath = self.collectionView.indexPath(for: cell) {
//            self.selectedIndexPath = indexPath
//            
//            let item = self.viewModel.products[indexPath.row]
//            if let cell = collectionView.cellForItem(at: indexPath) as? ProductCell {
//                self.zoomImage(imageView: cell.imageView, imageUrl: item.url_large)
//            }
//        }
//    }
//    
//}

// MARK: - KRPullLoadViewDelegate

extension ProductsViewController: KRPullLoadViewDelegate {
    
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
