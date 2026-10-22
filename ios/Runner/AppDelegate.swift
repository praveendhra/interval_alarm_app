import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets flutter_local_notifications show alarms while the app is open.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate

    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "NotificationSoundConverter") {
      let channel = FlutterMethodChannel(
        name: "interval_alarm/notification_sound",
        binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "convert",
          let args = call.arguments as? [String: Any],
          let src = args["src"] as? String,
          let dest = args["dest"] as? String,
          let seconds = args["seconds"] as? Double
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try NotificationSound.convert(src: src, dest: dest, seconds: seconds)
            DispatchQueue.main.async { result(true) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "convert_failed", message: "\(error)", details: nil))
            }
          }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// iOS only plays notification sounds that are PCM (caf/wav/aiff) and under
/// 30 seconds, from Library/Sounds. This decodes any tune AVFoundation can
/// read (mp3, m4a, wav, aac) and writes it as 16-bit PCM CAF, looping the
/// tune until it fills `seconds`.
enum NotificationSound {
  struct ConversionError: Error, CustomStringConvertible {
    let description: String
  }

  static func convert(src: String, dest: String, seconds: Double) throws {
    let input = try AVAudioFile(forReading: URL(fileURLWithPath: src))
    guard input.length > 0 else { throw ConversionError(description: "empty audio file") }

    let format = input.processingFormat
    let destURL = URL(fileURLWithPath: dest)
    let fm = FileManager.default
    try fm.createDirectory(
      at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let tmpURL = destURL.deletingPathExtension().appendingPathExtension("tmp.caf")
    try? fm.removeItem(at: tmpURL)

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: format.channelCount,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]

    do {
      let output = try AVAudioFile(
        forWriting: tmpURL, settings: settings,
        commonFormat: format.commonFormat, interleaved: format.isInterleaved)

      let chunk: AVAudioFrameCount = 4096
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else {
        throw ConversionError(description: "could not allocate buffer")
      }

      let target = AVAudioFramePosition(seconds * format.sampleRate)
      var written: AVAudioFramePosition = 0
      var emptyReads = 0
      while written < target {
        if input.framePosition >= input.length { input.framePosition = 0 }
        let want = AVAudioFrameCount(min(AVAudioFramePosition(chunk), target - written))
        try input.read(into: buffer, frameCount: want)
        if buffer.frameLength == 0 {
          emptyReads += 1
          if emptyReads > 2 { break }
          input.framePosition = 0
          continue
        }
        emptyReads = 0
        try output.write(from: buffer)
        written += AVAudioFramePosition(buffer.frameLength)
      }
    }

    try? fm.removeItem(at: destURL)
    try fm.moveItem(at: tmpURL, to: destURL)
  }
}
