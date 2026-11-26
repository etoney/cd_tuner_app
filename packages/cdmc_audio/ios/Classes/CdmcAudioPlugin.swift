import Flutter
import UIKit

public class CdmcAudioPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CdmcAudioPlugin()
        let channel = FlutterMethodChannel(name: "cdmc_audio", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        guard #available(iOS 13.0, *) else { return }
        FlutterEventChannel(name: "cdmc_audio/pitch", binaryMessenger: registrar.messenger())
            .setStreamHandler(Sink { sink in AudioEngine.shared.onPitch = sink.map { s in { (v: Double) in s(v) } } })
        FlutterEventChannel(name: "cdmc_audio/beat", binaryMessenger: registrar.messenger())
            .setStreamHandler(Sink { sink in AudioEngine.shared.onBeat = sink.map { s in { (v: Int) in s(v) } } })
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 13.0, *) else {
            result(FlutterError(code: "unsupported", message: "Needs iOS 13 or later", details: nil))
            return
        }
        let engine = AudioEngine.shared
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "startTuner":
            engine.requestMic { ok in
                result(ok ? engine.startTuner() : false)
            }
        case "stopTuner":
            engine.stopTuner(); result(nil)
        case "startTone":
            engine.startTone((args["hz"] as? NSNumber)?.doubleValue ?? 440); result(nil)
        case "stopTone":
            engine.stopTone(); result(nil)
        case "pluck":
            engine.pluck((args["hz"] as? NSNumber)?.doubleValue ?? 440); result(nil)
        case "previewSound":
            engine.previewSound((args["sound"] as? NSNumber)?.intValue ?? 0); result(nil)
        case "setMetronome":
            engine.setMetronome(
                bpm: (args["bpm"] as? NSNumber)?.doubleValue ?? 120,
                beats: (args["beats"] as? [NSNumber])?.map { $0.intValue } ?? [3, 2, 2, 2],
                subdivision: (args["subdivision"] as? NSNumber)?.intValue ?? 1,
                sound: (args["sound"] as? NSNumber)?.intValue ?? 0,
                playing: (args["playing"] as? Bool) ?? false
            )
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

/// Small adapter so each event channel hands its sink to the engine.
private final class Sink: NSObject, FlutterStreamHandler {
    typealias Emit = (Any) -> Void
    private let attach: (Emit?) -> Void
    init(_ attach: @escaping (Emit?) -> Void) { self.attach = attach }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        attach({ value in events(value) })
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        attach(nil)
        return nil
    }
}
