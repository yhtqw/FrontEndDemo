import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'configs/constants_config.dart';
import 'models/element_model.dart';
import 'models/response_area_model.dart';
import 'utils/transform_utils.dart';

/// 抽取渲染的元素
class TransformItem extends StatelessWidget {
  const TransformItem({
    super.key,
    required this.elementItem,
    required this.selected,
    required this.areaList,
  });

  final ElementModel elementItem;
  final bool selected;
  final List<ResponseAreaModel> areaList;

  /// 当在特殊角度处，边框稍微变粗一些，用于区分
  double get _selectedBorderWidth {
    return (elementItem.rotationAngle == 0 || elementItem.rotationAngle == pi / 2 || elementItem.rotationAngle == pi * 3 / 2 || elementItem.rotationAngle == pi) ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: elementItem.x,
      top: elementItem.y,
      // 新增旋转功能
      child: SizedBox(
        width: elementItem.elementWidth,
        height: elementItem.elementHeight,
        // color: Colors.blueAccent,
        child: Transform.rotate(
          angle: elementItem.rotationAngle,
          child: SizedBox(
            width: elementItem.elementWidth,
            height: elementItem.elementHeight,
            // 新增区域的渲染
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 图片元素
                if (elementItem.type == ElementType.imageType.type) Image.file(
                  File(elementItem.imagePath!),
                  width: elementItem.elementWidth,
                  height: elementItem.elementHeight,
                  fit: BoxFit.cover,
                ),

                // 文本元素，为了保持与计算出来的一致，所以使用RichText
                if (elementItem.type == ElementType.textType.type && elementItem.textOptions != null) SizedBox(
                  width: elementItem.elementWidth,
                  height: elementItem.elementHeight,
                  child: RichText(
                    textDirection: TextDirection.ltr,
                    textAlign: TransformUtils.getTextAlign(
                      elementItem.textOptions?.textAlign,
                    ),
                    text: TextSpan(
                      text: elementItem.textOptions!.text,
                      style: TextStyle(
                        fontSize: elementItem.textOptions?.fontSize,
                        height: elementItem.textOptions?.textHeight,
                        color: elementItem.textOptions?.fontColor,
                        fontFamily: elementItem.textOptions?.fontFamily,
                        letterSpacing: elementItem.textOptions?.letterSpacing,
                        fontWeight: TransformUtils.getFontWeight(
                          elementItem.textOptions?.fontWeight,
                        ),
                      ),
                    ),
                  ),
                ),

                // 如果选中，则展示选中框
                if (selected) Container(
                  width: elementItem.elementWidth,
                  height: elementItem.elementHeight,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blueAccent,
                      width:  _selectedBorderWidth,
                    ),
                  ),
                ),

                // 如果选中，则展示操作区域
                if (selected) ...areaList.map((item) => Positioned(
                  top: elementItem.elementHeight * item.yRatio - item.areaHeight / 2,
                  left: elementItem.elementWidth * item.xRatio - item.areaWidth / 2,
                  child: Container(
                    width: item.areaWidth,
                    height: item.areaHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(item.areaWidth / 2),
                    ),
                    child: Image.asset(
                      item.iconConfig?[elementItem.type] ?? item.icon,
                      width: item.areaWidth - ConstantsConfig.areaIconMargin,
                      height: item.areaHeight - ConstantsConfig.areaIconMargin,
                      fit: BoxFit.scaleDown,
                      color: Colors.white,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
