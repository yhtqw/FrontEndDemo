import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LiquidNavShader.preload();
  runApp(const GlassDemoApp());
}

class GlassDemoApp extends StatefulWidget {
  const GlassDemoApp({super.key});

  @override
  State<GlassDemoApp> createState() => _GlassDemoAppState();
}

class _GlassDemoAppState extends State<GlassDemoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: ArticlePage(
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
          });
        },
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final seed = brightness == Brightness.dark
        ? const Color(0xFF9EBBFF)
        : const Color(0xFF315FDD);
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
      useMaterial3: true,
    );
  }
}

class ArticlePage extends StatefulWidget {
  const ArticlePage({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  static const double _collapseRange = 128;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCollapse);
  }

  void _updateCollapse() {
    _collapse.value = (_scrollController.offset / _collapseRange).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateCollapse)
      ..dispose();
    _collapse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101318) : const Color(0xFFF6F7FB),
      body: Stack(
        children: <Widget>[
          _ArticleScrollView(controller: _scrollController),
          ValueListenableBuilder<double>(
            valueListenable: _collapse,
            builder: (context, progress, _) {
              return GlassNavigationBar(
                progress: progress,
                onToggleTheme: widget.onToggleTheme,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArticleScrollView extends StatelessWidget {
  const _ArticleScrollView({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paragraphs = <String>[
      '测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本'
      '测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本',
      '测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本',
      '测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本',
      '测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本测试文本',
    ];

    return CustomScrollView(
      controller: controller,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _Hero(dark: dark),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          sliver: SliverList.separated(
            itemCount: 5,
            itemBuilder: (context, index) {
              final paragraph = paragraphs[index % paragraphs.length];
              return _ArticleCard(
                index: index,
                paragraph: paragraph,
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 14),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      padding: const EdgeInsets.fromLTRB(24, 160, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const <Color>[Color(0xFF152548), Color(0xFF6B3E78), Color(0xFF151C33)]
              : const <Color>[Color(0xFFD9E9FF), Color(0xFFEFD8FF), Color(0xFFBFE7E1)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text('测试文本', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            '测试标题',
            style: TextStyle(fontSize: 32, height: 1.08, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.index, required this.paragraph});

  final int index;
  final String paragraph;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('0${index + 1}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(paragraph, style: const TextStyle(fontSize: 16, height: 1.7)),
          ],
        ),
      ),
    );
  }
}

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.progress,
    required this.onToggleTheme,
  });

  final double progress;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final compactHeight = 56.0;
    final expandedHeight = 116.0;
    final barHeight = ui.lerpDouble(expandedHeight, compactHeight, progress)!;
    final highContrast = mediaQuery.highContrast;
    final reduceMotion = mediaQuery.disableAnimations ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

    final lightProgress = reduceMotion ? 0.0 : progress;
    final lightX = ui.lerpDouble(0.22, 0.78, lightProgress)!;
    final lightY = 0.18 + math.sin(lightProgress * math.pi) * 0.22;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: SizedBox(
          height: barHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                LiquidGlassFilter(
                  scrollProgress: progress,
                  lightX: lightX,
                  lightY: lightY,
                  isDark: dark,
                  highContrast: highContrast,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (dark ? Colors.white : Colors.white)
                          .withValues(alpha: dark ? 0.18 : 0.58),
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                _NavigationContent(
                  progress: progress,
                  onToggleTheme: onToggleTheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationContent extends StatelessWidget {
  const _NavigationContent({required this.progress, required this.onToggleTheme});

  final double progress;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inlineOpacity = Curves.easeOut.transform(progress);
    final largeOpacity = 1 - Curves.easeIn.transform(progress);
    final largeScale = ui.lerpDouble(1.0, 0.90, progress)!;

    return Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 56,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 8),
                _RoundAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: '返回',
                  onPressed: () {},
                ),
                Expanded(
                  child: Opacity(
                    opacity: inlineOpacity,
                    child: Center(
                      child: Text(
                        'Liquid Glass',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                _RoundAction(
                  icon: Icons.dark_mode_outlined,
                  tooltip: '切换深浅色',
                  onPressed: onToggleTheme,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 14,
          child: IgnorePointer(
            ignoring: progress > 0.8,
            child: Opacity(
              opacity: largeOpacity,
              child: Transform.scale(
                alignment: Alignment.centerLeft,
                scale: largeScale,
                child: Text(
                  '玻璃导航栏',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(40),
        maximumSize: const Size.square(40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class LiquidGlassFilter extends StatefulWidget {
  const LiquidGlassFilter({
    super.key,
    required this.scrollProgress,
    required this.lightX,
    required this.lightY,
    required this.isDark,
    required this.highContrast,
  });

  final double scrollProgress;
  final double lightX;
  final double lightY;
  final bool isDark;
  final bool highContrast;

  @override
  State<LiquidGlassFilter> createState() => _LiquidGlassFilterState();
}

class _LiquidGlassFilterState extends State<LiquidGlassFilter> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _createShader();
  }

  Future<void> _createShader() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    final program = await LiquidNavShader.program;
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.highContrast) {
      return ColoredBox(
        color: widget.isDark ? const Color(0xFF171A20) : const Color(0xFFF8FAFF),
      );
    }

    final shader = _shader;
    if (shader == null) {
      return _FrostedFallback(isDark: widget.isDark);
    }

    shader
      ..setFloat(2, widget.scrollProgress)
      ..setFloat(3, widget.lightX)
      ..setFloat(4, widget.lightY)
      ..setFloat(5, widget.isDark ? 1 : 0);

    return BackdropFilter(
      filter: ui.ImageFilter.shader(shader),
      child: const SizedBox.expand(),
    );
  }
}

class _FrostedFallback extends StatelessWidget {
  const _FrostedFallback({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: ColoredBox(
        color: isDark
            ? const Color(0xCC1A1D24)
            : const Color(0xBFF9FBFF),
      ),
    );
  }
}

class LiquidNavShader {
  static ui.FragmentProgram? _program;

  static Future<void> preload() async {
    _program ??= await ui.FragmentProgram.fromAsset('shaders/liquid_nav.frag');
  }

  static Future<ui.FragmentProgram> get program async {
    await preload();
    return _program!;
  }
}
