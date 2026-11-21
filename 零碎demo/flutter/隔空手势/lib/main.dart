import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'gesture_engine.dart';
import 'vision_camera.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: GesturePage()),
  );
}

class GesturePage extends StatefulWidget {
  const GesturePage({super.key});
  @override
  State<GesturePage> createState() => _GesturePageState();
}

class _GesturePageState extends State<GesturePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _engine = GestureEngine();
  final _scale = ValueNotifier(1.0);
  late final VisionCamera _vision;
  late final Ticker _ticker;
  late final AnimationController _cardAnimation;
  Duration? _previousTick;
  int _lastResult = -1, _epoch = -1;
  int _index = 0, _previousIndex = 0, _direction = -1;
  bool _active = false, _stale = true;
  GestureMode _mode = GestureMode.image;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vision = VisionCamera()..addListener(_onVision);
    _cardAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    _ticker = createTicker(_tick)..start();
    unawaited(_vision.setEnabled(true));
  }

  void _onVision() {
    if (!mounted) return;
    if (_epoch != _vision.trackingEpoch) {
      _epoch = _vision.trackingEpoch;
      _engine.reset();
    }
    if (_vision.resultMs != _lastResult) {
      _lastResult = _vision.resultMs;
      _stale = false;
      final hand = _vision.hand;
      final result = hand == null
          ? _engine.noHand(_vision.resultMs)
          : _engine.update(hand);
      _active = result.active;
      if (result.swipe != 0 && !_cardAnimation.isAnimating) {
        final next = (_index - result.swipe).clamp(0, 2);
        if (next != _index) {
          _previousIndex = _index;
          _index = next;
          _direction = result.swipe;
          _cardAnimation.forward(from: 0);
        }
      }
    }
    setState(() {});
  }

  void _tick(Duration elapsed) {
    final previous = _previousTick;
    _previousTick = elapsed;
    if (previous == null) return;
    if (_vision.nowMs - _vision.resultMs > 250) {
      _engine.noHand(_vision.nowMs);
      if (!_stale) {
        setState(() {
          _active = false;
          _stale = true;
        });
      }
    }
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    final alpha = 1 - math.exp(-dt / 0.07);
    final next = _scale.value + alpha * (_engine.targetScale - _scale.value);
    if ((next - _scale.value).abs() > 0.0001) _scale.value = next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _engine.reset();
    _active = false;
    unawaited(_vision.setEnabled(state == AppLifecycleState.resumed));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vision.removeListener(_onVision);
    _ticker.dispose();
    _cardAnimation.dispose();
    _scale.dispose();
    unawaited(_vision.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('隔空手势'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() {
            _engine.reset(keepScale: false);
            _index = _previousIndex = 0;
            _cardAnimation.value = 1;
          }),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            SegmentedButton<GestureMode>(
              segments: const [
                ButtonSegment(value: GestureMode.image, label: Text('图片缩放')),
                ButtonSegment(value: GestureMode.cards, label: Text('挥手切卡')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() {
                _mode = selection.first;
                _engine.setMode(_mode);
                _active = false;
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: const Color(0xffedf4f1),
                  child: Center(
                    child: _mode == GestureMode.image
                        ? ValueListenableBuilder<double>(
                            valueListenable: _scale,
                            child: Image.asset(
                              'assets/demo.png',
                              fit: BoxFit.contain,
                            ),
                            builder: (_, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                          )
                        : AnimatedBuilder(
                            animation: _cardAnimation,
                            builder: (_, _) => LayoutBuilder(
                              builder: (_, bounds) {
                                final t = Curves.easeOutCubic.transform(
                                  _cardAnimation.value,
                                );
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (t < 1)
                                      Transform.translate(
                                        offset: Offset(
                                          _direction * bounds.maxWidth * t,
                                          0,
                                        ),
                                        child: DemoCard(index: _previousIndex),
                                      ),
                                    Transform.translate(
                                      offset: Offset(
                                        _direction * bounds.maxWidth * (t - 1),
                                        0,
                                      ),
                                      child: DemoCard(index: _index),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _preview(),
              ),
            ),
            const SizedBox(height: 10),
            Text(_active ? '正在控制' : '将一只手放入画面，停稳后开始'),
          ],
        ),
      ),
    ),
  );

  Widget _preview() {
    final camera = _vision.controller;
    if (_vision.error != null) {
      return ColoredBox(
        color: const Color(0xffedf4f1),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '无法启动相机或识别器，请检查权限与模型资源。',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              TextButton(
                onPressed: () => _vision.setEnabled(true),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_vision.ready || camera == null) {
      return const ColoredBox(
        color: Color(0xffedf4f1),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _vision.imageSize.width,
            height: _vision.imageSize.height,
            child: CameraPreview(camera),
          ),
        ),
        CustomPaint(
          painter: HandPainter(
            _vision.nowMs - _vision.resultMs <= 250
                ? _vision.hand?.points ?? []
                : [],
            _vision.imageSize,
          ),
        ),
      ],
    );
  }
}

class DemoCard extends StatelessWidget {
  const DemoCard({required this.index, super.key});
  final int index;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: [
      const Color(0xffd4eee6),
      const Color(0xffdbe6fb),
      const Color(0xffffe1c6),
    ][index],
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon([Icons.park, Icons.water, Icons.wb_sunny][index], size: 96),
        const SizedBox(height: 20),
        Text(['山间', '湖边', '晴天'][index], style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('${index + 1} / 3'),
      ],
    ),
  );
}

class HandPainter extends CustomPainter {
  HandPainter(this.points, this.imageSize);
  final List<Offset> points;
  final Size imageSize;
  static const _chains = [
    [0, 1, 2, 3, 4],
    [0, 5, 6, 7, 8],
    [5, 9, 10, 11, 12],
    [9, 13, 14, 15, 16],
    [13, 17, 18, 19, 20],
    [0, 17],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final k = math.max(
      size.width / imageSize.width,
      size.height / imageSize.height,
    );
    final offset = Offset(
      (size.width - k * imageSize.width) / 2,
      (size.height - k * imageSize.height) / 2,
    );
    final paint = Paint()
      ..color = const Color(0xff54f2c5)
      ..strokeWidth = 2;
    final mapped = points.map((p) => p * k + offset).toList();
    if (mapped.length != 21) return;
    for (final chain in _chains) {
      for (var i = 1; i < chain.length; i++) {
        canvas.drawLine(mapped[chain[i - 1]], mapped[chain[i]], paint);
      }
    }
    for (final point in mapped) {
      canvas.drawCircle(point, 3, paint);
    }
  }

  @override
  bool shouldRepaint(HandPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.imageSize != imageSize;
}
