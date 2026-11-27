import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/metronome.dart';
import 'data/tunings.dart';
import 'screens/metronome_screen.dart';
import 'screens/tuner_screen.dart';
import 'screens/tunings_screen.dart';
import 'ui/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final rig = Rig();
  final metronome = Metronome();
  await Future.wait([rig.load(), metronome.load()]);
  runApp(CdTunerApp(rig: rig, metronome: metronome));
}

class CdTunerApp extends StatelessWidget {
  const CdTunerApp({super.key, required this.rig, required this.metronome});
  final Rig rig;
  final Metronome metronome;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tempus Tuner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: const Color(0xFF0B0807)),
      home: Shell(rig: rig, metronome: metronome),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.rig, required this.metronome});
  final Rig rig;
  final Metronome metronome;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesignCanvas(
        child: Stack(children: [
          // The header stays still while the pages fade.
          PageHeader(semantic: const ['Tuner', 'Metronome', 'Tunings'][tab]),
          Positioned.fill(
            bottom: 70,
            child: FadeFlicker(index: tab, children: [
              TunerScreen(rig: widget.rig, active: tab == 0, openTunings: () => setState(() => tab = 2)),
              MetronomeScreen(metronome: widget.metronome),
              TuningsScreen(rig: widget.rig),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TabBarIron(index: tab, onTap: (i) => setState(() => tab = i)),
          ),
        ]),
      ),
    );
  }
}

/// Page change: the old page fades out, then the new one fades in with a
/// brief candle-like flicker and a faint warm glow. Every page stays alive
/// underneath (the tuner keeps listening, the metronome keeps ticking).
class FadeFlicker extends StatefulWidget {
  const FadeFlicker({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<FadeFlicker> createState() => _FadeFlickerState();
}

class _FadeFlickerState extends State<FadeFlicker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
    ..addListener(_tick);
  late int _shown = widget.index;

  static const _outEnd = 0.38, _inStart = 0.46;

  void _tick() {
    if (_c.value >= _outEnd && _shown != widget.index) {
      setState(() => _shown = widget.index);
    } else {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(FadeFlicker old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) {
      if (MediaQuery.of(context).disableAnimations) {
        _shown = widget.index;
      } else {
        // Already mid-fade and faded out: just keep going to the new page.
        _c.forward(from: _c.isAnimating && _c.value > _outEnd ? _outEnd : 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Flicker strength, 0..1, fading away as the page settles.
  static double _flick(double u) {
    final f = 0.5 + 0.28 * math.sin(u * 29) + 0.22 * math.sin(u * 61 + 1.7);
    return (1 - u) * f.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = _c.isAnimating ? _c.value : 1.0;
    double opacity;
    double glow = 0;
    if (t < _outEnd) {
      opacity = Curves.easeIn.transform(1 - t / _outEnd);
    } else if (t < _inStart) {
      opacity = 0;
    } else {
      final u = (t - _inStart) / (1 - _inStart);
      final f = _flick(u);
      opacity = (Curves.easeOut.transform(u) * (1 - 0.45 * f)).clamp(0.0, 1.0);
      glow = 0.12 * f;
    }
    return Stack(fit: StackFit.expand, children: [
      Opacity(
        opacity: opacity,
        child: IndexedStack(index: _shown, children: widget.children),
      ),
      if (glow > 0.003)
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.9,
                colors: [const Color(0xFFFF9A3C).withOpacity(glow), const Color(0x00FF9A3C)],
              ),
            ),
          ),
        ),
    ]);
  }
}
