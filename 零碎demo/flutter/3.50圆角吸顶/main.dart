import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6655DD)),
        scaffoldBackgroundColor: const Color(0xFFF3F1F8),
      ),
      home: const PreviewPage(),
    );
  }
}

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> with WidgetsBindingObserver {
  final _productKey = GlobalKey();
  RawDialogRoute<void>? _previewRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 示例采用位置快照；窗口变化时关闭，避免孔洞错位。
    final route = _previewRoute;
    if (route != null && route.isCurrent) {
      route.navigator?.pop();
    }
  }

  Future<void> _openPreview({required bool spotlight}) async {
    // 连退出阶段也保留锁，防止多层滤镜叠加。
    if (_previewRoute != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlayBox =
        navigator.overlay!.context.findRenderObject()! as RenderBox;
    final productBox =
        _productKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = productBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final target = origin & productBox.size;
    final reduceMotion =
        MediaQuery.reduceMotionOf(context) ||
        MediaQuery.disableAnimationsOf(context);

    final route = RawDialogRoute<void>(
      barrierColor: const Color(0x00000000),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      barrierBuilder: (context, details, barrier) => AnimatedDialogBarrier(
        animation: details.animation,
        barrier: barrier,
        target: spotlight ? target : null,
      ),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PreviewPanel(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 派生动画不创建控制器，由路由管理生命周期。
        final progress = animation.drive(
          CurveTween(curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: progress,
          child: ScaleTransition(
            scale: progress.drive(Tween<double>(begin: 0.96, end: 1)),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
    );

    _previewRoute = route;
    try {
      await navigator.push<void>(route);
      // push 的结果返回时，退场动画可能还没结束。
      await route.completed;
    } finally {
      _previewRoute = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Studio Store',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  key: _productKey,
                  height: 200,
                  child: const ProductCard(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openPreview(spotlight: false),
                        child: const Text('Blur'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _openPreview(spotlight: true),
                        child: const Text('Spotlight'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ListTile(
                  leading: Icon(Icons.graphic_eq),
                  title: Text('Spatial audio'),
                  subtitle: Text('More detail in every track'),
                ),
                const ListTile(
                  leading: Icon(Icons.battery_full),
                  title: Text('40 hours'),
                  subtitle: Text('Ready for the whole week'),
                ),
                const ListTile(
                  leading: Icon(Icons.local_shipping_outlined),
                  title: Text('Free delivery'),
                  subtitle: Text('Ships within 2 days'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF7565ED), Color(0xFFBBAFF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.headphones_rounded, size: 96, color: Colors.white),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Orbit One\n\$129',
                style: TextStyle(
                  fontSize: 25,
                  height: 1.6,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 432),
            child: Material(
              color: const Color(0xFFFEFCFF),
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Orbit One\n\$129',
                        style: TextStyle(fontSize: 24, height: 1.5),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '关闭预览',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedDialogBarrier extends StatelessWidget {
  const AnimatedDialogBarrier({
    super.key,
    required this.animation,
    required this.barrier,
    this.target,
  });

  final Animation<double> animation;
  final Widget barrier;
  final Rect? target;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: barrier,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(animation.value);
        final sigma = 12 * t;
        final hole = target?.inflate(8 * t);
        return Stack(
          fit: StackFit.expand,
          children: [
            // 只裁剪视觉层，透明孔洞仍受完整遮罩保护。
            IgnorePointer(
              child: ClipPath(
                clipper: SpotlightClipper(hole),
                child: BackdropFilter(
                  enabled: sigma > 0,
                  filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF161026).withValues(alpha: 0.24 * t),
                          const Color(0xFF161026).withValues(alpha: 0.54 * t),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }
}

class SpotlightClipper extends CustomClipper<Path> {
  const SpotlightClipper(this.hole);

  final Rect? hole;

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      path
        ..fillType = PathFillType.evenOdd
        ..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(24)));
    }
    return path;
  }

  @override
  bool shouldReclip(SpotlightClipper oldClipper) => oldClipper.hole != hole;
}
