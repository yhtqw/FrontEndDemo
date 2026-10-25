/// 可复用的跨平台底部导航栏。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 一个跨平台底部导航目的地。
///
/// [id] 是稳定业务标识，不能用数组下标代替；Material 图标和 SF Symbol
/// 分开保存，避免把 Flutter 的 IconData 编码耦合到 Swift。
@immutable
class LiquidTabBarDestination {
  const LiquidTabBarDestination({
    required this.id,
    required this.label,
    required this.materialIcon,
    required this.iosSymbolName,
    this.selectedMaterialIcon,
    this.selectedIosSymbolName,
  }) : assert(id != ''),
       assert(label != ''),
       assert(iosSymbolName != '');

  final String id;
  final String label;
  final IconData materialIcon;
  final IconData? selectedMaterialIcon;
  final String iosSymbolName;
  final String? selectedIosSymbolName;

  Map<String, Object> toNativeMap() => <String, Object>{
    'id': id,
    'label': label,
    'iosSymbolName': iosSymbolName,
    'selectedIosSymbolName': selectedIosSymbolName ?? iosSymbolName,
  };
}

/// Flutter 与原生底栏之间的动画控制器。
///
/// 一个 controller 只绑定一个 [LiquidTabBar]。它只保存 compact 动画状态；
/// 选中项由 [LiquidTabBar.selectedIndex] 受控，避免和路由维护两份真相。
class LiquidTabBarController extends ChangeNotifier {
  static const _channelPrefix = 'com.example.liquid_tab_bar';

  LiquidTabBarController({bool initiallyCollapsed = false})
    : _isCollapsed = initiallyCollapsed;

  MethodChannel? _channel;
  ValueChanged<int>? _onNativeSelected;
  bool _isCollapsed;
  int _revision = 0;

  bool get isCollapsed => _isCollapsed;
  int get revision => _revision;

  /// 收起底栏；重复调用不会重复发送原生命令。
  void collapse() => setCollapsed(true);

  /// 展开底栏；重复调用不会重复发送原生命令。
  void expand() => setCollapsed(false);

  /// 设置收起状态。revision 用于让原生侧丢弃迟到的旧消息。
  void setCollapsed(bool collapsed) {
    if (_isCollapsed == collapsed) {
      return;
    }

    _isCollapsed = collapsed;
    _revision += 1;
    notifyListeners();
    unawaited(_sendIntent());
  }

  void _attach(
    int viewId,
    int selectedIndex,
    ValueChanged<int> onNativeSelected,
  ) {
    _detach();

    final channel = MethodChannel('$_channelPrefix/$viewId');
    _channel = channel;
    _onNativeSelected = onNativeSelected;
    channel.setMethodCallHandler(_handleNativeCall);

    // Platform View 创建完成后只同步最终状态，不回放滚动过程。
    unawaited(_sendIntent());
    _setSelected(selectedIndex);
  }

  void _setSelected(int index) {
    unawaited(_send('setSelected', <String, Object>{'index': index}));
  }

  void _updateOnNativeSelected(ValueChanged<int> callback) {
    _onNativeSelected = callback;
  }

  void _detach() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _onNativeSelected = null;
  }

  Future<void> _sendIntent() {
    return _send(_isCollapsed ? 'collapse' : 'expand', <String, Object>{
      'revision': _revision,
    });
  }

  Future<void> _send(String method, [Object? arguments]) async {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // 页面销毁后已排队的消息可以安全忽略。
    } on PlatformException catch (error) {
      // 宽窄布局切换会销毁并重建 iOS Platform View。已经发出的异步命令
      // 可能在旧 View 收到前才抵达，这类回包不是业务错误。
      if (error.code != 'view_disposed') {
        debugPrint('LiquidTabBar 原生调用失败：${error.code}');
      }
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'tabSelected' || call.arguments is! num) {
      throw MissingPluginException('未知原生回调：${call.method}');
    }

    // 原生点击只是一次选择请求。最终选中状态必须由业务层提交，
    // 这样路由重定向或权限拦截时可以把原生 UI 纠正回真实状态。
    _onNativeSelected?.call((call.arguments as num).toInt());
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}

/// 把连续的 Flutter 滚动通知压缩为收起、展开两种意图。
///
/// 这是可选帮助类。业务页面也可以自行决定何时调用 controller.collapse()。
class LiquidTabBarScrollDriver {
  LiquidTabBarScrollDriver(this.controller, {this.threshold = 20});

  final LiquidTabBarController controller;
  final double threshold;

  double? _lastPixels;
  double _distance = 0;
  int _lastDirection = 0;

  /// 直接传给 NotificationListener.onNotification。
  bool onNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _lastPixels = notification.metrics.pixels;
      _distance = 0;
      _lastDirection = 0;
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 0.5) {
      controller.expand();
      return false;
    }

    if (notification is! ScrollUpdateNotification) {
      return false;
    }

    final metrics = notification.metrics;
    final previousPixels = _lastPixels;
    _lastPixels = metrics.pixels;

    if (metrics.pixels <= metrics.minScrollExtent + 0.5) {
      _distance = 0;
      _lastDirection = 0;
      controller.expand();
      return false;
    }

    if (previousPixels == null) {
      return false;
    }

    final delta = metrics.pixels - previousPixels;
    if (delta == 0) {
      return false;
    }

    final direction = delta > 0 ? 1 : -1;
    if (direction != _lastDirection) {
      _lastDirection = direction;
      _distance = 0;
    }

    _distance += delta.abs();
    if (_distance >= threshold) {
      _distance = 0;
      controller.setCollapsed(direction > 0);
    }

    return false;
  }
}

/// iOS 26+ 使用 UIKit Liquid Glass；iOS 26 以下使用原生模糊降级；
/// Android 和其他平台使用 Flutter Material 3 NavigationBar。
class LiquidTabBar extends StatefulWidget {
  LiquidTabBar({
    required this.destinations,
    required this.controller,
    required this.onSelected,
    required this.selectedIndex,
    super.key,
    this.height = 72,
  }) : assert(destinations.length >= 2 && destinations.length <= 5),
       assert(_hasUniqueIds(destinations)),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length),
       assert(height >= 56);

  final List<LiquidTabBarDestination> destinations;
  final LiquidTabBarController controller;

  /// 选择请求由宿主提交；例如在这里调用 StatefulNavigationShell.goBranch。
  final ValueChanged<int> onSelected;

  /// 唯一的选中状态来源。使用 go_router 时传入 navigationShell.currentIndex。
  final int selectedIndex;
  final double height;

  static bool _hasUniqueIds(List<LiquidTabBarDestination> destinations) {
    return destinations.map((destination) => destination.id).toSet().length ==
        destinations.length;
  }

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> {
  int? _viewId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant LiquidTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      oldWidget.controller._detach();
      widget.controller.addListener(_onControllerChanged);
      final viewId = _viewId;
      if (viewId != null) {
        widget.controller._attach(
          viewId,
          widget.selectedIndex,
          widget.onSelected,
        );
      }
    } else {
      if (oldWidget.selectedIndex != widget.selectedIndex) {
        widget.controller._setSelected(widget.selectedIndex);
      }
      if (oldWidget.onSelected != widget.onSelected) {
        // 原生 View 没有重建时，也要替换它回调到 Dart 的闭包。
        widget.controller._updateOnNativeSelected(widget.onSelected);
      }
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    widget.controller._attach(viewId, widget.selectedIndex, widget.onSelected);
  }

  void _onFallbackSelected(int index) => widget.onSelected(index);

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 浏览器可以报告 iOS 平台，例如 Safari；Web 没有 UiKitView，必须降级。
    final usesNativeIosRenderer =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final child = usesNativeIosRenderer
        ? UiKitView(
            // 导航配置变化时重建原生 View；controller 状态变化不会改变这个 key。
            key: ValueKey<String>(
              'liquid-tab-bar-ios:${_destinationSignature()}',
            ),
            viewType: 'com.example.liquid_tab_bar',
            layoutDirection: TextDirection.ltr,
            creationParams: _creationParams(),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
            },
          )
        : _FlutterFallback(
            destinations: widget.destinations,
            selectedIndex: widget.selectedIndex,
            collapsed: widget.controller.isCollapsed,
            onSelected: _onFallbackSelected,
          );

    final bar = SizedBox(height: widget.height, child: child);

    // iOS 的悬浮原生栏由插件统一负责底部安全区；Android NavigationBar
    // 自己会处理 Insets，不能再机械叠一层 SafeArea。
    if (usesNativeIosRenderer) {
      return SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: bar,
      );
    }
    return bar;
  }

  Map<String, Object> _creationParams() => <String, Object>{
    'selectedIndex': widget.selectedIndex,
    'collapsed': widget.controller.isCollapsed,
    'revision': widget.controller.revision,
    'destinations': widget.destinations
        .map((destination) => destination.toNativeMap())
        .toList(),
  };

  String _destinationSignature() {
    return widget.destinations
        .map(
          (destination) =>
              '${destination.id}:${destination.label}:${destination.iosSymbolName}:${destination.selectedIosSymbolName}',
        )
        .join('|');
  }
}

class _FlutterFallback extends StatelessWidget {
  const _FlutterFallback({
    required this.destinations,
    required this.selectedIndex,
    required this.collapsed,
    required this.onSelected,
  });

  final List<LiquidTabBarDestination> destinations;
  final int selectedIndex;
  final bool collapsed;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: collapsed ? 0.88 : 1,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, destinations.length - 1).toInt(),
        onDestinationSelected: onSelected,
        destinations: <NavigationDestination>[
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.materialIcon),
              selectedIcon: Icon(
                destination.selectedMaterialIcon ?? destination.materialIcon,
              ),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
