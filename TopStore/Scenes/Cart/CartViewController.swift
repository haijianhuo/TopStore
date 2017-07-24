//
//  CartViewController.swift
//  TopStore
//
//  Created by Haijian Huo on 7/14/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import Kingfisher
import JTSImageViewController

class CartViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    var disposeBag = DisposeBag()
    
    let viewModel = CartViewModel.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: String(describing: CartCell.self), bundle: nil), forCellReuseIdentifier: String(describing: CartCell.self))
        
        _ = tableView.rx.setDataSource(self)
        _ = tableView.rx.setDelegate(self)
        
        bind()
    }
    
    func bind() {
        
        
        self.viewModel.productsUpdated.asObservable().subscribe(onNext: { [weak self] (element) in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.updateBadge()
            }
        }).addDisposableTo(disposeBag)

        
    }
    
    @IBAction func clearButtonTapped(_ sender: Any) {
        self.clearConfirm()
    }
    
    @IBAction func checkoutButtonTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Checkout?", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func updateBadge() {
        self.tabBarController?.tabBar.items?.last?.badgeValue =
        self.viewModel.products.count > 0 ?  String(self.viewModel.products.count) : nil
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
    
    func clearConfirm() {
        let alert = UIAlertController(title: "Clear Cart?", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.viewModel.clearCart()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }

    
    func deleteConfirm(at indexPath: IndexPath) {
        let alert = UIAlertController(title: "Delete?", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteRow(at: indexPath)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func deleteRow(at indexPath: IndexPath) {
        self.viewModel.removeRow(at: indexPath, productsUpdated: false)
        self.tableView.deleteRows(at: [indexPath], with: .automatic)
        self.updateBadge()
        
    }

}

// MARK: - UITableViewDataSource

extension CartViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.products.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.deleteRow(at: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: CartCell.self), for: indexPath) as! CartCell
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        
        let item = self.viewModel.products[indexPath.row]

        cell.titleLabel.text = item.name
        
        if let url = URL(string: item.url_small) {
            _ = cell.photoView.kf.setImage(with: url,
                                           placeholder: UIImage(named: "Placeholder"),
                                           options: [.transition(ImageTransition.fade(1))],
                                           progressBlock: nil,
                                           completionHandler: nil)

        }
        else {
            cell.photoView.image = UIImage(named: "Placeholder")
        }
        
        cell.priceLabel.text = CurrencyFormatter.dollarsFormatter.rw_string(from: item.price)

        
        _ = cell.deleteButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.view.endEditing(true)
                if let indexPath = tableView.indexPath(for: cell) {
                    self.deleteConfirm(at: indexPath)
                }

                
            }).addDisposableTo(cell.disposeBag)

        _ = cell.photoButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.zoomImage(imageView: cell.photoView, imageUrl: item.url_large)
            }).addDisposableTo(cell.disposeBag)

        return cell
        
    }
    
}

// MARK: - UITableViewDelegate

extension CartViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
    }
}

// MARK: - JTSImageViewControllerDismissalDelegate

extension CartViewController: JTSImageViewControllerDismissalDelegate
{
    func imageViewerDidDismiss(_ imageViewer: JTSImageViewController!) {
        if let imageURL = imageViewer.imageInfo.imageURL {
            if let image = imageViewer.image {
                ImageCache.default.store(image, forKey: imageURL.absoluteString)
            }
        }
    }
    
}
