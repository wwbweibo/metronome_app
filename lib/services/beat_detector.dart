import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class BeatDetector {
  AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _amplitudeSub;
  StreamSubscription? _streamSub;

  double _fastEnv = 0.0;
  double _noiseFloor = 0.001;
  bool _inOnset = false;
  DateTime? _lastOnsetTime;

  static const _minOnsetGap = Duration(milliseconds: 180);
  static const _minThreshold = 0.02;

  void Function(DateTime)? onOnsetDetected;
  void Function(double level)? onLevelUpdate;

  Future<bool> start() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) return false;

      if (kIsWeb) {
        // Web：startStream 依赖 AudioWorklet，浏览器兼容性差。
        // 改用 start() 录到 blob URL（不消费）+ onAmplitudeChanged 获取振幅。
        await _recorder.start(
          const RecordConfig(
              encoder: AudioEncoder.opus, sampleRate: 16000, numChannels: 1),
          path: 'metronome_mic.webm', // web 上忽略，会自动用 blob URL
        );
        _amplitudeSub = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 50))
            .listen(_handleAmplitude);
      } else {
        // Android/iOS：直接拿 PCM 数据算 RMS
        final stream = await _recorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ));
        _streamSub = stream.listen(_processPcm);
      }
      return true;
    } catch (e) {
      debugPrint('BeatDetector.start error: $e');
      return false;
    }
  }

  /// 处理 PCM16 原始数据（非 Web 路径）
  void _processPcm(Uint8List data) {
    if (data.length < 2) return;
    final view = ByteData.sublistView(data);
    final numSamples = data.length ~/ 2;
    double sum = 0;
    for (var i = 0; i < numSamples; i++) {
      final s = view.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    final rms = math.sqrt(sum / numSamples);
    _processLevel(rms);
  }

  /// 处理 dBFS 振幅（Web 路径）
  void _handleAmplitude(Amplitude amp) {
    final linear =
        amp.current > -160 ? math.pow(10.0, amp.current / 20.0).toDouble() : 0.0;
    _processLevel(linear);
  }

  void _processLevel(double linear) {
    // 快速包络：新值更大立即跟上，否则缓慢衰减
    _fastEnv = math.max(linear, _fastEnv * 0.6);

    // 噪声底线：仅在安静时缓慢跟踪
    if (_fastEnv < _noiseFloor * 3.0) {
      _noiseFloor = 0.998 * _noiseFloor + 0.002 * _fastEnv;
    }

    onLevelUpdate?.call(_fastEnv.clamp(0.0, 1.0));

    // Onset 检测
    final threshold = math.max(_noiseFloor * 5.0, _minThreshold);
    if (!_inOnset && _fastEnv > threshold) {
      _inOnset = true;
      final now = DateTime.now();
      if (_lastOnsetTime == null ||
          now.difference(_lastOnsetTime!) > _minOnsetGap) {
        _lastOnsetTime = now;
        onOnsetDetected?.call(now);
      }
    } else if (_inOnset && _fastEnv < threshold * 0.35) {
      _inOnset = false;
    }
  }

  double get currentLevel => _fastEnv.clamp(0.0, 1.0);

  Future<void> stop() async {
    await _amplitudeSub?.cancel();
    await _streamSub?.cancel();
    _amplitudeSub = null;
    _streamSub = null;
    try {
      await _recorder.stop();
      await _recorder.dispose();
    } catch (_) {}
    _recorder = AudioRecorder();
    _reset();
  }

  void _reset() {
    _fastEnv = 0.0;
    _noiseFloor = 0.001;
    _inOnset = false;
    _lastOnsetTime = null;
  }

  void dispose() {
    _amplitudeSub?.cancel();
    _streamSub?.cancel();
    _recorder.dispose();
  }
}
