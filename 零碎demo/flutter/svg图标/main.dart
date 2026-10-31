import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() {
  runApp(const MorphDemoApp());
}

class MorphDemoApp extends StatelessWidget {
  const MorphDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Morph Icon Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MorphDemoPage(),
    );
  }
}

class MorphDemoPage extends StatefulWidget {
  const MorphDemoPage({super.key});

  @override
  State<MorphDemoPage> createState() => _MorphDemoPageState();
}

class _MorphDemoPageState extends State<MorphDemoPage> {
  bool _isPlaying = false;
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图标 Morph 微交互')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _ActionCard(
                title: _isPlaying ? '正在播放' : '已暂停',
                description: '测试文本测试文本',
                action: MorphToggleButton(
                  value: _isPlaying,
                  onChanged: (value) => setState(() => _isPlaying = value),
                  labelFor: (value) => value ? '暂停播放' : '开始播放',
                  iconBuilder: (motion, color) => CustomPaint(
                    size: const Size.square(32),
                    painter: PointMorphPainter(
                      plan: MorphPlans.playPause,
                      motion: motion,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ActionCard(
                title: _isFavorite ? '已收藏' : '加入收藏',
                description: '测试文本测试文本',
                action: MorphToggleButton(
                  value: _isFavorite,
                  onChanged: (value) => setState(() => _isFavorite = value),
                  labelFor: (value) => value ? '取消收藏' : '加入收藏',
                  iconBuilder: (motion, color) => CustomPaint(
                    size: const Size.square(32),
                    painter: FavoritePainter(motion: motion, color: color),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.action,
  });

  final String title;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(description),
                ],
              ),
            ),
            const SizedBox(width: 12),
            action,
          ],
        ),
      ),
    );
  }
}

typedef MorphIconBuilder = Widget Function(
    RetargetableMotion motion,
    Color color,
    );

class MorphToggleButton extends StatefulWidget {
  const MorphToggleButton({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelFor,
    required this.iconBuilder,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String Function(bool value) labelFor;
  final MorphIconBuilder iconBuilder;

  @override
  State<MorphToggleButton> createState() => _MorphToggleButtonState();
}

class _MorphToggleButtonState extends State<MorphToggleButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final RetargetableMotion _motion;
  bool _wasReducedMotion = false;

  bool get _reducedMotion {
    // Android 的 Remove animations 与 iOS 的 Reduce Motion 不是同一开关。
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    return MediaQuery.disableAnimationsOf(context) || features.reduceMotion;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion = RetargetableMotion(
      vsync: this,
      initialValue: widget.value ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isReducedMotion = _reducedMotion;
    if (isReducedMotion && !_wasReducedMotion) {
      _motion.snapTo(widget.value ? 1 : 0);
    }
    _wasReducedMotion = isReducedMotion;
  }

  @override
  void didUpdateWidget(covariant MorphToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _motion.animateTo(widget.value ? 1 : 0, reduceMotion: _reducedMotion);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();
    if (!mounted) return;

    final isReducedMotion = _reducedMotion;
    if (isReducedMotion) {
      _motion.snapTo(widget.value ? 1 : 0);
    }
    _wasReducedMotion = isReducedMotion;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final label = widget.labelFor(widget.value);

    return Semantics(
      button: true,
      toggled: widget.value,
      label: label,
      onTap: () => widget.onChanged(!widget.value),
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: label,
          onPressed: () => widget.onChanged(!widget.value),
          icon: widget.iconBuilder(_motion, color),
        ),
      ),
    );
  }
}

/// 保存一段可中断动画的当前值，而不是只保存正向或反向两个命令。
class RetargetableMotion extends ChangeNotifier {
  RetargetableMotion({
    required TickerProvider vsync,
    required double initialValue,
    this.duration = const Duration(milliseconds: 260),
  }) : _from = initialValue,
        _to = initialValue {
    _controller = AnimationController(
      vsync: vsync,
      duration: duration,
      value: 1,
      animationBehavior: AnimationBehavior.normal,
    )..addListener(notifyListeners);
  }

  final Duration duration;
  late final AnimationController _controller;
  double _from;
  double _to;

  double get value {
    final t = Curves.easeOutCubic.transform(_controller.value);
    return ui.lerpDouble(_from, _to, t)!;
  }

  void animateTo(double target, {required bool reduceMotion}) {
    // 先取当前的几何帧，反向点击时才不会跳回起点。
    final current = value;
    _controller.stop();
    _from = current;
    _to = target;

    if (reduceMotion) {
      _controller.value = 1;
      notifyListeners();
      return;
    }

    _controller
      ..value = 0
      ..forward();
  }

  void snapTo(double target) {
    _controller.stop();
    _from = target;
    _to = target;
    _controller.value = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class MorphPlan {
  const MorphPlan({required this.fromContours, required this.toContours});

  final List<List<Offset>> fromContours;
  final List<List<Offset>> toContours;
}

class MorphPlans {
  // 真实项目中这份数据由构建期 SVG 编译器生成，而不是手写在组件里。
  static const playPause = MorphPlan(
    fromContours: [
      [Offset(6, 4), Offset(12, 8.5), Offset(12, 15.5), Offset(6, 20)],
      [Offset(12, 8.5), Offset(20, 12), Offset(12, 15.5), Offset(12, 8.5)],
    ],
    toContours: [
      [Offset(7, 5), Offset(10.5, 5), Offset(10.5, 19), Offset(7, 19)],
      [Offset(13.5, 5), Offset(17, 5), Offset(17, 19), Offset(13.5, 19)],
    ],
  );
}

class PointMorphPainter extends CustomPainter {
  PointMorphPainter({
    required this.plan,
    required this.motion,
    required this.color,
  }) : super(repaint: motion);

  final MorphPlan plan;
  final RetargetableMotion motion;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = motion.value;
    final scale = math.min(size.width, size.height) / 24;
    final origin = Offset(
      (size.width - 24 * scale) / 2,
      (size.height - 24 * scale) / 2,
    );
    final path = Path();

    for (
    var contourIndex = 0;
    contourIndex < plan.fromContours.length;
    contourIndex++
    ) {
      final from = plan.fromContours[contourIndex];
      final to = plan.toContours[contourIndex];
      final first = _lerpPoint(from.first, to.first, progress, scale, origin);
      path.moveTo(first.dx, first.dy);

      for (var pointIndex = 1; pointIndex < from.length; pointIndex++) {
        final point = _lerpPoint(
          from[pointIndex],
          to[pointIndex],
          progress,
          scale,
          origin,
        );
        path.lineTo(point.dx, point.dy);
      }
      path.close();
    }

    canvas.drawPath(path, Paint()..color = color);
  }

  Offset _lerpPoint(
      Offset from,
      Offset to,
      double t,
      double scale,
      Offset origin,
      ) {
    return Offset(
      origin.dx + ui.lerpDouble(from.dx, to.dx, t)! * scale,
      origin.dy + ui.lerpDouble(from.dy, to.dy, t)! * scale,
    );
  }

  @override
  bool shouldRepaint(covariant PointMorphPainter oldDelegate) {
    return oldDelegate.plan != plan ||
        oldDelegate.motion != motion ||
        oldDelegate.color != color;
  }
}

class FavoritePainter extends CustomPainter {
  FavoritePainter({required this.motion, required this.color})
      : super(repaint: motion);

  final RetargetableMotion motion;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = motion.value;
    final width = size.width;
    final height = size.height;
    final center = Offset(width / 2, height / 2);
    final pulse = 1 + 0.10 * math.sin(math.pi * progress);

    final heart = Path()
      ..moveTo(width * 0.5, height * 0.84)
      ..cubicTo(
        width * 0.12,
        height * 0.62,
        width * 0.16,
        height * 0.30,
        width * 0.34,
        height * 0.25,
      )
      ..cubicTo(
        width * 0.45,
        height * 0.22,
        width * 0.5,
        height * 0.32,
        width * 0.5,
        height * 0.40,
      )
      ..cubicTo(
        width * 0.5,
        height * 0.32,
        width * 0.55,
        height * 0.22,
        width * 0.66,
        height * 0.25,
      )
      ..cubicTo(
        width * 0.84,
        height * 0.30,
        width * 0.88,
        height * 0.62,
        width * 0.5,
        height * 0.84,
      )
      ..close();

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(pulse)
      ..translate(-center.dx, -center.dy);

    canvas.drawPath(
      heart,
      Paint()
        ..color = color.withValues(alpha: progress)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      heart,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FavoritePainter oldDelegate) {
    return oldDelegate.motion != motion || oldDelegate.color != color;
  }
}
