import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class PitchDetector {
  AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _streamSub;

  static const _sampleRate = 22050;
  static const _bufferSize = 4096;
  static const _hopSize = 1024;

  // Electric guitar fundamental range, with room for 24th-fret notes and
  // common alternate tunings down to low B.
  static const _minGuitarFreq = 55.0;
  static const _maxGuitarFreq = 1400.0;

  // Mild preamp only. Electric guitar transients clip phone mics easily, and
  // hard clipping creates extra harmonics that confuse pitch detection.
  static const _gain = 3.2;

  // RMS gate after gain and high-pass. This stays sensitive enough for quiet
  // direct sound while ignoring room noise and amp hiss between notes.
  static const _rmsGate = 0.010;

  // ── Smoothing ────────────────────────────────────────────────────────────
  static const _medN = 5;
  static const _emaAlpha = 0.34;

  // YIN confidence threshold. Lower is stricter. Electric guitar benefits from
  // a slightly conservative threshold because harmonics are strong.
  static const _yinThreshold = 0.14;

  final List<double> _pcmBuf = [];
  final List<double> _rawFreqs = []; // circular window for median
  double? _smoothedFreq;
  String? _lockedNote;
  int _sameNoteFrames = 0;
  double _dc = 0;

  void Function(double freq, String note, int cents)? onPitchDetected;
  void Function()? onSilence;

  Future<bool> start() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) return false;
      if (kIsWeb) return false;

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      _streamSub = stream.listen(_processPcm);
      return true;
    } catch (e) {
      debugPrint('PitchDetector.start error: $e');
      return false;
    }
  }

  void _processPcm(Uint8List data) {
    final view = ByteData.sublistView(data);
    final numSamples = data.length ~/ 2;
    for (var i = 0; i < numSamples; i++) {
      final raw = view.getInt16(i * 2, Endian.little) / 32768.0;
      _dc = _dc * 0.995 + raw * 0.005;
      _pcmBuf.add(((raw - _dc) * _gain).clamp(-0.98, 0.98));
    }

    while (_pcmBuf.length >= _bufferSize) {
      _analyzeFrame(List.of(_pcmBuf.sublist(0, _bufferSize)));
      _pcmBuf.removeRange(0, _hopSize);
    }
  }

  void _analyzeFrame(List<double> samples) {
    // ── Silence gate ──────────────────────────────────────────────────────
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    if (math.sqrt(sum / samples.length) < _rmsGate) {
      _resetSmoothing();
      onSilence?.call();
      return;
    }

    // ── Raw pitch detection ───────────────────────────────────────────────
    final detected = _yin(samples);
    if (detected == null) {
      _resetSmoothing();
      onSilence?.call();
      return;
    }
    final raw = _correctElectricGuitarHarmonic(detected, samples);

    // ── Median filter (3 frames) — kills isolated spikes ─────────────────
    _rawFreqs.add(raw);
    if (_rawFreqs.length > _medN) _rawFreqs.removeAt(0);
    final median = _median(_rawFreqs);

    // ── EMA smoothing with octave-error rejection ─────────────────────────
    if (_smoothedFreq == null) {
      _smoothedFreq = median;
    } else {
      final ratio = median / _smoothedFreq!;
      if (ratio > 1.88 || ratio < 0.53) {
        // Likely an octave error → reset and accept new value
        _smoothedFreq = median;
        _rawFreqs
          ..clear()
          ..add(median);
      } else {
        _smoothedFreq = _emaAlpha * median + (1.0 - _emaAlpha) * _smoothedFreq!;
      }
    }

    final (note, cents) = _stableNote(_smoothedFreq!);
    onPitchDetected?.call(_smoothedFreq!, note, cents);
  }

  // ── YIN pitch detection ───────────────────────────────────────────────────

  double? _yin(List<double> samples) {
    final n = samples.length;
    final minPeriod = (_sampleRate / _maxGuitarFreq).floor();
    final maxPeriod = (_sampleRate / _minGuitarFreq).ceil();
    final diff = List<double>.filled(maxPeriod + 1, 0);
    final cmnd = List<double>.filled(maxPeriod + 1, 1);

    for (var tau = minPeriod; tau <= maxPeriod; tau++) {
      double d = 0;
      final len = n - tau;
      for (var i = 0; i < len; i++) {
        final delta = samples[i] - samples[i + tau];
        d += delta * delta;
      }
      diff[tau] = d;
    }

    var runningSum = 0.0;
    var bestTau = 0;
    var bestCmnd = double.infinity;

    for (var tau = minPeriod; tau <= maxPeriod; tau++) {
      runningSum += diff[tau];
      if (runningSum <= 0) continue;
      cmnd[tau] = diff[tau] * tau / runningSum;
      if (cmnd[tau] < bestCmnd) {
        bestCmnd = cmnd[tau];
        bestTau = tau;
      }
    }

    for (var tau = minPeriod + 1; tau <= maxPeriod; tau++) {
      if (cmnd[tau] >= _yinThreshold) continue;
      while (tau + 1 <= maxPeriod && cmnd[tau + 1] < cmnd[tau]) {
        tau++;
      }
      bestTau = tau;
      bestCmnd = cmnd[tau];
      break;
    }

    if (bestTau == 0 || bestCmnd > 0.26) return null;

    final refinedTau = _parabolicTau(diff, bestTau, minPeriod, maxPeriod);
    final freq = _sampleRate / refinedTau;
    if (freq < _minGuitarFreq || freq > _maxGuitarFreq) return null;
    return freq;
  }

  double _parabolicTau(List<double> values, int tau, int minTau, int maxTau) {
    if (tau <= minTau || tau >= maxTau) return tau.toDouble();
    final left = values[tau - 1];
    final center = values[tau];
    final right = values[tau + 1];
    final denom = left - 2.0 * center + right;
    if (denom.abs() < 1e-10) return tau.toDouble();
    return tau + 0.5 * (left - right) / denom;
  }

  double _correctElectricGuitarHarmonic(double freq, List<double> samples) {
    var corrected = freq;

    // If YIN locked to the octave harmonic, the subharmonic can still show a
    // strong normalized autocorrelation. Avoid third-harmonic correction here:
    // a correct high E string at E4 can otherwise be folded down to A2.
    for (final divisor in [2.0]) {
      final sub = corrected / divisor;
      if (sub < _minGuitarFreq) continue;
      final subCorr = _normalizedCorrelation(samples, sub);
      final currentCorr = _normalizedCorrelation(samples, corrected);
      if (subCorr > currentCorr * 0.82 && _isNearGuitarNote(sub)) {
        corrected = sub;
      }
    }

    return corrected;
  }

  double _normalizedCorrelation(List<double> samples, double freq) {
    final lag = (_sampleRate / freq).round();
    if (lag <= 0 || lag >= samples.length) return 0;
    double xy = 0;
    double x2 = 0;
    double y2 = 0;
    final len = samples.length - lag;
    for (var i = 0; i < len; i++) {
      final x = samples[i];
      final y = samples[i + lag];
      xy += x * y;
      x2 += x * x;
      y2 += y * y;
    }
    final denom = math.sqrt(x2 * y2);
    return denom <= 1e-12 ? 0 : xy / denom;
  }

  bool _isNearGuitarNote(double freq) {
    for (final target in _guitarReferenceNotes) {
      final cents = 1200.0 * math.log(freq / target) / math.log(2.0);
      if (cents.abs() <= 42) return true;
    }
    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _median(List<double> values) {
    if (values.length == 1) return values.first;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  static const _noteNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const _guitarReferenceNotes = [
    73.42, // D2, common drop-D / lower alternate tunings
    82.41, // E2
    110.00, // A2
    146.83, // D3
    196.00, // G3
    246.94, // B3
    329.63, // E4
  ];

  (String, int) _frequencyToNote(double freq) {
    final midi = 12.0 * (math.log(freq / 440.0) / math.log(2.0)) + 69.0;
    final rounded = midi.round();
    final cents = ((midi - rounded) * 100).round().clamp(-50, 50);
    final name = _noteNames[rounded % 12];
    final octave = (rounded ~/ 12) - 1;
    return ('$name$octave', cents);
  }

  (String, int) _stableNote(double freq) {
    final (note, cents) = _frequencyToNote(freq);
    if (_lockedNote == null || note == _lockedNote) {
      _lockedNote = note;
      _sameNoteFrames++;
      return (note, cents);
    }

    // Guitar notes have a noisy attack. Hold the previous note briefly unless
    // the new candidate is clearly established or very far away.
    final lockedFreq = _noteToFrequency(_lockedNote!);
    final semitoneJump = (12.0 * math.log(freq / lockedFreq) / math.log(2.0))
        .abs();
    if (_sameNoteFrames < 2 && semitoneJump < 3.0) {
      _sameNoteFrames++;
      final lockedCents = (1200.0 * math.log(freq / lockedFreq) / math.log(2.0))
          .round()
          .clamp(-50, 50);
      return (_lockedNote!, lockedCents);
    }

    _lockedNote = note;
    _sameNoteFrames = 1;
    return (note, cents);
  }

  double _noteToFrequency(String note) {
    final match = RegExp(r'^([A-G]#?)(-?\d+)$').firstMatch(note);
    if (match == null) return 440;
    final name = match.group(1)!;
    final octave = int.parse(match.group(2)!);
    final index = _noteNames.indexOf(name);
    final midi = (octave + 1) * 12 + index;
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  void _resetSmoothing() {
    _rawFreqs.clear();
    _smoothedFreq = null;
    _lockedNote = null;
    _sameNoteFrames = 0;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> stop() async {
    await _streamSub?.cancel();
    _streamSub = null;
    _pcmBuf.clear();
    _resetSmoothing();
    try {
      await _recorder.stop();
      await _recorder.dispose();
    } catch (_) {}
    _recorder = AudioRecorder();
  }

  void dispose() {
    _streamSub?.cancel();
    _recorder.dispose();
  }
}
