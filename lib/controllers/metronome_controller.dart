import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/time_signature.dart';
import '../services/audio_service.dart';
import '../services/beat_detector.dart';

/// BPM 节拍模式
enum BpmMode {
  /// 标准节拍器：BPM = 每分钟点击数，与拍号无关。
  /// 4/4、3/4、6/8 在 BPM=120 时每点都是 500ms。
  standard,

  /// DAW 风格：BPM 永远指四分音符。
  /// 6/8 在 BPM=120 时每点 250ms（八分音符 = 四分音符的一半）。
  quarterNote,
}

extension BpmModeLabel on BpmMode {
  String get label => switch (this) {
        BpmMode.standard => 'STANDARD',
        BpmMode.quarterNote => 'DAW',
      };
}

class ProgressiveSettings {
  final bool enabled;
  final int startBpm;
  final int endBpm;
  final int stepSize;    // 每步增加的 BPM 量
  final int barsPerStep; // 每个速度持续的小节数

  const ProgressiveSettings({
    this.enabled = false,
    this.startBpm = 80,
    this.endBpm = 140,
    this.stepSize = 1,
    this.barsPerStep = 4,
  });

  ProgressiveSettings copyWith({
    bool? enabled,
    int? startBpm,
    int? endBpm,
    int? stepSize,
    int? barsPerStep,
  }) => ProgressiveSettings(
    enabled: enabled ?? this.enabled,
    startBpm: startBpm ?? this.startBpm,
    endBpm: endBpm ?? this.endBpm,
    stepSize: stepSize ?? this.stepSize,
    barsPerStep: barsPerStep ?? this.barsPerStep,
  );
}

class MetronomeController extends ChangeNotifier {
  int _bpm = 120;
  TimeSignature _timeSignature = TimeSignature.fourFour;
  BpmMode _bpmMode = BpmMode.standard;
  bool _isPlaying = false;
  int _currentBeat = 0;
  int _barsPlayedAtCurrentBpm = 0;

  ProgressiveSettings _progressive = const ProgressiveSettings();
  int _progressiveBpm = 120;
  double _progressRatio = 0.0;

  bool _micEnabled = false;
  bool _showMismatchFlash = false;
  double _micLevel = 0.0;
  bool _micPermissionDenied = false;
  DateTime? _lastLevelNotify; // 电平条更新节流

  Timer? _timer;
  DateTime? _lastBeatTime;
  DateTime? _scheduleAnchor; // 当前调度的锚点时刻（最后一次重锚）
  int _tickSinceAnchor = 0;  // 自锚点起的 tick 序号，用于绝对时间调度
  final List<DateTime> _tapTimes = [];

  final AudioService _audio = AudioService();
  final BeatDetector _detector = BeatDetector();

  bool _audioReady = false;

  MetronomeController() {
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _audio.initialize();
    _audioReady = true;
    notifyListeners();
  }

  // Getters
  int get bpm => _bpm;
  TimeSignature get timeSignature => _timeSignature;
  BpmMode get bpmMode => _bpmMode;
  bool get isPlaying => _isPlaying;
  int get currentBeat => _currentBeat;
  ProgressiveSettings get progressive => _progressive;
  int get progressiveBpm => _progressiveBpm;
  double get progressRatio => _progressRatio;
  bool get micEnabled => _micEnabled;
  bool get showMismatchFlash => _showMismatchFlash;
  double get micLevel => _micLevel;
  bool get micPermissionDenied => _micPermissionDenied;
  bool get audioReady => _audioReady;

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    _currentBeat = 0;
    _barsPlayedAtCurrentBpm = 0;
    if (_progressive.enabled) {
      _progressiveBpm = _progressive.startBpm;
      _bpm = _progressiveBpm;
      _updateProgressRatio();
    }
    _scheduleTimer();
    WakelockPlus.enable();
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _currentBeat = 0;
    _progressRatio = 0;
    WakelockPlus.disable();
    notifyListeners();
  }

  void togglePlay() {
    if (_isPlaying) {
      stop();
    } else {
      play();
    }
  }

  void setBpm(int newBpm) {
    _bpm = newBpm.clamp(40, 220);
    _rescheduleAfterRateChange();
    notifyListeners();
  }

  void setTimeSignature(TimeSignature ts) {
    _timeSignature = ts;
    _currentBeat = 0;
    _rescheduleAfterRateChange();
    notifyListeners();
  }

  void setBpmMode(BpmMode mode) {
    if (_bpmMode == mode) return;
    _bpmMode = mode;
    _rescheduleAfterRateChange();
    notifyListeners();
  }

  /// 速率变更时软重锚：以最后播放的拍为锚点，下一拍按新间隔到来，
  /// 不会立即触发额外的点击（避免拖动 BPM 滑块时的连击）
  void _rescheduleAfterRateChange() {
    if (!_isPlaying) return;
    _timer?.cancel();
    _scheduleAnchor = _lastBeatTime ?? DateTime.now();
    _tickSinceAnchor = 0;
    _scheduleNextTick();
  }

  void updateProgressive(ProgressiveSettings settings) {
    _progressive = settings;
    notifyListeners();
  }

  void handleTap() {
    final now = DateTime.now();
    _tapTimes.removeWhere((t) => now.difference(t) > const Duration(seconds: 3));
    _tapTimes.add(now);
    if (_tapTimes.length >= 2) {
      final totalMs = _tapTimes.last.difference(_tapTimes.first).inMilliseconds;
      final avgMs = totalMs / (_tapTimes.length - 1);
      setBpm((60000 / avgMs).round().clamp(40, 220));
    }
  }

  Future<void> toggleMic() async {
    if (_micEnabled) {
      await _detector.stop();
      _detector.onOnsetDetected = null;
      _detector.onLevelUpdate = null;
      _micEnabled = false;
      _micLevel = 0.0;
      _micPermissionDenied = false;
      notifyListeners();
    } else {
      // 回调必须在 start() 之前注册，避免竞态
      _detector.onOnsetDetected = _handleOnset;
      _detector.onLevelUpdate = _handleLevelUpdate;
      final granted = await _detector.start();
      if (granted) {
        _micEnabled = true;
        _micPermissionDenied = false;
      } else {
        _detector.onOnsetDetected = null;
        _detector.onLevelUpdate = null;
        _micPermissionDenied = true;
      }
      notifyListeners();
    }
  }

  void _handleLevelUpdate(double level) {
    // 节流：最多 25fps 通知 UI
    final now = DateTime.now();
    if (_lastLevelNotify != null &&
        now.difference(_lastLevelNotify!) < const Duration(milliseconds: 40)) {
      return;
    }
    _lastLevelNotify = now;
    // PCM RMS 通常在 0.01~0.1，放大 10 倍后进度条可见
    _micLevel = (level * 10.0).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 每拍毫秒数：
  /// - standard 模式：60000 / bpm（与拍号无关，BPM = 每分钟点击数）
  /// - quarterNote 模式：(60000 / bpm) × (4 / 分母)，BPM 始终代表四分音符
  int _beatIntervalMs() {
    final base = 60000.0 / _bpm;
    return switch (_bpmMode) {
      BpmMode.standard => base.round(),
      BpmMode.quarterNote =>
        (base * 4.0 / _timeSignature.denominator).round(),
    };
  }

  void _handleOnset(DateTime onsetTime) {
    if (!_isPlaying || _lastBeatTime == null) return;

    final beatIntervalUs = (_beatIntervalMs() * 1000);
    final elapsed = onsetTime.difference(_lastBeatTime!).inMicroseconds;
    final nearestBeatOffset = elapsed % beatIntervalUs;
    final diff = nearestBeatOffset < beatIntervalUs / 2
        ? nearestBeatOffset
        : beatIntervalUs - nearestBeatOffset;
    final diffMs = diff ~/ 1000;

    if (diffMs > 150) {
      _showMismatchFlash = true;
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 350), () {
        _showMismatchFlash = false;
        notifyListeners();
      });
    }
  }

  /// 启动绝对时间调度：第一拍立即响，后续每拍按"锚点 + N × 间隔"对齐
  void _scheduleTimer() {
    _scheduleAnchor = DateTime.now();
    _tickSinceAnchor = 0;
    _executeTick(); // 第 0 拍立即播
  }

  void _executeTick() {
    if (!_isPlaying) return;

    // _lastBeatTime 用于麦克风 onset 比较，使用调度的"理想时刻"而非 DateTime.now，
    // 抑制单拍抖动对节拍偏差判定的影响
    final intervalUs = _beatIntervalMs() * 1000;
    final scheduledAt = _scheduleAnchor!
        .add(Duration(microseconds: intervalUs * _tickSinceAnchor));
    _lastBeatTime = scheduledAt;

    final isAccent = _timeSignature.isAccent(_currentBeat);
    if (_audioReady) _audio.playTick(isAccent: isAccent);

    _currentBeat = (_currentBeat + 1) % _timeSignature.beats;

    if (_currentBeat == 0) {
      _barsPlayedAtCurrentBpm++;
      if (_progressive.enabled) _handleProgressiveStep();
    }

    // 关键顺序：先排好下一拍的 timer，再做 UI 更新。
    // 否则 notifyListeners 触发的 widget rebuild 会占住主线程，timer 调度被推迟。
    _scheduleNextTick();
    notifyListeners();
  }

  /// 单次 Timer 调度，每次按绝对目标时间校正漂移
  void _scheduleNextTick() {
    if (!_isPlaying || _scheduleAnchor == null) return;
    _tickSinceAnchor++;
    final intervalUs = _beatIntervalMs() * 1000;
    final target = _scheduleAnchor!
        .add(Duration(microseconds: intervalUs * _tickSinceAnchor));
    final delay = target.difference(DateTime.now());
    _timer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _executeTick,
    );
  }

  void _handleProgressiveStep() {
    if (_barsPlayedAtCurrentBpm >= _progressive.barsPerStep) {
      _barsPlayedAtCurrentBpm = 0;
      final direction = _progressive.endBpm >= _progressive.startBpm ? 1 : -1;
      if (direction > 0 && _progressiveBpm < _progressive.endBpm) {
        _progressiveBpm = (_progressiveBpm + _progressive.stepSize).clamp(
            _progressive.startBpm, _progressive.endBpm);
      } else if (direction < 0 && _progressiveBpm > _progressive.endBpm) {
        _progressiveBpm = (_progressiveBpm - _progressive.stepSize).clamp(
            _progressive.endBpm, _progressive.startBpm);
      }
      _bpm = _progressiveBpm;
      _updateProgressRatio();
      // 重锚到本拍的调度时刻，下一拍按新 BPM 计算
      _scheduleAnchor = _lastBeatTime;
      _tickSinceAnchor = 0;
    }
  }

  void _updateProgressRatio() {
    final total = (_progressive.endBpm - _progressive.startBpm).abs();
    if (total == 0) {
      _progressRatio = 1.0;
      return;
    }
    final done = (_progressiveBpm - _progressive.startBpm).abs();
    _progressRatio = done / total;
  }

  @override
  void dispose() {
    stop();
    if (_micEnabled) _detector.stop();
    _detector.dispose();
    _audio.dispose();
    super.dispose();
  }
}
