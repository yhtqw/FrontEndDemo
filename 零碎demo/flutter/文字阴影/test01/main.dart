import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const ShadowApp());

const _blur = int.fromEnvironment('BLUR', defaultValue: 4);
const _shadow = bool.fromEnvironment('SHADOW', defaultValue: true);
const _isolate = bool.fromEnvironment('ISOLATE');
const _slow = bool.fromEnvironment('SLOW');
const _empty = bool.fromEnvironment('EMPTY');

class ShadowApp extends StatelessWidget {
  const ShadowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const ShadowScene(),
  );
}

class ShadowScene extends StatefulWidget {
  const ShadowScene({
    super.key,
    this.blur = _blur,
    this.shadow = _shadow,
    this.isolate = _isolate,
    this.slow = _slow,
    this.empty = _empty,
  });

  final int blur;
  final bool shadow;
  final bool isolate;
  final bool slow;
  final bool empty;

  @override
  State<ShadowScene> createState() => _ShadowSceneState();
}

class _ShadowSceneState extends State<ShadowScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  Duration _elapsedBeforeRun = Duration.zero;
  int _frames = 0;
  final _score = ValueNotifier<int>(0);
  bool _paused = false;
  bool _foreground = true;

  Duration get _elapsed =>
      _elapsedBeforeRun + (_clock.lastElapsedDuration ?? Duration.zero);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(_tick);
    _clock.repeat();
  }

  void _tick() {
    // 慢更新只改变文字频率，背景仍由同一个时钟驱动。
    if (widget.empty) return;
    final next = widget.slow ? _elapsed.inSeconds : ++_frames;
    _score.value = next;
  }

  void _syncClock() {
    final shouldRun = !_paused && _foreground;
    if (shouldRun && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!shouldRun && _clock.isAnimating) {
      _elapsedBeforeRun = _elapsed;
      _clock.stop();
    }
  }

  void _toggle() {
    setState(() => _paused = !_paused);
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    _score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadows = widget.shadow
        ? <Shadow>[
            Shadow(
              color: const Color(0xFF47E6D0),
              offset: const Offset(0, 2),
              blurRadius: math.max(0, widget.blur).toDouble(),
            ),
          ]
        : const <Shadow>[];

    final title = Text(
      'ORBIT RUN',
      key: const ValueKey('title'),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFE9FFF9),
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: 5,
        shadows: shadows,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF08111E),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: SizedBox.expand(
          child: widget.empty
              ? CustomPaint(
                  key: const ValueKey('empty'),
                  painter: _EmptyPainter(_clock),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _OrbitPainter(_clock)),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(widget.slow ? '1 Hz' : 'FRAME'),
                                Text(_paused ? 'PAUSED' : 'LIVE'),
                              ],
                            ),
                            const Spacer(flex: 3),
                            // 隔离的是静态标题，不是整个游戏画面。
                            if (widget.isolate)
                              RepaintBoundary(
                                key: const ValueKey('title-boundary'),
                                child: title,
                              )
                            else
                              title,
                            const SizedBox(height: 24),
                            ValueListenableBuilder<int>(
                              valueListenable: _score,
                              builder: (context, value, child) => Text(
                                value.toString().padLeft(6, '0'),
                                key: const ValueKey('score'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 64,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  shadows: shadows,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'SCORE',
                              style: TextStyle(
                                color: Color(0xFF8A9FB8),
                                letterSpacing: 4,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(flex: 4),
                            Text(
                              '${widget.shadow ? 'BLUR ${widget.blur.toStringAsFixed(0)}' : 'NO SHADOW'}'
                              '  /  ${widget.isolate ? 'ISOLATED' : 'SHARED'}',
                              style: const TextStyle(
                                color: Color(0xFF8A9FB8),
                                fontSize: 11,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .45);
    final radius = size.shortestSide * .58;
    final ring = Paint()
      ..color = const Color(0xFF1B3046)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [.68, 1.0, 1.32]) {
      canvas.drawCircle(center, radius * scale, ring);
    }
    final angle = clock.value * math.pi * 2;
    final dot = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawLine(
      Offset(0, dot.dy),
      Offset(size.width, dot.dy),
      Paint()..color = const Color(0xFF183A43),
    );
    canvas.drawCircle(dot, 5, Paint()..color = const Color(0xFF47E6D0));
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.clock != clock;
}

class _EmptyPainter extends CustomPainter {
  _EmptyPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    // 持续请求绘制，但不画可见图元；不是停止出帧。
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-clock.value, 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmptyPainter oldDelegate) =>
      oldDelegate.clock != clock;
}
