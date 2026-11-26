import 'dart:math' as math;

import 'package:cdmc_audio/cdmc_audio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/tunings.dart';
import '../ui/style.dart';

/// Build or edit a custom tuning: tap any string, then pick its note,
/// octave and fine-tune. Starts from the current setup and tuning.
class CustomTuningScreen extends StatefulWidget {
  const CustomTuningScreen({super.key, required this.rig, this.existing});
  final Rig rig;
  final CustomTuning? existing;

  @override
  State<CustomTuningScreen> createState() => _CustomTuningScreenState();
}

class _CustomTuningScreenState extends State<CustomTuningScreen> {
  late final String id;
  late final Instrument instrument;
  late final TextEditingController name;
  late List<int> midis;
  late List<int> cents;
  int? open;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      id = e.id;
      instrument = e.instrument;
      name = TextEditingController(text: e.name);
      midis = [...e.midis];
      cents = [...e.cents];
    } else {
      final t = widget.rig.current;
      id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      instrument = widget.rig.instrument;
      name = TextEditingController(text: 'My Tuning');
      midis = [...t.midis];
      cents = List.generate(t.midis.length, t.centsAt);
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  double hz(int i) => widget.rig.a4 * math.pow(2, (midis[i] - 69) / 12 + cents[i] / 1200).toDouble();

  void _save() {
    widget.rig.saveCustom(CustomTuning(
      id: id,
      name: name.text.trim().isEmpty ? 'My Tuning' : name.text.trim(),
      instrument: instrument,
      midis: midis,
      cents: cents,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final n = midis.length;
    return Scaffold(
      body: DesignCanvas(
        child: Stack(children: [
          Positioned(
            left: 18,
            top: 52,
            width: 354,
            height: 48,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(height: 44, child: Center(child: Text('Cancel', style: T.gothic(20, color: C.muted)))),
              ),
              OvalButton.text('SAVE', width: 88, height: 44, selected: true, onTap: _save),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 96,
            child: Center(
              child: Text(
                'Custom Tuning',
                style: GoogleFonts.unifrakturCook(fontSize: 46, fontWeight: FontWeight.w700, color: C.bone, shadows: const [
                  Shadow(color: Colors.black, offset: Offset(0, 3)),
                  Shadow(color: Color(0xB3961408), blurRadius: 12),
                ]),
              ),
            ),
          ),
          Positioned(left: 110, top: 150, width: 170, height: 21, child: Image.asset(Img.flourish, fit: BoxFit.fill)),
          Positioned(
            left: 18,
            top: 176,
            width: 354,
            height: 64,
            child: Parchment(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('NAME', style: T.caps(11, color: const Color(0xFF3A2414), spacing: 2).copyWith(shadows: [])),
                Expanded(
                  child: TextField(
                    controller: name,
                    maxLength: 24,
                    cursorColor: C.ink,
                    style: T.ink(26),
                    decoration: const InputDecoration(border: InputBorder.none, counterText: '', isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 18,
            top: 250,
            width: 354,
            height: 520,
            child: ListView(padding: EdgeInsets.zero, children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text('Tap a string to set it · $n-string ${instrument.name}', style: T.gothic(18)),
              ),
              for (var i = 0; i < n; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Semantics(
                    button: true,
                    label: 'String ${n - i}, ${noteName(midis[i])}${noteOctave(midis[i])}. Tap to change.',
                    child: GestureDetector(
                      onTap: () => setState(() => open = i),
                      child: RustPlate(
                        radius: 8,
                        borderColor: open == i ? C.gold : const Color(0xFF1E130D),
                        rivets: false,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          height: 46,
                          child: Row(children: [
                            SizedBox(width: 62, child: Text('STR ${n - i}', style: T.caps(12, color: C.peach, spacing: 1))),
                            Expanded(
                              child: Container(
                                height: 4.4 - i * (3.4 / math.max(1, n - 1)),
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [C.bone, Color(0xFF8A7A62)],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('${noteName(midis[i])}${noteOctave(midis[i])}', style: T.gothic(26)),
                            ),
                            SizedBox(
                              width: 84,
                              child: Text('${hz(i).toStringAsFixed(2)} Hz',
                                  textAlign: TextAlign.right, style: T.digits(15, color: C.bone, glow: false)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          if (open != null) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => open = null),
                child: const ColoredBox(color: Color(0xB3050303)),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _sheet(open!)),
          ],
        ]),
      ),
    );
  }

  Widget _sheet(int i) {
    final n = midis.length;
    final note = midis[i] % 12;
    final oct = noteOctave(midis[i]);
    void setNote(int k) => setState(() => midis[i] = (oct + 1) * 12 + k);
    void setOct(int o) => setState(() => midis[i] = (o.clamp(0, 6).toInt() + 1) * 12 + note);
    void setCents(int c) => setState(() => cents[i] = c.clamp(-50, 50).toInt());

    return RustPlate(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFF1E130D), borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ScreenInset(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('String ${n - i} · ${noteName(midis[i])}$oct', style: T.gothic(28)),
              const Spacer(),
              Text('${hz(i).toStringAsFixed(2)} Hz', style: T.digits(22)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 6,
          childAspectRatio: 50 / 44,
          children: [
            for (var k = 0; k < 12; k++)
              OvalButton.text(noteNames[k], height: 44, fontSize: 15, selected: k == note, onTap: () => setNote(k)),
          ],
        ),
        const SizedBox(height: 12),
        _stepper('Octave', '$oct', () => setOct(oct - 1), () => setOct(oct + 1), 'Octave down', 'Octave up'),
        const SizedBox(height: 12),
        _stepper('Fine tune', '${cents[i] > 0 ? '+' : ''}${cents[i]}¢', () => setCents(cents[i] - 5),
            () => setCents(cents[i] + 5), 'Lower 5 cents', 'Raise 5 cents'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OvalButton.text('HEAR IT', height: 52, onTap: () => CdmcAudio.pluck(hz(i)))),
          const SizedBox(width: 12),
          Expanded(child: OvalButton.text('DONE', height: 52, selected: true, onTap: () => setState(() => open = null))),
        ]),
      ]),
    );
  }

  Widget _stepper(String label, String value, VoidCallback down, VoidCallback up, String downLabel, String upLabel) {
    Widget btn(String asset, String l, VoidCallback f) => Semantics(
          button: true,
          label: l,
          child: GestureDetector(onTap: f, child: Image.asset(asset, width: 48, height: 48)),
        );
    return SizedBox(
      height: 48,
      child: Row(children: [
        Text(label, style: T.gothic(20)),
        const Spacer(),
        btn(Img.minus, downLabel, down),
        SizedBox(width: 56, child: Text(value, textAlign: TextAlign.center, style: T.digits(22, color: C.bone, glow: false))),
        btn(Img.plus, upLabel, up),
      ]),
    );
  }
}
