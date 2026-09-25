import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const FoldAwareModalApp());

class FoldAwareModalApp extends StatelessWidget {
  const FoldAwareModalApp({super.key, this.initialDualPane = true});

  final bool initialDualPane;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
    home: ProductPage(initialDualPane: initialDualPane),
  );
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.initialDualPane});

  final bool initialDualPane;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late final ValueNotifier<bool> _simulateDualPane;
  String _selectedSku = '星云紫 / 256GB';

  @override
  void initState() {
    super.initState();
    _simulateDualPane = ValueNotifier(widget.initialDualPane);
  }

  @override
  void dispose() {
    _simulateDualPane.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('规格弹层与子屏'),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _simulateDualPane,
          builder: (context, value, _) => Row(
            children: [
              const Text('模拟双屏'),
              Switch(
                value: value,
                onChanged: (next) => _simulateDualPane.value = next,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    ),
    body: FoldAwareProductLayout(
      simulatedDualPane: _simulateDualPane,
      selectedSku: _selectedSku,
      onSkuChanged: (sku) => setState(() => _selectedSku = sku),
    ),
  );
}

class FoldAwareProductLayout extends StatelessWidget {
  const FoldAwareProductLayout({
    super.key,
    required this.simulatedDualPane,
    required this.selectedSku,
    required this.onSkuChanged,
  });

  final ValueListenable<bool> simulatedDualPane;
  final String selectedSku;
  final ValueChanged<String> onSkuChanged;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: simulatedDualPane,
      builder: (context, forceDualPane, _) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final panes = SubScreenResolver.resolve(
            size: size,
            displayFeatures: mediaQuery.displayFeatures,
            forceDualPane: forceDualPane,
          );
          final dualPane = panes.length == 2;
          late final Rect galleryRect;
          late final Rect purchaseRect;
          late final double contentHeight;

          if (dualPane) {
            galleryRect = panes.first.deflate(16);
            purchaseRect = panes.last.deflate(16);
            contentHeight = size.height;
          } else {
            galleryRect = Rect.fromLTWH(16, 16, size.width - 32, 240);
            purchaseRect = Rect.fromLTWH(
              16,
              galleryRect.bottom + 16,
              size.width - 32,
              380,
            );
            contentHeight = purchaseRect.bottom + 16;
          }

          return SingleChildScrollView(
            child: SizedBox(
              height: math.max(size.height, contentHeight),
              child: Stack(
                children: [
                  _animatedRect(galleryRect, const ProductGalleryCard()),
                  _animatedRect(
                    purchaseRect,
                    PurchaseCard(
                      selectedSku: selectedSku,
                      onSkuChanged: onSkuChanged,
                      simulatedDualPane: simulatedDualPane,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _animatedRect(Rect rect, Widget child) => AnimatedPositioned(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeInOutCubicEmphasized,
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: child,
  );
}

class ProductGalleryCard extends StatelessWidget {
  const ProductGalleryCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Text(
          'Fold X Pro\n商品图库',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    ),
  );
}

class PurchaseCard extends StatelessWidget {
  const PurchaseCard({
    super.key,
    required this.selectedSku,
    required this.onSkuChanged,
    required this.simulatedDualPane,
  });

  final String selectedSku;
  final ValueChanged<String> onSkuChanged;
  final ValueListenable<bool> simulatedDualPane;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fold X Pro', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '¥ 6,999',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text('当前已选：$selectedSku'),
          const SizedBox(height: 12),
          Builder(
            builder: (buttonContext) => FilledButton(
              onPressed: () => _openSheet(buttonContext),
              child: const Text('选择规格'),
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (buttonContext) => OutlinedButton(
              onPressed: () => _openDialog(buttonContext),
              child: const Text('查看库存说明'),
            ),
          ),
        ],
      ),
    ),
  );

  void _openSheet(BuildContext context) {
    Navigator.of(context).push(
      FoldAwareModalRoute<void>(
        anchorPoint: anchorPointOf(context),
        affinity: PaneAffinity.trailing,
        simulatedDualPane: simulatedDualPane,
        kind: FoldAwareSurfaceKind.bottomSheet,
        builder: (_) =>
            SkuSheet(selectedSku: selectedSku, onChanged: onSkuChanged),
      ),
    );
  }

  void _openDialog(BuildContext context) {
    Navigator.of(context).push(
      FoldAwareModalRoute<void>(
        anchorPoint: anchorPointOf(context),
        affinity: PaneAffinity.trailing,
        simulatedDualPane: simulatedDualPane,
        kind: FoldAwareSurfaceKind.dialog,
        builder: (_) => const StockDialog(),
      ),
    );
  }
}

Offset anchorPointOf(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
}

enum FoldAwareSurfaceKind { dialog, bottomSheet }

enum PaneAffinity { closestToAnchor, leading, trailing }

class FoldAwareModalRoute<T> extends PopupRoute<T> {
  FoldAwareModalRoute({
    required this.anchorPoint,
    required this.affinity,
    required this.simulatedDualPane,
    required this.kind,
    required this.builder,
  });

  final Offset anchorPoint;
  final PaneAffinity affinity;
  final ValueListenable<bool> simulatedDualPane;
  final FoldAwareSurfaceKind kind;
  final WidgetBuilder builder;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '关闭弹层';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      ) => FadeTransition(
    opacity: animation,
    child: FoldAwareModalSurface(
      anchorPoint: anchorPoint,
      affinity: affinity,
      simulatedDualPane: simulatedDualPane,
      kind: kind,
      builder: builder,
    ),
  );
}

class FoldAwareModalSurface extends StatelessWidget {
  const FoldAwareModalSurface({
    super.key,
    required this.anchorPoint,
    required this.affinity,
    required this.simulatedDualPane,
    required this.kind,
    required this.builder,
  });

  final Offset anchorPoint;
  final PaneAffinity affinity;
  final ValueListenable<bool> simulatedDualPane;
  final FoldAwareSurfaceKind kind;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: simulatedDualPane,
      builder: (context, forceDualPane, _) => LayoutBuilder(
        builder: (context, constraints) {
          final panes = SubScreenResolver.resolve(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            displayFeatures: mediaQuery.displayFeatures,
            forceDualPane: forceDualPane,
          );
          final pane = SubScreenResolver.select(
            candidates: panes,
            anchorPoint: anchorPoint,
            affinity: affinity,
            textDirection: Directionality.of(context),
          );

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubicEmphasized,
                left: pane.left,
                top: pane.top,
                width: pane.width,
                height: pane.height,
                child: SizedBox(
                  key: const ValueKey('fold-aware-modal-surface'),
                  child: MediaQuery(
                    data: mediaQuery.removeDisplayFeatures(pane),
                    child: _buildSurface(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSurface(BuildContext context) {
    switch (kind) {
      case FoldAwareSurfaceKind.dialog:
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: builder(context),
          ),
        );
      case FoldAwareSurfaceKind.bottomSheet:
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: builder(context),
          ),
        );
    }
  }
}

class SubScreenResolver {
  const SubScreenResolver._();

  static List<Rect> resolve({
    required Size size,
    required List<DisplayFeature> displayFeatures,
    required bool forceDualPane,
  }) {
    final feature = _verticalFeature(displayFeatures, size);
    if (feature != null) {
      final bounds = feature.bounds;
      return [
        Rect.fromLTWH(0, 0, bounds.left, size.height),
        Rect.fromLTWH(
          bounds.right,
          0,
          math.max(0, size.width - bounds.right),
          size.height,
        ),
      ].where((pane) => pane.width > 0).toList();
    }

    if (forceDualPane && size.width >= 400) {
      const gap = 16.0;
      final paneWidth = (size.width - gap) / 2;
      return [
        Rect.fromLTWH(0, 0, paneWidth, size.height),
        Rect.fromLTWH(paneWidth + gap, 0, paneWidth, size.height),
      ];
    }
    return [Offset.zero & size];
  }

  static Rect select({
    required List<Rect> candidates,
    required Offset anchorPoint,
    required PaneAffinity affinity,
    required TextDirection textDirection,
  }) {
    if (candidates.length == 1) return candidates.single;
    switch (affinity) {
      case PaneAffinity.leading:
        return textDirection == TextDirection.ltr
            ? candidates.first
            : candidates.last;
      case PaneAffinity.trailing:
        return textDirection == TextDirection.ltr
            ? candidates.last
            : candidates.first;
      case PaneAffinity.closestToAnchor:
        return _nearest(candidates, anchorPoint);
    }
  }

  static DisplayFeature? _verticalFeature(
      List<DisplayFeature> features,
      Size size,
      ) {
    for (final feature in features) {
      if (feature.bounds.height >= size.height * 0.6) return feature;
    }
    return null;
  }

  static Rect _nearest(List<Rect> candidates, Offset anchor) {
    for (final candidate in candidates) {
      if (candidate.contains(anchor)) return candidate;
    }
    return candidates.reduce((best, current) {
      return _distance(current, anchor) < _distance(best, anchor)
          ? current
          : best;
    });
  }

  static double _distance(Rect rect, Offset point) {
    final dx =
        math.max(rect.left - point.dx, 0) + math.max(point.dx - rect.right, 0);
    final dy =
        math.max(rect.top - point.dy, 0) + math.max(point.dy - rect.bottom, 0);
    return (dx * dx + dy * dy).toDouble();
  }
}

class SkuSheet extends StatefulWidget {
  const SkuSheet({
    super.key,
    required this.selectedSku,
    required this.onChanged,
  });

  final String selectedSku;
  final ValueChanged<String> onChanged;

  @override
  State<SkuSheet> createState() => _SkuSheetState();
}

class _SkuSheetState extends State<SkuSheet> {
  late String _selectedSku;
  late final TextEditingController _noteController;
  static const _skus = ['星云紫 / 256GB', '曜石黑 / 256GB', '月光银 / 512GB'];

  @override
  void initState() {
    super.initState();
    _selectedSku = widget.selectedSku;
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('选择规格', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sku in _skus)
                    ChoiceChip(
                      label: Text(sku),
                      selected: _selectedSku == sku,
                      onSelected: (_) => setState(() => _selectedSku = sku),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '给商家的备注',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.onChanged(_selectedSku);
                    Navigator.of(context).pop();
                  },
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class StockDialog extends StatelessWidget {
  const StockDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('库存说明'),
    content: const Text('库存会在提交订单前再次校验。折叠或展开设备不会重置当前弹层。'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('知道了'),
      ),
    ],
  );
}
