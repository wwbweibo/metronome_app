import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/pitch_detector.dart';

const _bgTop = Color(0xFF10151B);
const _bgBottom = Color(0xFF07090C);
const _surface = Color(0xFF151A21);
const _surfaceHigh = Color(0xFF1B222B);
const _border = Color(0xFF28313B);
const _accent = Color(0xFFFF7A3D);
const _text = Color(0xFFF4F7FA);
const _muted = Color(0xFF91A0AF);
const _subtle = Color(0xFF62707F);
const _success = Color(0xFF3DDBA5);
const _warning = Color(0xFFFFB86B);
const _danger = Color(0xFFFF4D6D);

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen>
    with SingleTickerProviderStateMixin {
  final _detector = PitchDetector();
  bool _isListening = false;
  bool _permissionDenied = false;

  String _note = '';
  double _frequency = 0;
  int _cents = 0;
  bool _hasPitch = false;

  late final AnimationController _inTuneCtrl;

  @override
  void initState() {
    super.initState();
    _inTuneCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _inTuneCtrl.dispose();
    _detector.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isListening) {
      await _detector.stop();
      setState(() {
        _isListening = false;
        _hasPitch = false;
      });
      _inTuneCtrl.reverse();
      return;
    }

    _detector.onPitchDetected = (freq, note, cents) {
      if (!mounted) return;
      setState(() {
        _frequency = freq;
        _note = note;
        _cents = cents;
        _hasPitch = true;
      });
      if (cents.abs() <= 5) {
        _inTuneCtrl.forward();
      } else {
        _inTuneCtrl.reverse();
      }
    };
    _detector.onSilence = () {
      if (!mounted) return;
      setState(() => _hasPitch = false);
      _inTuneCtrl.reverse();
    };

    final ok = await _detector.start();
    if (ok) {
      setState(() {
        _isListening = true;
        _permissionDenied = false;
      });
    } else {
      setState(() => _permissionDenied = !kIsWeb);
    }
  }

  Color get _tuningColor {
    final abs = _cents.abs();
    if (abs <= 5) return _success;
    if (abs <= 15) return _warning;
    return _danger;
  }

  String get _statusText {
    if (!_isListening) return 'READY';
    if (!_hasPitch) return 'LISTENING';
    if (_cents.abs() <= 5) return 'IN TUNE';
    return _cents < 0 ? 'FLAT' : 'SHARP';
  }

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^([A-G]#?)(\d+)$').firstMatch(_note);
    final notePart = _hasPitch ? (match?.group(1) ?? '--') : '--';
    final octavePart = _hasPitch ? (match?.group(2) ?? '') : '';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              children: [
                _Header(
                  statusText: _statusText,
                  statusColor: _hasPitch ? _tuningColor : _muted,
                  isListening: _isListening,
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToneReadout(
                            notePart: notePart,
                            octavePart: octavePart,
                            frequency: _frequency,
                            cents: _cents,
                            hasPitch: _hasPitch,
                            tuningColor: _tuningColor,
                            inTuneAnim: _inTuneCtrl,
                          ),
                          const SizedBox(height: 24),
                          _TuningMeter(
                            cents: _cents,
                            hasPitch: _hasPitch,
                            color: _tuningColor,
                          ),
                          const SizedBox(height: 18),
                          _DirectionHint(
                            hasPitch: _hasPitch,
                            cents: _cents,
                            color: _tuningColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (kIsWeb)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Pitch detection requires a native app.',
                      style: TextStyle(color: _subtle, fontSize: 13),
                    ),
                  )
                else ...[
                  if (_permissionDenied)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Microphone permission denied.',
                        style: TextStyle(color: _danger, fontSize: 13),
                      ),
                    ),
                  _MicButton(isListening: _isListening, onTap: _toggle),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String statusText;
  final Color statusColor;
  final bool isListening;

  const _Header({
    required this.statusText,
    required this.statusColor,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'TUNER',
          style: TextStyle(
            color: _text,
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isListening ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToneReadout extends StatelessWidget {
  final String notePart;
  final String octavePart;
  final double frequency;
  final int cents;
  final bool hasPitch;
  final Color tuningColor;
  final Animation<double> inTuneAnim;

  const _ToneReadout({
    required this.notePart,
    required this.octavePart,
    required this.frequency,
    required this.cents,
    required this.hasPitch,
    required this.tuningColor,
    required this.inTuneAnim,
  });

  @override
  Widget build(BuildContext context) {
    final centsText = !hasPitch
        ? '--'
        : cents > 0
        ? '+$cents'
        : '$cents';

    return AnimatedBuilder(
      animation: inTuneAnim,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color.lerp(_border, _success, inTuneAnim.value)!,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  Colors.black.withValues(alpha: 0.24),
                  _success.withValues(alpha: 0.16),
                  inTuneAnim.value,
                )!,
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          const Text(
            'DETECTED NOTE',
            style: TextStyle(
              color: _subtle,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: hasPitch ? _text : const Color(0xFF39434E),
                  fontSize: 120,
                  fontWeight: FontWeight.w500,
                  height: 0.92,
                  letterSpacing: 0,
                ),
                child: Text(notePart),
              ),
              if (octavePart.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    octavePart,
                    style: TextStyle(
                      color: _text.withValues(alpha: 0.46),
                      fontSize: 42,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'FREQUENCY',
                  value: hasPitch ? frequency.toStringAsFixed(1) : '--',
                  unit: 'Hz',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'OFFSET',
                  value: centsText,
                  unit: 'cents',
                  valueColor: hasPitch ? tuningColor : _muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _subtle,
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? _text,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TuningMeter extends StatelessWidget {
  final int cents;
  final bool hasPitch;
  final Color color;

  const _TuningMeter({
    required this.cents,
    required this.hasPitch,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final position = (((cents.clamp(-50, 50) + 50) / 100) * width).clamp(
          10.0,
          width - 10.0,
        );

        return Container(
          height: 112,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MeterPainter(
                          hasPitch: hasPitch,
                          activeColor: color,
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOut,
                      left: hasPitch ? position - 10 : width / 2 - 10,
                      top: 27,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasPitch ? color : _subtle,
                          border: Border.all(color: _text, width: 2),
                          boxShadow: hasPitch
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.36),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('-50', style: _MeterLabelStyle()),
                  Text('-25', style: _MeterLabelStyle()),
                  Text('0', style: _MeterLabelStyle(color: _success)),
                  Text('+25', style: _MeterLabelStyle()),
                  Text('+50', style: _MeterLabelStyle()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MeterPainter extends CustomPainter {
  final bool hasPitch;
  final Color activeColor;

  const _MeterPainter({required this.hasPitch, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.56;
    final left = 4.0;
    final right = size.width - 4;
    final track = RRect.fromLTRBR(
      left,
      centerY - 4,
      right,
      centerY + 4,
      const Radius.circular(999),
    );

    canvas.drawRRect(track, Paint()..color = const Color(0xFF27313B));
    final activePaint = Paint();
    if (hasPitch) {
      activePaint.shader = const LinearGradient(
        colors: [_danger, _warning, _success, _warning, _danger],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(left, centerY - 4, right - left, 8));
    } else {
      activePaint.color = _subtle.withValues(alpha: 0.28);
    }
    canvas.drawRRect(track, activePaint);

    for (var c = -50; c <= 50; c += 10) {
      final x = left + ((c + 50) / 100) * (right - left);
      final isMajor = c % 25 == 0 || c == 0;
      final tickHeight = c == 0 ? 42.0 : (isMajor ? 26.0 : 16.0);
      final tickColor = c == 0
          ? _success
          : _muted.withValues(alpha: isMajor ? 0.7 : 0.35);
      canvas.drawLine(
        Offset(x, centerY - tickHeight / 2),
        Offset(x, centerY + tickHeight / 2),
        Paint()
          ..color = tickColor
          ..strokeWidth = c == 0 ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter oldDelegate) =>
      oldDelegate.hasPitch != hasPitch ||
      oldDelegate.activeColor != activeColor;
}

class _MeterLabelStyle extends TextStyle {
  const _MeterLabelStyle({Color color = _subtle})
    : super(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

class _DirectionHint extends StatelessWidget {
  final bool hasPitch;
  final int cents;
  final Color color;

  const _DirectionHint({
    required this.hasPitch,
    required this.cents,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = !hasPitch
        ? 'Play a note'
        : cents.abs() <= 5
        ? 'Centered'
        : cents < 0
        ? 'Tune up'
        : 'Tune down';

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 160),
      style: TextStyle(
        color: hasPitch ? color : _subtle,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
      child: Text(text),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;
  const _MicButton({required this.isListening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          size: 22,
        ),
        label: Text(isListening ? 'STOP LISTENING' : 'START TUNING'),
        style: FilledButton.styleFrom(
          backgroundColor: isListening ? _accent : _text,
          foregroundColor: isListening ? _text : const Color(0xFF10151B),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
