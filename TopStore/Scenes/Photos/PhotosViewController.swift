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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.backgroundColor = .clear
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "photo_background")!)

        bind()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.collectionView.collectionViewLayout.invalidateLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let indexPaths = self.collectionView.indexPathsForVisibleItems
        if indexPaths.count > 0 {
            let sortedArray = indexPaths.sorted {$0.row < $1.row}
            if let indexPath = sortedArray.first {
                self.collectionView.collectionViewLayout.invalidateLayout()
                
                coordinator.animate(alongsideTransition: nil, completion: {
                    _ in
                    self.collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                })
            }
        }
        else {
            self.collectionView.collectionViewLayout.invalidateLayout()
        }

    }

    func bind() {
        
        searchBar
            .rx
            .searchButtonClicked
            .subscribe(onNext: { [weak self] (element) in
                guard let `self` = self else { return }
                DispatchQueue.global().async {
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
        
        let item = self.viewModel.products[indexPath.row]
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCell
        self.zoomImage(imageView: cell.imageView, imageUrl: item.url_large)
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

extension PhotosViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let picDimension = collectionView.frame.size.width / 4.0
        return CGSize(width: picDimension, height: picDimension)
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

