import 'package:flutter/material.dart';

import 'models/filter_dropdown_option_model.dart';
import 'models/options_container_prop_model.dart';

class FilterOptionsContainer extends StatelessWidget {
  const FilterOptionsContainer({
    super.key,
    required this.filterItems,
    required this.onTapOption,
    required this.containerWidth,
    required this.optionsContainerProp,
    this.buildOption,
    required this.onTap,
    required this.isShowOptions,
  });

  /// 过滤的选项
  final List<FilterDropdownOptionModel> filterItems;
  /// 点击选项选择的回调
  final void Function(FilterDropdownOptionModel) onTapOption;
  /// 容器的宽度，选项容器的宽度和输入框容器的宽度保持一致
  final double containerWidth;
  /// 选项框的属性
  final OptionsContainerPropModel optionsContainerProp;
  /// 构建选项
  final Widget Function(FilterDropdownOptionModel)? buildOption;
  /// 点击事件，点击外部传递false，点击内部传递true
  final Function(bool) onTap;
  /// 控制是否显示
  final bool isShowOptions;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => onTap(true),
      child: TapRegion(
        // 监听点击外部执行关闭
        onTapOutside: (event) => onTap(false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: containerWidth,
          padding: optionsContainerProp.optionsPadding,
          decoration: BoxDecoration(
            color: optionsContainerProp.optionsBgColor ?? Colors.white,
            border: optionsContainerProp.optionsBorder,
            borderRadius: optionsContainerProp.optionsBorderRadius,
          ),
          constraints: BoxConstraints(
            maxHeight: isShowOptions ? optionsContainerProp.optionsMaxHeight : 0,
            minHeight: isShowOptions ? optionsContainerProp.optionsMinHeight : 0,
          ),
          child: SingleChildScrollView(
            hitTestBehavior: HitTestBehavior.deferToChild,
            child: Column(
              children: [
                if (filterItems.isNotEmpty) ...filterItems.map((item) => GestureDetector(
                  onTap: () => onTapOption(item),
                  child: buildOption != null ? buildOption!(item) : Container(
                    height: 30,
                    alignment: Alignment.center,
                    color: Colors.transparent,
                    child: Text(
                      item.text,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )),

                if (filterItems.isEmpty) Container(
                  height: 100,
                  alignment: Alignment.center,
                  child: Text(
                    '暂无匹配的选项',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
