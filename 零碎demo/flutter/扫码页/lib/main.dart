import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera_session.dart';
import 'inventory.dart';

final routeObserver = RouteObserver<ModalRoute<void>>();
const ink = Color(0xFF162C2B);
const mint = Color(0xFFB3F36B);

void main() => runApp(const InventoryApp());

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorObservers: [routeObserver],
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F6F0),
      colorScheme: ColorScheme.fromSeed(seedColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F6F0),
        foregroundColor: ink,
      ),
    ),
    home: const InventoryHome(),
  );
}

class InventoryHome extends StatefulWidget {
  const InventoryHome({super.key});

  @override
  State<InventoryHome> createState() => _InventoryHomeState();
}

class _InventoryHomeState extends State<InventoryHome> {
  final store = InventoryStore();

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('库存工作台')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text(
            '收货入库',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '扫描商品，核对本次待录入清单。',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (_, _) => InventoryList(store: store),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  padding: const EdgeInsets.all(20),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('开始扫码', style: TextStyle(fontSize: 17)),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => ScannerPage(store: store)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ScannerCamera implements CameraPort {
  ScannerCamera(this.controller);
  final MobileScannerController controller;
  bool _closed = false;

  @override
  Future<void> start() async {
    if (_closed) return;
    await controller.start();
    if (_closed) return; // 销毁后的延迟完成不能再读取 Controller。
    final state = controller.value;
    if (state.error != null) throw state.error!;
    if (!state.isRunning) throw StateError('相机尚未运行');
  }

  @override
  Future<void> stop() async {
    if (!_closed) await controller.stop();
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    await controller.dispose();
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.store});
  final InventoryStore store;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with SingleTickerProviderStateMixin, RouteAware {
  final camera = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 350,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
      BarcodeFormat.code128,
    ],
  );
  late final session = CameraSession(ScannerCamera(camera));
  late final intake = ScanIntake(widget.store);
  late final line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AppLifecycleListener lifecycle;
  StreamSubscription<BarcodeCapture>? subscription;
  ModalRoute<void>? observedRoute;
  bool foreground = false;
  bool routeVisible = true;
  bool wantsScan = true;
  bool leaving = false;
  bool awaitingSettings = false;
  bool permissionBlocked = false;
  int permissionCheck = 0;
  String? eventError;

  @override
  void initState() {
    super.initState();
    foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    session.addListener(_changed);
    intake.addListener(_rebuild);
    widget.store.addListener(_rebuild);
    subscription = camera.barcodes.listen(
      _capture,
      onError: (Object error, StackTrace stack) {
        if (!mounted || leaving) return;
        setState(() => eventError = '识别暂时失败，请重试');
        debugPrint('barcode error: $error\n$stack');
      },
    );
    lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        foreground = state == AppLifecycleState.resumed;
        if (foreground && awaitingSettings) {
          unawaited(_returnFromSettings());
        } else {
          _sync();
        }
      },
    );
    // 先让预览挂接 Controller，再按当前条件启动。
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<void>(context);
    if (route != observedRoute) {
      routeObserver.unsubscribe(this);
      observedRoute = route;
      if (route != null) routeObserver.subscribe(this, route);
    }
    _syncAnimation();
  }

  @override
  void didPushNext() {
    routeVisible = false;
    _sync();
  }

  @override
  void didPopNext() {
    routeVisible = true;
    _sync();
  }

  @override
  void didPop() => _close();

  void _sync() {
    if (leaving || !mounted) return;
    session.setDesired(
      foreground &&
          routeVisible &&
          wantsScan &&
          !awaitingSettings &&
          !permissionBlocked,
    );
    _changed();
  }

  void _changed() {
    if (!mounted || leaving) return;
    final active = session.running && session.desired && !session.closed;
    intake.setActive(active);
    _syncAnimation();
    _rebuild();
  }

  void _syncAnimation() {
    if (!mounted || leaving) return;
    final active = session.running && session.desired && !session.closed;
    if (active && !MediaQuery.disableAnimationsOf(context)) {
      if (!line.isAnimating) line.repeat();
    } else {
      line.stop();
    }
  }

  void _rebuild() {
    if (mounted && !leaving) setState(() {});
  }

  void _capture(BarcodeCapture capture) {
    if (leaving || !session.desired || !session.running) return;
    // 多个不同条码同时入框时让用户重新对准，不依赖返回顺序。
    final codes = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet();
    if (codes.length != 1) return;
    unawaited(_accept(codes.single));
  }

  Future<void> _accept(String code) async {
    if (await intake.accept(code) &&
        mounted &&
        !leaving &&
        foreground &&
        routeVisible) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {
        /* 反馈失败不影响录入。 */
      }
    }
  }

  Future<void> _settings() async {
    if (awaitingSettings || leaving) return;
    awaitingSettings = true;
    _sync();
    
    try {
      final opened = await openAppSettings();
      if (!opened && mounted && !leaving) {
        awaitingSettings = false;
        setState(() => eventError = '无法打开设置，请在系统设置中授权');
        _sync();
      }
    } catch (error) {
      if (!mounted || leaving) return;
      awaitingSettings = false;
      setState(() => eventError = '打开设置失败，请重试');
      _sync();
    }
  }

  Future<void> _returnFromSettings() async {
    final check = ++permissionCheck;
    
    try {
      final status = await Permission.camera.status;
      if (!mounted || leaving || !foreground || check != permissionCheck) {
        return;
      }
      awaitingSettings = false;
      permissionBlocked = !status.isGranted;
      if (status.isGranted) {
        eventError = null;
        session.retry();
      } else {
        eventError = '尚未获得相机权限';
      }
      _sync();
    } catch (error) {
      if (!mounted || leaving || !foreground || check != permissionCheck) {
        return;
      }
      awaitingSettings = false;
      permissionBlocked = true;
      eventError = '权限检查失败，请重试';
      _sync();
    }
  }

  void _retry() {
    eventError = null;
    permissionBlocked = false;
    session.retry();
    _sync();
  }

  void _close() {
    if (leaving) return;
    leaving = true;
    permissionCheck++;
    intake.setActive(false);
    line.stop();
    session.removeListener(_changed);
    unawaited(
      subscription?.cancel().catchError((Object e) => debugPrint('cancel: $e')),
    );
    subscription = null;
    unawaited(
      session.close().catchError(
        (Object e) => debugPrint('camera dispose: $e'),
      ),
    );
  }

  @override
  void dispose() {
    _close();
    routeObserver.unsubscribe(this);
    lifecycle.dispose();
    intake.removeListener(_rebuild);
    widget.store.removeListener(_rebuild);
    intake.dispose();
    line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = session.error != null;
    final permissionDenied =
        session.error is MobileScannerException &&
        (session.error as MobileScannerException).errorCode ==
            MobileScannerErrorCode.permissionDenied;
    final status = failed
        ? session.requiresRecreation
              ? '相机状态异常，请返回后重新扫码'
              : permissionDenied
              ? '需要相机权限才能扫码'
              : '相机暂不可用，请重试'
        : session.busy
        ? '正在连接相机…'
        : !session.desired
        ? '扫描已暂停'
        : intake.message;
    final color = intake.feedback == IntakeFeedback.failure
        ? const Color(0xFFFFBD75)
        : mint;
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码入库'),
        actions: [
          IconButton(
            tooltip: wantsScan ? '暂停扫描' : '继续扫描',
            onPressed: () {
              wantsScan = !wantsScan;
              _sync();
            },
            icon: Icon(
              wantsScan ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    final width = math.min(size.width * .78, 340.0);
                    final rect = Rect.fromCenter(
                      center: size.center(Offset.zero),
                      width: width,
                      height: math.min(width * .66, size.height * .60),
                    );
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: camera,
                          scanWindow: rect,
                          fit: BoxFit.cover,
                          tapToFocus: true,
                          placeholderBuilder: (_) =>
                              const ColoredBox(color: ink),
                          errorBuilder: (_, _) => const ColoredBox(color: ink),
                        ),
                        IgnorePointer(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: ScanPainter(
                                rect,
                                line,
                                color,
                                session.running && session.desired,
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 24,
                          left: 22,
                          child: Text(
                            'CONTINUOUS SCAN',
                            style: TextStyle(
                              color: Colors.white70,
                              letterSpacing: 2,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 22,
                          child: Column(
                            children: [
                              Text(
                                session.requiresRecreation
                                    ? status
                                    : eventError ?? status,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (failed || eventError != null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: session.requiresRecreation
                                          ? () => Navigator.of(context).pop()
                                          : _retry,
                                      child: Text(
                                        session.requiresRecreation
                                            ? '返回工作台'
                                            : '重试',
                                        style: const TextStyle(color: mint),
                                      ),
                                    ),
                                    if (!session.requiresRecreation)
                                      TextButton(
                                        onPressed: () => unawaited(_settings()),
                                        child: const Text(
                                          '去设置',
                                          style: TextStyle(color: mint),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: ink, size: 20),
                const SizedBox(width: 8),
                Text(
                  '本次已录入 ${widget.store.total} 件',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: session.running && session.desired && !intake.busy
                      ? intake.rearm
                      : null,
                  child: const Text('再次计入'),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: InventoryList(store: widget.store),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成录入'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryList extends StatelessWidget {
  const InventoryList({super.key, required this.store});
  final InventoryStore store;
  
  @override
  Widget build(BuildContext context) {
    final items = store.items.entries.toList();
    if (items.isEmpty) {
      return const Center(
        child: Text('暂无待录入商品', style: TextStyle(color: Colors.black45)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final entry = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key.code,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.value} ${entry.key.unit}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ScanPainter extends CustomPainter {
  ScanPainter(this.rect, this.progress, this.color, this.active)
    : super(repaint: progress);
  
  final Rect rect;
  final Animation<double> progress;
  final Color color;
  final bool active;
  
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .54));
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
    if (!active) return;
    canvas.save();
    canvas.clipRRect(hole);
    final y = rect.top + rect.height * progress.value;
    final beam = Rect.fromLTRB(rect.left, y - 26, rect.right, y);
    canvas.drawRect(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: .28)],
        ).createShader(beam),
    );
    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.right, y),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScanPainter old) =>
      old.rect != rect ||
      old.color != color ||
      old.active != active ||
      old.progress != progress;
}
