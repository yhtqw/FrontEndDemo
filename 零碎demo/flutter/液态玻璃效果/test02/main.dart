import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LiquidTabBarDemoApp());
}

class LiquidTabBarDemoApp extends StatelessWidget {
  const LiquidTabBarDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Liquid TabBar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B7CFF),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const ArticlePage(),
    );
  }
}

enum TabBarIntent { collapse, expand }

/// 保存原生 TabBar 的最终状态，避免 Platform View 尚未创建时丢命令。
class NativeLiquidTabBarController {
  static const _channelPrefix = 'com.example.native_liquid_tab_bar';

  MethodChannel? _channel;
  TabBarIntent _intent = TabBarIntent.expand;
  int _selectedIndex = 0;
  int _revision = 0;
  ValueChanged<int>? _onTabSelected;

  bool get isCollapsed => _intent == TabBarIntent.collapse;
  int get selectedIndex => _selectedIndex;
  int get revision => _revision;

  void attach(int viewId, ValueChanged<int> onTabSelected) {
    _channel?.setMethodCallHandler(null);

    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;
    _onTabSelected = onTabSelected;
    channel.setMethodCallHandler(_handleNativeCall);

    // 原生 View 创建完成后，只同步最新状态，不回放历史滚动。
    unawaited(_sendIntent());
    unawaited(_send('setSelected', <String, Object?>{'index': _selectedIndex}));
  }

  void detach() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _onTabSelected = null;
  }

  void setCollapsed(bool collapsed) {
    final next = collapsed ? TabBarIntent.collapse : TabBarIntent.expand;
    if (next == _intent) {
      return;
    }

    _intent = next;
    _revision += 1;
    unawaited(_sendIntent());
  }

  void select(int index) {
    if (_selectedIndex == index) {
      return;
    }

    _selectedIndex = index;
    unawaited(_send('setSelected', <String, Object?>{'index': index}));
  }

  Future<void> _sendIntent() {
    return _send(_intent.name, <String, Object?>{'revision': _revision});
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'tabSelected') {
      throw MissingPluginException('未知原生回调：${call.method}');
    }

    final value = call.arguments;
    if (value is! num) {
      throw PlatformException(
        code: 'bad_arguments',
        message: 'tabSelected 需要整数 index',
      );
    }

    _selectedIndex = value.toInt();
    _onTabSelected?.call(_selectedIndex);
  }

  Future<void> _send(String method, [Object? arguments]) async {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // 原生 View 已销毁时，忽略已经排队的旧命令。
    }
  }
}

/// 将连续滚动归纳成收起或展开意图。
class TabBarIntentReducer {
  TabBarIntentReducer({this.threshold = 20});

  final double threshold;

  double? _lastPixels;
  double _distance = 0;
  int _lastDirection = 0;
  bool _collapsed = false;

  TabBarIntent? reduce(ScrollNotification notification) {
    if (notification.depth != 0) {
      return null;
    }

    if (notification is ScrollStartNotification) {
      _lastPixels = notification.metrics.pixels;
      _distance = 0;
      _lastDirection = 0;
      return null;
    }

    if (notification is OverscrollNotification &&
        notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 0.5) {
      return _emit(false);
    }

    if (notification is! ScrollUpdateNotification) {
      return null;
    }

    final metrics = notification.metrics;
    final previousPixels = _lastPixels;
    _lastPixels = metrics.pixels;

    // 回到顶部时直接展开，不等方向阈值。
    if (metrics.pixels <= metrics.minScrollExtent + 0.5) {
      _distance = 0;
      _lastDirection = 0;
      return _emit(false);
    }

    if (previousPixels == null) {
      return null;
    }

    // 示例使用默认竖向、reverse: false 的列表。
    final delta = metrics.pixels - previousPixels;
    if (delta == 0) {
      return null;
    }

    final direction = delta > 0 ? 1 : -1;
    if (direction != _lastDirection) {
      _lastDirection = direction;
      _distance = 0;
    }

    _distance += delta.abs();
    if (_distance < threshold) {
      return null;
    }

    _distance = 0;
    return _emit(direction > 0);
  }

  TabBarIntent? _emit(bool shouldCollapse) {
    if (_collapsed == shouldCollapse) {
      return null;
    }

    _collapsed = shouldCollapse;
    return shouldCollapse ? TabBarIntent.collapse : TabBarIntent.expand;
  }
}

class ArticlePage extends StatefulWidget {
  const ArticlePage({super.key});

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final _tabController = NativeLiquidTabBarController();
  final _intentReducer = TabBarIntentReducer();

  static const _tabTitles = <String>['首页', '灵感', '我的'];
  int _selectedIndex = 0;

  bool _onScroll(ScrollNotification notification) {
    final intent = _intentReducer.reduce(notification);
    if (intent != null) {
      _tabController.setCollapsed(intent == TabBarIntent.collapse);
    }
    return false;
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    _tabController.select(index);
  }

  @override
  Widget build(BuildContext context) {
    final title = _tabTitles[_selectedIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF7F4FF),
              Color(0xFFEAF4FF),
              Color(0xFFFFF2E8),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    title: Text('$title · Flutter 笔记'),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                      child: Text(
                        '把滚动意图交给原生动画',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: 24,
                    itemBuilder: (BuildContext context, int index) {
                      return _ArticleCard(index: index);
                    },
                  ),
                  // 给底部原生栏预留内容空间。
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 72,
                  child: NativeLiquidTabBar(
                    controller: _tabController,
                    onTabSelected: _selectTab,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NativeLiquidTabBar extends StatefulWidget {
  const NativeLiquidTabBar({
    required this.controller,
    required this.onTabSelected,
    super.key,
  });

  final NativeLiquidTabBarController controller;
  final ValueChanged<int> onTabSelected;

  @override
  State<NativeLiquidTabBar> createState() => _NativeLiquidTabBarState();
}

class _NativeLiquidTabBarState extends State<NativeLiquidTabBar> {
  void _onPlatformViewCreated(int viewId) {
    widget.controller.attach(viewId, widget.onTabSelected);
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const ColoredBox(
        color: Color(0xFFE8E8ED),
        child: Center(child: Text('这个示例的原生玻璃栏仅支持 iOS 26+')),
      );
    }

    return UiKitView(
      key: const ValueKey<String>('native-liquid-tab-bar'),
      viewType: 'com.example.native_liquid_tab_bar',
      layoutDirection: TextDirection.ltr,
      creationParams: <String, Object?>{
        'selectedIndex': widget.controller.selectedIndex,
        'collapsed': widget.controller.isCollapsed,
        'revision': widget.controller.revision,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
      // 底栏区域的点击优先交给原生 UIButton。
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const colors = <Color>[
      Color(0xFFE2EDFF),
      Color(0xFFFFE9D8),
      Color(0xFFE5F7E8),
      Color(0xFFF2E7FF),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors[index % colors.length].withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '第 ${index + 1} 条滚动内容',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本'
            '测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本',
          ),
        ],
      ),
    );
  }
}
