import 'dart:math' as math;

import 'package:flutter/material.dart';

class PathGuideShaderMask extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final double borderRadius;
  final List<Color> gradientColors;
  final Duration duration;

  const PathGuideShaderMask({
    super.key,
    required this.child,
    this.borderWidth = 4.0,
    this.borderRadius = 16.0,
    // 默认给个炫酷的极光色
    this.gradientColors = const [
      Colors.transparent,
      Colors.cyan,
      Colors.purple,
      Colors.transparent
    ],
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<PathGuideShaderMask> createState() => _PathGuideShaderMaskState();
}

class _PathGuideShaderMaskState extends State<PathGuideShaderMask> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 创建一个无限重复的动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration
    )..repeat(); // 无限循环
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 第一层：流光边框层（只用 ShaderMask）
          // 这一层的大小应该稍微大一点，包裹住内容
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return ShaderMask(
                  // 混合模式设为 srcIn：只在 child 有像素的地方显示 Shader
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (Rect bounds) {
                    return SweepGradient(
                      center: Alignment.center,
                      // 这里的颜色决定了流光的长短和颜色
                      colors: const [
                        Colors.transparent,
                        Colors.blueAccent,
                        Colors.purpleAccent,
                        Colors.transparent
                      ],
                      stops: const [0.0, 0.1, 0.3, 0.4],
                      transform: GradientRotation(_controller.value * 2 * math.pi),
                    ).createShader(bounds);
                  },
                  // 【核心细节】：这个 child 必须是空心的边框！
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: Border.all(
                        color: Colors.white, // 这里颜色无所谓，但必须有颜色，Shader 才能附着
                        width: widget.borderWidth,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 第二层：真正的业务组件
          // 我们用 Padding 缩进去，确保不被边框压住
          Padding(
            padding: EdgeInsets.all(widget.borderWidth),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
