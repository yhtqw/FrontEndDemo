import 'package:flutter/material.dart';

import 'configs/constants_config.dart';

/// 绘制网格线
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double gridSize = ConstantsConfig.gridSize;
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    // 绘制垂直线
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 绘制水平线
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}