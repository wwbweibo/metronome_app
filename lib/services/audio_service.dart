import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final List<AudioPlayer> _accentPlayers = [];
  final List<AudioPlayer> _normalPlayers = [];
  int _accentIdx = 0;
  int _normalIdx = 0;
  bool _initialized = false;
  static const _poolSize = 4;

  late Source _accentSource;
  late Source _normalSource;

  Future<void> initialize() async {
    final accentBytes = _generateClick(frequency: 1500.0, durationMs: 50);
    final normalBytes = _generateClick(frequency: 880.0, durationMs: 50);

    if (kIsWeb) {
      _accentSource = BytesSource(accentBytes);
      _normalSource = BytesSource(normalBytes);
    } else {
      final dir = await getTemporaryDirectory();
      final accentPath = '${dir.path}/metro_accent.wav';
      final normalPath = '${dir.path}/metro_normal.wav';
      await File(accentPath).writeAsBytes(accentBytes);
      await File(normalPath).writeAsBytes(normalBytes);
      _accentSource = DeviceFileSource(accentPath);
      _normalSource = DeviceFileSource(normalPath);
    }

    // Android: audioFocus = none，不抢占焦点，避免打断麦克风录音
    // iOS:     category = playAndRecord + mixWithOthers，允许录音与播放共存
    final audioCtx = AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notification,
        stayAwake: false,
        isSpeakerphoneOn: false,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.defaultToSpeaker,
        },
      ),
    );

    for (var i = 0; i < _poolSize; i++) {
      final ap = AudioPlayer();
      final np = AudioPlayer();
      await ap.setAudioContext(audioCtx);
      await np.setAudioContext(audioCtx);
      // 预加载：让平台提前初始化播放器，消除首拍延迟
      await ap.setSource(_accentSource);
      await np.setSource(_normalSource);
      _accentPlayers.add(ap);
      _normalPlayers.add(np);
    }

    _initialized = true;
  }

  void playTick({required bool isAccent}) {
    if (!_initialized) return;
    final player = isAccent ? _accentPlayers[_accentIdx] : _normalPlayers[_normalIdx];
    if (isAccent) {
      _accentIdx = (_accentIdx + 1) % _poolSize;
    } else {
      _normalIdx = (_normalIdx + 1) % _poolSize;
    }
    // play() 每次从头重新加载并播放，比 seek+resume 更可靠
    player.play(isAccent ? _accentSource : _normalSource);
  }

  Future<void> dispose() async {
    for (final p in [..._accentPlayers, ..._normalPlayers]) {
      await p.dispose();
    }
    _initialized = false;
  }

  Uint8List _generateClick({required double frequency, required int durationMs}) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2;
    final buf = ByteData(44 + dataSize);

    _str(buf, 0, 'RIFF');
    buf.setUint32(4, 36 + dataSize, Endian.little);
    _str(buf, 8, 'WAVE');
    _str(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    _str(buf, 36, 'data');
    buf.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final env = math.exp(-t * 80.0);
      final v = (env *
              (math.sin(2 * math.pi * frequency * t) * 0.7 +
               math.sin(2 * math.pi * frequency * 2.5 * t) * 0.3) *
              30000)
          .round()
          .clamp(-32768, 32767);
      buf.setInt16(44 + i * 2, v, Endian.little);
    }
    return buf.buffer.asUint8List();
  }

  void _str(ByteData buf, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      buf.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
