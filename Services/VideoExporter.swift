//
//  VideoExporter.swift
//  VoiceTuner
//
//  Created by Max on 1.08.21.
//

import AVKit

protocol VideoExporting: AnyObject {
  func mergeVideoAndAudio(videoUrl: URL,
                          audioUrl: URL,
                          success: @escaping ((URL) -> Void),
                          failure: @escaping ((Error?) -> Void))
}

final class VideoExporter: VideoExporting {
  func mergeVideoAndAudio(videoUrl: URL,
                          audioUrl: URL,
                          success: @escaping ((URL) -> Void),
                          failure: @escaping ((Error?) -> Void)) {


    let mixComposition: AVMutableComposition = AVMutableComposition()
    var mutableCompositionVideoTrack: [AVMutableCompositionTrack] = []
    var mutableCompositionAudioTrack: [AVMutableCompositionTrack] = []
    let totalVideoCompositionInstruction : AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()

    let videoAsset: AVAsset = AVAsset(url: videoUrl)
    let audioAsset: AVAsset = AVAsset(url: audioUrl)

    if let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid), let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
      mutableCompositionVideoTrack.append(videoTrack)
      mutableCompositionAudioTrack.append(audioTrack)

      if let videoAssetTrack: AVAssetTrack = videoAsset.tracks(withMediaType: .video).first,
         let audioAssetTrack: AVAssetTrack = audioAsset.tracks(withMediaType: .audio).first {
        do {
          try mutableCompositionVideoTrack.first?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAssetTrack.timeRange.duration), of: videoAssetTrack, at: CMTime.zero)
          try mutableCompositionAudioTrack.first?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAssetTrack.timeRange.duration), of: audioAssetTrack, at: CMTime.zero)
          videoTrack.preferredTransform = videoAssetTrack.preferredTransform
        } catch{
          print(error.localizedDescription)
        }


        totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero,duration: videoAssetTrack.timeRange.duration)
      }
    }

    let mutableVideoComposition: AVMutableVideoComposition = AVMutableVideoComposition()
    mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
    mutableVideoComposition.renderSize = CGSize(width: 480, height: 640)

    if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
      let outputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("convertedVideo.mp4")

      do {
        if FileManager.default.fileExists(atPath: outputURL.path) {

          try FileManager.default.removeItem(at: outputURL)
        }
      } catch {
        print(error.localizedDescription)
      }

      if let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) {
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true

        /// try to export the file and handle the status cases
        exportSession.exportAsynchronously(completionHandler: {
          switch exportSession.status {
          case .failed:
            if let error = exportSession.error {
              failure(error)
            }

          case .cancelled:
            if let error = exportSession.error {
              failure(error)
            }

          default:
            print("finished")
            success(outputURL)
          }
        })
      } else {
        failure(nil)
      }
    }
  }
}
