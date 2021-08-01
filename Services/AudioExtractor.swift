//
//  AudioExtractor.swift
//  VoiceTuner
//
//  Created by Max on 31.07.21.
//

import AVKit

protocol AudioExtracting: AnyObject {
  func getAudioFile(from videoUrl: URL, completion: @escaping (AVAudioFile) -> ())
}

final class AudioExtractor: AudioExtracting {

  func getAudioFile(from videoUrl: URL, completion: @escaping (AVAudioFile) -> ()) {
    let composition = AVMutableComposition()
    let asset = AVURLAsset(url: videoUrl)
    guard let audioAssetTrack = asset.tracks(withMediaType: .audio).first,
          let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
    do {
      try audioCompositionTrack.insertTimeRange(audioAssetTrack.timeRange, of: audioAssetTrack, at: CMTime.zero)
    } catch {
      print(error)
    }

    let outputUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "audio.m4a")
    if FileManager.default.fileExists(atPath: outputUrl.path) {
      try? FileManager.default.removeItem(atPath: outputUrl.path)
    }

    let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)!
    exportSession.outputFileType = AVFileType.m4a
    exportSession.outputURL = outputUrl

    exportSession.exportAsynchronously {
      guard case exportSession.status = AVAssetExportSession.Status.completed else { return }

      DispatchQueue.main.async {
        guard let outputUrl = exportSession.outputURL,
              let audioFile = try? AVAudioFile(forReading: outputUrl) else { return }
        completion(audioFile)
      }
    }
  }
}

