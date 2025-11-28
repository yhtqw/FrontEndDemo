import 'package:flutter/material.dart';

import 'configs/constants_config.dart';
import 'image_element_add.dart';
import 'models/element_model.dart';
import 'save_button.dart';
import 'text_element_add.dart';

class TransformFunctionBar extends StatelessWidget {
  const TransformFunctionBar({
    super.key,
    required this.addElement,
    required this.transformWidth,
    required this.transformHeight,
    required this.onShowTextOptions,
    required this.onSave,
  });

  /// 变换区域的宽，用于计算选择元素的初始宽度
  final double transformWidth;
  /// 变换区域的高，用于计算选择元素的初始高度
  final double transformHeight;
  /// 新增元素方法，用于将选择的元素添加到元素列表中
  final Function(ElementModel) addElement;
  /// 是否展示文本属性弹框
  final Function(bool) onShowTextOptions;
  /// 保存
  final Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ConstantsConfig.bottomHeight,
      color: Colors.white60,
      padding: EdgeInsets.symmetric(horizontal: 10,),
      child: Row(
        spacing: 10,
        children: [
          // 图片新增
          ImageElementAdd(
            transformHeight: transformHeight,
            transformWidth: transformWidth,
            addElement: addElement,
          ),
          // 文本新增
          TextElementAdd(
            onShowTextOptions: onShowTextOptions,
          ),
          // 保存
          SaveButton(
            onSave: onSave,
          ),
        ],
      ),
    );
  }
}
