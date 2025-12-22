import 'package:flutter/material.dart';
import 'package:flutter_demo/pages/filter_dropdown/widgets/filter_dropdown/models/options_container_prop_model.dart';

import 'filter_options_container.dart';
import 'models/filter_dropdown_option_model.dart';

class FilterDropdown extends StatefulWidget {
  const FilterDropdown({
    super.key,
    required this.items,
    required this.onSelected,
    this.useCustomize = false,
    this.onFilter,
    this.containerHeight = 50,
    this.containerBorder,
    this.containerBorderRadius,
    this.containerBgColor,
    this.containerPadding = EdgeInsets.zero,
    this.hintText,
    this.hintStyle,
    this.textStyle,
    this.cursorColor,
    this.optionsMarginTop = 0,
    this.optionsContainerProp = const OptionsContainerPropModel(),
    this.buildOption,
  });

  /// 传入的选项
  final List<FilterDropdownOptionModel> items;
  /// 点击选项选中当前项的回调函数
  final Function(FilterDropdownOptionModel) onSelected;
  /// 是否保留自定义的输入
  final bool useCustomize;
  /// 自定义的过滤方法
  final bool Function(String)? onFilter;
  // TextField 容器相关的属性
  /// 容器的高
  final double containerHeight;
  /// 容器的边框
  final BoxBorder? containerBorder;
  /// 容器的圆角属性
  final BorderRadiusGeometry? containerBorderRadius;
  /// 容器的背景颜色
  final Color? containerBgColor;
  /// 容器的内边距
  final EdgeInsetsGeometry containerPadding;
  // 文本输入框的属性
  /// 提示文本
  final String? hintText;
  /// 提示文本样式
  final TextStyle? hintStyle;
  /// 输入文本样式
  final TextStyle? textStyle;
  /// 光标颜色
  final Color? cursorColor;
  // 选项框的样式
  /// 选项框距离输入框的边距
  final double optionsMarginTop;
  /// 选项框的属性
  final OptionsContainerPropModel optionsContainerProp;
  /// 自定义构建选项
  final Widget Function(FilterDropdownOptionModel)? buildOption;

  @override
  State<FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<FilterDropdown> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _containerKey = GlobalKey();
  List<FilterDropdownOptionModel> _filterItems = [];
  OverlayEntry? _overlayEntry;
  double _containerLeft = 0;
  double _containerTop = 0;
  double _containerWidth = 0;
  bool _onTapOptions = false;
  bool _isShowOptions = false;

  @override
  void initState() {
    super.initState();

    // 当获取焦点的时候，如果没有选项弹框，则自动展示选项弹框，
    // 当失去焦点的时候，如果存在选项弹框，则隐藏
    _focusNode.addListener(() {
      setState(() {
        if (_focusNode.hasFocus) {
          // 获取焦点时判断一下，重置选项
          if (_filterItems.length != widget.items.length) {
            _initData();
          }

          // 当获取焦点的时候，直接显示
          _updateOverlayEntry(true);
        } else if (!_focusNode.hasFocus) {
          // 失去焦点的时候直接隐藏
          _updateOverlayEntry(false);
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _setContainerInfo();
      _initData();
      _showOptions();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    // _removeOptions();
    _overlayEntry?.remove();
    _controller.dispose();
    _containerKey.currentState?.dispose();
    super.dispose();
  }

  /// 初始化数据
  void _initData() {
    _filterItems = [...widget.items];
  }

  void _onTapOption(FilterDropdownOptionModel item) {
    _controller.value = _controller.value.copyWith(
      // 设置值
      text: item.text,
      // 将光标移动到末尾
      selection: TextSelection.fromPosition(
        TextPosition(offset: item.text.length),
      ),
    );
    widget.onSelected(item);
    _onTapOptionsContainer(false);
    _onTapOutside();
  }

  void _onTapOptionsContainer(bool flag) {
    _onTapOptions = flag;
  }

  /// 显示选项
  void _showOptions() {
    // 每次展示选项框的时候重新获取一下
    _setContainerInfo();
    // _isShowOptions = true;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // 一般是定位在输入框的下方，所以为容器的top值+容器的高度
        top: _containerTop + widget.containerHeight + widget.optionsMarginTop,
        left: _containerLeft,
        child: Material(
          child: FilterOptionsContainer(
            containerWidth: _containerWidth,
            filterItems: _filterItems,
            onTapOption: _onTapOption,
            optionsContainerProp: widget.optionsContainerProp,
            buildOption: widget.buildOption,
            onTap: _onTapOptionsContainer,
            isShowOptions: _isShowOptions,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // /// 移出选项结构
  // void _removeOptions() {
  //   _overlayEntry?.remove();
  //   _overlayEntry = null;
  // }

  /// 输入框输入匹配数据
  void _onChanged(String text) {
    if (text.trim().isEmpty && _filterItems.length != widget.items.length) {
      _filterItems = [...widget.items];

      // _removeOptions();
      // _showOptions();
      _updateOverlayEntry(true);
    } else if (text.trim().isNotEmpty) {
      _filterItems.clear();
      for (var item in widget.items) {
        // 如果外面传入的过滤算法，则使用外界的
        if (widget.onFilter != null && widget.onFilter!(text)) {
          _filterItems.add(item);
        } else if (item.text.contains(text)) {
          // 如果没有传入，则使用内置这个简单的
          _filterItems.add(item);
        }
      }

      // _removeOptions();
      // _showOptions();
      _updateOverlayEntry(true);
    }
  }

  /// 更新选项容器
  ///
  /// 传入是否展示[showOptions]决定了选项容器是否展示
  void _updateOverlayEntry(bool showOptions) {
    _isShowOptions = showOptions;
    _overlayEntry?.markNeedsBuild();
  }

  /// 处理是否保留自定义的输入
  void _onCustomizeInput() {
    if (_controller.text == '') return;

    if (widget.items.indexWhere((item) => item.text == _controller.text) == -1) {
      if (widget.useCustomize) {
        // 通知外层当前输入框输入的内容
        widget.onSelected(FilterDropdownOptionModel(
          text: _controller.text,
          type: -1,
        ));
      } else {
        // 如果不保留自定义的输入，则置空
        _controller.text = '';
      }
    }
  }

  /// 点击输入框外面，执行清除焦点操作
  void _onTapOutside() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_onTapOptions) return;

      _onCustomizeInput();

      FocusScope.of(context).unfocus();
    });
  }

  /// 点击软键盘上面的完成，执行输入内容判断
  void _onSubmitted() {
    _onCustomizeInput();
  }

  /// 设置容器的属性，通过这些属性来确定选项的位置和宽度信息
  void _setContainerInfo() {
    RenderBox renderBox = _containerKey.currentContext!.findRenderObject() as RenderBox;
    Offset topLeft = renderBox.localToGlobal(Offset.zero);
    double dx = topLeft.dx;
    double dy = topLeft.dy;
    double width = renderBox.size.width;

    if (_containerLeft != dx || _containerTop != dy || _containerWidth != width) {
      _containerLeft = topLeft.dx;
      _containerTop = topLeft.dy;
      _containerWidth = renderBox.size.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _containerKey,
      height: widget.containerHeight,
      padding: widget.containerPadding,
      decoration: BoxDecoration(
        border: widget.containerBorder,
        borderRadius: widget.containerBorderRadius ?? BorderRadius.circular(10),
        color: widget.containerBgColor,
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: widget.textStyle,
        cursorColor: widget.cursorColor,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: widget.hintStyle,
        ),
        onChanged: _onChanged,
        onTapOutside: (event) => _onTapOutside(),
        onSubmitted: (text) => _onSubmitted(),
      ),
    );
  }
}
