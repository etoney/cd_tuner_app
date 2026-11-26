import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Instrument { guitar, bass }

extension InstrumentX on Instrument {
  String get label => this == Instrument.guitar ? 'GUITAR' : 'BASS';
  List<int> get counts => this == Instrument.guitar ? const [6, 7, 8] : const [4, 5, 6];
}

const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flatNames = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];

String noteName(int midi) => noteNames[midi % 12];
int noteOctave(int midi) => midi ~/ 12 - 1;
String notesLine(List<int> midis) => midis.map((m) => _flatNames[m % 12]).join(' ');

/// A tuning: notes from the lowest string to the highest, plus optional
/// fine-tune offsets in cents for each string.
class Tuning {
  const Tuning(this.name, this.notes, this.midis, [this.cents = const []]);
  final String name;
  final String notes;
  final List<int> midis;
  final List<int> cents;

  int centsAt(int i) => i < cents.length ? cents[i] : 0;

  double hz(int i, double a4) =>
      a4 * math.pow(2, (midis[i] - 69) / 12 + centsAt(i) / 1200).toDouble();
}

class CustomTuning {
  CustomTuning({
    required this.id,
    required this.name,
    required this.instrument,
    required this.midis,
    required this.cents,
  });

  final String id;
  final String name;
  final Instrument instrument;
  final List<int> midis;
  final List<int> cents;

  int get count => midis.length;
  Tuning get tuning => Tuning(name, notesLine(midis), midis, cents);

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'instr': instrument.name,
        'midis': midis,
        'cents': cents,
      };

  static CustomTuning fromJson(Map<String, dynamic> j) => CustomTuning(
        id: j['id'] as String,
        name: j['name'] as String,
        instrument: Instrument.values.byName(j['instr'] as String),
        midis: (j['midis'] as List).cast<int>(),
        cents: (j['cents'] as List).cast<int>(),
      );
}

String _key(Instrument i, int count) => '${i.name}$count';

const Map<String, List<Tuning>> presets = {
  'guitar6': [
    Tuning('Standard', 'E A D G B E', [40, 45, 50, 55, 59, 64]),
    Tuning('Eb Standard', 'Eb Ab Db Gb Bb Eb', [39, 44, 49, 54, 58, 63]),
    Tuning('Drop D', 'D A D G B E', [38, 45, 50, 55, 59, 64]),
    Tuning('D Standard', 'D G C F A D', [38, 43, 48, 53, 57, 62]),
    Tuning('Drop C', 'C G C F A D', [36, 43, 48, 53, 57, 62]),
    Tuning('Drop B', 'B F# B E G# C#', [35, 42, 47, 52, 56, 61]),
    Tuning('Open G', 'D G D G B D', [38, 43, 50, 55, 59, 62]),
    Tuning('DADGAD', 'D A D G A D', [38, 45, 50, 55, 57, 62]),
  ],
  'guitar7': [
    Tuning('B Standard', 'B E A D G B E', [35, 40, 45, 50, 55, 59, 64]),
    Tuning('Drop A', 'A E A D G B E', [33, 40, 45, 50, 55, 59, 64]),
    Tuning('A Standard', 'A D G C F A D', [33, 38, 43, 48, 53, 57, 62]),
    Tuning('Drop G', 'G D G C F A D', [31, 38, 43, 48, 53, 57, 62]),
  ],
  'guitar8': [
    Tuning('F# Standard', 'F# B E A D G B E', [30, 35, 40, 45, 50, 55, 59, 64]),
    Tuning('Drop E', 'E B E A D G B E', [28, 35, 40, 45, 50, 55, 59, 64]),
    Tuning('E Standard', 'E A D G C F A D', [28, 33, 38, 43, 48, 53, 57, 62]),
    Tuning('Drop D#', 'D# A# D# G# C# F# A# D#', [27, 34, 39, 44, 49, 54, 58, 63]),
  ],
  'bass4': [
    Tuning('Standard', 'E A D G', [28, 33, 38, 43]),
    Tuning('Drop D', 'D A D G', [26, 33, 38, 43]),
    Tuning('D Standard', 'D G C F', [26, 31, 36, 41]),
    Tuning('Drop C', 'C G C F', [24, 31, 36, 41]),
    Tuning('Eb Standard', 'Eb Ab Db Gb', [27, 32, 37, 42]),
  ],
  'bass5': [
    Tuning('B Standard', 'B E A D G', [23, 28, 33, 38, 43]),
    Tuning('Drop A', 'A E A D G', [21, 28, 33, 38, 43]),
    Tuning('A Standard', 'A D G C F', [21, 26, 31, 36, 41]),
    Tuning('High C', 'E A D G C', [28, 33, 38, 43, 48]),
  ],
  'bass6': [
    Tuning('B Standard', 'B E A D G C', [23, 28, 33, 38, 43, 48]),
    Tuning('Drop A', 'A E A D G C', [21, 28, 33, 38, 43, 48]),
    Tuning('A Standard', 'A D G C F Bb', [21, 26, 31, 36, 41, 46]),
  ],
};

/// The player's current instrument, string count and chosen tuning for each
/// setup, plus their custom tunings. Saved on the device.
class Rig extends ChangeNotifier {
  Instrument instrument = Instrument.guitar;
  int count = 6;
  double a4 = 440;

  /// Selected tuning per setup: an int index into [presets], or 'c:<id>'.
  final Map<String, Object> _sel = {};
  final List<CustomTuning> customs = [];
  SharedPreferences? _prefs;

  String get key => _key(instrument, count);
  List<Tuning> get presetList => presets[key]!;
  List<CustomTuning> get customList =>
      customs.where((c) => c.instrument == instrument && c.count == count).toList();

  Object get selection => _sel[key] ?? 0;

  Tuning get current {
    final s = selection;
    if (s is String && s.startsWith('c:')) {
      final c = customs.where((t) => t.id == s.substring(2));
      if (c.isNotEmpty) return c.first.tuning;
    }
    final i = s is int ? s : 0;
    return presetList[math.min(i, presetList.length - 1)];
  }

  bool isPresetSelected(int i) {
    final s = selection;
    if (s is int) return s == i;
    final exists = s is String && customs.any((c) => 'c:${c.id}' == s);
    return !exists && i == 0;
  }

  bool isCustomSelected(CustomTuning c) => selection == 'c:${c.id}';

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    final raw = p.getString('rig');
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        instrument = Instrument.values.byName(j['instr'] as String);
        count = j['count'] as int;
        if (!presets.containsKey(key)) {
          instrument = Instrument.guitar;
          count = 6;
        }
        a4 = (j['a4'] as num?)?.toDouble() ?? 440;
        (j['sel'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _sel[k] = v as Object);
      } catch (_) {}
    }
    final rawC = p.getString('customs');
    if (rawC != null) {
      try {
        customs.addAll((jsonDecode(rawC) as List)
            .map((e) => CustomTuning.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    notifyListeners();
  }

  void _save() {
    _prefs?.setString(
        'rig', jsonEncode({'instr': instrument.name, 'count': count, 'a4': a4, 'sel': _sel}));
    _prefs?.setString('customs', jsonEncode(customs.map((c) => c.toJson()).toList()));
    notifyListeners();
  }

  void setInstrument(Instrument i) {
    instrument = i;
    count = i.counts.first;
    _save();
  }

  void setCount(int c) {
    count = c;
    _save();
  }

  void nextCount() {
    final list = instrument.counts;
    setCount(list[(list.indexOf(count) + 1) % list.length]);
  }

  void setA4(double v) {
    a4 = v.clamp(415, 466).toDouble();
    _save();
  }

  void selectPreset(int i) {
    _sel[key] = i;
    _save();
  }

  void selectCustom(CustomTuning c) {
    _sel[_key(c.instrument, c.count)] = 'c:${c.id}';
    _save();
  }

  /// Adds or replaces a custom tuning and makes it the selected one.
  void saveCustom(CustomTuning c) {
    customs.removeWhere((x) => x.id == c.id);
    customs.add(c);
    instrument = c.instrument;
    count = c.count;
    _sel[key] = 'c:${c.id}';
    _save();
  }

  void deleteCustom(CustomTuning c) {
    customs.removeWhere((x) => x.id == c.id);
    final k = _key(c.instrument, c.count);
    if (_sel[k] == 'c:${c.id}') _sel[k] = 0;
    _save();
  }
}
