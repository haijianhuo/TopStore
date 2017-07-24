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
import JTSImageViewController

class PhotosViewController: UIViewController {

    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var disposeBag = DisposeBag()
    
    let viewModel = ProductsViewModel()

    var selectedIndexPath: IndexPath?
    var visibleIndexPath: IndexPath?

    var willRotate = false
    var needRefresh = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.allowsMultipleSelection = false
        
        self.collectionView.backgroundColor = .clear
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "photo_background")!)

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
        
        let imageInfo = JTSImageInfo()
        
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
        
        
        imageInfo.referenceRect = imageView.frame
        imageInfo.referenceView = imageView.superview
        
        let imageViewer = JTSImageViewController(imageInfo: imageInfo, mode:JTSImageViewControllerMode.image, backgroundStyle: JTSImageViewControllerBackgroundOptions.scaled)!
        imageViewer.dismissalDelegate = self
        imageViewer.show(from: self, transition: JTSImageViewControllerTransition.fromOriginalPosition)
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


// MARK: - JTSImageViewControllerDismissalDelegate

extension PhotosViewController: JTSImageViewControllerDismissalDelegate
{
    func imageViewerDidDismiss(_ imageViewer: JTSImageViewController!) {
        if let imageURL = imageViewer.imageInfo.imageURL {
            if let image = imageViewer.image {
                ImageCache.default.store(image, forKey: imageURL.absoluteString)
            }
        }
    }
    
}

