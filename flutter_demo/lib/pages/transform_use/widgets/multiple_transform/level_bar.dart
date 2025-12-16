import 'package:flutter/material.dart';

import 'base_icon_button.dart';
import 'models/bar_model.dart';

class LevelBar extends StatefulWidget {
  const LevelBar({
    super.key,
    required this.onChangeUsePosition,
    required this.usePosition,
    required this.disabled,
    required this.onLevel,
  });

  final Function() onChangeUsePosition;
  final bool usePosition;
  final bool disabled;
  final Function(LevelType) onLevel;

  @override
  State<LevelBar> createState() => _LevelBarState();
}

class _LevelBarState extends State<LevelBar> {
  /// 用于获取定位信息
  final GlobalKey _globalKey = GlobalKey();
  /// 容器
  OverlayEntry? _overlayEntry;
  /// 宽高定位信息用于定位容器
  double _barWidth = 0;
  double _barHeight = 0;
  double _barTop = 0;
  double _barLeft = 0;

  @override
  void didUpdateWidget(covariant LevelBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当使用层级工具，展示，不使用，隐藏
    if (oldWidget.usePosition != widget.usePosition) {
      if (widget.usePosition == false) {
        _hideLevelBar();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLevelBar();
        });
      }
    }
  }

  @override
  void dispose() {
    _globalKey.currentState?.dispose();
    _hideLevelBar();
    super.dispose();
  }

  /// 隐藏层级工具栏
  void _hideLevelBar() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  /// 展示层级工具栏
  void _showLevelBar() {
    _getDimensions();
    _hideLevelBar();

    // 创建 OverlayEntry
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: _barHeight + _barTop,
        left: _barLeft - 100 + _barWidth / 2,
        child: Material(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: Color(0xFFF0F0F0),
              border: Border.all(
                color: Colors.blueAccent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BaseIconButton(
                  iconSrc: 'assets/images/icon_top.png',
                  onPressed: () => widget.onLevel(LevelType.top),
                ),
                BaseIconButton(
                  iconSrc: 'assets/images/icon_upper_level.png',
                  onPressed: () => widget.onLevel(LevelType.upper),
                ),
                BaseIconButton(
                  iconSrc: 'assets/images/icon_next_level.png',
                  onPressed: () => widget.onLevel(LevelType.next),
                ),
                BaseIconButton(
                  iconSrc: 'assets/images/icon_bottom.png',
                  onPressed: () => widget.onLevel(LevelType.bottom),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 插入 Overlay
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 获取尺寸和布局信息
  void _getDimensions() {
    RenderBox? renderBox = _globalKey.currentContext?.findRenderObject() as RenderBox?;

    // 检查是否成功获取
    if (renderBox != null) {
      _barWidth = renderBox.size.width;
      _barHeight = renderBox.size.height;
      Offset offset = renderBox.localToGlobal(Offset.zero);
      _barTop = offset.dy;
      _barLeft = offset.dx;
    }
  }

  void _onTap() {
    if (!widget.disabled) {
      widget.onChangeUsePosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseIconButton(
      key: _globalKey,
      iconSrc: 'assets/images/icon_level.png',
      onPressed: _onTap,
      isSelected: widget.usePosition,
      disabled: widget.disabled,
    );
  }
}
