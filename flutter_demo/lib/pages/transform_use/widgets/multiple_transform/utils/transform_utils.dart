import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../configs/constants_config.dart';

class TransformUtils {
  static FontWeight? getFontWeight(int? fw) {
    switch (fw) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
      case 1000:
        return FontWeight.bold;
      default:
        return null;
    }
  }

  static TextAlign getTextAlign(String? ta) {
    switch (ta) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  /// 计算文本的宽高
  ///
  /// 传入文本字符串[text]、文本的样式[style]和最大的宽度[maxWidth]来计算文本的宽高
  static (double, double) calculateTextSize({
    required String text,
    required TextStyle style,
    required double maxWidth
  }) {
    if (text.isEmpty) {
      return (0, 0);
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final tempWidth = textPainter.width;
    final tempHeight = textPainter.height;
    // 不能小于最小值
    final minSize = ConstantsConfig.minSize;

    return (
      tempWidth <= minSize ? minSize : tempWidth,
      tempHeight <= minSize ? minSize : tempHeight
    );
  }

  static String toHex(Color color) {
    // String hex = color.toHexString(includeHashSign: true, enableAlpha: false);
    // print(hex);
    return color.toHexString();
  }
}
