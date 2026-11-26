import 'dart:async';

import 'package:cdmc_audio/cdmc_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeSig {
  const TimeSig(this.label, this.groups);
  final String label;

  /// Beat groupings, e.g. 7/8 = [2, 2, 3]. Simple meters use all 1s.
  final List<int> groups;

  int get beats => groups.fold(0, (a, b) => a + b);
  bool get simple => groups.every((g) => g == 1);
  String get groupLabel => simple ? label : '$label (${groups.join('+')})';

  /// Default accents: beat 1 accented, the start of each group a click,
  /// the rest soft (simple meters: all clicks).
  List<BeatLevel> defaults() {
    final out = <BeatLevel>[];
    for (var g = 0; g < groups.length; g++) {
      for (var k = 0; k < groups[g]; k++) {
        if (g == 0 && k == 0) {
          out.add(BeatLevel.accent);
        } else {
          out.add(k == 0 || simple ? BeatLevel.click : BeatLevel.soft);
        }
      }
    }
    return out;
  }
}

const timeSigs = [
  TimeSig('2/2', [1, 1]),
  TimeSig('2/4', [1, 1]),
  TimeSig('3/4', [1, 1, 1]),
  TimeSig('4/4', [1, 1, 1, 1]),
  TimeSig('5/4', [1, 1, 1, 1, 1]),
  TimeSig('7/4', [1, 1, 1, 1, 1, 1, 1]),
  TimeSig('5/8', [3, 2]),
  TimeSig('6/8', [3, 3]),
  TimeSig('7/8', [2, 2, 3]),
  TimeSig('9/8', [3, 3, 3]),
  TimeSig('10/8', [3, 3, 2, 2]),
  TimeSig('11/8', [3, 3, 3, 2]),
  TimeSig('12/8', [3, 3, 3, 3]),
  TimeSig('13/8', [3, 3, 3, 2, 2]),
  TimeSig('15/8', [3, 3, 3, 3, 3]),
  TimeSig('15/16', [4, 4, 4, 3]),
];
const fourFour = 3;

const subdivisions = [('1/4', 1), ('1/8', 2), ('Trip', 3), ('1/16', 4)];
const soundNames = ['Anvil', 'Woodblock', 'Rimshot', 'Iron Bell', 'Bone', 'Hi-Hat', 'Cowbell', 'Beep'];

String tempoName(int bpm) {
  if (bpm < 60) return 'LARGO';
  if (bpm < 76) return 'ADAGIO';
  if (bpm < 108) return 'ANDANTE';
  if (bpm < 120) return 'MODERATO';
  if (bpm < 168) return 'ALLEGRO';
  if (bpm < 200) return 'PRESTO';
  return 'PRESTISSIMO';
}

/// Metronome settings and play state. Lives for the whole app, so the
/// metronome keeps going when you switch to the tuner.
class Metronome extends ChangeNotifier {
  Metronome() {
    _beatSub = CdmcAudio.beats.listen((b) {
      if (b < 0) {
        if (playing) {
          playing = false;
          beat = -1;
          notifyListeners();
        }
        return;
      }
      beat = b;
      notifyListeners();
    });
  }

  int bpm = 120;
  int sig = fourFour;
  int sub = 0;
  int sound = 0;
  List<BeatLevel> levels = timeSigs[fourFour].defaults();
  bool playing = false;
  int beat = -1;

  late final StreamSubscription<int> _beatSub;
  final List<int> _taps = [];
  SharedPreferences? _prefs;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    bpm = p.getInt('m_bpm') ?? 120;
    sig = (p.getInt('m_sig') ?? fourFour).clamp(0, timeSigs.length - 1).toInt();
    sub = (p.getInt('m_sub') ?? 0).clamp(0, subdivisions.length - 1).toInt();
    sound = (p.getInt('m_sound') ?? 0).clamp(0, soundNames.length - 1).toInt();
    final lv = p.getStringList('m_levels');
    levels = lv != null && lv.length == timeSigs[sig].beats
        ? lv.map((s) => BeatLevel.values[int.parse(s).clamp(0, 3).toInt()]).toList()
        : timeSigs[sig].defaults();
    notifyListeners();
  }

  void _apply() {
    _prefs
      ?..setInt('m_bpm', bpm)
      ..setInt('m_sig', sig)
      ..setInt('m_sub', sub)
      ..setInt('m_sound', sound)
      ..setStringList('m_levels', levels.map((l) => '${l.index}').toList());
    CdmcAudio.setMetronome(
      bpm: bpm.toDouble(),
      beats: levels,
      subdivision: subdivisions[sub].$2,
      sound: sound,
      playing: playing,
    );
    notifyListeners();
  }

  void setBpm(num v) {
    bpm = v.round().clamp(20, 300).toInt();
    _apply();
  }

  void setSig(int i) {
    sig = i;
    levels = timeSigs[i].defaults();
    beat = -1;
    _apply();
  }

  void nextSub() {
    sub = (sub + 1) % subdivisions.length;
    _apply();
  }

  void nextSound() {
    sound = (sound + 1) % soundNames.length;
    _apply();
    CdmcAudio.previewSound(sound);
  }

  /// Accent → click → soft → off → accent.
  void cycleBeat(int i) {
    const order = {
      BeatLevel.accent: BeatLevel.click,
      BeatLevel.click: BeatLevel.soft,
      BeatLevel.soft: BeatLevel.off,
      BeatLevel.off: BeatLevel.accent,
    };
    levels = [...levels]..[i] = order[levels[i]]!;
    _apply();
  }

  void tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_taps.isNotEmpty && now - _taps.last > 2000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 5) _taps.removeAt(0);
    if (_taps.length > 1) setBpm(60000 * (_taps.length - 1) / (now - _taps.first));
  }

  void reset() {
    bpm = 120;
    sig = fourFour;
    sub = 0;
    levels = timeSigs[fourFour].defaults();
    _apply();
  }

  void toggle() {
    playing = !playing;
    if (!playing) beat = -1;
    _apply();
  }

  @override
  void dispose() {
    _beatSub.cancel();
    super.dispose();
  }
}
