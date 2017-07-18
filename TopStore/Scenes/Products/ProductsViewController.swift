//
//  ProductsViewController.swift
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

class ProductsViewController: UIViewController {
    
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var tableView: UITableView!
    
    var disposeBag = DisposeBag()
    
    let viewModel = ProductsViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: String(describing: ProductCell.self), bundle: nil), forCellReuseIdentifier: String(describing: ProductCell.self))
        
        tableView.contentInset.top = self.searchBar.frame.height
        tableView.scrollIndicatorInsets.top = tableView.contentInset.top

        _ = tableView.rx.setDataSource(self)
        _ = tableView.rx.setDelegate(self)
        
        bind()
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
                self.tableView.reloadData()
            }
        }).addDisposableTo(disposeBag)

        
        tableView.rx.contentOffset
            .filter { [weak self] offset in
                guard let `self` = self else { return false }
                guard self.tableView.frame.height > 0 else { return false }
                guard self.tableView.contentSize.height > 0 else { return false }
                return offset.y + self.tableView.frame.height >= self.tableView.contentSize.height - 100
            }
            .subscribe(onNext: { [weak self] (element) in
                guard let `self` = self else { return }
                DispatchQueue.global().async {
                    self.viewModel.loadNextPage()
                }
            })
            .addDisposableTo(disposeBag)
    }
    
    func zoomImage(imageView: UIImageView) {
        
        guard let image = imageView.image else { return }
        
        let imageInfo = JTSImageInfo()
        
        imageInfo.image = image
        
        imageInfo.referenceRect = imageView.frame
        imageInfo.referenceView = imageView.superview
        
        let imageViewer = JTSImageViewController(imageInfo: imageInfo, mode:JTSImageViewControllerMode.image, backgroundStyle: JTSImageViewControllerBackgroundOptions.scaled)!
        
        imageViewer.show(from: self, transition: JTSImageViewControllerTransition.fromOriginalPosition)
    }
    
}

// MARK: - UITableViewDataSource

extension ProductsViewController: UITableViewDataSource
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
            self.viewModel.removeRow(at: indexPath, productsUpdated: false)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ProductCell.self), for: indexPath) as! ProductCell
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        
        let item = self.viewModel.products[indexPath.row]

        cell.titleLabel.text = item.name
        
        if let url = URL(string: item.url) {
            _ = cell.photoView.kf.setImage(with: url,
                                           placeholder: UIImage(named: "Placeholder"),
                                           options: [.transition(ImageTransition.fade(1))],
                                           progressBlock: nil,
                                           completionHandler: nil)

        }
        else {
            cell.photoView.image = UIImage(named: "Placeholder")
        }
        let image = UIImage(named: item.added ? "Check" : "Add")
        cell.addButton.setImage(image, for: .normal)
        
        cell.priceLabel.text = CurrencyFormatter.dollarsFormatter.rw_string(from: item.price)

        
        _ = cell.addButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.view.endEditing(true)
                if let indexPath = tableView.indexPath(for: cell) {
                    let added = !item.added

                    self.viewModel.updateRow(added: added, at: indexPath, productsUpdated: false)
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }

                
            }).addDisposableTo(cell.disposeBag)

        _ = cell.photoButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.zoomImage(imageView: cell.photoView)
            }).addDisposableTo(cell.disposeBag)

        return cell
        
    }
}

// MARK: - UITableViewDelegate

extension ProductsViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
    }
}

