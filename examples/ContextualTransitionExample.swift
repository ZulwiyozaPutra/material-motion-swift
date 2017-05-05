/*
 Copyright 2016-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit
import IndefiniteObservable
import MaterialMotion

let numberOfImageAssets = 10
let numberOfPhotosInAlbum = 30

struct Photo {
  let name: String
  let image: UIImage
  let uuid: String

  fileprivate init(name: String) {
    self.uuid = NSUUID().uuidString
    self.name = name

    // NOTE: In a real app you should never load images from disk on the UI thread like this.
    // Instead, you should find some way to cache the thumbnails in memory and then asynchronously
    // load the full-size photos from disk/network when needed. The photo library APIs provide
    // exactly this sort of behavior (square thumbnails are accessible immediately on the UI thread
    // while the full-sized photos need to be loaded asynchronously).
    self.image = UIImage(named: "\(self.name).jpg")!
  }
}

class PhotoAlbum {
  let photos: [Photo]
  let identifierToIndex: [String: Int]

  init() {
    var photos: [Photo] = []
    var identifierToIndex: [String: Int] = [:]
    for index in 0..<numberOfPhotosInAlbum {
      let photo = Photo(name: "image\(index % numberOfImageAssets)")
      photos.append(photo)
      identifierToIndex[photo.uuid] = index
    }
    self.photos = photos
    self.identifierToIndex = identifierToIndex
  }
}

private let photoCellIdentifier = "photoCell"

private class PhotoCollectionViewCell: UICollectionViewCell {
  let imageView = UIImageView()

  override init(frame: CGRect) {
    super.init(frame: frame)

    imageView.contentMode = .scaleAspectFill
    imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    imageView.frame = bounds
    imageView.clipsToBounds = true

    contentView.addSubview(imageView)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func imageViewForTransition() -> UIImageView {
    return imageView
  }
}

public class ContextualTransitionExampleViewController: UICollectionViewController, TransitionContextViewRetriever {

  let album = PhotoAlbum()

  init() {
    super.init(collectionViewLayout: UICollectionViewFlowLayout())
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func viewDidLoad() {
    super.viewDidLoad()

    collectionView!.backgroundColor = .white
    collectionView!.register(PhotoCollectionViewCell.self,
                             forCellWithReuseIdentifier: photoCellIdentifier)
  }

  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    updateLayout()
  }

  func updateLayout() {
    let layout = collectionView!.collectionViewLayout as! UICollectionViewFlowLayout
    layout.sectionInset = .init(top: 4, left: 4, bottom: 4, right: 4)
    layout.minimumInteritemSpacing = 4
    layout.minimumLineSpacing = 4

    let numberOfColumns: CGFloat = 3
    let squareDimension = (view.bounds.width - layout.sectionInset.left - layout.sectionInset.right - (numberOfColumns - 1) * layout.minimumInteritemSpacing) / numberOfColumns
    layout.itemSize = CGSize(width: squareDimension, height: squareDimension)
  }

  public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return album.photos.count
  }

  public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: photoCellIdentifier,
                                                  for: indexPath) as! PhotoCollectionViewCell
    let photo = album.photos[indexPath.row]
    cell.imageView.image = photo.image
    return cell
  }

  public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let viewController = PhotoAlbumViewController(album: album)
    viewController.currentPhoto = album.photos[indexPath.row]
    present(viewController, animated: true)
  }

  public func contextViewForTransition(foreViewController: UIViewController) -> UIView? {
    guard let photoViewController = foreViewController as? PhotoAlbumViewController else {
      return nil
    }
    let currentPhoto = photoViewController.currentPhoto
    guard let photoIndex = album.identifierToIndex[currentPhoto.uuid] else {
      return nil
    }
    let photoIndexPath = IndexPath(item: photoIndex, section: 0)
    guard let visibleView = collectionView?.cellForItem(at: photoIndexPath) else {
      collectionView?.scrollToItem(at: photoIndexPath, at: .top, animated: false)
      collectionView?.reloadItems(at: [photoIndexPath])
      return collectionView?.cellForItem(at: photoIndexPath)
    }
    return visibleView
  }
}

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

  var collectionView: UICollectionView!
  var currentPhoto: Photo

  let album: PhotoAlbum
  init(album: PhotoAlbum) {
    self.album = album
    self.currentPhoto = self.album.photos.first!

    super.init(nibName: nil, bundle: nil)

    transitionController.transitionType = PushBackTransition.self
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    automaticallyAdjustsScrollViewInsets = false

    let layout = UICollectionViewFlowLayout()
    layout.itemSize = view.bounds.size
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 8
    layout.footerReferenceSize = CGSize(width: layout.minimumLineSpacing / 2,
                                        height: view.bounds.size.height)
    layout.headerReferenceSize = layout.footerReferenceSize
    layout.scrollDirection = .horizontal

    collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
    collectionView.isPagingEnabled = true
    collectionView.backgroundColor = .backgroundColor
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.dataSource = self
    collectionView.delegate = self

    collectionView.register(PhotoCollectionViewCell.self,
                            forCellWithReuseIdentifier: photoCellIdentifier)

    var extendedBounds = view.bounds
    extendedBounds.size.width = extendedBounds.width + layout.minimumLineSpacing
    collectionView.bounds = extendedBounds

    view.addSubview(collectionView)

    transitionController.disableSimultaneousRecognition(of: collectionView.panGestureRecognizer)

    for gesture in [UIPanGestureRecognizer(), UIPinchGestureRecognizer(), UIRotationGestureRecognizer()] {
      transitionController.dismissWhenGestureRecognizerBegins(gesture)
      view.addGestureRecognizer(gesture)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    collectionView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    navigationController?.setNavigationBarHidden(true, animated: animated)

    let photoIndex = album.photos.index { $0.image == currentPhoto.image }!
    let indexPath = IndexPath(item: photoIndex, section: 0)
    collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return album.photos.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: photoCellIdentifier,
                                                  for: indexPath) as! PhotoCollectionViewCell
    let photo = album.photos[indexPath.row]
    cell.imageView.image = photo.image
    cell.imageView.contentMode = .scaleAspectFit
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    dismiss(animated: true)
  }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    currentPhoto = album.photos[indexPathForCurrentPhoto().item]
  }

  func indexPathForCurrentPhoto() -> IndexPath {
    return collectionView.indexPathsForVisibleItems.first!
  }
}

public final class SlopRegion2: Interaction2 {
  init(_ direction: ReactiveProperty<TransitionDirection>, size: CGFloat, withTranslationOf gesture: UIPanGestureRecognizer, relativeTo: UIView) {
    self.direction = direction
    self.size = size

    self.stream = Reactive(gesture).events.translation(in: relativeTo)
  }

  private let direction: ReactiveProperty<TransitionDirection>
  private let stream: MotionObservable<CGPoint>
  private var subscription: Subscription?

  /**
   The velocity axis to observe.
   */
  public enum Axis {
    /**
     Observes the velocity's x axis.
     */
    case x

    /**
     Observes the velocity's y axis.
     */
    case y
  }

  public var axis: Axis = .y

  public var size: CGFloat

  public func enable() {

    let axis = self.axis
    let size = self.size
    let direction = self.direction

    let chooseAxis: (MotionObservable<CGPoint>) -> MotionObservable<CGFloat>
    switch axis {
    case .x:
      chooseAxis = { $0.x() }
    case .y:
      chooseAxis = { $0.y() }
    }

    subscription = chooseAxis(stream).slop(size: size).rewrite([.onExit: .backward, .onReturn: .forward]).subscribeToValue {
      direction.value = $0
    }
  }
  public func disable() {
    subscription?.unsubscribe()
    subscription = nil
  }
}

private class PushBackTransition: Transition {

  required init() {}

  func willBeginTransition(withContext ctx: TransitionContext, runtime: MotionRuntime) -> [Stateful] {
    let foreVC = ctx.fore as! PhotoAlbumViewController
    let foreImageView = (foreVC.collectionView.cellForItem(at: foreVC.indexPathForCurrentPhoto()) as! PhotoCollectionViewCell).imageView
    let contextView = ctx.contextView() as! PhotoCollectionViewCell
    let replicaView = ctx.replicator.replicate(view: contextView.imageView)

    let imageSize = foreImageView.image!.size

    let fitScale = min(foreImageView.bounds.width / imageSize.width,
                       foreImageView.bounds.height / imageSize.height)
    let fitSize = CGSize(width: fitScale * imageSize.width, height: fitScale * imageSize.height)

    let backPosition = contextView.superview!.convert(contextView.layer.position, to: ctx.containerView())
    let forePosition = foreImageView.superview!.convert(foreImageView.layer.position, to: ctx.containerView())

    let transitionSpring = TransitionSpring2(for: Reactive(replicaView.layer).positionKeyPath,
                                             direction: ctx.direction)
    transitionSpring.destinations = [
      .backward: backPosition,
      .forward: forePosition
    ]
    let tossable = Tossable2(replicaView, relativeTo: ctx.containerView(), spring: transitionSpring)

    tossable.draggable.gesture = ctx.gestureRecognizers.flatMap { $0 as? UIPanGestureRecognizer }.first

    if let gesture = tossable.draggable.gesture {
      let slopRegion = SlopRegion2(ctx.direction, size: 100, withTranslationOf: gesture, relativeTo: ctx.containerView())
      slopRegion.enable()

      // TODO: Create a FlickToDismiss interaction and a separate ChangeDirection interaction for
      // modal transitions.
      let changeDirection = ChangeDirection2(ctx.direction, withVelocityOf: gesture, containerView: ctx.containerView())
      changeDirection.enable()
    }

    let size = TransitionSpring2(for: Reactive(replicaView.layer).sizeKeyPath, direction: ctx.direction)
    size.destinations = [ .backward: contextView.bounds.size, .forward: fitSize ]

    // TODO: How do better define this pattern of "when dragging, stop this animation".
    size.stop()
    size.enable()
    tossable.draggable.state.subscribeToValue {
      if $0 == .active {
        size.stop()
      } else {
        size.start()
      }
    }

    tossable.enable()

    let opacity = TransitionSpring2(for: Reactive(ctx.fore.view.layer).opacityKeyPath, direction: ctx.direction)
    opacity.destinations = [ .backward: 0, .forward: 1 ]
    opacity.enable()

    runtime.add(Hidden(), to: foreImageView)

    return [tossable, size, opacity]
  }
}

// TODO: The need here is we want to hide a given view will the transition is active. This
// implementation does not register a stream with the runtime.
private class Hidden: Interaction {
  deinit {
    for view in hiddenViews {
      view.isHidden = false
    }
  }
  func add(to view: UIView, withRuntime runtime: MotionRuntime, constraints: NoConstraints) {
    view.isHidden = true
    hiddenViews.insert(view)
  }
  var hiddenViews = Set<UIView>()
}
