import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:video_player/video_player.dart';

import 'playback_session.dart';

class PlayerShell extends StatefulWidget {
  const PlayerShell({super.key, required this.session, required this.child});
  final PlaybackSession session;
  final Widget child;

  @override
  State<PlayerShell> createState() => _PlayerShellState();
}

class _PlayerShellState extends State<PlayerShell> with SingleTickerProviderStateMixin {
  late final _expand = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  
  bool _expanded = true;
  bool _wasActive = false;
  
  final _surfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    widget.session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    final active = widget.session.active;
    
    if (active && !_wasActive) {
      _expanded = true;
      _expand.value = 1;
    }
    
    _wasActive = active;
    
    setState(() {});
  }

  void _setExpanded(bool expanded) {
    setState(() => _expanded = expanded);
    
    if (MediaQuery.disableAnimationsOf(context)) {
      _expand.value = expanded ? 1 : 0;
    } else {
      _expand.animateTo(expanded ? 1 : 0, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _expand.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    
    return PopScope(
      canPop: !session.active || !_expanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && session.active) _setExpanded(false);
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final insets = MediaQuery.paddingOf(context);
            final miniWidth = math.min(size.width - 32, 420.0);
            final mini = Rect.fromLTWH(
              (size.width - miniWidth) / 2,
              size.height - insets.bottom - 92,
              miniWidth,
              76,
            );
            final full = Offset.zero & size;
            
            return Stack(
              children: [
                widget.child,
                if (session.active)
                  AnimatedBuilder(
                    animation: _expand,
                    builder: (context, child) {
                      final t = _expand.value;
                      return Positioned.fromRect(
                        rect: Rect.lerp(mini, full, t)!,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16 * (1 - t)),
                          child: ColoredBox(color: const Color(0xff060b09), child: child),
                        ),
                      );
                    },
                    // 动画改变布局，视频节点始终留在同一个位置。
                    child: RawGestureDetector(
                      key: _surfaceKey,
                      gestures: {
                        _VideoVerticalDrag:
                            GestureRecognizerFactoryWithHandlers<_VideoVerticalDrag>(
                              _VideoVerticalDrag.new,
                              (recognizer) => recognizer
                                ..allow = (position) {
                                  if (_expand.value <= .5) return true;
                                  
                                  final box = _surfaceKey.currentContext!.findRenderObject()! as RenderBox;
                                  
                                  // 控制栏不参加纵向拖动竞争。
                                  return box.globalToLocal(position).dy < box.size.height - insets.bottom - 110;
                                }
                                ..onStart = (_) {
                                  _expand.stop();
                                }
                                ..onUpdate = (details) {
                                  _expand.value = (_expand.value - details.delta.dy / math.max(1, size.height - 100)).clamp(0, 1);
                                }
                                ..onEnd = (details) {
                                  final velocity = details.primaryVelocity ?? 0;
                                  _setExpanded(
                                    velocity.abs() > 500 ? velocity < 0 : _expand.value > .5,
                                  );
                                }
                                ..onCancel = () => _setExpanded(_expanded),
                            ),
                      },
                      child: _PlayerSurface(
                        session: session,
                        expansion: _expand,
                        topInset: insets.top,
                        bottomInset: insets.bottom,
                        onExpand: () => _setExpanded(true),
                        onCollapse: () => _setExpanded(false),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlayerSurface extends StatelessWidget {
  const _PlayerSurface({
    required this.session,
    required this.expansion,
    required this.topInset,
    required this.bottomInset,
    required this.onExpand,
    required this.onCollapse,
  });
  
  final PlaybackSession session;
  final Animation<double> expansion;
  final double topInset, bottomInset;
  final VoidCallback onExpand, onCollapse;

  @override
  Widget build(BuildContext context) {
    final player = session.controller;
    
    Widget picture = Image.asset('assets/cover.png', fit: BoxFit.cover);
    
    if (player != null && player.value.isInitialized) {
      picture = AspectRatio(aspectRatio: player.value.aspectRatio, child: VideoPlayer(player));
    }
    
    return AnimatedBuilder(
      animation: expansion,
      child: Center(child: picture),
      builder: (context, picture) {
        final t = expansion.value;
        final full = t > .5;
        
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.lerp(Alignment.centerLeft, Alignment.center, t)!,
              child: FractionallySizedBox(widthFactor: .32 + .68 * t, child: picture),
            ),
            if (!full)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('mini-player'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onExpand,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        SizedBox(width: constraints.maxWidth * .32 + 10),
                        const Expanded(
                          child: Text(
                            '山海之间',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        _PlaybackButton(session: session),
                        IconButton(
                          tooltip: '关闭播放器',
                          onPressed: session.close,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (full) ...[
              Positioned(
                left: 0,
                right: 0,
                top: topInset,
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('collapse-player'),
                      tooltip: '收起播放器',
                      onPressed: onCollapse,
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    const Expanded(
                      child: Text('山海之间', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: '关闭播放器',
                      onPressed: session.close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (player != null && player.value.isInitialized)
                Positioned.fill(
                  top: topInset + 56,
                  child: _Transport(
                    key: ObjectKey(player),
                    session: session,
                    player: player,
                    bottomInset: bottomInset,
                  ),
                ),
            ],
            if (session.loading) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            if (session.failure != null)
              Center(
                child: FilledButton.icon(
                  onPressed: session.open,
                  icon: const Icon(Icons.refresh),
                  label: Text(session.failure!),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({required this.session, this.size = 28});
  final PlaybackSession session;
  final double size;

  @override
  Widget build(BuildContext context) {
    final player = session.controller;
    
    if (player == null || !player.value.isInitialized) return const SizedBox(width: 48);
    
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) => IconButton(
        key: const ValueKey('toggle-playback'),
        tooltip: value.isPlaying ? '暂停' : '播放',
        onPressed: session.toggle,
        iconSize: size,
        icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
    );
  }
}

class _Transport extends StatefulWidget {
  const _Transport({
    super.key,
    required this.session,
    required this.player,
    required this.bottomInset,
  });
  
  final PlaybackSession session;
  final VideoPlayerController player;
  final double bottomInset;

  @override
  State<_Transport> createState() => _TransportState();
}

class _TransportState extends State<_Transport> {
  Duration? _preview;
  Duration _anchor = Duration.zero;
  double _drag = 0;
  double _doubleTapX = 0;
  int _seekRevision = 0;
  bool _visible = true;
  bool _scrubbing = false;
  bool _sliderCanceled = false;
  Timer? _hide;

  void _show() {
    _hide?.cancel();
    setState(() => _visible = true);
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && _preview == null) setState(() => _visible = false);
    });
  }

  void _previewAt(Duration position) {
    if (widget.player.value.duration <= Duration.zero) return;
    
    ++_seekRevision;
    _hide?.cancel();
    
    final ms = position.inMilliseconds.clamp(0, widget.player.value.duration.inMilliseconds);
    
    setState(() {
      _preview = Duration(milliseconds: ms);
      _visible = true;
    });
  }

  void _cancelScrub() {
    if (!_scrubbing) return;
    
    _scrubbing = false;
    ++_seekRevision;
    
    setState(() => _preview = null);
  }

  Future<void> _commit() async {
    final target = _preview;
    
    if (target == null) return;
    
    final revision = ++_seekRevision;
    
    // 平台完成本次定位调用后再归还进度显示权。
    await widget.session.seek(target);
    
    if (!mounted || revision != _seekRevision) return;
    
    setState(() => _preview = null);
    _show();
  }

  void _jump(int seconds) {
    _previewAt((_preview ?? widget.player.value.position) + Duration(seconds: seconds));
    unawaited(_commit());
  }

  @override
  void dispose() {
    _hide?.cancel();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final canSeek = widget.player.value.duration > Duration.zero;
      
      return Stack(
        children: [
          Positioned.fill(
            bottom: 110 + widget.bottomInset,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_visible) {
                  setState(() => _visible = false);
                } else {
                  _show();
                }
              },
              onDoubleTapDown: (details) => _doubleTapX = details.localPosition.dx,
              onDoubleTap: () => _jump(_doubleTapX < constraints.maxWidth / 2 ? -3 : 3),
              onHorizontalDragStart: !canSeek
                  ? null
                  : (_) {
                      _scrubbing = true;
                      _anchor = _preview ?? widget.player.value.position;
                      _drag = 0;
                      _previewAt(_anchor);
                    },
              onHorizontalDragUpdate: !canSeek
                  ? null
                  : (details) {
                      _drag += details.delta.dx;
                      final total = widget.player.value.duration.inMilliseconds;
                      _previewAt(
                        _anchor +
                            Duration(milliseconds: (_drag / constraints.maxWidth * total).round()),
                      );
                    },
              onHorizontalDragEnd: (_) {
                _scrubbing = false;
                unawaited(_commit());
              },
              onHorizontalDragCancel: _cancelScrub,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: widget.player,
                  builder: (context, value, _) => value.hasError
                      ? const Text('媒体读取失败，请关闭后重试')
                      : value.isBuffering
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : _preview != null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              formatTime(_preview!),
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: widget.bottomInset + 12,
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _visible ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xee101513),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: widget.player,
                    builder: (context, value, _) {
                      final maxMs = math.max(1, value.duration.inMilliseconds);
                      final position = (_preview ?? value.position).inMilliseconds.clamp(0, maxMs);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Listener(
                            onPointerDown: (_) => _sliderCanceled = false,
                            onPointerCancel: (_) {
                              _sliderCanceled = true;
                              _cancelScrub();
                            },
                            child: Slider(
                              value: position.toDouble(),
                              max: maxMs.toDouble(),
                              onChangeStart: value.duration <= Duration.zero
                                  ? null
                                  : (ms) {
                                      _scrubbing = true;
                                      _previewAt(Duration(milliseconds: ms.round()));
                                    },
                              onChanged: value.duration <= Duration.zero
                                  ? null
                                  : (ms) => _previewAt(Duration(milliseconds: ms.round())),
                              onChangeEnd: (_) {
                                if (_sliderCanceled) return;
                                _scrubbing = false;
                                unawaited(_commit());
                              },
                              semanticFormatterCallback: (ms) =>
                                  formatTime(Duration(milliseconds: ms.round())),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: '后退三秒',
                                  onPressed: canSeek ? () => _jump(-3) : null,
                                  icon: const Icon(Icons.fast_rewind_rounded),
                                ),
                                _PlaybackButton(session: widget.session, size: 34),
                                IconButton(
                                  tooltip: '前进三秒',
                                  onPressed: canSeek ? () => _jump(3) : null,
                                  icon: const Icon(Icons.fast_forward_rounded),
                                ),
                                const Spacer(),
                                Text(
                                  '${formatTime(Duration(milliseconds: position))} / ${formatTime(value.duration)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

String formatTime(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

// 保持识别器稳定；只有手指按下的位置决定是否加入竞争。
class _VideoVerticalDrag extends VerticalDragGestureRecognizer {
  bool Function(Offset)? allow;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (allow?.call(event.position) ?? true) && super.isPointerAllowed(event);
}
