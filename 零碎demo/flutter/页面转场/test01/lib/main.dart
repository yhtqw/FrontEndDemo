import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'reveal_route.dart';

final routeObserver = RouteObserver<ModalRoute<dynamic>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.FragmentProgram? program;
  
  try {
    program = await ui.FragmentProgram.fromAsset('shaders/reveal.frag');
  } catch (error, stack) {
    // 资源失败时仍可进入应用，转场退回淡入。
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: '转场预加载'),
    );
  }
  
  runApp(DemoApp(program: program));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.program});
  final ui.FragmentProgram? program;
  
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorObservers: [routeObserver],
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xffa7f3d0),
      scaffoldBackgroundColor: const Color(0xff101b30),
      useMaterial3: true,
    ),
    home: Lobby(program: program),
  );
}

class Lobby extends StatefulWidget {
  const Lobby({super.key, required this.program});
  final ui.FragmentProgram? program;
  
  @override
  State<Lobby> createState() => _LobbyState();
}

class _LobbyState extends State<Lobby> with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  ModalRoute<dynamic>? _route;
  Timer? _supplyTimer;
  int _seconds = 120;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  void _resume() {
    if (!_pulse.isAnimating) _pulse.repeat();
    
    _supplyTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 120);
    });
  }

  void _pause() {
    _pulse.stop();
    _supplyTimer?.cancel();
    _supplyTimer = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    
    if (route != _route) {
      routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) routeObserver.subscribe(this, route);
    }
  }

  // 本例推入即暂停，让过渡期间的背景保持静止。
  @override
  void didPushNext() => _pause();
  
  @override
  void didPopNext() => _resume();

  Future<void> _open(RevealEffect effect, Offset globalPosition) async {
    if (_opening) return;
    
    _opening = true;
    final navigator = Navigator.of(context);
    final box = navigator.context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final origin = Offset(
      (local.dx / box.size.width).clamp(0.0, 1.0),
      (local.dy / box.size.height).clamp(0.0, 1.0),
    );
    
    try {
      final route = RevealRoute(
        program: widget.program,
        effect: effect,
        origin: origin,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        page: const Expedition(),
      );
      
      await navigator.push<void>(route);
      await route.completed; // 退出动画结束后才允许下一次跳转。
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pause();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: Landscape(_pulse))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOVA / PLAY',
                  style: TextStyle(
                    letterSpacing: 3,
                    fontSize: 13,
                    color: Color(0xffa7f3d0),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '星河大厅',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '下一场补给  ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                for (final effect in RevealEffect.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Builder(
                      builder: (cardContext) => InkWell(
                        key: ValueKey(effect),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          final box =
                              cardContext.findRenderObject()! as RenderBox;
                          _open(
                            effect,
                            box.localToGlobal(box.size.center(Offset.zero)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 21,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff1d3049),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                effect.icon,
                                color: const Color(0xffa7f3d0),
                                size: 28,
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Text(
                                  effect.label,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class Expedition extends StatefulWidget {
  const Expedition({super.key});
  
  @override
  State<Expedition> createState() => _ExpeditionState();
}

class _ExpeditionState extends State<Expedition> {
  int _stars = 0;
  
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff1ad79),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: Landscape(null, sunset: true)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('back'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
                const Text(
                  'SEASON 07',
                  style: TextStyle(color: Color(0xfffff2df), letterSpacing: 3),
                ),
                const SizedBox(height: 12),
                const Text(
                  '落日航线',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: Color(0xfffff2df),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '已收集 $_stars 枚星片',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xfffff2df),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const ValueKey('collect'),
                  onPressed: () => setState(() => _stars++),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('收集星片'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

extension on RevealEffect {
  String get label => switch (this) {
    RevealEffect.iris => '光圈开场',
    RevealEffect.diamond => '菱形擦除',
    RevealEffect.dissolve => '溶解切换',
  };
  
  IconData get icon => switch (this) {
    RevealEffect.iris => Icons.circle_outlined,
    RevealEffect.diamond => Icons.diamond_outlined,
    RevealEffect.dissolve => Icons.grain,
  };
}

class Landscape extends CustomPainter {
  const Landscape(this.pulse, {this.sunset = false}) : super(repaint: pulse);
  final Animation<double>? pulse;
  final bool sunset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sunset
              ? const [Color(0xffffd7a5), Color(0xffe9866b)]
              : const [Color(0xff101b30), Color(0xff284765)],
        ).createShader(rect),
    );
    final paint = Paint();
    
    if (!sunset) {
      final glow = 0.55 + 0.35 * math.sin((pulse?.value ?? 0) * math.pi * 2);
      for (var i = 0; i < 38; i++) {
        final x = ((i * 73 + 17) % 101) / 101 * size.width;
        final y = ((i * 29 + 11) % 97) / 97 * size.height * 0.58;
        canvas.drawCircle(
          Offset(x, y),
          i.isEven ? 1.6 : 1,
          paint..color = Colors.white.withValues(alpha: glow),
        );
      }
    }
    
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.30),
      size.width * 0.16,
      paint..color = sunset ? const Color(0xffffecbc) : const Color(0xffb4d9d7),
    );
    
    for (var layer = 0; layer < 3; layer++) {
      final base = size.height * (0.51 + layer * 0.12);
      final path = Path()..moveTo(0, base);
    
      for (var i = 0; i <= 8; i++) {
        path.lineTo(
          size.width * i / 8,
          base - math.sin(i * 1.7 + layer) * size.height * 0.055,
        );
      }
      
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      
      canvas.drawPath(
        path,
        paint
          ..color = (sunset
              ? const [Color(0xffcc7970), Color(0xffa85f68), Color(0xff704b60)]
              : const [
                  Color(0xff35576b),
                  Color(0xff24415b),
                  Color(0xff172a42),
                ])[layer],
      );
    }
  }

  @override
  bool shouldRepaint(Landscape oldDelegate) => oldDelegate.sunset != sunset || oldDelegate.pulse != pulse;
}
