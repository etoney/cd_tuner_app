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
          Positioned.fill(
            bottom: 70,
            child: IndexedStack(index: tab, children: [
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
