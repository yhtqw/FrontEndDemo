import 'dart:math';

import 'package:flutter/material.dart';

/// 抽取状态字符串
const String statusMove = 'move';
const String statusScale = 'scale';
/// 新增旋转状态热区字符串
const String statusRotate = 'rotate';

class TransformContainer extends StatefulWidget {
  const TransformContainer({super.key});

  @override
  State<TransformContainer> createState() => _TransformContainerState();
}

class _TransformContainerState extends State<TransformContainer> {
  /// 抽取容器的宽
  final double containerWidth = 300;
  /// 抽取容器的高
  final double containerHeight = 600;
  /// 抽取响应缩放操作区域的大小
  final double scaleWidth = 20;
  final double scaleHeight = 20;
  /// 抽取响应旋转操作区域的大小
  final double rotateWidth = 20;
  final double rotateHeight = 20;
  final double minWidth = 40;
  final double minHeight = 40;

  /// 抽取元素的宽
  double elementWidth = 100;
  /// 抽取元素的高
  double elementHeight = 100;
  double x = 10;
  double y = 10;
  double initX = 10;
  double initY = 10;
  Offset startPosition = Offset(0, 0);
  String? status;
  /// 新增是否使用等比例
  bool useProportional = true;
  double rotateNumber = 0;
  double initRotateNumber = 0;

  void _onPanDown(DragDownDetails details) {
    print('按下: $details');

    String? tempStatus = _onDownZone(details.localPosition.dx, details.localPosition.dy);

    setState(() {
      if (tempStatus == statusMove) {
        startPosition = details.globalPosition;
      } else {
        startPosition = details.localPosition;
      }
      // startPosition = details.localPosition;
      status = tempStatus;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    print('更新: $details');
    if (status == statusMove) {
      _onMove(details.globalPosition.dx, details.globalPosition.dy);
    } else if (status == statusScale) {
      _onScale(details.delta.dx, details.delta.dy);
    } else if (status == statusRotate) {
      _onRotate(details.localPosition.dx, details.localPosition.dy);
    }
  }

  void _onPanEnd() {
    print('抬起或者因为某些原因并没有触发onPanDown事件');
    setState(() {
      // 当次结束后重新记录，也可以在按下时记录
      initX = x;
      initY = y;
      initRotateNumber = rotateNumber;
    });
  }

  /// 处理移动
  void _onMove(double dx, double dy) {
    setState(() {
      // 计算方法
      x = initX + dx - startPosition.dx;
      y = initY + dy - startPosition.dy;

      // 限制左边界
      if (x < 0) {
        x = 0;
      }
      // 限制右边界
      if (x > containerWidth - elementWidth) {
        x = containerWidth - elementWidth;
      }
      // 限制上边界
      if (y < 0) {
        y = 0;
      }
      // 限制下边界
      if (y > containerHeight - elementHeight) {
        y = containerHeight - elementHeight;
      }
    });
  }

  /// 处理旋转
  void _onRotate(double dx, double dy) {
    /// 要计算点 (x, y) 与任意点 (x', y') 连线所成的角度，可以使用 arctan2 函数。
    /// 关键在于将两点之间的相对坐标差作为 arctan2 的输入参数。
    /// 这里我们以元素的中心为旋转中心
    /// 利用上述方法计算起始点（按下时）与中心的连线组成的夹角为初始夹角，
    /// 拖动的点与中心点连线组层的夹角为结束时的夹角，
    /// 通过初始夹角与结束夹角计算旋转的角度

    // 确定旋转中心，因为这里的拖动是单个元素，坐标都是相对于元素自身形成的坐标系，所以坐标中心始终都是元素的中心
    double centerX = elementWidth / 2;
    double centerY = elementHeight / 2;

    double diffStartX = startPosition.dx - centerX;
    double diffStartY = startPosition.dy - centerY;
    double diffEndX = dx - centerX;
    double diffEndY = dy - centerY;
    double angleStart = atan2(diffStartY, diffStartX);
    double angleEnd = atan2(diffEndY, diffEndX);

    setState(() {
      rotateNumber = initRotateNumber + angleEnd - angleStart;
    });
  }

  /// 处理缩放
  void _onScale(double dx, double dy) {
    // 加上双倍的变换值
    double tempWidth = elementWidth + dx * 2;

    // 限制边界值
    tempWidth = tempWidth.clamp(minWidth, containerWidth);
    // if (tempWidth < minWidth) {
    //   tempWidth = minWidth;
    // } else if (tempWidth > containerWidth) {
    //   tempWidth = containerWidth;
    // }

    if (useProportional) {
      double tempHeight = elementHeight * (tempWidth / elementWidth);
      setState(() {
        x -= (tempWidth - elementWidth) / 2;
        y -= (tempHeight - elementHeight) / 2;
        elementHeight = tempHeight;
        elementWidth = tempWidth;
      });
    } else {
      // 非等比缩放直接应用变化
      setState(() {
        elementHeight += dy * 2;
        elementWidth = tempWidth;
        x -= dx;
        y -= dy;
      });
    }
  }

  /// 判断点击在什么区域
  String? _onDownZone(double x, double y) {
    final offsetScale = rotatePoint(elementWidth, elementHeight);
    final offsetRotate = rotatePoint(elementWidth, rotateHeight);

    if (
      x >= offsetScale.dx - scaleWidth &&
      x <= offsetScale.dx &&
      y >= offsetScale.dy - scaleHeight &&
      y <= offsetScale.dy
    ) {
      return statusScale;
    } else if (
      x >= offsetRotate.dx - rotateHeight &&
      x <= offsetRotate.dx &&
      y >= offsetRotate.dy - rotateHeight &&
      y <= offsetRotate.dy
    ) {
      return statusRotate;
    } else if (
      x >= 0 &&
      x <= elementWidth &&
      y >= 0 &&
      y <= elementHeight
    ) {
      return statusMove;
    }

    return null;
  }

  Offset rotatePoint(double x, double y) {
    final deg = rotateNumber * pi / 180;
    // 确定旋转中心，因为这里的拖动是单个元素，坐标都是相对于元素自身形成的坐标系，所以坐标中心始终都是元素的中心
    final centerX = elementWidth / 2;
    final centerY = elementHeight / 2;
    final diffX = x - centerX;
    final diffY = y - centerY;

    final dx = diffX * cos(deg) - diffY * sin(deg) + centerX;
    final dy = diffX * sin(deg) + diffY * cos(deg) + centerY;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: containerWidth,
      height: containerHeight,
      color: Colors.blueAccent,
      child: Stack(
        children: [
          Positioned(
            left: x,
            top: y,
            child: Transform.rotate(
              angle: rotateNumber,
              child: GestureDetector(
                onPanDown: _onPanDown,
                onPanUpdate: _onPanUpdate,
                onPanEnd: (details) => _onPanEnd(),
                onPanCancel: _onPanEnd,
                child: Container(
                  width: elementWidth,
                  height: elementHeight,
                  color: Colors.transparent,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: elementWidth,
                        height: elementHeight,
                        color: Colors.amber,
                      ),

                      // 响应旋转操作
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: scaleWidth,
                          height: scaleHeight,
                          color: Colors.white,
                        ),
                      ),

                      // 响应缩放操作
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: scaleWidth,
                          height: scaleHeight,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
