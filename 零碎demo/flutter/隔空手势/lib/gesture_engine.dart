import 'dart:collection';
import 'dart:ui';

enum GestureMode { image, cards }

class HandSample {
  const HandSample({
    required this.timestampMs,
    required this.points,
    required this.openPalm,
  });

  final int timestampMs;

  // 已校正方向、镜像后的图像像素坐标。
  final List<Offset> points;
  final bool openPalm;
}

class GestureUpdate {
  const GestureUpdate(this.targetScale, this.swipe, this.active);

  final double targetScale;

  // -1 向左，1 向右，0 表示本次没有切卡事件。
  final int swipe;
  final bool active;
}

enum _SwipePhase { waiting, tracking, cooling }

class _Motion {
  const _Motion(this.time, this.center, this.palm, this.travel);

  final int time;
  final Offset center;
  final double palm;
  final double travel;
}

class GestureEngine {
  factory GestureEngine({GestureMode mode = GestureMode.image}) =>
      GestureEngine._(mode);
  GestureEngine._(this._mode);

  GestureMode _mode;
  double _scale = 1;
  int? _lastTime;
  int? _lastSeen;
  Offset? _previousCenter;
  double? _previousPalm;

  int? _zoomArmAt;
  double? _zoomArmRatio;
  Offset? _zoomArmCenter;
  double? _zoomBaseRatio;
  double _zoomBaseScale = 1;

  _SwipePhase _phase = _SwipePhase.waiting;
  int? _openSince;
  int? _lastOpen;
  int _cooldownUntil = 0;
  int? _stillSince;
  Offset? _stillCenter;
  double _travel = 0;
  final _history = ListQueue<_Motion>();

  double get targetScale => _scale;
  GestureMode get mode => _mode;

  GestureUpdate _result([int swipe = 0]) => GestureUpdate(
    _scale,
    swipe,
    _mode == GestureMode.image
        ? _zoomBaseRatio != null
        : _phase == _SwipePhase.tracking,
  );

  void setMode(GestureMode value) {
    if (_mode == value) return;
    _mode = value;
    reset();
  }

  void reset({bool keepScale = true}) {
    if (!keepScale) _scale = 1;
    _lastTime = null;
    _lastSeen = null;
    _previousCenter = null;
    _previousPalm = null;
    _clearInteraction();
  }

  GestureUpdate noHand(int timestampMs) {
    if (!_acceptTime(timestampMs)) return _result();
    // 中断的轨迹不参与挥手判断；短暂失跟时仍保留缩放基线。
    if (_phase == _SwipePhase.tracking) _clearSwipe();
    if (_lastSeen == null || timestampMs - _lastSeen! >= 200) {
      _clearInteraction();
    }
    return _result();
  }

  GestureUpdate update(HandSample sample) {
    if (!_acceptTime(sample.timestampMs)) return _result();
    final points = sample.points;
    if (points.length != 21 ||
        points.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      _clearInteraction();
      return _result();
    }
    final palm = (points[5] - points[17]).distance;
    if (palm < 8) {
      _clearInteraction();
      return _result();
    }
    final center =
        (points[0] + points[5] + points[9] + points[13] + points[17]) / 5;
    final gap = _lastSeen == null ? 0 : sample.timestampMs - _lastSeen!;
    final jumped =
        _previousCenter != null &&
        gap < 100 &&
        (center - _previousCenter!).distance > palm * 4;
    final changedSize =
        _previousPalm != null &&
        (palm / _previousPalm! > 2.2 || _previousPalm! / palm > 2.2);
    if (gap >= 200 || jumped || changedSize) _clearInteraction();
    _lastSeen = sample.timestampMs;
    _previousCenter = center;
    _previousPalm = palm;

    if (_mode == GestureMode.image) {
      _zoom(sample.timestampMs, points, center, palm);
      return _result();
    }
    return _result(_swipe(sample, center, palm));
  }

  bool _acceptTime(int timestampMs) {
    if (timestampMs < 0 || (_lastTime != null && timestampMs <= _lastTime!)) {
      return false;
    }
    _lastTime = timestampMs;
    return true;
  }

  void _zoom(int time, List<Offset> points, Offset center, double palm) {
    final ratio = (points[4] - points[8]).distance / palm;
    if (!ratio.isFinite || ratio > 3) {
      _clearZoom();
      return;
    }
    if (_zoomBaseRatio != null) {
      _scale = (_zoomBaseScale * ratio / _zoomBaseRatio!).clamp(0.5, 3.0);
      return;
    }
    if (ratio < 0.2) {
      _clearZoom();
      return;
    }
    final moved =
        _zoomArmCenter != null &&
        (center - _zoomArmCenter!).distance > palm * 0.35;
    final changed =
        _zoomArmRatio != null && (ratio / _zoomArmRatio! - 1).abs() > 0.12;
    if (_zoomArmAt == null || moved || changed) {
      _zoomArmAt = time;
      _zoomArmRatio = ratio;
      _zoomArmCenter = center;
    }
    if (time - _zoomArmAt! >= 200) {
      _zoomBaseRatio = ratio;
      _zoomBaseScale = _scale;
    }
  }

  int _swipe(HandSample sample, Offset center, double palm) {
    final time = sample.timestampMs;
    if (sample.openPalm) _lastOpen = time;

    if (_phase == _SwipePhase.cooling) {
      if (_stillCenter == null ||
          (center - _stillCenter!).distance > palm * 0.18) {
        _stillCenter = center;
        _stillSince = time;
      }
      final rested = _stillSince != null && time - _stillSince! >= 220;
      if (time >= _cooldownUntil && rested && sample.openPalm) {
        _phase = _SwipePhase.tracking;
        _history.clear();
        _travel = 0;
        _history.add(_Motion(time, center, palm, _travel));
      }
      return 0;
    }

    if (_phase == _SwipePhase.waiting) {
      if (!sample.openPalm) {
        _openSince = null;
        return 0;
      }
      _openSince ??= time;
      if (time - _openSince! >= 120) {
        _phase = _SwipePhase.tracking;
        _history.add(_Motion(time, center, palm, _travel));
      }
      return 0;
    }

    if (_lastOpen == null || time - _lastOpen! > 100) {
      _clearSwipe();
      return 0;
    }
    if (_history.isNotEmpty) {
      _travel += (center.dx - _history.last.center.dx).abs();
    }
    _history.add(_Motion(time, center, palm, _travel));
    while (_history.isNotEmpty && time - _history.first.time > 600) {
      _history.removeFirst();
    }
    if (!sample.openPalm) return 0;

    for (final origin in _history) {
      final elapsed = time - origin.time;
      if (elapsed < 80) break;
      final delta = (center - origin.center) / origin.palm;
      final speed = delta.dx.abs() * 1000 / elapsed;
      final path = (_travel - origin.travel) / origin.palm;
      final consistent = path == 0 || delta.dx.abs() / path >= 0.85;
      if (delta.dx.abs() >= 1 &&
          speed >= 2 &&
          delta.dy.abs() <= 0.7 &&
          consistent) {
        _phase = _SwipePhase.cooling;
        _cooldownUntil = time + 350;
        _stillSince = time;
        _stillCenter = center;
        _history.clear();
        return delta.dx < 0 ? -1 : 1;
      }
    }
    return 0;
  }

  void _clearZoom() {
    _zoomArmAt = null;
    _zoomArmRatio = null;
    _zoomArmCenter = null;
    _zoomBaseRatio = null;
  }

  void _clearSwipe() {
    _phase = _SwipePhase.waiting;
    _openSince = null;
    _lastOpen = null;
    _stillSince = null;
    _stillCenter = null;
    _history.clear();
    _travel = 0;
    _cooldownUntil = 0;
  }

  void _clearInteraction() {
    _clearZoom();
    _clearSwipe();
  }
}
