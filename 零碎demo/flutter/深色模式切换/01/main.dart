import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const ThemeRevealDemo());
}

/// 这个示例只依赖 Flutter SDK，方便直接复制到新项目运行
class ThemeRevealDemo extends StatefulWidget {
  const ThemeRevealDemo({super.key});

  @override
  State<ThemeRevealDemo> createState() => _ThemeRevealDemoState();
}

class _ThemeRevealDemoState extends State<ThemeRevealDemo> {
  final GlobalKey _captureKey = GlobalKey();
  final GlobalKey _themeButtonKey = GlobalKey();

  ThemeMode _themeMode = ThemeMode.light;
  bool _isTransitioning = false;
  bool _useSimpleTransition = false;

  Future<void> _toggleTheme() async {
    if (_isTransitioning) return;

    final buttonContext = _themeButtonKey.currentContext;
    if (buttonContext == null) return;

    final targetMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    final shouldSkipAnimation =
        _useSimpleTransition || MediaQuery.disableAnimationsOf(buttonContext);

    // 在异步截图之前读取，避免跨 async gap 持有 BuildContext
    final pixelRatio = math.min(
      MediaQuery.devicePixelRatioOf(buttonContext),
      2.0,
    );

    // 用户要求减少动态效果，或策略已决定降级时，直接提交主题即可
    if (shouldSkipAnimation) {
      setState(() => _themeMode = targetMode);
      return;
    }

    final overlay = Overlay.of(buttonContext, rootOverlay: true);
    final buttonBox = buttonContext.findRenderObject();
    if (buttonBox is! RenderBox) {
      setState(() => _themeMode = targetMode);
      return;
    }

    setState(() => _isTransitioning = true);

    ui.Image? oldFrame;
    var handedToOverlay = false;

    try {
      // 保证 RepaintBoundary 已经完成绘制，才能安全地截到旧主题
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || !buttonContext.mounted) return;

      final renderObject = _captureKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary ||
          renderObject.debugNeedsPaint) {
        _commitImmediately(targetMode);
        return;
      }

      // 全分辨率截图在高 DPR 设备上很贵，2.0 是 Demo 的保守预算
      oldFrame = await renderObject.toImage(pixelRatio: pixelRatio);
      if (!mounted || !buttonContext.mounted) return;

      // 截图期间窗口可能旋转或尺寸变化，所以这里重新读取 Overlay 几何信息
      final overlayObject = overlay.context.findRenderObject();
      final currentButtonObject = buttonContext.findRenderObject();
      if (overlayObject is! RenderBox || currentButtonObject is! RenderBox) {
        _commitImmediately(targetMode);
        return;
      }

      final globalCenter = currentButtonObject.localToGlobal(
        currentButtonObject.size.center(Offset.zero),
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
              entry.remove();
              entry.dispose();
              frame.dispose();

              if (mounted) {
                setState(() => _isTransitioning = false);
              }
            },
          );
        },
      );

      // 先把旧帧盖住，再提交新主题
      overlay.insert(entry);
      handedToOverlay = true;
      setState(() => _themeMode = targetMode);
    } catch (error, stackTrace) {
      debugPrint('主题圆形转场失败，已降级为直接切换：$error\n$stackTrace');
      _commitImmediately(targetMode);
    } finally {
      // Overlay 成功接管后由动画结束回调释放，失败路径在这里兜底
      if (!handedToOverlay) {
        oldFrame?.dispose();
      }
    }
  }

  void _commitImmediately(ThemeMode targetMode) {
    if (!mounted) return;

    setState(() {
      _themeMode = targetMode;
      _isTransitioning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),

      // 圆形揭露是唯一的视觉过渡，不能再叠一层 AnimatedTheme 插值
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) {
        // 截取 Navigator 及其 Overlay 里的 Flutter 内容，不截取系统状态栏
        return RepaintBoundary(
          key: _captureKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _HomePage(
        themeButtonKey: _themeButtonKey,
        isTransitioning: _isTransitioning,
        useSimpleTransition: _useSimpleTransition,
        onToggleTheme: _toggleTheme,
        onSimpleTransitionChanged: (value) {
          setState(() => _useSimpleTransition = value);
        },
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.themeButtonKey,
    required this.isTransitioning,
    required this.useSimpleTransition,
    required this.onToggleTheme,
    required this.onSimpleTransitionChanged,
  });

  final GlobalKey themeButtonKey;
  final bool isTransitioning;
  final bool useSimpleTransition;
  final VoidCallback onToggleTheme;
  final ValueChanged<bool> onSimpleTransitionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HeroMode(
      // 动画期间拒绝新的 Hero 飞行，避免它和主题 Overlay 争夺同一层级
      enabled: !isTransitioning,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('圆形主题转场 Demo'),
          actions: [
            IconButton(
              key: themeButtonKey,
              tooltip: isDark ? '切换到浅色模式' : '切换到深色模式',
              onPressed: isTransitioning ? null : onToggleTheme,
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            ),
          ],
        ),
        body: AbsorbPointer(
          // 页面本身也停止接收输入，和 Overlay 的输入锁形成双保险
          absorbing: isTransitioning,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Hero(
                tag: 'theme-reveal-card',
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const _DetailPage(),
                        ),
                      );
                    },
                    child: Container(
                      height: 180,
                      color: colorScheme.primaryContainer,
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        '点击测试 Hero 路由转场（这里我带了 Hero，转场运行的时候，页面会暂时拒绝导航，这样可以避免 Hero 飞行和截图 Overlay 争抢）',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用普通切换'),
                subtitle: const Text(
                  '模拟低端机、截图不可靠或减少动态效果时的降级策略。',
                ),
                value: useSimpleTransition,
                onChanged: onSimpleTransitionChanged,
              ),
              const SizedBox(height: 12),
              Text(
                isTransitioning
                    ? '正在交接画面，请稍等一下。'
                    : '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Hero 详情页')),
      body: Center(
        child: Hero(
          tag: 'theme-reveal-card',
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 280,
              height: 280,
              color: colorScheme.primaryContainer,
              alignment: Alignment.center,
              child: Text(
                '这里是详情页',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
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

    // 先让新主题在旧截图下面完成一帧绘制，再开始挖洞
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
        // 不能用 IgnorePointer，否则点击会穿透到下面的新页面
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 用实际 Overlay 的约束算半径，嵌套 Navigator 也不会坐标错位
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

  // 多给 1 个逻辑像素，避免抗锯齿在角落留下旧主题细线
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

    // evenOdd 让矩形减去圆形，留下的正好是仍要显示的旧画面
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
