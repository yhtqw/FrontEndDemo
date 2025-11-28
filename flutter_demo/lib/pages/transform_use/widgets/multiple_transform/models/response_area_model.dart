import 'dart:ui';

import 'element_model.dart';

typedef AreaFunction = ElementModel Function({
  /// 点击的坐标
  required Offset tapPoint,
  /// 选中的元素
  required ElementModel element,
  /// 容器的宽度
  required double containerWidth,
  /// 容器的高度
  required double containerHeight,
  /// 移动的坐标
  Offset? movePoint,
});

enum TriggerMethod {
  move,
  down,;
}

class ResponseAreaModel {
  const ResponseAreaModel({
    required this.areaWidth,
    required this.areaHeight,
    required this.xRatio,
    required this.yRatio,
    required this.status,
    required this.icon,
    required this.trigger,
    this.fn,
    this.iconConfig,
  });

  /// 响应区域的宽
  final double areaWidth;
  /// 响应区域的高
  final double areaHeight;
  /// 响应区域的比例横向
  final double xRatio;
  /// 响应区域的比例竖向
  final double yRatio;
  /// 响应区域应该响应什么操作
  final String status;
  /// 响应区域的icon
  final String icon;
  /// 当前响应操作的触发方式
  final TriggerMethod trigger;
  /// 自定义区域可响应执行的方法
  // final Function({required double x, required double y})? fn;
  final AreaFunction? fn;
  /// 元素类型不同展示不同的操作icon
  final Map<String, String>? iconConfig;

  ResponseAreaModel copyWith({
    double? areaWidth,
    double? areaHeight,
    double? xRatio,
    double? yRatio,
    String? icon,
    // Function({required double x, required double y})? fn,
    AreaFunction? fn,
    Map<String, String>? iconConfig,
  }) {
    return ResponseAreaModel(
      areaWidth: areaWidth ?? this.areaWidth,
      areaHeight: areaHeight ?? this.areaHeight,
      xRatio: xRatio ?? this.xRatio,
      yRatio: yRatio ?? this.yRatio,
      status: status,
      icon: icon ?? this.icon,
      trigger: trigger,
      fn: fn ?? this.fn,
      iconConfig: iconConfig ?? this.iconConfig,
    );
  }
}

class CustomAreaConfig {
  const CustomAreaConfig({
    required this.status,
    this.use,
    this.xRatio,
    this.yRatio,
    this.trigger = TriggerMethod.down,
    this.icon,
    this.fn,
    this.iconConfig,
  });

  /// 区域的操作状态字符串，可以是内置的，如果是内置的就覆盖内置的属性
  final String status;
  /// 是否启用
  final bool? use;
  /// 自定义位置
  final double? xRatio;
  final double? yRatio;
  /// 区域响应操作的触发方式
  final TriggerMethod trigger;
  /// 自定义区域就是必传
  final String? icon;
  /// 自定义区域就是必传，点击对应的响应区域就执行自定义的方法
  final AreaFunction? fn;
  /// 元素类型不同展示不同的操作icon
  final Map<String, String>? iconConfig;
}
