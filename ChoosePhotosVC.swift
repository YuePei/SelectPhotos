//
//  ChoosePhotosVC.swift
//  LaboratoryManagement
//
//  Created by Peyton on 2019/11/19.
//  Copyright © 2019 shzygk. All rights reserved.
//

import UIKit
import Photos

enum AlbumsListStatus {
    case shown
    case notShown
}

class ChoosePhotosVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    var topView : UIView!
    var collectionView : UICollectionView!
    var blackTranslucentView : UIView!
    var albumsTableView : UITableView!
    
    var allPhotos : PHFetchResult<PHAsset>!
    var smartAlbums : PHFetchResult<PHAssetCollection>!
    var userCollections : PHFetchResult<PHCollection>!
    var imageManager = PHCachingImageManager()
    
    fileprivate var previousPreheatRect = CGRect.zero
    
    var targetSize : CGSize!
    //相册列表的状态，是展开，还是隐藏
    var albumListStatus = AlbumsListStatus.notShown
    //引用相册列表的高度约束，用作动画
    var albumnListViewHeightCons : NSLayoutConstraint?
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
        smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        self.setupUI()
        self.resetCachedAssets()
        PHPhotoLibrary.shared().register(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateCachedAssets()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateCachedAssets()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    //MARK: -------UICollectionViewDataSource-------
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.allPhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath)
        let asset = self.allPhotos.object(at: indexPath.row)
        if asset.mediaSubtypes.contains(.photoLive) {
            
        }
        
        self.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil, resultHandler: {image, _ in
            cell.contentView.layer.contents = image?.cgImage
        })
        
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateCachedAssets()
    }
    
    // MARK: Asset Caching
    
    fileprivate func resetCachedAssets() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = .zero
    }
    
    fileprivate func updateCachedAssets() {
        // Update only if the view is visible.
        guard isViewLoaded && view.window != nil else { return }
        
        //预加载的frame的高度是当前可见frame的2倍，注意insetBy的用法
        let visibleRect = CGRect(origin: collectionView!.contentOffset, size: collectionView!.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        print("visibleRect : \(visibleRect)")
        print("preHeatRect : \(preheatRect)")
        print("previous : \(self.previousPreheatRect)")
        print("-------------------------------")
        print("preMidY : \(preheatRect.midY)")
        print("previousMidY : \(previousPreheatRect.midY)")
        print("------------------------------\n")
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else { return }
        
        // Compute the assets to start and stop caching.
        let (addedRects, removedRects) = self.differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
            .map { indexPath in self.allPhotos.object(at: indexPath.item) }
        
        
        let removedAssets = removedRects
            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
            .map { indexPath in self.allPhotos.object(at: indexPath.item) }
        
        // Update the assets the PHCachingImageManager is caching.
        self.imageManager.startCachingImages(for: addedAssets,
                                        targetSize: self.targetSize, contentMode: .aspectFill, options: nil)
        self.imageManager.stopCachingImages(for: removedAssets,
                                       targetSize: self.targetSize, contentMode: .aspectFill, options: nil)
        // Store the computed rectangle for future comparison.
        previousPreheatRect = preheatRect
    }
    
    fileprivate func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        print(old.minY, old.maxY)
        //判断新frame和旧frame是否相交
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
    //MARK: -------ToolMethods-------
    private func setupUI() {
        self.initTopViews()
        self.initCollectionView()
        self.initBlackTranslucentView()
        self.initAlbumsList()
    }
    
    @objc func clickCancelBtn() {
        self.dismiss(animated: true) {
            
        }
    }
    
    @objc private func showOrHideAlbumList() {
        if self.albumListStatus == .notShown {
            self.showAlbumsList()
        }else {
            self.hideAlbumsList()
        }
    }
    
    
    @objc func showAlbumsList() {
        //1、显示相册列表
        for cons in self.view.constraints {
            if cons.firstItem is UITableView && cons.firstAttribute == NSLayoutConstraint.Attribute.height {
                self.albumnListViewHeightCons = cons
                cons.constant = 300
                UIView.animate(withDuration: 0.3,
                               delay: 0,
                               usingSpringWithDamping: 0.8,
                               initialSpringVelocity: 5,
                               options: UIView.AnimationOptions.curveEaseIn,
                               animations: {
                                
                                self.view.layoutIfNeeded()
                                
                }) { (succeed) in
                    if succeed {
                        self.albumListStatus = .shown
                    }
                }
            }
        }
        
        //2、显示黑色半透明背景
        self.blackTranslucentView.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            self.blackTranslucentView.alpha = 1
        }) { (succeed) in
            if succeed {
                //动画成功
                
            }
        }
    }
    
    @objc private func hideAlbumsList() {
        if self.albumListStatus == .shown {
            //1、隐藏相册列表
            self.albumnListViewHeightCons?.constant = 0
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 5,
                           options: UIView.AnimationOptions.curveEaseOut,
                           animations: {
                            self.view.layoutIfNeeded()
            }) { (succeed) in
                if succeed {
                    self.albumListStatus = .notShown
                }
            }
        }
        
        //2、隐藏黑色半透明背景
        UIView.animate(withDuration: 0.3, animations: {
            self.blackTranslucentView.alpha = 0
        }) { (succeed) in
            if succeed {
                //动画成功，隐藏
                self.blackTranslucentView.isHidden = true
            }
        }
    }
    
    private func initTopViews() {
        self.topView = UIView.init(frame: CGRect.init(x: 0, y: statusBar_Height, width: screenWidth, height: 44))
        self.view.addSubview(self.topView!)
        self.topView!.backgroundColor = UIColor.red
        
        //取消按钮
        let cancleButton = UIButton.init(type: UIButton.ButtonType.custom)
        cancleButton.frame = CGRect.init(x: 20, y: 5, width: 40, height: 34)
        self.topView!.addSubview(cancleButton)
        cancleButton.setTitle("取消", for: UIControl.State.normal)
        cancleButton.addTarget(self, action: #selector(clickCancelBtn), for: UIControl.Event.touchUpInside)
        
        //中间的选择相册按钮
        let exchangeAlbumBtn = UIButton.init(type: UIButton.ButtonType.custom)
        self.topView!.addSubview(exchangeAlbumBtn)
        exchangeAlbumBtn.frame = CGRect.init(x: 0, y: 0, width: 100, height: 34)
        exchangeAlbumBtn.center = CGPoint.init(x: self.topView!.center.x, y: self.topView!.frame.height / 2.0)
        exchangeAlbumBtn.setTitle("最近项目", for: UIControl.State.normal)
        exchangeAlbumBtn.addTarget(self, action: #selector(self.showOrHideAlbumList), for: UIControl.Event.touchUpInside)
    }
    
    private func initCollectionView() {
        let layout = UICollectionViewFlowLayout.init()
        layout.sectionInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        let width = (screenWidth - 3 * 5) / 4.0
        let height = width
        let scale = UIScreen.main.scale
        self.targetSize = CGSize.init(width: width * scale, height: height * scale)
        layout.estimatedItemSize = CGSize.init(width: width, height: height)
        
        self.collectionView = UICollectionView.init(frame: CGRect.zero, collectionViewLayout: layout)
        self.collectionView.backgroundColor = UIColor.white
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "imageCell")
        self.view.addSubview(self.collectionView!)
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        let topCons = NSLayoutConstraint.init(item: self.collectionView!, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.topView, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0)
        let leadingCons = NSLayoutConstraint.init(item: self.collectionView!, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1, constant: 0)
        let trailingCons = NSLayoutConstraint.init(item: self.collectionView!, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1, constant: 0)
        let bottomCons = NSLayoutConstraint.init(item: self.collectionView!, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0)
        self.view.addConstraints([topCons, leadingCons, trailingCons, bottomCons])
    }
    
    private func initBlackTranslucentView() {
        self.blackTranslucentView = UIView.init()
        self.blackTranslucentView.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.6)
        self.view.addSubview(self.blackTranslucentView)
        self.blackTranslucentView.translatesAutoresizingMaskIntoConstraints = false
        let topCons = NSLayoutConstraint.init(item: self.blackTranslucentView!, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.topView, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0)
        let leadingCons = NSLayoutConstraint.init(item: self.blackTranslucentView!, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1, constant: 0)
        let trailingCons = NSLayoutConstraint.init(item: self.blackTranslucentView!, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1, constant: 0)
        let bottomCons = NSLayoutConstraint.init(item: self.blackTranslucentView!, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0)
        self.view.addConstraints([topCons, leadingCons, trailingCons, bottomCons])
        self.blackTranslucentView.alpha = 0
        self.blackTranslucentView.isHidden = true
        
        let tapGes = UITapGestureRecognizer.init(target: self, action: #selector(self.hideAlbumsList))
        self.blackTranslucentView.addGestureRecognizer(tapGes)
        
    }
    
    private func initAlbumsList()  {
        self.albumsTableView = UITableView.init(frame: CGRect.zero, style: UITableView.Style.plain)
        self.view.addSubview(self.albumsTableView)
        self.albumsTableView.translatesAutoresizingMaskIntoConstraints = false
        let topCons = NSLayoutConstraint.init(item: self.albumsTableView!, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.topView, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0)
        let leadingCons = NSLayoutConstraint.init(item: self.albumsTableView!, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1, constant: 0)
        let trailingCons = NSLayoutConstraint.init(item: self.albumsTableView!, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1, constant: 0)
        let heightCons = NSLayoutConstraint.init(item: self.albumsTableView!, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.height, multiplier: 0, constant: 0)
        self.view.addConstraints([topCons, leadingCons, trailingCons, heightCons])
        self.albumsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.albumsTableView.delegate = self
        self.albumsTableView.dataSource = self
        self.albumsTableView.tableFooterView = UIView.init()
        
    }
}

extension ChoosePhotosVC : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let smart = self.smartAlbums {
            return smart.count
        }else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let collection = self.smartAlbums.object(at: indexPath.row)
        cell.textLabel?.text = collection.localizedTitle
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        //隐藏相册列表
        self.hideAlbumsList()
    }
}

extension ChoosePhotosVC : PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let changes = changeInstance.changeDetails(for: self.allPhotos)
            else { return }
        
        // Change notifications may originate from a background queue.
        // As such, re-dispatch execution to the main queue before acting
        // on the change, so you can update the UI.
        DispatchQueue.main.sync {
            // Hang on to the new fetch result.
             self.allPhotos = changes.fetchResultAfterChanges
            // If we have incremental changes, animate them in the collection view.
            if changes.hasIncrementalChanges {
                guard let collectionView = self.collectionView else { fatalError() }
                // Handle removals, insertions, and moves in a batch update.
                collectionView.performBatchUpdates({
                    if let removed = changes.removedIndexes, !removed.isEmpty {
                        collectionView.deleteItems(at: removed.map({ IndexPath(item: $0, section: 0) }))
                    }
                    if let inserted = changes.insertedIndexes, !inserted.isEmpty {
                        collectionView.insertItems(at: inserted.map({ IndexPath(item: $0, section: 0) }))
                    }
                    changes.enumerateMoves { fromIndex, toIndex in
                        collectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
                                                to: IndexPath(item: toIndex, section: 0))
                    }
                })
                // We are reloading items after the batch update since `PHFetchResultChangeDetails.changedIndexes` refers to
                // items in the *after* state and not the *before* state as expected by `performBatchUpdates(_:completion:)`.
                if let changed = changes.changedIndexes, !changed.isEmpty {
                    collectionView.reloadItems(at: changed.map({ IndexPath(item: $0, section: 0) }))
                }
            } else {
                // Reload the collection view if incremental changes are not available.
                collectionView.reloadData()
            }
            self.resetCachedAssets()
        }
    }
}

private extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)!
        return allLayoutAttributes.map { $0.indexPath }
    }
}
