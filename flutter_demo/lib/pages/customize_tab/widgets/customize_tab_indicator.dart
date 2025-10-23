import 'package:flutter/material.dart';

class CustomizeTabIndicator extends Decoration {
  const CustomizeTabIndicator({
    required this.color,
    this.radius = BorderRadius.zero,
  });

  /// 指示器颜色
  final Color color;
  /// 指示器的圆角属性
  final BorderRadius radius;

  // 需要重写绘制方法
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _RoundedPainter(this, onChanged);
}

// 自定义绘制方法
class _RoundedPainter extends BoxPainter {
  _RoundedPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  final CustomizeTabIndicator decoration;

  // 重写绘制的方法，这个方法会传给我们绘制区域的信息
  // 我们利用这些信息就可以实现自定义的绘制
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    // 获取绘制区域的大小，整个变换过程中都会更新
    double width = configuration.size!.width;
    double height = configuration.size!.height;
    // 获取绘制区域的偏移量（距离最边上的距离）
    Offset baseOffset = Offset(offset.dx, offset.dy,);

    // 设置要绘制的圆角矩形
    final RRect indicatorRRect = _buildRRect(
      baseOffset,
      width,
      height,
    );
    // 设置画笔属性
    final Paint paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.fill;

    // 绘制圆角矩形
    canvas.drawRRect(indicatorRRect, paint);
  }

  /// 绘制圆角指示器
  RRect _buildRRect(
    Offset offset,
    double width,
    double height,
  ) {
    return RRect.fromRectAndCorners(
      // 圆角矩形的绘制中心
      Rect.fromCenter(
        center: Offset(
          offset.dx + width / 2,
          offset.dy + height / 2,
        ),
        width: width,
        height: height,
      ),
      topLeft: decoration.radius.topLeft,
      topRight: decoration.radius.topRight,
      bottomRight: decoration.radius.bottomRight,
      bottomLeft: decoration.radius.bottomLeft,
    );
  }
}