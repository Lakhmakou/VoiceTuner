//
//  VideoPreviewViewController.swift
//  VoiceTuner
//
//  Created by Max on 31.07.21.
//

import UIKit
import AVKit
import Photos
import MessageUI

class VideoPreviewViewController: UIViewController {

  @IBOutlet private weak var videoView: UIView!
  @IBOutlet private weak var collectionView: UICollectionView!
  @IBOutlet private weak var shareView: UIView!
  @IBOutlet private weak var saveButton: UIButton!
  @IBOutlet private weak var loadingView: UIView!
  
  private var audioExtractor: AudioExtracting?
  private var effectMaker: EffectMaking?
  private var videoExporter: VideoExporting?

  private lazy var audioPlayerNode = AVAudioPlayerNode()
  private var audioFile: AVAudioFile?

  private let videoUrl: URL
  private var videoPlayer: AVPlayer?
  private var videoPlayerLayer: AVPlayerLayer?

  private var isAudioExtracted = false
  private var isViewPrepared = false

  init(videoUrl: URL) {
    self.videoUrl = videoUrl
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    configureCollection()
    audioExtractor = AudioExtractor()
    setLoadingScreenActive(true)
    audioExtractor?.getAudioFile(from: videoUrl) { [weak self] audioFile in
      guard let self = self else { return }
      self.audioFile = audioFile
      self.isAudioExtracted = true
      if self.isViewPrepared {
        self.configureAudio()
      }
      self.setLoadingScreenActive(false)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    addVideoPlayer(with: videoUrl, playerView: videoView)
    if isAudioExtracted {
      configureAudio()
    }
    isViewPrepared = true
  }

  @IBAction func closeButtonAction(_ sender: UIButton) {
    effectMaker?.stopEngine()
    dismiss(animated: true, completion: nil)
  }

  @IBAction func saveButtonAction(_ sender: UIButton) {
    setShareViewHidden(false)
    audioPlayerNode.pause()
    videoPlayer?.pause()
  }

  @IBAction func instagramButtonAction(_ sender: UIButton) {
    setShareViewHidden(false)
    setLoadingScreenActive(true)
    prepareVideo { [weak self] url in
      DispatchQueue.main.async {
        self?.setLoadingScreenActive(false)
        self?.dismiss(animated: true, completion: nil)
        self?.shareToInstagram()
      }
    }
  }

  @IBAction func iMessageButtonAction(_ sender: UIButton) {
    setShareViewHidden(true)
    setLoadingScreenActive(true)
    prepareVideo { [weak self] url in
      DispatchQueue.main.async {
        self?.setLoadingScreenActive(false)
        self?.shareToMessage(videoUrl: url)
      }
    }
  }

  @IBAction func moreButtonAction(_ sender: UIButton) {
    setShareViewHidden(true)
    setLoadingScreenActive(true)
    prepareVideo { [weak self] url in
      DispatchQueue.main.async {
        self?.setLoadingScreenActive(false)
        self?.shareOther(videoUrl: url)
      }
    }
  }
}

//MARK: - Private methods

private extension VideoPreviewViewController {

  func setLoadingScreenActive(_ active: Bool) {
    guard let loadingView = loadingView else {
      return
    }

    loadingView.isHidden = !active
  }

  func prepareVideo(completion: @escaping (URL) -> ()) {
    getAudio { [weak self] url in
      self?.mergeVideoAndAudio(audioURL: url) { url in
        self?.saveVideoToAlbum(url) { error in
          if let error = error {
            print(error.localizedDescription)
          } else {
            completion(url)
          }
        }
      }
    }
  }

  func shareToInstagram() {
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)


    if let lastAsset = fetchResult.firstObject {

      PHImageManager().requestAVAsset(
        forVideo: lastAsset,
        options: nil) { avurlAsset, _, _ in

        let videoFilePath = avurlAsset as! AVURLAsset
        let instagramURL = NSURL(string: "instagram://app")
        DispatchQueue.main.async {

          if UIApplication.shared.canOpenURL(instagramURL! as URL) {

            let url = URL(string: ("instagram://library?AssetPath="+videoFilePath.url.path))

            if UIApplication.shared.canOpenURL(url!) {
              UIApplication.shared.open(url!, options: [:], completionHandler:nil)
            }
          } else {
            let urlStr = "https://itunes.apple.com/in/app/instagram/id389801252?mt=8"
            UIApplication.shared.open(URL(string: urlStr)!, options: [:], completionHandler: nil)
          }
        }
      }
    }
  }

  func shareToMessage(videoUrl: URL) {
    let messageVC = MFMessageComposeViewController()
    messageVC.messageComposeDelegate  = self
    messageVC.addAttachmentURL(videoUrl, withAlternateFilename: "myPrettyVoice.mp4")
    present(messageVC, animated: true, completion: nil)
  }

  func shareOther(videoUrl: URL) {

    let items = [videoUrl]
    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
    activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact, .copyToPasteboard, .openInIBooks, .print]
    activityVC.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
      if let error = error {
        print(error.localizedDescription)
      }
      self?.dismiss(animated: false, completion: nil)
    }
    present(activityVC, animated: true)
  }

  func saveVideoToAlbum(_ outputURL: URL, completion: @escaping ((Error?) -> ())) {
    requestAuthorization {
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
      }) { saved, error in
        completion(error)
      }
    }
  }

  func requestAuthorization(completion: @escaping ()->Void) {
    if PHPhotoLibrary.authorizationStatus() != .authorized {
      PHPhotoLibrary.requestAuthorization { (status) in
        DispatchQueue.main.async {
          completion()
        }
      }
    } else {
      completion()
    }
  }

  func getAudio(completion: @escaping (URL) -> ()) {
    effectMaker?.saveAudioFile{ _ , outputFileUrl in
      completion(outputFileUrl)
    }
  }

  func mergeVideoAndAudio(audioURL: URL, completion: @escaping (URL) -> ()) {
    videoExporter = VideoExporter()
    videoExporter?.mergeVideoAndAudio(videoUrl: videoUrl, audioUrl: audioURL, success: { url in
      completion(url)
    }, failure: { error in
      print(error?.localizedDescription ?? "")
    })
  }

  func setShareViewHidden(_ isHidden: Bool) {
    saveButton.isHidden = !isHidden
    shareView.isHidden = isHidden
  }

  func configureCollection() {
    let effectCell = UINib(nibName: "EffectCollectionViewCell", bundle: nil)
    collectionView.register(effectCell, forCellWithReuseIdentifier: "EffectCollectionViewCell")
    collectionView.delegate = self
    collectionView.dataSource = self
  }

  func addVideoPlayer(with url: URL, playerView: UIView) {
    let asset = AVURLAsset(url: url)

    let playerItem = AVPlayerItem(asset: asset)
    videoPlayer = AVPlayer(playerItem: playerItem)
    //    videoPlayer?.currentItem?.audioTimePitchAlgorithm = .spectral
    videoPlayer?.isMuted = true
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(itemDidFinishPlaying(_:)),
                                           name: .AVPlayerItemDidPlayToEndTime,
                                           object: playerItem)

    videoPlayerLayer = AVPlayerLayer(player: videoPlayer)
    videoPlayerLayer?.backgroundColor = UIColor.black.cgColor
    videoPlayerLayer?.frame = CGRect(x: 0, y: 0, width: playerView.frame.width, height: playerView.frame.height)
    videoPlayerLayer?.videoGravity = .resizeAspect
    playerView.layer.sublayers?.forEach({$0.removeFromSuperlayer()})
    if let layer = videoPlayerLayer {
      playerView.layer.addSublayer(layer)
    }
  }

  @objc func itemDidFinishPlaying(_ notification: Notification) {

  }

  func configureAudio() {
    guard let audioFile = audioFile else { return }
    effectMaker = EffectMaker(audioPlayerNode: audioPlayerNode)
    effectMaker?.configure(audioFile: audioFile)
    audioPlayerNode.play()
    videoPlayer?.play()
  }

  func applyEffect(_ effect: Effect) {
    effectMaker?.makeEffect(effect)
  }
}

//MARK: - Collection methods

extension VideoPreviewViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return Effect.allCases.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let item = collectionView.dequeueReusableCell(withReuseIdentifier: "EffectCollectionViewCell", for: indexPath) as? EffectCollectionViewCell else {
      return UICollectionViewCell() }
    item.configure(with: Effect.allCases[indexPath.item].icon)
    return item
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    applyEffect(Effect.allCases[indexPath.item])
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return CGSize(width: collectionView.bounds.height, height: collectionView.bounds.height)
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return collectionView.bounds.height / 2
  }
}

//MARK: - MFMessageComposeViewControllerDelegate

extension VideoPreviewViewController: MFMessageComposeViewControllerDelegate {
  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    controller.dismiss(animated: true, completion: nil)
    dismiss(animated: false, completion: nil)
  }
}
