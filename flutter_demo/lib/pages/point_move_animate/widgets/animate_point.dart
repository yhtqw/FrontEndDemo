import 'dart:math';

import 'package:flutter/material.dart';

class AnimatePoint extends StatefulWidget {
  const AnimatePoint({
    super.key,
    required this.startPoint,
    required this.endPoint,
    this.topCurve = Curves.easeIn,
    this.leftCurve = Curves.easeOut,
    this.animateTime = 2000,
    required this.onCompleted,
    required this.delay,
  });

  /// 初始坐标点
  final Offset startPoint;
  /// 结束坐标点
  final Offset endPoint;
  /// top值变化曲线
  final Curve topCurve;
  /// left值变化曲线
  final Curve leftCurve;
  /// 动画总时长
  final int animateTime;
  /// 动画完成后的执行的方法
  final Function() onCompleted;
  /// 动画元素的间隔时间
  final Duration delay;

  @override
  State<AnimatePoint> createState() => _AnimatePointState();
}

class _AnimatePointState extends State<AnimatePoint> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Offset _controlPoint;
  // 阶段1：散开的终点
  late Offset _pMid;

  // 定义阶段占比
  final double burstEnd = 0.4; // 前 40% 时间用于爆开
  final double _baseScale = 1.4;
  final double _animateEnd = 0.9;
  final double _radius = 40.0;
  final int _controlRandom = 400;

  @override
  void initState() {
    _controller = AnimationController(
      duration: Duration(
        milliseconds: widget.animateTime,
      ),
      vsync: this,
    );

    // 1. 计算第一阶段散开点 (在起点周围随机半径 40-80 的圆内)
    final double angle = Random().nextDouble() * 2 * pi;
    final double radius = _radius + Random().nextDouble() * _radius;
    _pMid = widget.startPoint + Offset(cos(angle) * radius, sin(angle) * radius);

    // 计算控制点：在起点和终点连线的中点上方偏移
    // 你可以给偏移量加点 Random()，让每个金币飞出的弧度都不一样
    _controlPoint = Offset(
      (widget.startPoint.dx + widget.endPoint.dx) / 2
          + (_pMid.dx >= widget.startPoint.dx ? Random().nextInt(_controlRandom) : -Random().nextInt(_controlRandom)),
      (widget.startPoint.dy + widget.endPoint.dy) / 2
          + (_pMid.dx >= widget.startPoint.dx ? -Random().nextInt(_controlRandom) : Random().nextInt(_controlRandom)),
    );

    _controller.forward().then((_) => widget.onCompleted());
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  Offset _calculateBezierPath(double t, Offset p0, Offset p1, Offset p2) {
    // 根据公式计算每一帧的坐标
    double x = pow(1 - t, 2) * p0.dx + 2 * t * (1 - t) * p1.dx + pow(t, 2) * p2.dx;
    double y = pow(1 - t, 2) * p0.dy + 2 * t * (1 - t) * p1.dy + pow(t, 2) * p2.dy;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        double t = _controller.value;
        Offset currentPos;
        double currentAlpha = 1.0;
        double scale = _baseScale;

        // 计算当前金币在第二阶段开始的延迟比例 (基于传入的 delay 换算)
        double flyStart = burstEnd + (widget.delay.inMilliseconds / widget.animateTime);

        if (t <= burstEnd) {
          // --- 第一阶段：同步爆开 (0.0 -> burstEnd) ---
          double subT = t / burstEnd;
          // 使用 easeOutBack 产生爆发回弹感
          double curvedT = Curves.easeOutBack.transform(subT);
          currentPos = Offset.lerp(widget.startPoint, _pMid, curvedT)!;
          currentAlpha = curvedT; // 0 -> 1
        } else if (t < flyStart) {
          // // --- 中间停顿阶段：悬浮在散开点等待起飞 ---
          currentPos = _pMid;
        } else if (t < _animateEnd) {
          // --- 第二阶段：异步吸入 (flyStart -> _animateEnd) ---
          double subT = (t - flyStart) / (_animateEnd - flyStart);
          double curvedT = Curves.easeOutQuart.transform(subT);
          currentPos = _calculateBezierPath(curvedT, _pMid, _controlPoint, widget.endPoint);
        } else {
          // --- 最后阶段收尾
          currentPos = widget.endPoint;
          double subT = (t - _animateEnd) / 0.1;
          currentAlpha = 1.0 - subT;
          scale = (1.0 - subT) * _baseScale;
        }

        return Positioned(
          top: currentPos.dy,
          left: currentPos.dx,
          child: Transform.scale(
            scale: scale.clamp(0.0, _baseScale),
            alignment: Alignment.center,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: currentAlpha.clamp(0.0, 1.0)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      }
    );
  }
}
