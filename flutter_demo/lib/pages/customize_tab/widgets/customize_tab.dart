import 'package:flutter/material.dart';

import 'customize_tab_indicator.dart';

/// tab bar 位置的枚举
enum TabBarPosition { top, bottom, left, right }

/// 抽取一些默认的属性
BorderRadius ctDefaultIndicatorBorderRadius = BorderRadius.circular(10);

class CustomizeTab extends StatefulWidget {
  const CustomizeTab({
    super.key,
    this.tabBarHeight = kToolbarHeight,
    this.tabBarBackgroundColor,
    this.tabBarPadding = EdgeInsets.zero,
    this.tabBarBorderRadius,
    required this.tabs,
    this.unselectedColor,
    this.selectedColor,
    this.tabBarOptionMargin = const EdgeInsets.only(right: 10),
    this.tabBarOptionPadding = EdgeInsets.zero,
    this.indicatorColor = Colors.blue,
    this.indicatorBorderRadius,
    required this.tabViews,
    this.initialIndex,
    this.onChangeTabIndex,
    this.position = TabBarPosition.top,
  });

  /// tab bar 容器的高度，默认为AppBar工具栏组件的高度
  final double tabBarHeight;
  /// tab bar 容器的背景颜色
  final Color? tabBarBackgroundColor;
  /// tab bar 容器的内边距
  final EdgeInsetsGeometry tabBarPadding;
  /// tab bar 容器的圆角属性
  final BorderRadiusGeometry? tabBarBorderRadius;
  /// tab 选项
  final List<Widget> tabs;
  /// tab 选项未选中时的颜色
  final Color? unselectedColor;
  /// tab 选项选中时的颜色
  final Color? selectedColor;
  /// tab bar 选项每项的margin
  final EdgeInsetsGeometry tabBarOptionMargin;
  /// tab bar 选项每项的padding(因为大概率每项的padding是一致的，所以进行抽取)
  final EdgeInsetsGeometry tabBarOptionPadding;
  /// 指示器的颜色
  final Color indicatorColor;
  /// 指示器的圆角属性
  final BorderRadius? indicatorBorderRadius;
  /// tab 页面
  final List<Widget> tabViews;
  /// 初始化显示tab的索引
  final int? initialIndex;
  /// 当tab索引发生改变时的回调函数
  final Function(int)? onChangeTabIndex;
  /// tab bar所在位置，默认为top
  final TabBarPosition position;

  @override
  State<CustomizeTab> createState() => _CustomizeTabState();
}

class _CustomizeTabState extends State<CustomizeTab> with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex ?? 0,
    )..addListener(() {
      // indexIsChanging主要作用就是标识TabController是否正处于索引切换过程中。
      // 点击切换，在执行动画期间为true，用户手势操作结束后且动画完成为false
      // 滑动切换为false
      // 使用indexIsChanging来判断当前tab变化是否完成，完成了就执行回调
      if (!_controller.indexIsChanging) {
        widget.onChangeTabIndex?.call(_controller.index);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 对每个tab加内边距
  Widget _buildTabOption(Widget tab) {
    final Widget tabOption = Padding(
      padding: widget.tabBarOptionPadding,
      child: tab,
    );

    // 如果是left和right，因为外层的TabBar容器旋转了90度
    // 那Tab选项就旋转-90度还原，达到视觉的统一
    if (widget.position == TabBarPosition.left || widget.position == TabBarPosition.right) {
      return RotatedBox(
        quarterTurns: -1,
        child: tabOption,
      );
    } else {
      return tabOption;
    }
  }

  /// 构建TabBar
  Widget _buildTabBar() {
    final Widget tabBar = Container(
      width: double.infinity,
      height: widget.tabBarHeight,
      padding: widget.tabBarPadding,
      decoration: BoxDecoration(
        color: widget.tabBarBackgroundColor,
        borderRadius: widget.tabBarBorderRadius,
      ),
      child: TabBar(
        controller: _controller,
        indicator: CustomizeTabIndicator(
          color: widget.indicatorColor,
          radius: widget.indicatorBorderRadius
              ?? ctDefaultIndicatorBorderRadius,
        ),
        isScrollable: true,
        dividerHeight: 0,
        labelPadding: widget.tabBarOptionMargin,
        tabAlignment: TabAlignment.start,
        unselectedLabelColor: widget.unselectedColor,
        labelColor: widget.selectedColor,
        tabs: widget.tabs.map((tab) => _buildTabOption(tab)).toList(),
      ),
    );

    if (widget.position == TabBarPosition.left || widget.position == TabBarPosition.right) {
      // 如果是left和right，则旋转90度，
      return RotatedBox(
        quarterTurns: 1,
        child: tabBar,
      );
    } else {
      return tabBar;
    }
  }

  Widget _buildTabView(BoxConstraints boxConstraints) {
    final EdgeInsets tabBarPadding = widget.tabBarPadding.resolve(TextDirection.ltr);

    return widget.position == TabBarPosition.top || widget.position == TabBarPosition.bottom ? SizedBox(
      width: double.infinity,
      height: boxConstraints.maxHeight -
          widget.tabBarHeight -
          tabBarPadding.top -
          tabBarPadding.bottom,
      child: TabBarView(
        controller: _controller,
        children: widget.tabViews,
      ),
    ) : SizedBox(
      // 如果是left或者right，则宽高设置交换，并且将TabBarView旋转90度
      width: boxConstraints.maxWidth -
          widget.tabBarHeight -
          tabBarPadding.top -
          tabBarPadding.bottom,
      height: double.infinity,
      child: RotatedBox(
        quarterTurns: 1,
        child: TabBarView(
          controller: _controller,
          // 因为TabBarView旋转了90度，对应的Tab项要旋转-90度还原
          children: widget.tabViews.map((tabView) => RotatedBox(
            quarterTurns: -1,
            child: tabView,
          )).toList(),
        ),
      ),
    );
  }

  /// 构建tab
  Widget _buildTab(BoxConstraints boxConstraints) {
    List<Widget> children = [
      _buildTabBar(),
      _buildTabView(boxConstraints),
    ];

    // 如果是bottom和right，则渲染的结构会倒置
    if (widget.position == TabBarPosition.bottom
        || widget.position == TabBarPosition.right) {
      children = children.reversed.toList();
    }

    // 如果是top或者bottom，则是上下结构
    // 如果是left或者right，则是左右结构
    return widget.position == TabBarPosition.top || widget.position == TabBarPosition.bottom
        ? Column(children: children,)
        : Row(children: children,);
  }

  @override
  Widget build(BuildContext context) {
    // 通过父容器的约束动态构建子部件
    return LayoutBuilder(
      builder: (_, BoxConstraints boxConstraints) => _buildTab(boxConstraints),
    );
  }
}