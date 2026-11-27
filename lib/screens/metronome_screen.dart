import 'dart:math' as math;

import 'package:cdmc_audio/cdmc_audio.dart';
import 'package:flutter/material.dart';

import '../data/metronome.dart';
import '../ui/style.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key, required this.metronome});
  final Metronome metronome;

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController swing = AnimationController(vsync: this, value: 0.5);
  int _swingBpm = 0;
  bool _swinging = false;
  double _dragStartBpm = 0;
  double _dragDx = 0;

  Metronome get m => widget.metronome;

  @override
  void initState() {
    super.initState();
    m.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    m.removeListener(_sync);
    swing.dispose();
    super.dispose();
  }

  void _sync() {
    if (m.playing && (!_swinging || _swingBpm != m.bpm)) {
      _swinging = true;
      _swingBpm = m.bpm;
      swing.duration = Duration(microseconds: (60e6 / m.bpm).round());
      swing.repeat(reverse: true);
    } else if (!m.playing && _swinging) {
      _swinging = false;
      swing.animateTo(0.5, duration: const Duration(milliseconds: 300));
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sig = timeSigs[m.sig];
    return Stack(children: [
      const PageHeader(title: Img.titleMetronome, titleRect: Rect.fromLTWH(172, 52, 206, 84), semantic: 'Metronome'),

      // BPM readout with − / + buttons.
      Positioned(
        left: 18,
        top: 170,
        width: 354,
        height: 100,
        child: RustPlate(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _ImageButton(Img.minus, 62, 'Slower', () => m.setBpm(m.bpm - 1)),
            SizedBox(
              width: 176,
              height: 76,
              child: ScreenInset(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('BPM · ${tempoName(m.bpm)}', style: T.caps(11, color: C.muted, spacing: 3)),
                  Text('${m.bpm}', style: T.digits(50)),
                ]),
              ),
            ),
            _ImageButton(Img.plus, 62, 'Faster', () => m.setBpm(m.bpm + 1)),
          ]),
        ),
      ),

      // Tempo wheel: a flat, ridged thumbwheel you roll left (slower) or right (faster).
      Positioned(
        left: 18,
        top: 278,
        width: 354,
        height: 46,
        child: Semantics(
          slider: true,
          label: 'Tempo wheel',
          value: '${m.bpm} BPM',
          increasedValue: '${m.bpm + 1} BPM',
          decreasedValue: '${m.bpm - 1} BPM',
          onIncrease: () => m.setBpm(m.bpm + 1),
          onDecrease: () => m.setBpm(m.bpm - 1),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              _dragStartBpm = m.bpm.toDouble();
              _dragDx = 0;
            },
            onHorizontalDragUpdate: (d) {
              _dragDx += d.delta.dx;
              m.setBpm(_dragStartBpm + _dragDx / 6);
            },
            child: RustPlate(
              radius: 10,
              rivets: false,
              padding: const EdgeInsets.all(5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomPaint(painter: _WheelPainter(m.bpm), size: Size.infinite),
              ),
            ),
          ),
        ),
      ),

      // Time signatures (scrolls).
      Positioned(
        left: 6,
        top: 334,
        width: 96,
        height: 248,
        child: Parchment(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
          child: Column(children: [
            Text('Time', style: T.ink(22)),
            const SizedBox(height: 4),
            Expanded(
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                  stops: [0, 0.07, 0.88, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: timeSigs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => Center(
                    child: OvalButton.text(timeSigs[i].label,
                        width: 66, height: 44, fontSize: 16, selected: i == m.sig, onTap: () => m.setSig(i)),
                  ),
                ),
              ),
            ),
            const Icon(Icons.expand_more, color: C.ink, size: 18),
          ]),
        ),
      ),

      // Metronome with swinging pendulum.
      Positioned(
        left: 108,
        top: 334,
        width: 175,
        height: 250,
        child: Stack(children: [
          Positioned.fill(child: Image.asset(Img.pyramid, fit: BoxFit.fill)),
          Positioned.fill(
            child: ClipPath(
              clipper: _InteriorClipper(),
              child: AnimatedBuilder(
                animation: swing,
                builder: (_, __) {
                  final angle = (Curves.easeInOut.transform(swing.value) * 2 - 1) * 15 * math.pi / 180;
                  return Stack(children: [
                    Positioned(
                      left: 84,
                      top: 46,
                      width: 5,
                      height: 156,
                      child: Transform.rotate(
                        angle: angle,
                        alignment: Alignment.bottomCenter,
                        child: _Rod(weightFromBottom: 126 - (m.bpm - 20) * 0.3),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ]),
      ),

      // Sound + subdivision.
      Positioned(
        left: 288,
        top: 334,
        width: 96,
        height: 248,
        child: Parchment(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Text('Sound', style: T.ink(22)),
            const SizedBox(height: 6),
            _ImageButton(Img.speaker, 64, 'Click sound ${soundNames[m.sound]}. Tap for next sound.', m.nextSound),
            const SizedBox(height: 6),
            Text(soundNames[m.sound],
                textAlign: TextAlign.center, style: T.caps(12, color: C.ink, spacing: 0).copyWith(shadows: [])),
            Text('${m.sound + 1} of ${soundNames.length}',
                style: T.caps(10, color: const Color(0xFF3A2A1C), spacing: 1).copyWith(shadows: [])),
            const SizedBox(height: 10),
            Text('Subdivide', style: T.ink(20)),
            const SizedBox(height: 6),
            OvalButton.text(subdivisions[m.sub].$1, width: 66, height: 44, onTap: m.nextSub, semanticLabel: 'Subdivision'),
          ]),
        ),
      ),

      // Beat accent lamps.
      Positioned(
        left: 18,
        top: 590,
        width: 354,
        height: 86,
        child: RustPlate(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(children: [
            Text('Beat Accent · ${sig.groupLabel}', style: T.gothic(19)),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 0; i < m.levels.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _BeatLamp(level: m.levels[i], now: m.playing && m.beat == i, index: i, onTap: () => m.cycleBeat(i)),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),

      // Tap tempo / play / reset.
      Positioned(
        left: 0,
        top: 682,
        width: 390,
        height: 88,
        child: Stack(children: [
          Positioned(left: 6, top: 16, width: 108, height: 56, child: _ImageButton(Img.tap, 108, 'Tap tempo', m.tap, height: 45)),
          Positioned(left: 105, top: 0, width: 180, height: 88, child: Image.asset(Img.playCenter, fit: BoxFit.fill)),
          // While playing, cover the play disc with the same disc showing pause bars.
          if (m.playing)
            Positioned(left: 153.7, top: 0, width: 83.7, height: 79.8, child: Image.asset(Img.pauseDisc, fit: BoxFit.fill)),
          Positioned(
            left: 155,
            top: 0,
            width: 80,
            height: 80,
            child: Semantics(
              button: true,
              label: m.playing ? 'Stop' : 'Start',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: m.toggle,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(left: 282, top: 16, width: 100, height: 56, child: _ImageButton(Img.reset, 100, 'Reset', m.reset, height: 45)),
        ]),
      ),
    ]);
  }
}

class _ImageButton extends StatelessWidget {
  const _ImageButton(this.asset, this.width, this.label, this.onTap, {this.height});
  final String asset;
  final double width;
  final double? height;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: Image.asset(asset, width: width, height: height ?? width, fit: BoxFit.fill)),
      ),
    );
  }
}

class _BeatLamp extends StatelessWidget {
  const _BeatLamp({required this.level, required this.now, required this.index, required this.onTap});
  final BeatLevel level;
  final bool now;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, glow, name) = switch (level) {
      BeatLevel.accent => (LampColor.red, true, 'accent'),
      BeatLevel.click => (LampColor.amber, true, 'click'),
      BeatLevel.soft => (LampColor.dim, false, 'soft'),
      BeatLevel.off => (LampColor.off, false, 'off'),
    };
    return Semantics(
      button: true,
      label: 'Beat ${index + 1}, $name. Tap to change.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0C0908),
            border: Border.all(color: now ? C.gold : const Color(0xFF4A3426), width: 3),
            boxShadow: [
              const BoxShadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 2)),
              if (now) BoxShadow(color: C.gold.withOpacity(0.8), blurRadius: 12),
            ],
          ),
          child: Lamp(color: color, size: 28, glow: glow),
        ),
      ),
    );
  }
}

class _Rod extends StatelessWidget {
  const _Rod({required this.weightFromBottom});
  final double weightFromBottom;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(colors: [Color(0xFF8A7A62), Color(0xFFE8DCC6), Color(0xFFA8987E)]),
            boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
      ),
      Positioned(
        left: -13,
        bottom: weightFromBottom,
        width: 31,
        height: 29,
        child: Image.asset(Img.weight, fit: BoxFit.fill),
      ),
    ]);
  }
}

class _InteriorClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(75, 40)
    ..lineTo(98, 40)
    ..lineTo(141, 201)
    ..lineTo(31, 201)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.bpm);
  final int bpm;

  static const _ridges = 36;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, r = w / 2;
    final rect = Offset.zero & size;
    // Cylinder body: bright in the middle, falling into shadow at both ends.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF050302), Color(0xFF3A2418), Color(0xFF7A4E34), Color(0xFF3A2418), Color(0xFF050302)],
          stops: [0, 0.22, 0.5, 0.78, 1],
        ).createShader(rect),
    );
    // Ridges: evenly spaced round the drum, so they bunch up towards the edges.
    final step = 2 * math.pi / _ridges;
    final phase = (bpm * step / 2) % step;
    for (var t = -math.pi / 2 + phase; t < math.pi / 2; t += step) {
      final x = r + r * math.sin(t);
      final light = math.cos(t);
      final width = 1.0 + 2.2 * light;
      canvas.drawLine(Offset(x, 0), Offset(x, h), Paint()
        ..color = Color.lerp(const Color(0xFF0A0604), const Color(0xFF140C08), light)!
        ..strokeWidth = width);
      canvas.drawLine(Offset(x + width, 0), Offset(x + width, h), Paint()
        ..color = const Color(0xFFE0B48A).withOpacity(0.35 * light * light)
        ..strokeWidth = 1);
    }
    // Top and bottom bevels.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 5), Paint()..color = const Color(0x66000000));
    canvas.drawRect(Rect.fromLTWH(0, h - 5, w, 5), Paint()..color = const Color(0x88000000));
    // Centre index: a glowing red line with notches.
    final cx = r;
    canvas.drawLine(Offset(cx, 4), Offset(cx, h - 4), Paint()
      ..color = const Color(0x99FF3C1E)
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawLine(Offset(cx, 4), Offset(cx, h - 4), Paint()
      ..color = const Color(0xFFFF5A30)
      ..strokeWidth = 2.5);
    final notch = Paint()..color = const Color(0xFFFF5A30);
    canvas.drawPath(Path()..moveTo(cx - 6, 0)..lineTo(cx + 6, 0)..lineTo(cx, 7)..close(), notch);
    canvas.drawPath(Path()..moveTo(cx - 6, h)..lineTo(cx + 6, h)..lineTo(cx, h - 7)..close(), notch);
    // Hints at the ends.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final (text, left) in [('◂ SLOWER', true), ('FASTER ▸', false)]) {
      tp.text = TextSpan(text: text, style: T.caps(10, color: C.muted, spacing: 1.5));
      tp.layout();
      tp.paint(canvas, Offset(left ? 10 : w - 10 - tp.width, (h - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.bpm != bpm;
}
