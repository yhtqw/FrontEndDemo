import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// 会话属于应用壳，页面切换不销毁播放器。
class PlaybackSession extends ChangeNotifier {
  VideoPlayerController? _controller;
  VideoPlayerController? get controller => _controller;
  bool active = false;
  bool loading = false;
  bool wantsPlay = false;
  String? failure;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _commands = Future.value();
  Future<void> _retiring = Future.value();

  Future<void> _release(VideoPlayerController? player) {
    final pending = _commands;

    _retiring = _retiring.then((_) async {
      await pending;
      await player?.dispose();
    });

    return _retiring;
  }

  Future<void> open() async {
    final generation = ++_generation;

    active = true;
    wantsPlay = true;
    failure = null;
    loading = true;

    final previous = _controller;

    _controller = null;
    notifyListeners();
    
    await _release(previous);
    
    if (!_current(generation)) return;
    
    final player = VideoPlayerController.asset('assets/demo.mp4');
    _controller = player;
    
    try {
      await player.initialize();
    
      if (!_current(generation)) return;
      
      await player.setLooping(true);
      
      if (!_current(generation)) return;
      if (wantsPlay) await player.play();
    } catch (_) {
      if (_current(generation)) failure = '播放失败，请重试';
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation) => !_disposed && active && generation == _generation;

  Future<void> _enqueue(Future<void> Function(VideoPlayerController) action) {
    final generation = _generation;
    final player = _controller;
    final command = _commands.then((_) async {
      if (!_current(generation) || player == null || !player.value.isInitialized) return;
      
      try {
        await action(player);
      } catch (_) {
        if (_current(generation)) {
          failure = '操作失败，请重试';
          notifyListeners();
        }
      }
    });
    
    _commands = command;
    
    return command;
  }

  Future<void> toggle() {
    wantsPlay = !wantsPlay;
    
    final desired = wantsPlay;
    
    return _enqueue((player) => desired ? player.play() : player.pause());
  }

  Future<void> pause() {
    wantsPlay = false;
    
    return _enqueue((player) => player.pause());
  }

  Future<void> seek(Duration position) => _enqueue((player) {
    final ms = position.inMilliseconds.clamp(0, player.value.duration.inMilliseconds);
    
    return player.seekTo(Duration(milliseconds: ms));
  });

  Future<void> close() async {
    ++_generation; // 旧初始化结果不能再次启动播放。
    
    active = false;
    loading = false;
    wantsPlay = false;
    
    final player = _controller;
    
    _controller = null;
    
    notifyListeners();
    
    await _release(player);
  }

  @override
  void dispose() {
    _disposed = true;
    
    ++_generation;
    
    unawaited(_release(_controller));
    
    super.dispose();
  }
}
