import 'package:flutter/material.dart';

import '../configs/constants_config.dart';
import '../utils/transform_utils.dart';
import 'response_area_model.dart';

enum ElementType {
  /// 图片
  imageType(type: 'image'),
  /// 文本
  textType(type: 'text'),;

  final String type;
  const ElementType({required this.type});
}

enum TextAlignType {
  left(type: 'left', textAlign: TextAlign.left),
  right(type: 'right', textAlign: TextAlign.right),
  center(type: 'center', textAlign: TextAlign.center),
  justify(type: 'justify', textAlign: TextAlign.justify),
  ;

  final String type;
  final TextAlign textAlign;
  const TextAlignType({
    required this.type,
    required this.textAlign,
  });
}

class ElementTextOptions {
  const ElementTextOptions({
    required this.text,
    this.textHeight = ConstantsConfig.initFontHeight,
    this.fontSize = ConstantsConfig.initFontSize,
    this.fontColor = Colors.black,
    this.fontWeight,
    this.fontFamily,
    this.textAlign = ConstantsConfig.initFontAlign,
    this.letterSpacing,
  });

  /// 文本内容
  final String text;
  /// 文本行高
  final double textHeight;
  /// 文本大小
  final double fontSize;
  /// 文本颜色
  final Color fontColor;
  /// 文本字重（100-1000，1000就是bold）
  final int? fontWeight;
  /// 文本字体
  final String? fontFamily;
  /// 文本对齐方式
  final String? textAlign;
  /// 文本字间距
  final double? letterSpacing;

  ElementTextOptions copyWith({
    String? text,
    double? textHeight,
    double? fontSize,
    Color? fontColor,
    int? fontWeight,
    String? fontFamily,
    String? textAlign,
    double? letterSpacing,
  }) {
    return ElementTextOptions(
      text: text ?? this.text,
      textHeight: textHeight ?? this.textHeight,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      letterSpacing: letterSpacing ?? this.letterSpacing,
    );
  }

  static Map<String, dynamic> toJson(ElementTextOptions data) {
    return {
      "text": data.text,
      "textHeight": data.textHeight,
      "fontSize": data.fontSize,
      "fontColor": TransformUtils.toHex(data.fontColor),
      "fontWeight": data.fontWeight,
      "fontFamily": data.fontFamily,
      "textAlign": data.textAlign,
      "letterSpacing": data.letterSpacing,
    };
  }
}

class ElementModel {
  const ElementModel({
    required this.id,
    required this.elementWidth,
    required this.elementHeight,
    required this.type,
    this.x = ConstantsConfig.initX,
    this.y = ConstantsConfig.initY,
    this.rotationAngle = ConstantsConfig.initRotationAngle,
    this.imagePath,
    this.textOptions,
  });

  /// 当前元素的唯一id
  final int id;
  /// 元素的宽
  final double elementWidth;
  /// 元素的高
  final double elementHeight;
  /// 元素的x坐标
  final double x;
  /// 元素的y坐标
  final double y;
  /// 元素的旋转角度
  final double rotationAngle;
  /// 元素的类型
  final String type;
  /// 如果是元素是图片类型，图片的path
  final String? imagePath;
  /// 如果元素是文本类型，文本属性
  final ElementTextOptions? textOptions;

  ElementModel copyWith({
    double? elementWidth,
    double? elementHeight,
    double? x,
    double? y,
    double? rotationAngle,
    ElementTextOptions? textOptions,
  }) {
    return ElementModel(
      id: id,
      elementWidth: elementWidth ?? this.elementWidth,
      elementHeight: elementHeight ?? this.elementHeight,
      x: x ?? this.x,
      y: y ?? this.y,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      type: type,
      imagePath: imagePath,
      textOptions: textOptions ?? this.textOptions,
    );
  }

  static Map<String, dynamic> toJson(ElementModel data) {
    return {
      "id": data.id,
      "elementWidth": data.elementWidth,
      "elementHeight": data.elementHeight,
      "x": data.x,
      "y": data.y,
      "rotationAngle": data.rotationAngle,
      "type": data.type,
      "imagePath": data.imagePath,
      "textOptions": data.textOptions == null ? '' : ElementTextOptions.toJson(data.textOptions!),
    };
  }
}

/// 元素当前操作状态
enum ElementStatus {
  move(value: 'move'),
  rotate(value: 'rotate'),
  scale(value: 'scale'),
  deleteStatus(value: 'deleteStatus'),;

  final String value;

  const ElementStatus({required this.value});
}

/// 元素的临时中间变量
class TemporaryModel {
  const TemporaryModel({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotationAngle,
    this.status,
    this.trigger,
  });

  /// 单次操作完成时的初始x坐标
  final double x;
  /// 单次操作完成时的初始y坐标
  final double y;
  /// 单次操作完成时的初始宽度
  final double width;
  /// 单次操作完成时的初始高度
  final double height;
  /// 单次操作完成时的初始旋转角度
  final double rotationAngle;
  /// 对应的元素的操作状态
  final String? status;
  /// 当前响应操作的触发方式
  final TriggerMethod? trigger;

  TemporaryModel copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationAngle,
    String? status,
    TriggerMethod? trigger,
  }) {
    return TemporaryModel(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      status: status ?? this.status,
      trigger: trigger ?? this.trigger,
    );
  }
}
