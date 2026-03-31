import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PathGuideWrapper extends StatefulWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final Duration duration;
  final double borderRadius;
  final double trailLengthPercent;
  final bool animate;

  const PathGuideWrapper({
    super.key,
    required this.child,
    this.color = Colors.blue,
    this.strokeWidth = 3.0,
    this.duration = const Duration(seconds: 3),
    this.borderRadius = 12.0,
    this.trailLengthPercent = 0.3,
    this.animate = true,
  });

  @override
  State<PathGuideWrapper> createState() => _PathGuideWrapperState();
}

class _PathGuideWrapperState extends State<PathGuideWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(PathGuideWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      widget.animate ? _controller.repeat() : _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        // 使用 foregroundPainter 确保在子组件之上
        foregroundPainter: _PathGuidePainter(
          animation: _controller,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
          radius: widget.borderRadius,
          trailPercent: widget.trailLengthPercent,
        ),
        child: widget.child,
      ),
    );
  }
}

class _PathGuidePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final double strokeWidth;
  final double radius;
  final double trailPercent;

  // 【优化 1】缓存所有的 Paint 对象，杜绝在 paint 方法中每帧分配内存
  final Paint _trailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _headPaint = Paint();
  final Paint _whitePaint = Paint()..color = Colors.white;

  // 【优化 2】缓存几何路径与测量数据。Size 不变，路径就不重算！
  Size? _cachedSize;
  late Path _cachedPath;
  late ui.PathMetric _cachedMetric;
  late double _totalLength;
  late Rect _cachedRect;

  _PathGuidePainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.trailPercent,
  }) : super(repaint: animation) {
    // 初始化固定的画笔属性
    _trailPaint.strokeWidth = strokeWidth;
    _trailPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.5);
  }

  /// 检查并更新缓存
  void _updateCache(Size size) {
    if (_cachedSize == size) return; // 尺寸未变，直接跳过几何运算
    _cachedSize = size;

    // 向外偏移半个线宽
    _cachedRect = (Offset.zero & size).inflate(strokeWidth / 2);
    final RRect rRect = RRect.fromRectAndRadius(_cachedRect, Radius.circular(radius));

    _cachedPath = Path()..addRRect(rRect);
    // computeMetrics 非常耗时，现在只在 Size 变化时执行 1 次
    _cachedMetric = _cachedPath.computeMetrics().first;
    _totalLength = _cachedMetric.length;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 触发缓存校验
    _updateCache(size);

    final double trailLength = _totalLength * trailPercent;
    final double currentPos = _totalLength * animation.value;

    Path extractPath = Path();
    double start = currentPos - trailLength;
    if (start < 0) {
      extractPath.addPath(_cachedMetric.extractPath(_totalLength + start, _totalLength), Offset.zero);
      extractPath.addPath(_cachedMetric.extractPath(0, currentPos), Offset.zero);
    } else {
      extractPath = _cachedMetric.extractPath(start, currentPos);
    }

    // 【优化 3】使用底层的 ui.Gradient 结合 Float64List 矩阵旋转
    // 计算渐变旋转角，并增加 trailPercent * pi 补偿视觉误差
    final double rotation = (2 * math.pi * animation.value) - (math.pi / 2) - (trailPercent * math.pi);

    // 构建高效的变换矩阵，将渐变中心移至矩形中心并旋转
    final Float64List matrix4 = (Matrix4.identity()
      ..translateByDouble(_cachedRect.center.dx, _cachedRect.center.dy, 0, 1)
      ..rotateZ(rotation)
      ..translateByDouble(-_cachedRect.center.dx, -_cachedRect.center.dy, 0, 1)
    ).storage;

    // 直接生成底层 Shader，比 Flutter 层的 SweepGradient 轻量
    _trailPaint.shader = ui.Gradient.sweep(
      _cachedRect.center,
      [color.withAlpha(0), color],
      [0.0, 1.0],
      TileMode.clamp,
      0.0,
      math.pi * 2,
      matrix4,
    );

    canvas.drawPath(extractPath, _trailPaint);

    // 绘制指示头
    final ui.Tangent? tangent = _cachedMetric.getTangentForOffset(currentPos);
    if (tangent != null) {
      _drawHead(canvas, tangent);
    }
  }

  void _drawHead(Canvas canvas, ui.Tangent tangent) {
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(-tangent.angle);

    _headPaint.color = color;
    _headPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth);
    canvas.drawCircle(Offset.zero, strokeWidth * 1.5, _headPaint);

    final Path triangle = Path()
      ..moveTo(strokeWidth * 2, 0)
      ..lineTo(-strokeWidth, strokeWidth * 1.2)
      ..lineTo(-strokeWidth, -strokeWidth * 1.2)
      ..close();

    canvas.drawPath(triangle, _whitePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PathGuidePainter oldDelegate) => true;
}