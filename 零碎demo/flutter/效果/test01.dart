/*
需要安装 flutter_shaders_ui: 1.2.0
*/

import 'package:flutter/material.dart';
import 'package:flutter_shaders_ui/flutter_shaders_ui.dart';

final RouteObserver<ModalRoute<dynamic>> routeObserver =
RouteObserver<ModalRoute<dynamic>>();

void main() {
  runApp(const ShaderDemoApp());
}

class ShaderDemoApp extends StatelessWidget {
  const ShaderDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      navigatorObservers: [routeObserver],
      home: const ShaderDemoPage(),
    );
  }
}

enum EffectKind { aurora, wave, fire, water }

extension EffectKindLabel on EffectKind {
  String get label => switch (this) {
    EffectKind.aurora => '极光',
    EffectKind.wave => '波浪',
    EffectKind.fire => '火焰',
    EffectKind.water => '水波',
  };
}

class ShaderDemoPage extends StatefulWidget {
  const ShaderDemoPage({super.key});

  @override
  State<ShaderDemoPage> createState() => _ShaderDemoPageState();
}

class _ShaderDemoPageState extends State<ShaderDemoPage>
    with WidgetsBindingObserver, RouteAware {
  late final AppLifecycleListener _lifecycleListener;

  ModalRoute<dynamic>? _subscribedRoute;
  EffectKind _effect = EffectKind.aurora;

  bool _routeVisible = true;
  bool _appForeground = true;
  bool _userAllowsMotion = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final initialState = WidgetsBinding.instance.lifecycleState;
    _appForeground =
        initialState == null || initialState == AppLifecycleState.resumed;

    // 用现代生命周期 API 处理前后台，不需要自己维护 binding 回调。
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChanged,
    );
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;

    if (mounted && isForeground != _appForeground) {
      setState(() => _appForeground = isForeground);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();

    // iOS Reduce Motion 变化不会自动成为 widget 依赖，需要主动刷新。
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route != null && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        routeObserver.unsubscribe(this);
      }

      _subscribedRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  void _setRouteVisible(bool value) {
    if (mounted && value != _routeVisible) {
      setState(() => _routeVisible = value);
    }
  }

  @override
  void didPush() => _setRouteVisible(true);

  @override
  void didPopNext() => _setRouteVisible(true);

  @override
  void didPushNext() => _setRouteVisible(false);

  @override
  void didPop() => _setRouteVisible(false);

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _lifecycleListener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // iOS 的 Reduce Motion 不会设置 disableAnimations，需要单独处理。
    final iosReduceMotion =
        View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

    final systemWantsLessMotion = disableAnimations || iosReduceMotion;

    // 页面不可见、进后台或用户关闭效果时，连 shader 绘制都不做。
    final renderShader = _routeVisible &&
        _appForeground &&
        _userAllowsMotion &&
        TickerMode.of(context);

    // flutter_shaders_ui 会处理 disableAnimations；
    // 这里额外覆盖 iOS 的 Reduce Motion。
    final tickShader = renderShader && !iosReduceMotion;

    final status = !_userAllowsMotion
        ? '动态背景已由应用内开关关闭'
        : !renderShader
        ? '当前页面不可见或应用不在前台，Shader 已暂停'
        : systemWantsLessMotion
        ? '系统要求减少动态，保留静态背景'
        : '前台可见，Shader 上限为 30 FPS';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Shader 被关掉时，仍然保留经过设计的静态底色。
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF101827),
                  Color(0xFF07111F),
                ],
              ),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: TickerMode(
                enabled: tickShader,
                child: ShaderPerformance(
                  settings: const ShaderPerformanceSettings(
                    maxFramesPerSecond: 30,
                    respectReducedMotion: true,
                  ),
                  child: _buildEffect(enabled: renderShader),
                ),
              ),
            ),
          ),

          // 包内部已经隔离 shader 画布；
          // 这里再隔离静态前景，避免背景 repaint 带上控制面板。
          RepaintBoundary(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shader Playground',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<EffectKind>(
                              segments: EffectKind.values.map(
                                (effect) => ButtonSegment<EffectKind>(
                                  value: effect,
                                  label: Text(effect.label),
                                ),
                              ).toList(),
                              selected: {_effect},
                              onSelectionChanged: (selection) {
                                setState(() => _effect = selection.first);
                              },
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('动态背景'),
                              subtitle: const Text(
                                '关闭后不再进行 shader 绘制，只保留静态配色',
                              ),
                              value: _userAllowsMotion,
                              onChanged: (value) {
                                setState(() => _userAllowsMotion = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const CoveredPage(),
                                  ),
                                );
                              },
                              child: const Text('打开下一页，验证路由暂停'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffect({required bool enabled}) {
    return switch (_effect) {
      EffectKind.aurora => AuroraEffect(
        enabled: enabled,
        color1: const Color(0xFF3BF5A2),
        color2: const Color(0xFF8B5CF6),
        intensity: 0.52,
        speed: 0.38,
      ),
      EffectKind.wave => WaveBackground(
        enabled: enabled,
        color1: const Color(0xFF06285B),
        color2: const Color(0xFF00E5C7),
        amplitude: 0.8,
        frequency: 2,
        speed: 0.9,
      ),
      EffectKind.fire => FireEffect(
        enabled: enabled,
        intensity: 0.42,
        speed: 0.45,
        color1: const Color(0xFFFFE082),
        color2: const Color(0xFFFF5722),
      ),
      EffectKind.water => WaterEffect(
        enabled: enabled,
        speed: 0.35,
        depth: 0.58,
        waveIntensity: 0.30,
        causticIntensity: 0.42,
        foamAmount: 0.0,
      ),
    };
  }
}

class CoveredPage extends StatelessWidget {
  const CoveredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下一页')),
      body: const Center(
        child: Text('返回上一页以后，Shader 才会恢复。'),
      ),
    );
  }
}
