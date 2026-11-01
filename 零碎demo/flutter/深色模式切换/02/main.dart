import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const OverlayMotionDemo());
}

enum MotionKind { theme, tab }

/// 所有会改变大范围画面的效果，都先经过这里排队。
class AppMotionCoordinator extends ChangeNotifier {
  MotionKind? _activeEffect;
  bool _routeTransitioning = false;
  bool _routeGestureInProgress = false;

  MotionKind? get activeEffect => _activeEffect;

  bool get isBusy =>
      _activeEffect != null ||
          _routeTransitioning ||
          _routeGestureInProgress;

  bool tryStartEffect(MotionKind kind) {
    if (isBusy) return false;

    _activeEffect = kind;
    notifyListeners();
    return true;
  }

  void finishEffect(MotionKind kind) {
    if (_activeEffect != kind) return;

    _activeEffect = null;
    notifyListeners();
  }

  void setRouteTransitioning(bool value) {
    if (_routeTransitioning == value) return;

    _routeTransitioning = value;
    notifyListeners();
  }

  void setRouteGestureInProgress(bool value) {
    if (_routeGestureInProgress == value) return;

    _routeGestureInProgress = value;
    notifyListeners();
  }
}

/// 观察 PageRoute 的动画状态，把 Hero 所在的路由转场也纳入协调器。
class MotionNavigatorObserver extends NavigatorObserver {
  MotionNavigatorObserver(this.coordinator);

  final AppMotionCoordinator coordinator;
  final Set<Route<dynamic>> _inFlightRoutes = <Route<dynamic>>{};
  final Map<Route<dynamic>, void Function(AnimationStatus)> _listeners =
  <Route<dynamic>, void Function(AnimationStatus)>{};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _watch(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _watch(route);
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    _watch(newRoute);
    _watch(oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stopWatching(route);
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route,
      Route<dynamic>? previousRoute,
      ) {
    coordinator.setRouteGestureInProgress(true);
  }

  @override
  void didStopUserGesture() {
    coordinator.setRouteGestureInProgress(false);
  }

  void _watch(Route<dynamic>? route) {
    if (route is! TransitionRoute<dynamic> ||
        _listeners.containsKey(route)) {
      return;
    }

    final animation = route.animation;
    if (animation == null) return;

    var hasStarted = false;
    late final void Function(AnimationStatus) listener;

    listener = (status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        hasStarted = true;
        _inFlightRoutes.add(route);
        _publishRouteState();
        return;
      }

      // 初始路由可能一进来就是 dismissed，不能提前移除监听。
      if (hasStarted &&
          (status == AnimationStatus.completed ||
              status == AnimationStatus.dismissed)) {
        _stopWatching(route);
      }
    };

    _listeners[route] = listener;
    animation.addStatusListener(listener);
    listener(animation.status);
  }

  void _stopWatching(Route<dynamic> route) {
    final listener = _listeners.remove(route);

    if (route is TransitionRoute<dynamic> && listener != null) {
      route.animation?.removeStatusListener(listener);
    }

    _inFlightRoutes.remove(route);
    _publishRouteState();
  }

  void _publishRouteState() {
    coordinator.setRouteTransitioning(_inFlightRoutes.isNotEmpty);
  }
}

class OverlayMotionDemo extends StatefulWidget {
  const OverlayMotionDemo({super.key});

  @override
  State<OverlayMotionDemo> createState() => _OverlayMotionDemoState();
}

class _OverlayMotionDemoState extends State<OverlayMotionDemo> {
  final GlobalKey _captureKey = GlobalKey();
  final GlobalKey _themeButtonKey = GlobalKey();
  final PageController _pageController = PageController();

  late final AppMotionCoordinator _coordinator;
  late final MotionNavigatorObserver _navigatorObserver;

  ThemeMode _themeMode = ThemeMode.light;
  int _selectedTab = 0;
  bool _useSimpleThemeSwitch = false;
  OverlayEntry? _themeOverlayEntry;
  ui.Image? _themeFrame;

  @override
  void initState() {
    super.initState();
    _coordinator = AppMotionCoordinator();
    _navigatorObserver = MotionNavigatorObserver(_coordinator);
  }

  @override
  void dispose() {
    _removeThemeOverlay();
    _pageController.dispose();
    _coordinator.dispose();
    super.dispose();
  }

  Future<void> _switchTab(int targetTab) async {
    if (targetTab == _selectedTab ||
        !_coordinator.tryStartEffect(MotionKind.tab)) {
      return;
    }

    setState(() => _selectedTab = targetTab);

    try {
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          targetTab,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _coordinator.finishEffect(MotionKind.tab);
    }
  }

  Future<void> _toggleTheme() async {
    if (!_coordinator.tryStartEffect(MotionKind.theme)) return;

    final buttonContext = _themeButtonKey.currentContext;
    if (buttonContext == null) {
      _coordinator.finishEffect(MotionKind.theme);
      return;
    }

    final targetMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    final shouldSkipAnimation =
        _useSimpleThemeSwitch ||
            MediaQuery.disableAnimationsOf(buttonContext);

    if (shouldSkipAnimation) {
      _commitThemeImmediately(targetMode);
      return;
    }

    final pixelRatio = math.min(
      MediaQuery.devicePixelRatioOf(buttonContext),
      2.0,
    );
    final overlay = Overlay.of(buttonContext, rootOverlay: true);

    ui.Image? oldFrame;
    var handedToOverlay = false;

    try {
      // 等当前界面稳定后再截旧帧，绝不能先提交 ThemeMode。
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || !buttonContext.mounted) return;

      final renderObject = _captureKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary ||
          renderObject.debugNeedsPaint) {
        _commitThemeImmediately(targetMode);
        return;
      }

      oldFrame = await renderObject.toImage(pixelRatio: pixelRatio);
      if (!mounted || !buttonContext.mounted) return;

      final overlayObject = overlay.context.findRenderObject();
      final buttonObject = buttonContext.findRenderObject();
      if (overlayObject is! RenderBox || buttonObject is! RenderBox) {
        _commitThemeImmediately(targetMode);
        return;
      }

      final globalCenter = buttonObject.localToGlobal(
        buttonObject.size.center(Offset.zero),
      );
      final origin = overlayObject.globalToLocal(globalCenter);
      final frame = oldFrame;

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) {
          return _ThemeRevealLayer(
            image: frame,
            origin: origin,
            onFinished: () {
              if (_themeOverlayEntry == entry) {
                _removeThemeOverlay();
              }

              if (mounted) {
                _coordinator.finishEffect(MotionKind.theme);
              }
            },
          );
        },
      );

      overlay.insert(entry);
      _themeOverlayEntry = entry;
      _themeFrame = frame;
      handedToOverlay = true;

      // Overlay 已经盖住旧画面，现在再让底层完成主题 rebuild。
      setState(() => _themeMode = targetMode);
    } catch (error, stackTrace) {
      debugPrint('主题转场失败，已退回普通切换：$error\n$stackTrace');

      if (handedToOverlay) {
        _removeThemeOverlay();
      }

      _commitThemeImmediately(targetMode);
    } finally {
      if (!handedToOverlay) {
        oldFrame?.dispose();
      }
    }
  }

  void _commitThemeImmediately(ThemeMode targetMode) {
    if (!mounted) return;

    setState(() => _themeMode = targetMode);
    _coordinator.finishEffect(MotionKind.theme);
  }

  void _removeThemeOverlay() {
    final entry = _themeOverlayEntry;
    final frame = _themeFrame;

    _themeOverlayEntry = null;
    _themeFrame = null;

    entry?.remove();
    entry?.dispose();
    frame?.dispose();
  }

  void _openArticle(BuildContext context, Article article) {
    // Hero 会随路由进 Overlay 飞行；协调器忙碌时不再启动新的飞行。
    if (_coordinator.isBusy) return;

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ArticleDetailPage(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      themeAnimationStyle: AnimationStyle.noAnimation,
      navigatorObservers: <NavigatorObserver>[_navigatorObserver],
      builder: (context, child) {
        // 根边界覆盖 Navigator 与其 Overlay，主题截图只在这里产生一次。
        return RepaintBoundary(
          key: _captureKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AppShell(
        coordinator: _coordinator,
        pageController: _pageController,
        selectedTab: _selectedTab,
        useSimpleThemeSwitch: _useSimpleThemeSwitch,
        themeButtonKey: _themeButtonKey,
        onSelectTab: _switchTab,
        onToggleTheme: _toggleTheme,
        onSimpleThemeSwitchChanged: (value) {
          if (!_coordinator.isBusy) {
            setState(() => _useSimpleThemeSwitch = value);
          }
        },
        onOpenArticle: _openArticle,
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.coordinator,
    required this.pageController,
    required this.selectedTab,
    required this.useSimpleThemeSwitch,
    required this.themeButtonKey,
    required this.onSelectTab,
    required this.onToggleTheme,
    required this.onSimpleThemeSwitchChanged,
    required this.onOpenArticle,
  });

  final AppMotionCoordinator coordinator;
  final PageController pageController;
  final int selectedTab;
  final bool useSimpleThemeSwitch;
  final GlobalKey themeButtonKey;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onToggleTheme;
  final ValueChanged<bool> onSimpleThemeSwitchChanged;
  final void Function(BuildContext context, Article article) onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: coordinator,
      builder: (context, child) {
        final isBusy = coordinator.isBusy;
        final isEffectRunning = coordinator.activeEffect != null;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return HeroMode(
          // 路由转场时仍需允许 Hero 飞行；只在主题或 tab 效果中暂停新 Hero。
          enabled: !isEffectRunning,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('一个 Overlay，三种转场'),
              actions: [
                IconButton(
                  key: themeButtonKey,
                  tooltip: isDark ? '切换到浅色模式' : '切换到深色模式',
                  onPressed: isBusy ? null : onToggleTheme,
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                  ),
                ),
              ],
            ),
            body: AbsorbPointer(
              absorbing: isBusy,
              child: PageView(
                controller: pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FeedTab(
                    useSimpleThemeSwitch: useSimpleThemeSwitch,
                    onSimpleThemeSwitchChanged:
                    onSimpleThemeSwitchChanged,
                    onOpenArticle: onOpenArticle,
                  ),
                  LibraryTab(onOpenArticle: onOpenArticle),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedTab,
              onDestinationSelected: isBusy ? null : onSelectTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: '发现',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  selectedIcon: Icon(Icons.bookmark),
                  label: '收藏',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.color,
  });

  final String id;
  final String title;
  final String summary;
  final Color color;
}

const _featuredArticle = Article(
  id: 'overlay-order',
  title: '别让三种转场抢同一个 Overlay',
  summary: '主题、Hero 和底部导航各自有各自的边界。',
  color: Color(0xFF00695C),
);

const _savedArticle = Article(
  id: 'motion-budget',
  title: '动画预算不是越多越好',
  summary: '让设备把帧时间花在真正有价值的地方。',
  color: Color(0xFF5E35B1),
);

class FeedTab extends StatelessWidget {
  const FeedTab({
    super.key,
    required this.useSimpleThemeSwitch,
    required this.onSimpleThemeSwitchChanged,
    required this.onOpenArticle,
  });

  final bool useSimpleThemeSwitch;
  final ValueChanged<bool> onSimpleThemeSwitchChanged;
  final void Function(BuildContext context, Article article) onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('feed'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '底部导航只负责切换主目的地，Hero 只跟路由走，主题遮罩只在根 Overlay 出现。',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          '把三件事拆开以后，用户连续点按钮时不会出现三套动画互相盖住的情况。',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        ArticleCard(
          article: _featuredArticle,
          onOpenArticle: onOpenArticle,
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('使用普通主题切换'),
          subtitle: const Text('模拟低端机、PlatformView 或无障碍降级。'),
          value: useSimpleThemeSwitch,
          onChanged: onSimpleThemeSwitchChanged,
        ),
      ],
    );
  }
}

class LibraryTab extends StatelessWidget {
  const LibraryTab({
    super.key,
    required this.onOpenArticle,
  });

  final void Function(BuildContext context, Article article) onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('library'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '收藏',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          '这里的 Hero tag 和发现页不同。两个 tab 同时存在于 PageView 时，不能给它们塞相同 tag。',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        ArticleCard(
          article: _savedArticle,
          onOpenArticle: onOpenArticle,
        ),
      ],
    );
  }
}

class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    required this.onOpenArticle,
  });

  final Article article;
  final void Function(BuildContext context, Article article) onOpenArticle;

  @override
  Widget build(BuildContext context) {
    final onColor =
    ThemeData.estimateBrightnessForColor(article.color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Hero(
      tag: 'article-${article.id}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpenArticle(context, article),
          child: Container(
            height: 180,
            color: article.color,
            padding: const EdgeInsets.all(24),
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: onColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  article.summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: onColor.withValues(alpha: 0.9),
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

class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({
    super.key,
    required this.article,
  });

  final Article article;

  @override
  Widget build(BuildContext context) {
    final onColor =
    ThemeData.estimateBrightnessForColor(article.color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Scaffold(
      appBar: AppBar(title: const Text('文章详情')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Hero(
            tag: 'article-${article.id}',
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: 300,
                color: article.color,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomLeft,
                child: Text(
                  article.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: onColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '这里故意使用根 Navigator 的标准路由。Hero 飞行由 Navigator 自己的 '
                'HeroController 管理，主题和 tab 转场则被协调器拦在路由动画之外。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ThemeRevealLayer extends StatefulWidget {
  const _ThemeRevealLayer({
    required this.image,
    required this.origin,
    required this.onFinished,
  });

  final ui.Image image;
  final Offset origin;
  final VoidCallback onFinished;

  @override
  State<_ThemeRevealLayer> createState() => _ThemeRevealLayerState();
}

class _ThemeRevealLayerState extends State<_ThemeRevealLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

    // 先保证新主题已经画在旧帧下面，再开始让圆洞变大。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        // 这层必须吃掉输入，不能让点击穿透到新主题页面。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxRadius = _radiusToCover(
              constraints.biggest,
              widget.origin,
            );

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = Curves.easeInOutCubic.transform(
                  _controller.value,
                );

                return CustomPaint(
                  painter: _OldFramePainter(
                    image: widget.image,
                    origin: widget.origin,
                    radius: maxRadius * progress,
                  ),
                  child: child,
                );
              },
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

double _radiusToCover(Size size, Offset origin) {
  final corners = <Offset>[
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ];

  return corners
      .map((corner) => (corner - origin).distance)
      .reduce(math.max) +
      1;
}

class _OldFramePainter extends CustomPainter {
  const _OldFramePainter({
    required this.image,
    required this.origin,
    required this.radius,
  });

  final ui.Image image;
  final Offset origin;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final destination = Offset.zero & size;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final outsideCircle = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(destination)
      ..addOval(Rect.fromCircle(center: origin, radius: radius));

    canvas.save();
    canvas.clipPath(outsideCircle);
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OldFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.origin != origin ||
        oldDelegate.radius != radius;
  }
}
