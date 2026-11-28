import 'dart:async';
import 'dart:math' as math;

import 'package:cdmc_audio/cdmc_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/tunings.dart';
import '../ui/style.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key, required this.rig, required this.active, required this.openTunings});
  final Rig rig;

  /// True while the Tuner tab is showing; the microphone only runs then.
  final bool active;
  final VoidCallback openTunings;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
  int activeString = 0;
  bool auto = true;
  bool listenWanted = true;
  bool listening = false;
  bool micDenied = false;
  bool tone = false;
  double? heard;
  double cents = 0;
  final List<double> _hist = [];
  StreamSubscription<double>? _pitchSub;
  Timer? _holdTimer;

  /// Strings confirmed in tune since the tuning was chosen.
  final Set<int> tuned = {};
  /// True for a moment after a string is confirmed: the skull glows green.
  bool skullGlow = false;
  Timer? _glowTimer;
  DateTime? _inTuneSince;
  /// A reading far from the current note, waiting for a second to confirm it.
  double? _cand;
  int? _confirmed;

  /// How long a string must sit in tune before it counts.
  static const _confirmAfter = Duration(milliseconds: 450);

  /// How long the last reading stays on screen after the string fades out.
  static const _hold = Duration(milliseconds: 2500);
  String _lastKey = '';

  Rig get rig => widget.rig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    rig.addListener(_onRig);
    _lastKey = '${rig.key}|${rig.current.name}';
    _pitchSub = CdmcAudio.pitch.listen(_onPitch);
    if (widget.active) _startMic();
  }

  @override
  void didUpdateWidget(TunerScreen old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      if (widget.active && listenWanted) {
        _startMic();
      } else if (!widget.active) {
        _stopMic(keepWanted: true);
        _setTone(false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      if (widget.active && listenWanted) _startMic();
    } else if (s == AppLifecycleState.paused) {
      _stopMic(keepWanted: true);
      _setTone(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    rig.removeListener(_onRig);
    _pitchSub?.cancel();
    _holdTimer?.cancel();
    _glowTimer?.cancel();
    CdmcAudio.stopTuner();
    CdmcAudio.keepAwake(false);
    CdmcAudio.stopTone();
    super.dispose();
  }

  void _onRig() {
    final k = '${rig.key}|${rig.current.name}';
    if (k != _lastKey) {
      _lastKey = k;
      activeString = 0;
      _hist.clear();
      heard = null;
      tuned.clear();
      _resetConfirm();
    }
    activeString = math.min(activeString, rig.current.midis.length - 1);
    if (tone) CdmcAudio.startTone(rig.current.hz(activeString, rig.a4));
    setState(() {});
  }

  Future<void> _startMic() async {
    if (listening) return;
    final ok = await CdmcAudio.startTuner();
    if (ok) CdmcAudio.keepAwake(true);
    if (!mounted) return;
    setState(() {
      listening = ok;
      micDenied = !ok;
      if (ok) listenWanted = true;
    });
  }

  void _stopMic({bool keepWanted = false}) {
    CdmcAudio.stopTuner();
    CdmcAudio.keepAwake(false);
    _holdTimer?.cancel();
    if (!mounted) return;
    setState(() {
      listening = false;
      if (!keepWanted) listenWanted = false;
      heard = null;
      _hist.clear();
    });
  }

  void _setTone(bool on) {
    tone = on;
    if (on) {
      CdmcAudio.startTone(rig.current.hz(activeString, rig.a4));
    } else {
      CdmcAudio.stopTone();
    }
    if (mounted) setState(() {});
  }

  void _onPitch(double hz) {
    if (!listening) return;
    if (hz <= 0) {
      // Keep the last reading on screen for a moment as the note fades,
      // then go back to "no signal" (needle parked, never centred).
      if (heard != null && (_holdTimer == null || !_holdTimer!.isActive)) {
        _holdTimer = Timer(_hold, () {
          if (!mounted) return;
          setState(() {
            heard = null;
            _hist.clear();
            _resetConfirm();
          });
        });
      }
      return;
    }
    _holdTimer?.cancel();
    double centsBetween(double a, double b) => (1200 * math.log(a / b) / math.ln2).abs();
    var newNote = _hist.isEmpty;
    if (_hist.isNotEmpty) {
      final cur = ([..._hist]..sort())[_hist.length ~/ 2];
      if (centsBetween(hz, cur) > 70) {
        // Far from the note we're showing. One such reading is usually a
        // glitch (pluck noise, an octave slip): ignore it. Two in a row
        // that agree mean a different string was plucked: switch to it.
        final c0 = _cand;
        if (c0 != null && centsBetween(hz, c0) < 40) {
          _hist
            ..clear()
            ..add(c0);
          _resetConfirm();
          newNote = true;
        } else {
          _cand = hz;
          return;
        }
      }
    }
    _cand = null;
    _hist.add(hz);
    if (_hist.length > 3) _hist.removeAt(0);
    final sorted = [..._hist]..sort();
    final med = sorted[sorted.length ~/ 2];
    final t = rig.current;
    var idx = activeString;
    if (auto) {
      var best = double.infinity;
      for (var i = 0; i < t.midis.length; i++) {
        final d = (1200 * math.log(med / t.hz(i, rig.a4)) / math.ln2).abs();
        if (d < best) {
          best = d;
          idx = i;
        }
      }
    }
    final raw = 1200 * math.log(med / t.hz(idx, rig.a4)) / math.ln2;
    // Glide toward each new reading so the needle moves smoothly.
    final c = (newNote || idx != activeString || heard == null) ? raw : cents + (raw - cents) * 0.5;
    setState(() {
      if (idx != activeString) {
        activeString = idx;
        if (tone) CdmcAudio.startTone(t.hz(idx, rig.a4));
      }
      heard = med;
      cents = c;
      _checkInTune(idx, c);
    });
  }

  void _resetConfirm() {
    _cand = null;
    _inTuneSince = null;
    _confirmed = null;
  }

  /// Called on every reading (inside setState). Once a string has sat in
  /// tune for a moment, the skull glows, the string is marked tuned and the
  /// tuner lets go of it, ready for the next string.
  void _checkInTune(int idx, double c) {
    if (_confirmed != null && _confirmed != idx) _resetConfirm();
    if (c.abs() > 5) {
      // A brief wobble just outside the green doesn't restart the count.
      if (c.abs() > 8) _inTuneSince = null;
      // Clearly out again (and a settled reading): no longer counts as tuned.
      if (c.abs() > 12 && _hist.length >= 3) tuned.remove(idx);
      if (_confirmed == idx && c.abs() > 12) _confirmed = null;
      return;
    }
    if (_confirmed == idx) return;
    final now = DateTime.now();
    _inTuneSince ??= now;
    if (now.difference(_inTuneSince!) < _confirmAfter) return;

    _confirmed = idx;
    final first = tuned.add(idx);
    skullGlow = true;
    if (first) HapticFeedback.lightImpact();
    _glowTimer?.cancel();
    _glowTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        skullGlow = false;
        // Play the string again (or let it keep ringing in tune) and the
        // skull lights up again.
        _confirmed = null;
        _inTuneSince = null;
      });
    });
    // Ready for the next string: forget this note and its readings.
    CdmcAudio.resetPitchLock();
    _hist.clear();
    if (!auto) {
      final n = rig.current.midis.length;
      for (var k = 1; k < n; k++) {
        final next = (idx + k) % n;
        if (!tuned.contains(next)) {
          activeString = next;
          if (tone) CdmcAudio.startTone(rig.current.hz(next, rig.a4));
          break;
        }
      }
    }
  }

  void _pick(int i) {
    setState(() {
      activeString = i;
      auto = false;
      _hist.clear();
      _resetConfirm();
    });
    if (tone) CdmcAudio.startTone(rig.current.hz(i, rig.a4));
  }

  Color get toneColor {
    if (heard == null) return const Color(0xFFB8A890);
    final a = cents.abs();
    return a <= 5 ? C.inTune : (a <= 20 ? C.close : C.off);
  }

  @override
  Widget build(BuildContext context) {
    final t = rig.current;
    final n = t.midis.length;
    final midi = t.midis[activeString];
    final target = t.hz(activeString, rig.a4);
    final color = toneColor;
    final hasPitch = heard != null;
    final status = !hasPitch
        ? (listening ? 'PLAY A STRING' : 'NOT LISTENING')
        : skullGlow && tuned.length == n
            ? 'ALL STRINGS IN TUNE'
            : skullGlow
                ? 'IN TUNE · NEXT STRING'
                : cents.abs() <= 5
            ? 'IN TUNE'
            : (cents < 0 ? 'FLAT · TUNE UP' : 'SHARP · TUNE DOWN');

    return Stack(children: [

      // Current setup and tuning; opens the Tunings tab.
      Positioned(
        left: 18,
        top: 180,
        width: 354,
        height: 46,
        child: GestureDetector(
          onTap: widget.openTunings,
          child: RustPlate(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('$n-STRING ${t.baritone ? 'BARITONE' : rig.instrument.label}', style: T.caps(11, color: C.peach, spacing: 2)),
              const Spacer(),
              Flexible(
                flex: 3,
                child: Text(t.name, overflow: TextOverflow.ellipsis, style: T.gothic(22)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, color: C.bone, size: 20),
            ]),
          ),
        ),
      ),

      // Gauge with live needle and note.
      Positioned(
        left: 2,
        top: 230,
        width: 386,
        height: 150,
        child: Stack(children: [
          Positioned.fill(child: Image.asset(Img.gauge, fit: BoxFit.fill)),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: hasPitch ? cents.clamp(-50, 50).toDouble() : -50),
              duration: Duration(milliseconds: hasPitch ? 80 : 400),
              builder: (_, v, __) => Opacity(
                opacity: hasPitch ? 1 : 0.35,
                child: CustomPaint(painter: _NeedlePainter(v, color)),
              ),
            ),
          ),
          Positioned(
            left: 115,
            top: 74,
            width: 156,
            height: 74,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(noteName(midi),
                    style: T.caps(40, color: color, spacing: 0).copyWith(height: 0.95, shadows: [
                      Shadow(color: color, blurRadius: 14),
                      const Shadow(color: Colors.black, offset: Offset(0, 2)),
                    ])),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 1),
                  child: Text('${noteOctave(midi)}', style: T.caps(15, color: color, spacing: 0)),
                ),
              ]),
              Text(hasPitch ? '${heard!.toStringAsFixed(1)} Hz' : (listening ? 'PLAY A STRING' : '— Hz'),
                  style: T.caps(hasPitch ? 14 : 11, color: const Color(0xFFD8CCB4), spacing: 0.5)),
            ]),
          ),
        ]),
      ),

      // Tuning mode + reference tone.
      Positioned(
        left: 4,
        top: 390,
        width: 102,
        height: 194,
        child: RustPlate(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('TUNING MODE', textAlign: TextAlign.center, style: T.caps(10, spacing: 1)),
            const SizedBox(height: 6),
            LampButton(label: 'AUTO', on: auto, onTap: () => setState(() => auto = true)),
            const SizedBox(height: 6),
            LampButton(label: 'MANUAL', on: !auto, onTap: () => setState(() => auto = false)),
            const SizedBox(height: 12),
            Text('REF TONE', textAlign: TextAlign.center, style: T.caps(10, spacing: 1)),
            const SizedBox(height: 6),
            OvalButton(
              height: 38,
              selected: tone,
              semanticLabel: 'Reference tone for the selected string',
              onTap: () => _setTone(!tone),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(tone ? Icons.volume_up : Icons.volume_off, size: 15, color: C.bone),
                const SizedBox(width: 4),
                Text(tone ? 'ON' : 'OFF', style: T.caps(11, spacing: 0, color: C.bone)),
              ]),
            ),
          ]),
        ),
      ),

      // Headstock: tap a peg to tune that string.
      Positioned(
        left: 109,
        top: 388,
        width: 172,
        height: 185,
        child: _SpinSwitcher(
          spinKey: '${rig.key}|$n',
          child: _Headstock(
          key: ValueKey('${rig.key}|$n'),
          tuning: t,
          active: activeString,
          color: hasPitch ? color : C.gold,
          tuned: Set.of(tuned),
          glow: skullGlow,
          onPick: _pick,
        ),
        ),
      ),

      // Instrument + string count.
      Positioned(
        left: 284,
        top: 390,
        width: 102,
        height: 194,
        child: RustPlate(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('INSTRUMENT', textAlign: TextAlign.center, style: T.caps(10, spacing: 1)),
            const SizedBox(height: 6),
            for (final i in Instrument.values) ...[
              LampButton(label: i.label, on: rig.instrument == i, onTap: () => rig.setInstrument(i)),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            Text('STRINGS', textAlign: TextAlign.center, style: T.caps(10, spacing: 1)),
            const SizedBox(height: 6),
            OvalButton.text('$n',
                height: 38, fontSize: 16, onTap: rig.nextCount, semanticLabel: '$n strings. Tap to change.'),
          ]),
        ),
      ),

      // Readout.
      Positioned(
        left: 18,
        top: 596,
        width: 354,
        height: 66,
        child: RustPlate(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: ScreenInset(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(status, style: T.caps(9, color: C.muted)),
                  Text(hasPitch ? '${cents > 0 ? '+' : cents < 0 ? '−' : ''}${cents.abs().toStringAsFixed(0)}¢' : '—',
                      style: T.digits(24, color: color)),
                ]),
              ),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('HEARING', style: T.caps(9, color: C.muted)),
                  Text(hasPitch ? '${heard!.toStringAsFixed(1)} Hz' : '— Hz', style: T.digits(17, color: C.bone, glow: false)),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('TARGET · STR ${n - activeString}', style: T.caps(9, color: C.muted)),
                  Text('${target.toStringAsFixed(2)} Hz', style: T.digits(17, color: C.bone, glow: false)),
                ]),
              ),
            ]),
          ),
        ),
      ),

      // Calibration.
      Positioned(
        left: 18,
        top: 676,
        width: 196,
        height: 80,
        child: RustPlate(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            _Arrow(left: true, onTap: () => rig.setA4(rig.a4 - 1)),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('CALIBRATION', style: T.caps(11, spacing: 1)),
                const SizedBox(height: 2),
                Text('${rig.a4.round()} Hz', style: T.caps(22, spacing: 0)),
              ]),
            ),
            _Arrow(left: false, onTap: () => rig.setA4(rig.a4 + 1)),
          ]),
        ),
      ),

      // Listen on/off.
      Positioned(
        left: 226,
        top: 676,
        width: 146,
        height: 80,
        child: Semantics(
          button: true,
          toggled: listening,
          child: GestureDetector(
            onTap: () => listening ? _stopMic() : _startMic(),
            child: RustPlate(
              radius: 40,
              rivets: false,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Lamp(color: listening ? LampColor.green : LampColor.off, size: 18, glow: listening),
                const SizedBox(width: 10),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(listening ? 'LISTENING' : 'LISTEN', style: T.caps(17, spacing: 0)),
                  Text(micDenied ? 'MIC BLOCKED' : (listening ? 'TAP TO STOP' : 'USE MICROPHONE'),
                      style: T.caps(9, color: C.peach, spacing: 1)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.left, required this.onTap});
  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: left ? 'Lower calibration' : 'Raise calibration',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: 44, height: 56, child: CustomPaint(painter: _ArrowPainter(left))),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.left);
  final bool left;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final d = left ? -1.0 : 1.0;
    final p = Path()
      ..moveTo(c.dx + 6 * d, c.dy)
      ..lineTo(c.dx - 6 * d, c.dy - 10)
      ..lineTo(c.dx - 6 * d, c.dy + 10)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFD8CCB4));
    canvas.drawPath(p, Paint()
      ..color = const Color(0xFF3A2416)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => old.left != left;
}

/// Needle drawn in the gauge art's own pixel space (1040 x 403).
class _NeedlePainter extends CustomPainter {
  _NeedlePainter(this.cents, this.color);
  final double cents;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1040, size.height / 403);
    const pivot = Offset(517, 649.7);
    final a = cents / 50 * 47 * math.pi / 180;
    Offset at(double r) => pivot + Offset(r * math.sin(a), -r * math.cos(a));
    final p1 = at(455), p2 = at(585);
    canvas.drawLine(p1, p2, Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawLine(p1, p2, Paint()
      ..color = const Color(0xFFFFFBE8)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(p2, 9, Paint()..color = const Color(0xFFFFFBE8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter old) => old.cents != cents || old.color != color;
}

/// Headstock with one peg per string: 3+3, 4+3, 4+4, 2+2, 3+2 and so on.
/// Drawn in the headstock art's pixel space (520 x 560) at scale [_s].
class _Headstock extends StatelessWidget {
  const _Headstock({
    super.key,
    required this.tuning,
    required this.active,
    required this.color,
    required this.tuned,
    required this.glow,
    required this.onPick,
  });
  final Set<int> tuned;
  final bool glow;
  final Tuning tuning;
  final int active;
  final Color color;
  final ValueChanged<int> onPick;

  static const _s = 0.33;

  List<_Post> _posts() {
    final n = tuning.midis.length;
    final l = (n + 1) ~/ 2, r = n - l;
    List<double> rows(int k) => k == 1 ? [230] : List.generate(k, (i) => 118 + i * 226 / (k - 1));
    final ly = rows(l), ry = r > 0 ? rows(r) : <double>[];
    return [
      for (var i = 0; i < l; i++) _Post(l - 1 - i, 152, ly[i], true),
      for (var i = 0; i < r; i++) _Post(l + i, 358, ry[i], false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final n = tuning.midis.length;
    final posts = _posts();
    final l = (n + 1) ~/ 2;
    final spacing = math.min(44.0, (l > 1 ? 226 / (l - 1) : 120) * _s);
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(left: 0, top: 0, width: 520 * _s, height: 492 * _s, child: Image.asset(Img.headBody, fit: BoxFit.fill)),
      // The skull lights up green when a string is confirmed in tune.
      Positioned(
        left: 190 * _s,
        top: 110 * _s,
        width: 130 * _s,
        height: 180 * _s,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: glow ? 1 : 0,
            duration: Duration(milliseconds: glow ? 150 : 700),
            child: Stack(children: [
              Positioned(
                left: 15 * _s,
                top: 15 * _s,
                width: 100 * _s,
                height: 144 * _s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(50 * _s, 72 * _s)),
                    boxShadow: [
                      BoxShadow(color: C.inTune.withOpacity(0.85), blurRadius: 16, spreadRadius: 2),
                      BoxShadow(color: C.inTune.withOpacity(0.45), blurRadius: 30, spreadRadius: 6),
                    ],
                  ),
                ),
              ),
              Positioned.fill(child: Image.asset(Img.skullGlow, fit: BoxFit.fill)),
            ]),
          ),
        ),
      ),
      Positioned.fill(child: CustomPaint(painter: _StringsPainter(posts, n, active, color, tuned))),
      for (final p in posts) ...[
        Positioned(
          left: (p.left ? 8 : 420) * _s,
          top: (p.y - 36) * _s,
          width: 30,
          height: 24,
          child: Transform.flip(
            flipX: !p.left,
            child: Container(
              decoration: p.i == active
                  ? BoxDecoration(boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 8)])
                  : null,
              child: Image.asset(Img.peg, fit: BoxFit.fill),
            ),
          ),
        ),
        Positioned(
          left: (p.x - 34) * _s,
          top: (p.y - 34) * _s,
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: p.i == active
                  ? [BoxShadow(color: color, spreadRadius: 2), BoxShadow(color: color, blurRadius: 12)]
                  : null,
            ),
            child: Image.asset(Img.post),
          ),
        ),
        Positioned(
          left: p.left ? 0 : 112,
          top: p.y * _s - spacing / 2,
          width: 60,
          height: spacing,
          child: Semantics(
            button: true,
            selected: p.i == active,
            label: 'String ${n - p.i}, ${noteName(tuning.midis[p.i])}${noteOctave(tuning.midis[p.i])}',
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onPick(p.i)),
          ),
        ),
      ],
    ]);
  }
}

class _Post {
  const _Post(this.i, this.x, this.y, this.left);
  final int i;
  final double x, y;
  final bool left;
}

class _StringsPainter extends CustomPainter {
  _StringsPainter(this.posts, this.n, this.active, this.color, this.tuned);
  final Set<int> tuned;
  final List<_Post> posts;
  final int n, active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(_Headstock._s);
    // Neck and nut.
    canvas.drawRect(const Rect.fromLTWH(160, 494, 192, 70), Paint()..color = const Color(0xFF1C120C));
    canvas.drawRect(const Rect.fromLTWH(160, 494, 192, 70), Paint()
      ..color = const Color(0xFF5A3A24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(152, 484, 208, 14), const Radius.circular(3)),
        Paint()..color = const Color(0xFFD8CCB4));
    for (final p in posts) {
      final nx = 172 + p.i * (168 / math.max(1, n - 1));
      final path = Path()
        ..moveTo(p.x, p.y)
        ..lineTo(nx, 490)
        ..lineTo(nx, 560);
      final on = p.i == active;
      if (on) {
        canvas.drawPath(path, Paint()
          ..color = color.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
      canvas.drawPath(path, Paint()
        ..color = on ? color : (tuned.contains(p.i) ? C.inTune : const Color(0xFFD8CCB4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 - p.i * (4.5 / math.max(1, n - 1))
        ..strokeCap = StrokeCap.round);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StringsPainter old) =>
      old.active != active ||
      old.color != color ||
      old.n != n ||
      old.posts != posts ||
      !setEquals(old.tuned, tuned);
}

/// Spins the headstock around its vertical axis when the string count or
/// instrument changes; the new pegs appear on the way back round.
class _SpinSwitcher extends StatelessWidget {
  const _SpinSwitcher({required this.spinKey, required this.child});
  final String spinKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) =>
          Stack(clipBehavior: Clip.none, children: [...previous, if (current != null) current]),
      transitionBuilder: (w, anim) {
        final incoming = w.key == ValueKey(spinKey);
        return AnimatedBuilder(
          animation: anim,
          child: w,
          builder: (context, child) {
            final v = anim.value;
            // Each half of the spin belongs to one side: old out, then new in.
            if (v < 0.5) return const SizedBox.shrink();
            final turn = (1 - v) * math.pi; // pi/2 -> 0
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(incoming ? -turn : turn),
              child: child,
            );
          },
        );
      },
      child: child,
    );
  }
}
