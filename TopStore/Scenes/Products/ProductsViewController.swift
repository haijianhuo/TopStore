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

class ProductsViewController: UIViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var avatarPulseButton: HHPulseButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var disposeBag = DisposeBag()
    
    let viewModel = ProductsViewModel()
    
    var selectedIndexPath: IndexPath?
    var visibleIndexPath: IndexPath?
    
    var willRotate = false
    var needRefresh = false
    
    let items: [(icon: String, color: UIColor)] = [
        ("icon_home", UIColor(red:0.19, green:0.57, blue:1, alpha:1)),
        ("icon_search", UIColor(red:0.22, green:0.74, blue:0, alpha:1)),
        ("notifications-btn", UIColor(red:0.96, green:0.23, blue:0.21, alpha:1)),
        ("settings-btn", UIColor(red:0.51, green:0.15, blue:1, alpha:1)),
        ("nearby-btn", UIColor(red:1, green:0.39, blue:0, alpha:1)),
        ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.avatarPulseButton.delegate = self
        
        if let image = UIImage(named:"photo_background") {
            self.view.backgroundColor = UIColor(patternImage: image)
        }
        
        ImageCache.default.maxCachePeriodInSecond = -1
        
        // Do any additional setup after loading the view.
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.allowsMultipleSelection = false
        
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
                    self.collectionView.collectionViewLayout.invalidateLayout()
                    
                    coordinator.animate(alongsideTransition: nil, completion: {
                        _ in
                        self.collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                        self.willRotate = false
                    })
                }
            }
            else {
                self.collectionView.collectionViewLayout.invalidateLayout()
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.avatarPulseButton.animate(start: true)

        if self.needRefresh {
            self.needRefresh = false
            self.collectionView.collectionViewLayout.invalidateLayout()
            if let indexPath = self.selectedIndexPath {
                let dispatchTime = DispatchTime.now() + 0.2
                DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
                    self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
                }
            }
            
        }
    }
    
    func bind() {
        
        searchBar
            .rx
            .searchButtonClicked
            .subscribe(onNext: { [weak self] (element) in
                guard let `self` = self else { return }
                DispatchQueue.global().async {
                    self.selectedIndexPath = nil
                    self.viewModel.loadPage(query: self.searchBar.text!, page: 1)
                }
            }).addDisposableTo(disposeBag)
        
        searchBar
            .rx
            .text
            .map { $0! }
            .throttle(1, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] (element) in
                guard let `self` = self else { return }
                DispatchQueue.global().async {
                    self.selectedIndexPath = nil
                    self.viewModel.loadPage(query: element, page: 1)
                }
            }).addDisposableTo(disposeBag)
        
        self.viewModel.productsUpdated.asObservable().subscribe(onNext: { [weak self] (element) in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }).addDisposableTo(disposeBag)
        
        collectionView.rx.contentOffset
            .filter { [weak self] offset in
                guard let `self` = self else { return false }
                guard !self.willRotate else { return false }
                guard self.collectionView.frame.height > 0 else { return false }
                guard self.collectionView.contentSize.height > 0 else { return false }
                
                self.view.endEditing(true)
                return offset.y + self.collectionView.frame.height >= self.collectionView.contentSize.height - 100
            }
            .subscribe(onNext: { [weak self] (element) in
                guard let `self` = self else { return }
                DispatchQueue.global().async {
                    self.viewModel.loadNextPage()
                }
            })
            .addDisposableTo(disposeBag)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func photoButtonTapped(_ sender: UIButton) {
        
        guard let cell = sender.superview?.superview as? ProductCell else { return }
        
        if let indexPath = self.collectionView.indexPath(for: cell) {
            self.selectedIndexPath = indexPath
            
            let item = self.viewModel.products[indexPath.row]
            if let cell = collectionView.cellForItem(at: indexPath) as? ProductCell {
                self.zoomImage(imageView: cell.imageView, imageUrl: item.url_large)
            }

        }
        
    }

    @IBAction func addButtonTapped(_ sender: UIButton) {
        
        self.view.endEditing(true)
        
        guard let cell = sender.superview?.superview as? ProductCell else { return }
        
        if let indexPath = self.collectionView.indexPath(for: cell) {
            self.selectedIndexPath = indexPath
            
            let product = self.viewModel.products[indexPath.row]
            self.addConfirm(product)
        }
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
        
        return cell
    }
    
}

// MARK: - UICollectionViewDelegate

extension ProductsViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
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
        imageViewer.show(from: self, transition: .fromOriginalPosition)
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
    func imageViewController(_ imageViewController: HHImageViewController, willDisplay button: UIButton, atIndex: Int) {
        button.backgroundColor = items[atIndex].color
        
        button.setImage(UIImage(named: items[atIndex].icon), for: .normal)
        
        // set highlited image
        let highlightedImage  = UIImage(named: items[atIndex].icon)?.withRenderingMode(.alwaysTemplate)
        button.setImage(highlightedImage, for: .highlighted)
        button.tintColor = UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.3)
    }
    
    func imageViewController(_ imageViewController: HHImageViewController, buttonDidSelected button: UIButton, atIndex: Int, image: UIImage?) {
        print("button did selected: \(atIndex)")
    }
}
