import 'package:cd_tuner_app/data/metronome.dart';
import 'package:cd_tuner_app/data/tunings.dart';
import 'package:cdmc_audio/cdmc_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every preset has one note per string', () {
    presets.forEach((key, list) {
      final count = int.parse(key.replaceAll(RegExp(r'[a-z]'), ''));
      for (final t in list) {
        expect(t.midis.length, count, reason: '$key ${t.name}');
      }
    });
  });

  test('standard tuning targets', () {
    final e2 = presets['guitar6']!.first.hz(0, 440);
    expect(e2, closeTo(82.41, 0.01));
    final b0 = presets['bass5']!.first.hz(0, 440);
    expect(b0, closeTo(30.87, 0.01));
  });

  test('7/8 groups as 2+2+3 with accents on each group', () {
    final sig = timeSigs.firstWhere((s) => s.label == '7/8');
    expect(sig.beats, 7);
    expect(sig.defaults(), [
      BeatLevel.accent, BeatLevel.soft,
      BeatLevel.click, BeatLevel.soft,
      BeatLevel.click, BeatLevel.soft, BeatLevel.soft,
    ]);
  });
}
