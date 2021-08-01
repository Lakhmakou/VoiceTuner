//
//  CameraConfiguration.swift
//  AVFoundationSwift
//
//  Created by Rubaiyat Jahan Mumu on 7/16/19.
//  Copyright © 2019 Rubaiyat Jahan Mumu. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

protocol CameraConfiguration: AnyObject {
  func setup(delegate: AVCaptureFileOutputRecordingDelegate, handler: @escaping (Error?)-> Void)
  func displayPreview(_ view: UIView) throws
  func recordVideo(completion: @escaping (URL?, Error?)-> Void)
  func stopRecording(completion: @escaping (Error?)->Void)
  func switchCameras() throws 
}

final class CameraConfigurator: NSObject {

  private enum CameraControllerError: Swift.Error {
    case captureSessionAlreadyRunning
    case captureSessionIsMissing
    case inputsAreInvalid
    case invalidOperation
    case noCamerasAvailable
    case unknown
  }

  private enum CameraPosition {
    case front
    case rear
  }

  private var captureSession: AVCaptureSession?
  private var frontCamera: AVCaptureDevice?
  private var rearCamera: AVCaptureDevice?
  private var audioDevice: AVCaptureDevice?

  private var currentCameraPosition: CameraPosition?
  private var frontCameraInput: AVCaptureDeviceInput?
  private var rearCameraInput: AVCaptureDeviceInput?
  private var previewLayer: AVCaptureVideoPreviewLayer?

  private var videoRecordCompletionBlock: ((URL?, Error?) -> Void)?

  private var videoOutput: AVCaptureMovieFileOutput?
  private var audioInput: AVCaptureDeviceInput?
  private weak var delegate: AVCaptureFileOutputRecordingDelegate?
}

//MARK: - Private methods

private extension CameraConfigurator {
  func createCaptureSession() {
    self.captureSession = AVCaptureSession()
  }

  func configureCaptureDevices() throws {
    let session = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera],
                                                        mediaType: .video,
                                                        position: .unspecified)

    let cameras = (session.devices.compactMap{$0})

    for camera in cameras {
      if camera.position == .front {
        self.frontCamera = camera
      }
      if camera.position == .back {
        self.rearCamera = camera

        try camera.lockForConfiguration()
        camera.focusMode = .continuousAutoFocus
        camera.unlockForConfiguration()
      }
    }
    audioDevice = AVCaptureDevice.default(for: .audio)
  }

  func configureDeviceInputs() throws {
    guard let captureSession = captureSession else {
      throw CameraControllerError.captureSessionIsMissing
    }
    if let frontCamera = frontCamera {
      self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
      if captureSession.canAddInput(self.frontCameraInput!) {
        captureSession.addInput(self.frontCameraInput!)
        currentCameraPosition = .front
      } else {
        throw CameraControllerError.inputsAreInvalid
      }
    } else if let rearCamera = self.rearCamera {
      self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
      if captureSession.canAddInput(self.rearCameraInput!) {
        captureSession.addInput(self.rearCameraInput!)
        currentCameraPosition = .rear
      } else {
        throw CameraControllerError.inputsAreInvalid
      }
    } else {
      throw CameraControllerError.noCamerasAvailable
    }

    if let audioDevice = self.audioDevice {
      self.audioInput = try AVCaptureDeviceInput(device: audioDevice)
      if captureSession.canAddInput(self.audioInput!) {
        captureSession.addInput(self.audioInput!)
      } else {
        throw CameraControllerError.inputsAreInvalid
      }
    }
  }

  func configureVideoOutput() throws {
    guard let captureSession = self.captureSession else {
      throw CameraControllerError.captureSessionIsMissing
    }

    self.videoOutput = AVCaptureMovieFileOutput()
    if captureSession.canAddOutput(self.videoOutput!) {
      captureSession.addOutput(self.videoOutput!)
    }
    captureSession.startRunning()
  }

  func switchToFrontCamera(captureSession: AVCaptureSession, inputs: [AVCaptureInput]) throws {
    guard let rearCameraInput = self.rearCameraInput,
          inputs.contains(rearCameraInput),
          let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }

    captureSession.removeInput(rearCameraInput)
    self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
    if captureSession.canAddInput(self.frontCameraInput!) {
      captureSession.addInput(frontCameraInput!)
      currentCameraPosition = .front
    }

    else { throw CameraControllerError.invalidOperation }
  }

  func switchToRearCamera(captureSession: AVCaptureSession, inputs: [AVCaptureInput]) throws {
    guard let frontCameraInput = self.frontCameraInput,
          inputs.contains(frontCameraInput),
          let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }

    captureSession.removeInput(frontCameraInput)
    self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
    if captureSession.canAddInput(rearCameraInput!) {
      captureSession.addInput(rearCameraInput!)
      currentCameraPosition = .rear
    }

    else { throw CameraControllerError.invalidOperation }
  }
}

//MARK: - CameraConfiguration

extension CameraConfigurator: CameraConfiguration {

  func setup(delegate: AVCaptureFileOutputRecordingDelegate, handler: @escaping (Error?)-> Void) {
    self.delegate = delegate
    DispatchQueue(label: "setup").async { [weak self] in
      do {
        self?.createCaptureSession()
        try self?.configureCaptureDevices()
        try self?.configureDeviceInputs()
        try self?.configureVideoOutput()
      } catch {
        DispatchQueue.main.async {
          handler(error)
        }
        return
      }

      DispatchQueue.main.async {
        handler(nil)
      }
    }
  }

  func displayPreview(_ view: UIView) throws {
    guard let captureSession = self.captureSession,
          captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }

    self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
    self.previewLayer?.connection?.videoOrientation = .portrait

    view.layer.insertSublayer(self.previewLayer!, at: 0)
    self.previewLayer?.frame = CGRect(x: 0, y: 0, width: view.frame.width , height: view.frame.height)
  }

  func switchCameras() throws {
    guard let currentCameraPosition = currentCameraPosition,
          let captureSession = self.captureSession,
          captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
    captureSession.beginConfiguration()
    let inputs = captureSession.inputs

    switch currentCameraPosition {
    case .front:
      try switchToRearCamera(captureSession: captureSession, inputs: inputs)

    case .rear:
      try switchToFrontCamera(captureSession: captureSession, inputs: inputs)
    }
    captureSession.commitConfiguration()
  }

  func recordVideo(completion: @escaping (URL?, Error?) -> Void) {
    guard let captureSession = captureSession,
          let delegate = delegate,
          captureSession.isRunning else {
      completion(nil, CameraControllerError.captureSessionIsMissing)
      return
    }

    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let fileUrl = paths[0].appendingPathComponent("video.mov")
    try? FileManager.default.removeItem(at: fileUrl)
    videoOutput!.startRecording(to: fileUrl, recordingDelegate: delegate)
    self.videoRecordCompletionBlock = completion
  }

  func stopRecording(completion: @escaping (Error?) -> Void) {
    guard let captureSession = self.captureSession,
          captureSession.isRunning else {
      completion(CameraControllerError.captureSessionIsMissing)
      return
    }
    self.videoOutput?.stopRecording()
  }
}

