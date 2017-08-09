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
import PopupDialog

class CartViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    var selectedIndexPath: IndexPath?

    var disposeBag = DisposeBag()
    
    let viewModel = CartViewModel.shared

    let items: [(icon: String, color: UIColor)] = [
        ("shopping_delete", UIColor(red:0.96, green:0.23, blue:0.21, alpha:1))
    ]
    
    @IBOutlet weak var summaryView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let image = UIImage(named:"photo_background") {
            self.view.backgroundColor = UIColor(patternImage: image)
        }

        
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
        let popup = PopupDialog(title: "Check out shopping cart", message: "Not implemented yet!", buttonAlignment: .horizontal, transitionStyle: .zoomIn, gestureDismissal: true) {
        }
        
        let buttonOne = CancelButton(title: "OK") {
        }
        
        popup.addButtons([buttonOne])
        self.present(popup, animated: true, completion: nil)
    }
    
    func updateBadge() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            if let tabBarContainer = appDelegate.window?.rootViewController as? TabBarContainer {
                if let button = tabBarContainer.tabBarButton(name: .cart) {
                    button.badgeString = self.viewModel.products.count > 0 ?  String(self.viewModel.products.count) : nil
                }
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
        imageViewer.showCircleMenuOnStart = true
        imageViewer.show(from: self, transition: .fromOriginalPosition)
    }
    
    func clearConfirm() {
        
        let popup = PopupDialog(title: "Clear shopping cart", message: "Remove all items from shopping cart?", buttonAlignment: .horizontal, transitionStyle: .zoomIn, gestureDismissal: true) {
        }
        
        let buttonOne = CancelButton(title: "Cancel") {
        }
        
        let buttonTwo = DestructiveButton(title: "Remove") {
            self.viewModel.clearCart()
        }
        popup.addButtons([buttonOne, buttonTwo])
        self.present(popup, animated: true, completion: nil)
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
        //cell.delegate = self

        return cell
        
    }
    
}

// MARK: - UITableViewDelegate

extension CartViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        self.selectedIndexPath = indexPath

        let product = self.viewModel.products[indexPath.row]
        if let cell = tableView.cellForRow(at: indexPath) as? CartCell {
            self.zoomImage(imageView: cell.photoView, imageUrl: product.url_large)
        }

    }
}

// MARK: - CartCellDelegate
/*
extension CartViewController: CartCellDelegate
{
    func deleteButtonDidTap(_ cell: CartCell, _ sender: Any) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            self.deleteConfirm(at: indexPath)
        }
    }
    
    func photoButtonDidTap(_ cell: CartCell, _ sender: Any) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let item = self.viewModel.products[indexPath.row]
            self.zoomImage(imageView: cell.photoView, imageUrl: item.url_large)
       }
    }
}
*/

// MARK: - HHImageViewControllerDelegate

extension CartViewController: HHImageViewControllerDelegate
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
                self.deleteRow(at: selectedIndexPath)
            }
        }
        
        return true
    }
}

