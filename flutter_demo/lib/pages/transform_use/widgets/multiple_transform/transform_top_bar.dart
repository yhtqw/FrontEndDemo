import 'package:flutter/material.dart';

import 'base_icon_button.dart';
import 'configs/constants_config.dart';
import 'level_bar.dart';
import 'models/bar_model.dart';
import 'models/element_model.dart';

class TransformTopBar extends StatelessWidget {
  const TransformTopBar({
    super.key,
    required this.onSave,
    required this.onUseGrid,
    required this.useGrid,
    required this.onChangeUseAuxiliaryLine,
    required this.useAuxiliaryLine,
    required this.onChangeUsePosition,
    required this.usePosition,
    this.currentElement,
    required this.onLevel,
  });

  /// 保存
  final Function() onSave;
  final Function() onUseGrid;
  final bool useGrid;
  final Function() onChangeUseAuxiliaryLine;
  final bool useAuxiliaryLine;
  final Function() onChangeUsePosition;
  final bool usePosition;
  final ElementModel? currentElement;
  final Function(LevelType) onLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ConstantsConfig.topHeight,
      padding: EdgeInsets.symmetric(horizontal: 10,),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 选中元素的辅助线
          BaseIconButton(
            iconSrc: 'assets/images/icon_auxiliary_line.png',
            onPressed: onChangeUseAuxiliaryLine,
            isSelected: useAuxiliaryLine,
          ),

          // 网格
          BaseIconButton(
            iconSrc: 'assets/images/icon_grid.png',
            onPressed: onUseGrid,
            isSelected: useGrid,
          ),

          // 层级
          LevelBar(
            onChangeUsePosition: onChangeUsePosition,
            usePosition: usePosition,
            disabled: currentElement == null,
            onLevel: onLevel,
          ),
          // BaseIconButton(
          //   iconSrc: 'assets/images/icon_level.png',
          //   onPressed: onChangeUsePosition,
          //   isSelected: usePosition,
          // ),

          // 保存
          BaseIconButton(
            iconSrc: 'assets/images/icon_save.png',
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
