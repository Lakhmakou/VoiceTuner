//
//  MainViewController.swift
//  VoiceTuner
//
//  Created by Max on 31.07.21.
//

import UIKit
import AVKit

class MainViewController: UIViewController {

  @IBOutlet private weak var captureView: UIView!
  @IBOutlet private weak var startStopButton: UIButton!
  @IBOutlet private weak var previewImageView: UIImageView!

  private var cameraConfigurator: CameraConfiguration?

  var videoRecordingStarted: Bool = false {
    didSet{
      if videoRecordingStarted {
        self.startStopButton.setImage(UIImage(named: "stopButton"), for: .normal)
      } else {
        self.startStopButton.setImage(UIImage(named: "startButton"), for: .normal)
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.cameraConfigurator = CameraConfigurator()
    cameraConfigurator?.setup(delegate: self) { [weak self] error in
      guard let self = self else { return }
      if error != nil {
        print(error!.localizedDescription)
      }
      try? self.cameraConfigurator?.displayPreview(self.previewImageView)
    }
    registerNotification()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.isHidden = true
  }

  @IBAction private func startStopButtonAction(_ sender: UIButton) {
    if videoRecordingStarted {
      videoRecordingStarted = false
      cameraConfigurator?.stopRecording { error in
        if let error = error {
          print(error.localizedDescription)
        }
      }
    } else if !videoRecordingStarted {
      videoRecordingStarted = true
      cameraConfigurator?.recordVideo { _, error in
        if let error = error {
          print(error.localizedDescription )
        }
      }
    }

  }
  @IBAction private func switchCameraAction(_ sender: UIButton) {
    do {
      try cameraConfigurator?.switchCameras()
    } catch {
      print(error.localizedDescription)
    }
  }
  
  @IBAction private func pickFromGalleryAction(_ sender: UIButton) {
    createImagePicker()
  }
}

//MARK: Private methods

extension MainViewController {
  private func registerNotification() {
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self,
                                   selector: #selector(appMovedToBackground),
                                   name: UIApplication.willResignActiveNotification,
                                   object: nil)
  }

  @objc func appMovedToBackground() {
    if videoRecordingStarted {
      videoRecordingStarted = false
      cameraConfigurator?.stopRecording { (error) in
        print(error ?? "")
      }
    }
  }

  func createImagePicker() {
    let pickerController = UIImagePickerController()
    pickerController.delegate = self
    pickerController.allowsEditing = false
    pickerController.mediaTypes = ["public.movie"]
    pickerController.sourceType = .photoLibrary
    present(pickerController, animated: false)
  }
  
  func goToVideoPreview(videoUrl: URL) {
    let vc = VideoPreviewViewController(videoUrl: videoUrl)
    vc.modalPresentationStyle = .overFullScreen
    navigationController?.present(vc, animated: true, completion: nil)
  }
}

//MARK: UIImagePickerControllerDelegate

extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController( _ picker: UIImagePickerController,
                              didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)

    if let videoUrl = info[.mediaURL] as? URL {
      goToVideoPreview(videoUrl: videoUrl)
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }
}


//MARK: - AVCaptureFileOutputRecordingDelegate

extension MainViewController: AVCaptureFileOutputRecordingDelegate {
  func fileOutput(_ output: AVCaptureFileOutput,
                  didFinishRecordingTo outputFileURL: URL,
                  from connections: [AVCaptureConnection],
                  error: Error?) {
    if error == nil {
      goToVideoPreview(videoUrl: outputFileURL)
    } else {
      print(error?.localizedDescription ?? "")
    }
  }
}
