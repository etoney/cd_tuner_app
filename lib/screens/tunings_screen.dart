import 'package:flutter/material.dart';

import '../data/tunings.dart';
import '../ui/style.dart';
import 'custom_tuning_screen.dart';

class TuningsScreen extends StatefulWidget {
  const TuningsScreen({super.key, required this.rig, this.onPicked});
  final Rig rig;
  /// Called after a tuning is picked from the list (the app goes to the tuner).
  final VoidCallback? onPicked;

  @override
  State<TuningsScreen> createState() => _TuningsScreenState();
}

class _TuningsScreenState extends State<TuningsScreen> {
  String? confirmDelete;

  Rig get rig => widget.rig;

  @override
  void initState() {
    super.initState();
    rig.addListener(_changed);
  }

  @override
  void dispose() {
    rig.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _openEditor([CustomTuning? existing]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomTuningScreen(rig: rig, existing: existing)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        left: 18,
        top: 180,
        width: 354,
        height: 60,
        child: RustPlate(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(children: [
            for (final i in Instrument.values) ...[
              if (i != Instrument.values.first) const SizedBox(width: 10),
              Expanded(
                child: OvalButton.text(i.label,
                    height: 40, fontSize: 14, selected: rig.instrument == i, onTap: () => rig.setInstrument(i)),
              ),
            ],
          ]),
        ),
      ),
      Positioned(
        left: 18,
        top: 248,
        width: 354,
        height: 60,
        child: RustPlate(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(children: [
            for (final c in rig.instrument.counts) ...[
              if (c != rig.instrument.counts.first) const SizedBox(width: 10),
              Expanded(
                child: OvalButton.text('$c STRING',
                    height: 44, fontSize: 14, selected: rig.count == c, onTap: () => rig.setCount(c)),
              ),
            ],
          ]),
        ),
      ),
      Positioned(
        left: 18,
        top: 318,
        width: 354,
        height: 456,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _label('PRESETS'),
            for (var i = 0; i < rig.presetList.length; i++) ...[
              if (rig.presetList[i].baritone && (i == 0 || !rig.presetList[i - 1].baritone)) ...[
                const SizedBox(height: 8),
                _label('BARITONE'),
              ],
              _row(
                name: rig.presetList[i].name,
                notes: rig.presetList[i].notes,
                on: rig.isPresetSelected(i),
                onTap: () {
                  rig.selectPreset(i);
                  widget.onPicked?.call();
                },
              ),
            ],
            const SizedBox(height: 8),
            _label('MY TUNINGS'),
            if (rig.customList.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text('NONE YET FOR ${rig.count}-STRING ${rig.instrument.label}', style: T.caps(11, color: C.muted, spacing: 1)),
              ),
            for (final c in rig.customList)
              _row(
                name: c.name,
                notes: notesLine(c.midis),
                on: rig.isCustomSelected(c),
                onTap: () => setState(() {
                  confirmDelete = null;
                  rig.selectCustom(c);
                  widget.onPicked?.call();
                }),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _iconButton(Icons.edit_outlined, 'Edit ${c.name}', () => _openEditor(c)),
                  _deleteButton(c),
                ]),
              ),
            GestureDetector(
              onTap: () => _openEditor(),
              child: RustPlate(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                child: Row(children: [
                  const OvalButton(width: 40, height: 40, selected: true, child: Icon(Icons.add, color: Color(0xFFFFE0D0))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('New custom tuning', style: T.gothic(22)),
                      const SizedBox(height: 2),
                      Text('START FROM ${rig.current.name.toUpperCase()}', style: T.caps(11, color: C.peach, spacing: 1)),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _label(String s) =>
      Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(s, style: T.caps(11, spacing: 2)));

  Widget _row({
    required String name,
    required String notes,
    required bool on,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: on,
        child: RustPlate(
          borderColor: on ? const Color(0xFF8A2A18) : const Color(0xFF1E130D),
          child: SizedBox(
            height: 60,
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(children: [
                      Lamp(color: on ? LampColor.red : LampColor.off, size: 18, glow: on),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.gothic(23, color: on ? const Color(0xFFFFD8C8) : C.bone)),
                          const SizedBox(height: 3),
                          Text(notes, style: T.caps(11, color: C.peach, spacing: 1.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              if (trailing != null) trailing,
              const SizedBox(width: 8),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: C.bone, size: 20)),
        ),
      );

  Widget _deleteButton(CustomTuning c) {
    final confirm = confirmDelete == c.id;
    return Semantics(
      button: true,
      label: confirm ? 'Tap again to delete ${c.name}' : 'Delete ${c.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!confirm) {
            setState(() => confirmDelete = c.id);
          } else {
            confirmDelete = null;
            rig.deleteCustom(c);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 44),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: confirm ? const Color(0xFF8E1A10) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: confirm
              ? Text('DELETE?', style: T.caps(10, color: const Color(0xFFFFE0D0), spacing: 0))
              : const Icon(Icons.close, color: C.muted, size: 20),
        ),
      ),
    );
  }
}
