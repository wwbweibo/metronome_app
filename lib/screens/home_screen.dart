import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/metronome_controller.dart';
import '../models/time_signature.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeController>(
      builder: (context, ctrl, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF0F0F1A),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text(
                  'METRONOME',
                  style: TextStyle(
                    color: Color(0xFF8888AA),
                    fontSize: 13,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                centerTitle: true,
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _BeatDots(ctrl: ctrl),
                      const SizedBox(height: 32),
                      _BpmDisplay(ctrl: ctrl),
                      const SizedBox(height: 12),
                      _BpmSlider(ctrl: ctrl),
                      const SizedBox(height: 24),
                      _TimeSignatureSelector(ctrl: ctrl),
                      const SizedBox(height: 12),
                      _BpmModeSelector(ctrl: ctrl),
                      const SizedBox(height: 32),
                      _PlayButton(ctrl: ctrl),
                      const SizedBox(height: 16),
                      _TapTempoButton(ctrl: ctrl),
                      const SizedBox(height: 24),
                      _ProgressivePanel(ctrl: ctrl),
                      const SizedBox(height: 8),
                      _MicPanel(ctrl: ctrl),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            // Mismatch flash overlay
            if (ctrl.showMismatchFlash)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: ctrl.showMismatchFlash ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    color: Colors.red.withValues(alpha: 0.35),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BeatDots extends StatelessWidget {
  final MetronomeController ctrl;
  const _BeatDots({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final beats = ctrl.timeSignature.beats;
    // currentBeat is the NEXT beat to play; the one just played is (currentBeat - 1 + beats) % beats
    final activeBeat = (ctrl.currentBeat - 1 + beats) % beats;

    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(beats, (i) {
          final isActive = ctrl.isPlaying && i == activeBeat;
          final isAccent = ctrl.timeSignature.isAccent(i);
          final dotSize = isActive ? (isAccent ? 24.0 : 20.0) : (isAccent ? 16.0 : 12.0);
          return SizedBox(
            width: 32,
            height: 36,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? (isAccent ? const Color(0xFFFF6B35) : const Color(0xFFFFB347))
                      : const Color(0xFF2A2A3A),
                  boxShadow: isActive
                      ? [BoxShadow(
                          color: isAccent
                              ? const Color(0xFFFF6B35).withValues(alpha: 0.7)
                              : const Color(0xFFFFB347).withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )]
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BpmDisplay extends StatelessWidget {
  final MetronomeController ctrl;
  const _BpmDisplay({required this.ctrl});

  void _showBpmInput(BuildContext context) {
    final textCtrl = TextEditingController(text: '${ctrl.bpm}');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Enter BPM', style: TextStyle(color: Color(0xFF8888AA), fontSize: 14, letterSpacing: 2)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w200),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6B35))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2)),
            hintText: '40 – 220',
            hintStyle: TextStyle(color: Color(0xFF444466), fontSize: 20),
          ),
          onSubmitted: (v) {
            final val = int.tryParse(v);
            if (val != null) ctrl.setBpm(val);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF666688))),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(textCtrl.text);
              if (val != null) ctrl.setBpm(val);
              Navigator.pop(ctx);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFFFF6B35))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StepButton(
              icon: Icons.remove,
              onPressed: () => ctrl.setBpm(ctrl.bpm - 1),
              onLongPress: () => ctrl.setBpm(ctrl.bpm - 5),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _showBpmInput(context),
              child: Text(
                '${ctrl.bpm}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 20),
            _StepButton(
              icon: Icons.add,
              onPressed: () => ctrl.setBpm(ctrl.bpm + 1),
              onLongPress: () => ctrl.setBpm(ctrl.bpm + 5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _tempoLabel(ctrl.bpm),
          style: const TextStyle(
            color: Color(0xFF6666AA),
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        if (ctrl.progressive.enabled && ctrl.isPlaying) ...[
          const SizedBox(height: 8),
          Text(
            '${ctrl.progressive.startBpm} → ${ctrl.progressive.endBpm}',
            style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 12),
          ),
        ],
      ],
    );
  }

  String _tempoLabel(int bpm) {
    if (bpm < 60) return 'LARGO';
    if (bpm < 66) return 'LARGHETTO';
    if (bpm < 76) return 'ADAGIO';
    if (bpm < 108) return 'ANDANTE';
    if (bpm < 120) return 'MODERATO';
    if (bpm < 156) return 'ALLEGRO';
    if (bpm < 176) return 'VIVACE';
    if (bpm < 200) return 'PRESTO';
    return 'PRESTISSIMO';
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  const _StepButton({required this.icon, required this.onPressed, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF8888AA)),
        iconSize: 28,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _BpmSlider extends StatelessWidget {
  final MetronomeController ctrl;
  const _BpmSlider({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFFFF6B35),
        inactiveTrackColor: const Color(0xFF2A2A3A),
        thumbColor: Colors.white,
        overlayColor: const Color(0xFFFF6B35).withValues(alpha: 0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      child: Slider(
        value: ctrl.bpm.toDouble(),
        min: 40,
        max: 220,
        onChanged: (v) => ctrl.setBpm(v.round()),
      ),
    );
  }
}

class _TimeSignatureSelector extends StatelessWidget {
  final MetronomeController ctrl;
  const _TimeSignatureSelector({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: TimeSignature.all.map((ts) {
        final selected = ctrl.timeSignature == ts;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFF6B35) : const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xFFFF6B35) : const Color(0xFF333344),
              ),
            ),
            child: InkWell(
              onTap: () => ctrl.setTimeSignature(ts),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  ts.label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF8888AA),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final MetronomeController ctrl;
  const _PlayButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ctrl.togglePlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ctrl.isPlaying ? const Color(0xFFFF6B35) : const Color(0xFF1E1E2E),
          border: Border.all(
            color: ctrl.isPlaying ? const Color(0xFFFF6B35) : const Color(0xFF444466),
            width: 2,
          ),
          boxShadow: ctrl.isPlaying
              ? [BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 4,
                )]
              : null,
        ),
        child: Icon(
          ctrl.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

class _TapTempoButton extends StatelessWidget {
  final MetronomeController ctrl;
  const _TapTempoButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: ctrl.handleTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF8888AA),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF333344)),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 18),
          SizedBox(width: 8),
          Text('TAP TEMPO', style: TextStyle(letterSpacing: 2, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProgressivePanel extends StatelessWidget {
  final MetronomeController ctrl;
  const _ProgressivePanel({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final p = ctrl.progressive;
    return _Panel(
      title: 'PROGRESSIVE MODE',
      trailing: Switch(
        value: p.enabled,
        onChanged: (v) => ctrl.updateProgressive(p.copyWith(enabled: v)),
        activeThumbColor: const Color(0xFFFF6B35),
      ),
      child: p.enabled
          ? Column(
              children: [
                const SizedBox(height: 8),
                _LabeledSlider(
                  label: 'Start BPM',
                  value: p.startBpm.toDouble(),
                  min: 40, max: 220,
                  displayValue: '${p.startBpm}',
                  onChanged: (v) => ctrl.updateProgressive(p.copyWith(startBpm: v.round())),
                ),
                const SizedBox(height: 8),
                _LabeledSlider(
                  label: 'End BPM',
                  value: p.endBpm.toDouble(),
                  min: 40, max: 220,
                  displayValue: '${p.endBpm}',
                  onChanged: (v) => ctrl.updateProgressive(p.copyWith(endBpm: v.round())),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      '增加步长',
                      style: TextStyle(color: Color(0xFF8888AA), fontSize: 13),
                    ),
                    const Spacer(),
                    ...[1, 2, 5, 10].map((n) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Chip(
                        label: '+$n',
                        selected: p.stepSize == n,
                        onTap: () => ctrl.updateProgressive(p.copyWith(stepSize: n)),
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      '持续时间',
                      style: TextStyle(color: Color(0xFF8888AA), fontSize: 13),
                    ),
                    const Spacer(),
                    ...[1, 2, 4, 8].map((n) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Chip(
                        label: '${n}小节',
                        selected: p.barsPerStep == n,
                        onTap: () => ctrl.updateProgressive(p.copyWith(barsPerStep: n)),
                      ),
                    )),
                  ],
                ),
                if (ctrl.isPlaying) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${ctrl.progressiveBpm} BPM',
                        style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ctrl.progressRatio,
                            backgroundColor: const Color(0xFF2A2A3A),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${p.endBpm} BPM',
                        style: const TextStyle(color: Color(0xFF8888AA), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _MicPanel extends StatelessWidget {
  final MetronomeController ctrl;
  const _MicPanel({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'MIC MONITOR',
      trailing: Switch(
        value: ctrl.micEnabled,
        onChanged: (_) => ctrl.toggleMic(),
        activeThumbColor: const Color(0xFFFF6B35),
      ),
      child: ctrl.micEnabled
          ? Column(
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Detects your playing and flashes red when off-beat.',
                  style: TextStyle(color: Color(0xFF666688), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.mic, color: Color(0xFF8888AA), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ctrl.micLevel,
                          backgroundColor: const Color(0xFF2A2A3A),
                          valueColor: AlwaysStoppedAnimation(
                            ctrl.showMismatchFlash ? Colors.red : const Color(0xFF44CC88),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : ctrl.micPermissionDenied
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Microphone permission denied.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                )
              : const SizedBox.shrink(),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget trailing;
  final Widget child;
  const _Panel({required this.title, required this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF252535)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF8888AA),
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                trailing,
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(color: Color(0xFF8888AA), fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFF6B35),
              inactiveTrackColor: const Color(0xFF2A2A3A),
              thumbColor: Colors.white,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: SliderComponentShape.noThumb,
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            displayValue,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B35) : const Color(0xFF252535),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF8888AA),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


class _BpmModeSelector extends StatelessWidget {
  final MetronomeController ctrl;
  const _BpmModeSelector({required this.ctrl});

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text("BPM Mode",
            style: TextStyle(color: Color(0xFF8888AA), fontSize: 14, letterSpacing: 2)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("STANDARD",
                style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(
              "BPM = 每分钟点击数。所有拍号节奏相同，拍号只决定重音位置。",
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            SizedBox(height: 12),
            Text("DAW",
                style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(
              "BPM 永远指四分音符。6/8 在同 BPM 下点击速度是 4/4 的两倍。",
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Color(0xFFFF6B35))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "BPM MODE",
          style: TextStyle(color: Color(0xFF666688), fontSize: 10, letterSpacing: 2),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF333344)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: BpmMode.values.map((m) {
              final selected = ctrl.bpmMode == m;
              return InkWell(
                onTap: () => ctrl.setBpmMode(m),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFF6B35) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    m.label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF8888AA),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 16, color: Color(0xFF666688)),
          onPressed: () => _showInfo(context),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
