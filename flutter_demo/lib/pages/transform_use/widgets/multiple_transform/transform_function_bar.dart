import 'package:flutter/material.dart';

import 'configs/constants_config.dart';
import 'image_element_add.dart';
import 'models/element_model.dart';
import 'text_element_add.dart';

class TransformFunctionBar extends StatelessWidget {
  const TransformFunctionBar({
    super.key,
    required this.addElement,
    required this.transformWidth,
    required this.transformHeight,
    required this.onShowTextOptions,
    required this.onExpandWidth,
    required this.onReduceWidth,
    required this.onExpandHeight,
    required this.onReduceHeight,
  });

  /// 变换区域的宽，用于计算选择元素的初始宽度
  final double transformWidth;
  /// 变换区域的高，用于计算选择元素的初始高度
  final double transformHeight;
  /// 新增元素方法，用于将选择的元素添加到元素列表中
  final Function(ElementModel) addElement;
  /// 是否展示文本属性弹框
  final Function(bool) onShowTextOptions;
  final Function() onExpandWidth;
  final Function() onReduceWidth;
  final Function() onExpandHeight;
  final Function() onReduceHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ConstantsConfig.bottomHeight,
      child: Column(
        children: [
          SizedBox(height: 20,),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: onExpandWidth,
                  child: Text(
                    '扩展宽度',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: onReduceWidth,
                  child: Text(
                    '缩小宽度',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: onExpandHeight,
                  child: Text(
                    '扩展高度',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: onReduceHeight,
                  child: Text(
                    '缩小高度',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10,),

          Expanded(
            child: Container(
              color: Colors.white60,
              padding: EdgeInsets.only(left: 10, right: 10, top: 10),
              alignment: Alignment.topCenter,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
