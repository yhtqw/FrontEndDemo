import 'dart:async';

import 'package:flutter/foundation.dart';

/// start 成功应代表相机确实运行，失败由适配器抛出。
abstract interface class CameraPort {
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

class _SessionChanges extends ChangeNotifier {
  void emit() => notifyListeners();
}

class CameraSession implements Listenable {
  CameraSession(this._port);

  final CameraPort _port;
  final _SessionChanges _changes = _SessionChanges();
  bool _desired = false;
  bool _running = false;
  bool _busy = false;
  bool _closed = false;
  bool _requiresRecreation = false;
  Object? _error;
  Future<void>? _closeFuture;

  bool get desired => _desired;
  // false 表示未确认可运行，不代表硬件已释放。
  bool get running => _running;
  bool get busy => _busy;
  bool get closed => _closed;
  bool get requiresRecreation => _requiresRecreation;
  Object? get error => _error;

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _changes.removeListener(listener);

  void setDesired(bool value) {
    if (_closed) return;
    if (_desired != value) {
      _desired = value;
      _changes.emit();
    }
    _drive();
  }

  void retry() {
    if (_closed || _requiresRecreation) return;
    _error = null;
    _changes.emit();
    _drive();
  }

  void _drive() {
    if (_closed || _busy || _error != null || _running == _desired) return;
    _busy = true;
    _changes.emit();
    unawaited(_reconcile());
  }

  Future<void> _reconcile() async {
    try {
      while (!_closed && _error == null && _running != _desired) {
        final target = _desired;
        try {
          if (target) {
            await _port.start();
          } else {
            await _port.stop();
          }
          // 操作完成时，页面可能已经退出。
          if (_closed) return;
          _running = target;
          _changes.emit();
        } catch (error) {
          if (_closed) return;
          _running = false;
          // stop 失败后状态不确定，再次 stop 可能本地早退。
          // 保留错误，关闭后重新创建 Controller 才能继续。
          if (!target) _requiresRecreation = true;
          _error = error;
          _changes.emit();
        }
      }
    } finally {
      if (!_closed) {
        _busy = false;
        _changes.emit();
      }
    }
  }

  Future<void> close() {
    final pending = _closeFuture;
    if (pending != null) return pending;

    final done = Completer<void>();
    _closeFuture = done.future;
    _closed = true;
    _desired = false;
    _running = false;
    _busy = false;

    // 不等待在途 start，由插件负责启动后的会话释放。
    final release = Future<void>.sync(_port.dispose);
    _changes.emit();
    // close 也允许从监听回调触发，避开通知中的销毁断言。
    scheduleMicrotask(_changes.dispose);
    unawaited(
      release.then<void>(
        (_) => done.complete(),
        onError: (Object error, StackTrace stack) {
          _error = error;
          done.completeError(error, stack);
        },
      ),
    );
    return done.future;
  }
}
