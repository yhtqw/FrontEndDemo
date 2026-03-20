import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// 边框路径动画包装器封装
class PathGuideWrapper extends StatefulWidget {
  // 要包裹的子组件
  final Widget child;
  // 路径颜色
  final Color color;
  // 路径宽度
  final double strokeWidth;
  // 动画时长
  final Duration duration;
  // 圆角属性
  final double borderRadius;
  // 拖尾占总长度比例 (0.0 ~ 1.0)
  final double trailLengthPercent;
  // 是否开启动画
  final bool animate;

  const PathGuideWrapper({
    super.key,
    required this.child,
    this.color = Colors.blue,
    this.strokeWidth = 2.0,
    this.duration = const Duration(seconds: 3),
    this.borderRadius = 12.0,
    this.trailLengthPercent = 0.2,
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
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(PathGuideWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果动画开关变化，则重新执行/暂停动画
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
    // 【性能优化】隔离重绘区域
    return RepaintBoundary(
      child: CustomPaint(
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

  _PathGuidePainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.trailPercent,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 构建路径
    final Rect rect = Offset.zero & size;

    // 稍微向外偏移半个线宽，防止压到子组件边缘
    final RRect rRect = RRect.fromRectAndRadius(
      rect.inflate(strokeWidth / 2),
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rRect);
    final PathMetric metric = path.computeMetrics().first;
    final double totalLength = metric.length;
    final double trailLength = totalLength * trailPercent;
    final double currentPos = totalLength * animation.value;

    // 计算截取区间：始终保持一段完整的、不间断的 Path
    // 如果 start < 0，我们通过逻辑偏移，从“模拟的第二圈”截取
    double drawStart = currentPos - trailLength;
    double drawEnd = currentPos;

    // 核心技巧：如果是跨起点阶段，我们将区间平移到 totalLength 之后
    // 这样在绘制时，它是一段连续的、没有物理断裂的 Path
    late Path extractPath;
    if (drawStart < 0) {
      // 关键：合并末尾和开头。
      // 我们先取末尾那一段，再连接上开头那一段，形成一个“组合路径”
      extractPath = metric.extractPath(totalLength + drawStart, totalLength);
      // forceExtract: true 保证了路径的连续性，不产生 MoveTo 跳跃
      extractPath.addPath(metric.extractPath(0, drawEnd), Offset.zero);
    } else {
      extractPath = metric.extractPath(drawStart, drawEnd);
    }

    final Paint trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    // 动态 Shader
    trailPaint.shader = SweepGradient(
      colors: [color.withValues(alpha: 0), color],
      stops: const [0.0, 1.0],
      transform: GradientRotation(
        2 * math.pi * animation.value - math.pi / 2
      ),
    ).createShader(rect);

    canvas.drawPath(extractPath, trailPaint);

    final Tangent? tangent = metric.getTangentForOffset(currentPos);
    if (tangent != null) {
      _drawHead(canvas, tangent);
    }
  }

  void _drawHead(Canvas canvas, Tangent tangent) {
    final Paint headPaint = Paint()..color = color;

    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(-tangent.angle);

    // 绘制指示点或三角形
    final Path triangle = Path()
      ..moveTo(strokeWidth * 2, 0)
      ..lineTo(-strokeWidth, strokeWidth * 1.5)
      ..lineTo(-strokeWidth, -strokeWidth * 1.5)
      ..close();

    // 添加核心发光
    canvas.drawCircle(
      Offset.zero,
      strokeWidth * 2,
      headPaint
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          strokeWidth
        ),
    );
    canvas.drawPath(
      triangle,
      Paint()
        ..color = Colors.white
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PathGuidePainter oldDelegate) => false;
}