
import 'package:flutter/material.dart';

/// 选项框的属性
class OptionsContainerPropModel {
  /// 选项框的背景色
  final Color? optionsBgColor;
  /// 选项框的圆角属性
  final BorderRadiusGeometry? optionsBorderRadius;
  /// 选项框的边框
  final BoxBorder? optionsBorder;
  /// 选项框的最小高度
  final double optionsMinHeight;
  /// 选项框的最大高度
  final double optionsMaxHeight;
  /// 选项框的内边距
  final EdgeInsetsGeometry optionsPadding;

  const OptionsContainerPropModel({
    this.optionsBgColor,
    this.optionsBorderRadius,
    this.optionsBorder,
    this.optionsMinHeight = 50,
    this.optionsMaxHeight = 300,
    this.optionsPadding = EdgeInsets.zero,
  });
}