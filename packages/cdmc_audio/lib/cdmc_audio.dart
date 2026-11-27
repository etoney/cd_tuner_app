import 'dart:async';

import 'package:flutter/services.dart';

/// Loudness of one beat in the metronome bar.
enum BeatLevel { off, soft, click, accent }

/// Dart side of the native audio engine.
///
/// The metronome runs entirely in native code: clicks are mixed into the
/// output stream at exact sample positions, so timing never depends on the
/// Flutter UI thread and playback continues with the screen locked (iOS
/// background audio, Android foreground service).
class CdmcAudio {
  CdmcAudio._();

  static const MethodChannel _m = MethodChannel('cdmc_audio');
  static const EventChannel _pitch = EventChannel('cdmc_audio/pitch');
  static const EventChannel _beat = EventChannel('cdmc_audio/beat');

  static Stream<double>? _pitchStream;
  static Stream<int>? _beatStream;

  /// Detected fundamental frequency in Hz, about ten times a second while the
  /// tuner is listening. Emits -1 when the input is too quiet or unpitched.
  static Stream<double> get pitch => _pitchStream ??=
      _pitch.receiveBroadcastStream().map((e) => (e as num).toDouble());

  /// Index of the beat that is sounding now (0-based), emitted in time with
  /// the audio. Emits -1 when the metronome stops, including when it is
  /// stopped from the lock-screen notification.
  static Stream<int> get beats =>
      _beatStream ??= _beat.receiveBroadcastStream().map((e) => (e as num).toInt());

  /// Asks for microphone access if needed and starts pitch detection.
  /// Returns false when the user declines.
  static Future<bool> startTuner() async =>
      (await _m.invokeMethod<bool>('startTuner')) ?? false;

  static Future<void> stopTuner() => _m.invokeMethod('stopTuner');

  /// Stops the screen from dimming and locking (used while the tuner listens).
  static Future<void> keepAwake(bool on) => _m.invokeMethod('keepAwake', {'on': on});

  /// Plays a steady reference tone (triangle wave) until [stopTone].
  static Future<void> startTone(double hz) =>
      _m.invokeMethod('startTone', {'hz': hz});

  static Future<void> stopTone() => _m.invokeMethod('stopTone');

  /// Plays one short note, for checking a string by ear.
  static Future<void> pluck(double hz) => _m.invokeMethod('pluck', {'hz': hz});

  /// Starts the metronome, or updates it in place when already running
  /// (tempo and pattern changes take effect on the next click).
  static Future<void> setMetronome({
    required double bpm,
    required List<BeatLevel> beats,
    required int subdivision,
    required int sound,
    required bool playing,
  }) =>
      _m.invokeMethod('setMetronome', {
        'bpm': bpm,
        'beats': beats.map((b) => b.index).toList(),
        'subdivision': subdivision,
        'sound': sound,
        'playing': playing,
      });

  /// Plays one accented click of [sound] so the user can hear a preset.
  static Future<void> previewSound(int sound) =>
      _m.invokeMethod('previewSound', {'sound': sound});
}
