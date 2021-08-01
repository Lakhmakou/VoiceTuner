//
//  EffectMaker.swift
//  VoiceTuner
//
//  Created by Max on 31.07.21.
//

import AVKit

enum Effect: String, CaseIterable {
  case man
  case monster
  case girl
  case cartoon
  case room
  case alien

  var icon: UIImage {
    return UIImage(named: "\(self.rawValue)Ico") ?? UIImage()
  }
}

protocol EffectMaking: AnyObject {
  func makeEffect(_ effectType: Effect?)
  func configure(audioFile: AVAudioFile)
  func saveAudioFile(completion: @escaping (AVAudioFile, URL) -> ())
  func stopEngine()
}

final class EffectMaker {

  private var audioPlayerNode: AVAudioPlayerNode
  private var inputAudioFile: AVAudioFile?
  private var audioEngine: AVAudioEngine?
  private var currentEffect: AVAudioUnitEffect?
  private var reverb: AVAudioUnitReverb?
  private var distortion: AVAudioUnitDistortion?
  private var pitch: AVAudioUnitTimePitch?
  private var outputFile: AVAudioFile?

  init(audioPlayerNode: AVAudioPlayerNode) {
    self.audioPlayerNode = audioPlayerNode
  }
}

//MARK: - Private methods

extension EffectMaker {

  private func makeMan() {
    makeDefault()
    pitch?.pitch = -200
  }

  private func makeMonster() {
    makeDefault()
    pitch?.pitch = -800
    reverb?.wetDryMix = 30
  }

  private func makeGirl() {
    makeDefault()
    pitch?.pitch = 600
    distortion?.preGain = -30
  }

  private func makeRoom() {
    makeDefault()
    reverb?.wetDryMix = 50
  }

  private func makeCartoon() {
    makeDefault()
    pitch?.pitch = 1200
  }

  private func makeAlien() {
    makeDefault()
    distortion?.loadFactoryPreset(.speechAlienChatter)
  }

  private func makeDefault() {
    reverb?.wetDryMix = 0
    pitch?.pitch = 0
    distortion?.loadFactoryPreset(.drumsBitBrush)
    distortion?.wetDryMix = 0
  }
}

//MARK: - EffectMaking

extension EffectMaker: EffectMaking {

  func configure(audioFile: AVAudioFile) {
    inputAudioFile = audioFile
    audioEngine = AVAudioEngine()
    guard let audioEngine = audioEngine else { return }
    audioEngine.stop()
    let mixer = audioEngine.mainMixerNode

    audioEngine.attach(audioPlayerNode)
    audioEngine.connect(mixer, to: audioEngine.outputNode, format: audioFile.processingFormat)
    
    reverb = AVAudioUnitReverb()
    distortion = AVAudioUnitDistortion()
    pitch = AVAudioUnitTimePitch()

    if let reverb = reverb,
       let distortion = distortion,
       let pitch = pitch {
      
      audioEngine.attach(reverb)
      audioEngine.connect(reverb, to: mixer, format: audioFile.processingFormat)
      audioEngine.connect(audioPlayerNode, to: reverb, format: audioFile.processingFormat)

      audioEngine.attach(distortion)
      audioEngine.connect(distortion, to: mixer, format: audioFile.processingFormat)
      audioEngine.connect(reverb, to: distortion, format: audioFile.processingFormat)

      audioEngine.attach(pitch)
      audioEngine.connect(pitch, to: mixer, format: audioFile.processingFormat)
      audioEngine.connect(distortion, to: pitch, format: audioFile.processingFormat)

    }

    audioEngine.prepare()
    do {
      try audioEngine.start()
      audioPlayerNode.scheduleFile(audioFile, at: nil) {
        if audioEngine.isRunning {
          audioEngine.stop()
        }
      }
    } catch {
      print(error.localizedDescription)
    }
  }

  func makeEffect(_ effectType: Effect?) {

    switch effectType {
    case .man:
      makeMan()
    case .monster:
      makeMonster()
    case .girl:
      makeGirl()
    case .cartoon:
      makeCartoon()
    case .room:
      makeRoom()
    case .alien:
      makeAlien()
    case .none:
      makeDefault()
    }
  }

  func stopEngine() {
    audioEngine?.stop()
    audioEngine?.reset()
    audioEngine = nil
  }

  func saveAudioFile(completion: @escaping (AVAudioFile, URL) -> ()) {

    let audioSession = AVAudioSession.sharedInstance()
    let sampleRate = audioSession.sampleRate


    guard let mixer = audioEngine?.mainMixerNode,
          let inputFile = inputAudioFile,
          let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let outputUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "newAudio.aac")
        if FileManager.default.fileExists(atPath: outputUrl.path) {
          try? FileManager.default.removeItem(atPath: outputUrl.path)
        }
        do {
          let outputFile = try AVAudioFile(forWriting: outputUrl,
                                     settings: [
                                      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                      AVSampleRateKey: Int(audioFormat.sampleRate),
                                      AVNumberOfChannelsKey: Int(audioFormat.channelCount),
                                      AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
                                  ],
                                     commonFormat: .pcmFormatFloat32,
                                     interleaved: true)
          mixer.installTap(onBus: 0,
                           bufferSize: 1024,
                           format: mixer.outputFormat(forBus: 0)) { [weak self] buffer, time in
            do {
              if outputFile.length < inputFile.length {
                try outputFile.write(from: buffer)
              } else {
                completion(outputFile, outputUrl)
                self?.audioEngine?.mainMixerNode.removeTap(onBus: 0)
                self?.audioEngine?.reset()
              }

            } catch {
              print(error.localizedDescription) }
          }
          audioEngine?.prepare()
          do {
            try audioEngine?.start()
          } catch {
            print(error.localizedDescription)
            return
          }
        } catch {
          print(error.localizedDescription)
        }
  }
}
