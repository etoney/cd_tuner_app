import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours, fonts and the rusted-iron building blocks shared by every screen.
/// Screens are laid out on a 390 x 844 design canvas (see [DesignCanvas]).
class C {
  static const bone = Color(0xFFE8DCC6);
  static const boneBright = Color(0xFFF3EADB);
  static const label = Color(0xFFF0E2C8);
  static const peach = Color(0xFFF0C9A0);
  static const muted = Color(0xFFCDBFA8);
  static const ink = Color(0xFF1C120B);
  static const red = Color(0xFFD42A1A);
  static const ember = Color(0xFFFF6A3A);
  static const gold = Color(0xFFE6C77A);
  static const inTune = Color(0xFF7DFF4A);
  static const close = Color(0xFFFFD23A);
  static const off = Color(0xFFFF3A2A);
}

class Img {
  static const _p = 'assets/images/';
  static const bg = '${_p}bg.jpg';
  static const rust = '${_p}rust.jpg';
  static const parchment = '${_p}parchment.jpg';
  static const screen = '${_p}screen.jpg';
  static const flourish = '${_p}flourish.png';
  static const pyramid = '${_p}pyramid.png';
  static const weight = '${_p}weight.png';
  static const minus = '${_p}minus.png';
  static const plus = '${_p}plus.png';
  static const speaker = '${_p}speaker.png';
  static const tap = '${_p}tap.png';
  static const reset = '${_p}reset.png';
  static const playCenter = '${_p}playcenter.png';
  static const pauseCenter = '${_p}pausecenter.png';
  static const gauge = '${_p}gauge.png';
  static const headBody = '${_p}headbody.png';
  static const header = '${_p}header.png';
  static const skullGlow = '${_p}skullglow.png';
  static const peg = '${_p}peg.png';
  static const post = '${_p}post.png';
}

class T {
  static const _shadow = [Shadow(color: Colors.black, offset: Offset(0, 1))];
  static const _boneShadow = [
    Shadow(color: Colors.black, offset: Offset(0, 2)),
    Shadow(color: Color(0x80C82814), blurRadius: 10),
  ];

  /// Small engraved capitals used for labels.
  static TextStyle caps(double size, {Color color = C.label, double spacing = 1.5, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.cinzel(fontSize: size, fontWeight: w, letterSpacing: spacing, color: color, shadows: _shadow, height: 1.1);

  /// Blackletter headings ("Beat Accent", tuning names).
  static TextStyle gothic(double size, {Color color = C.bone}) =>
      GoogleFonts.grenzeGotisch(fontSize: size, fontWeight: FontWeight.w700, color: color, shadows: _boneShadow, height: 1);

  /// Ink on parchment.
  static TextStyle ink(double size) =>
      GoogleFonts.grenzeGotisch(fontSize: size, fontWeight: FontWeight.w700, color: C.ink, height: 1);

  /// Red or bone digital-style numbers.
  static TextStyle digits(double size, {Color color = C.red, bool glow = true}) => GoogleFonts.anton(
        fontSize: size,
        color: color,
        height: 1,
        shadows: [
          if (glow) Shadow(color: color.withOpacity(0.55), blurRadius: 12),
          const Shadow(color: Colors.black, offset: Offset(0, 2)),
        ],
      );
}

/// Lays a screen out on the 390 x 844 design canvas and scales it to fit
/// the phone, with the rusty background filling any spare space.
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({super.key, required this.child});
  final Widget child;

  static const size = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0807),
        image: DecorationImage(image: AssetImage(Img.bg), fit: BoxFit.cover),
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );
  }
}

/// Rusted, riveted iron plate.
class RustPlate extends StatelessWidget {
  const RustPlate({
    super.key,
    this.child,
    this.radius = 10,
    this.padding = EdgeInsets.zero,
    this.borderColor = const Color(0xFF1E130D),
    this.rivets = true,
  });

  final Widget? child;
  final double radius;
  final EdgeInsets padding;
  final Color borderColor;
  final bool rivets;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: borderColor, width: 2),
        image: const DecorationImage(
          image: AssetImage(Img.rust),
          repeat: ImageRepeat.repeat,
          scale: 1.6,
          alignment: Alignment.topLeft,
        ),
        boxShadow: const [BoxShadow(color: Color(0xBF000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: r,
        gradient: const RadialGradient(
          radius: 1.1,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: [0, 0.6, 1],
        ),
      ),
      child: CustomPaint(
        painter: rivets ? _RivetPainter() : null,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _RivetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 40) return;
    const inset = 9.0;
    for (final o in [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      canvas.drawCircle(o, 3.2, Paint()..color = const Color(0xFF3A2216));
      canvas.drawCircle(
        o,
        2.4,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xFFE0BC94), Color(0xFF7A5444)])
              .createShader(Rect.fromCircle(center: o.translate(-0.6, -0.6), radius: 2.4)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dark recessed screen (BPM readout, note readout).
class ScreenInset extends StatelessWidget {
  const ScreenInset({super.key, required this.child, this.radius = 6, this.padding = EdgeInsets.zero});
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: const Color(0xFF120C0A),
        image: const DecorationImage(image: AssetImage(Img.screen), repeat: ImageRepeat.repeat, scale: 2),
        border: Border.all(color: const Color(0xFF7A5440), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFF140D09), spreadRadius: 2)],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const RadialGradient(
          radius: 0.9,
          colors: [Color(0x00000000), Color(0xB3000000)],
          stops: [0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Torn parchment panel.
class Parchment extends StatelessWidget {
  const Parchment({super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _TornClipper(),
      child: Container(
        padding: padding,
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage(Img.parchment), repeat: ImageRepeat.repeat, scale: 1.7),
        ),
        foregroundDecoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 0.9,
            colors: [Color(0x00000000), Color(0xCC46230C)],
            stops: [0.5, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _TornClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    const pts = <List<double>>[
      [.04, .01], [.30, 0.0], [.55, .02], [.80, 0.0], [.97, .02], [1.0, .20], [.96, .40], [1.0, .62],
      [.97, .85], [1.0, .99], [.70, 1.0], [.45, .97], [.20, 1.0], [.01, .98], [.03, .75], [0.0, .50], [.04, .25],
    ];
    final p = Path()..moveTo(pts[0][0] * s.width, pts[0][1] * s.height);
    for (final q in pts.skip(1)) {
      p.lineTo(q[0] * s.width, q[1] * s.height);
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Oval iron button; glows red when [selected].
class OvalButton extends StatelessWidget {
  const OvalButton({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.width,
    this.height = 44,
    this.semanticLabel,
  });

  OvalButton.text(
    String text, {
    super.key,
    this.onTap,
    this.selected = false,
    this.width,
    this.height = 44,
    double fontSize = 15,
    this.semanticLabel,
  }) : child = Text(text,
            style: GoogleFonts.cinzel(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFFFFE0D0) : const Color(0xFFE2D6C2),
            ));

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final double? width;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.all(Radius.elliptical((width ?? 66) / 2, height / 2));
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: selected ? const Color(0xFFFF7A45) : const Color(0xFF8A6A4E), width: 2),
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              colors: selected
                  ? const [Color(0xFFE8442A), Color(0xFF8E1A10), Color(0xFF3A0705)]
                  : const [Color(0xFF4A403C), Color(0xFF1A1514), Color(0xFF0A0807)],
              stops: const [0, 0.6, 1],
            ),
            boxShadow: [
              BoxShadow(color: selected ? const Color(0xFF4A1A0E) : const Color(0xFF2A1D16), spreadRadius: 3),
              if (selected) const BoxShadow(color: Color(0xBFFF3C1E), blurRadius: 18),
              const BoxShadow(color: Color(0xB3000000), blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Glass indicator lamp.
class Lamp extends StatelessWidget {
  const Lamp({super.key, required this.color, this.size = 16, this.glow = false});

  final LampColor color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final c = switch (color) {
      LampColor.red => const [Color(0xFFFFB090), Color(0xFFE8281A), Color(0xFF6A0906)],
      LampColor.amber => const [Color(0xFFFFE2B0), Color(0xFFD98A2A), Color(0xFF5A3008)],
      LampColor.dim => const [Color(0xFFB07050), Color(0xFF5A2A1A), Color(0xFF1A0A06)],
      LampColor.green => const [Color(0xFFD8FFB0), Color(0xFF5ADF2A), Color(0xFF1A5A06)],
      LampColor.off => const [Color(0xFF5A5450), Color(0xFF151212), Color(0xFF050404)],
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: c, stops: const [0, 0.45, 1]),
        boxShadow: glow ? [BoxShadow(color: c[1], blurRadius: size * 0.8)] : null,
      ),
    );
  }
}

enum LampColor { red, amber, dim, green, off }

/// Rounded switch with a lamp, like the panel switches in the art.
class LampButton extends StatelessWidget {
  const LampButton({super.key, required this.label, required this.on, required this.onTap, this.height = 40});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: on ? const Color(0xFF2A0C08) : const Color(0xFF0C0908),
            border: Border.all(color: on ? const Color(0xFF8A2A18) : const Color(0xFF3A2A20), width: 2),
          ),
          child: Row(children: [
            Lamp(color: on ? LampColor.red : LampColor.off, size: 13, glow: on),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: T.caps(10.5, spacing: 0, color: on ? const Color(0xFFFF9A7A) : C.muted)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Header crest + page title art.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, this.semantic = ''});
  final String semantic;

  // Frameless Castle Danger emblem, centred and ending just above the
  // controls (bottom at 173) so it clears the Dynamic Island.
  static const _w = 330.0;
  static const _h = _w * 669 / 1688;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        left: 195 - _w / 2,
        top: 173 - _h,
        width: _w,
        height: _h,
        child: Semantics(
          header: true,
          label: semantic,
          child: Image.asset(Img.header, fit: BoxFit.fill, semanticLabel: 'Castle Danger Music Company'),
        ),
      ),
    ]);
  }
}

/// Bottom tab bar.
class TabBarIron extends StatelessWidget {
  const TabBarIron({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['Tuner', 'Metronome', 'Tunings'];
    return SizedBox(
      height: 70,
      child: RustPlate(
        radius: 0,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: i == index
                            ? T.gothic(20, color: C.ember).copyWith(shadows: const [
                                Shadow(color: Colors.black, offset: Offset(0, 2)),
                                Shadow(color: Color(0xE6FF3C1E), blurRadius: 12),
                              ])
                            : T.gothic(20),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
