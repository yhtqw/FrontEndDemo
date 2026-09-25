import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const FoldAwareModalApp());
}

class FoldAwareModalApp extends StatelessWidget {
  const FoldAwareModalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const ProductPage(),
    );
  }
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  bool _simulateDualPane = true;
  String _selectedSku = '星云紫 / 256GB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('规格弹层与子屏'),
        actions: [
          Row(
            children: [
              const Text('模拟双屏'),
              Switch(
                value: _simulateDualPane,
                onChanged: (value) {
                  setState(() => _simulateDualPane = value);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: FoldAwareProductLayout(
        forceDualPane: _simulateDualPane,
        selectedSku: _selectedSku,
        onSkuChanged: (sku) {
          setState(() => _selectedSku = sku);
        },
      ),
    );
  }
}

class FoldAwareProductLayout extends StatelessWidget {
  const FoldAwareProductLayout({
    super.key,
    required this.forceDualPane,
    required this.selectedSku,
    required this.onSkuChanged,
  });

  final bool forceDualPane;
  final String selectedSku;
  final ValueChanged<String> onSkuChanged;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final panes = SubScreenResolver.resolve(
          size: size,
          displayFeatures: mediaQuery.displayFeatures,
          forceDualPane: forceDualPane,
        );

        final isDualPane = panes.length == 2;
        final leftPane = panes.first;
        final rightPane = isDualPane ? panes.last : panes.first;

        return Stack(
          children: [
            Positioned.fromRect(
              rect: leftPane.deflate(16),
              child: const ProductGalleryCard(),
            ),
            Positioned.fromRect(
              rect: rightPane.deflate(16),
              child: PurchaseCard(
                selectedSku: selectedSku,
                onSkuChanged: onSkuChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ProductGalleryCard extends StatelessWidget {
  const ProductGalleryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Center(
          child: Text(
            '这边是商品图库',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}

class PurchaseCard extends StatelessWidget {
  const PurchaseCard({
    super.key,
    required this.selectedSku,
    required this.onSkuChanged,
  });

  final String selectedSku;
  final ValueChanged<String> onSkuChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              builder: (buttonContext) {
                return FilledButton(
                  onPressed: () {
                    Navigator.of(buttonContext).push(
                      FoldAwareModalRoute<void>(
                        anchorPoint: anchorPointOf(buttonContext),
                        kind: FoldAwareSurfaceKind.bottomSheet,
                        builder: (context) {
                          return SkuSheet(
                            selectedSku: selectedSku,
                            onChanged: onSkuChanged,
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('选择规格'),
                );
              },
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (buttonContext) {
                return OutlinedButton(
                  onPressed: () {
                    Navigator.of(buttonContext).push(
                      FoldAwareModalRoute<void>(
                        anchorPoint: anchorPointOf(buttonContext),
                        kind: FoldAwareSurfaceKind.dialog,
                        builder: (context) {
                          return const StockDialog();
                        },
                      ),
                    );
                  },
                  child: const Text('查看库存说明'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Offset anchorPointOf(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;

  return box.localToGlobal(
    Offset(box.size.width / 2, box.size.height / 2),
  );
}

enum FoldAwareSurfaceKind {
  dialog,
  bottomSheet,
}

class FoldAwareModalRoute<T> extends PopupRoute<T> {
  FoldAwareModalRoute({
    required this.anchorPoint,
    required this.kind,
    required this.builder,
  });

  final Offset anchorPoint;
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
      ) {
    return FadeTransition(
      opacity: animation,
      child: FoldAwareModalSurface(
        key: const ValueKey('fold-aware-modal'),
        anchorPoint: anchorPoint,
        kind: kind,
        builder: builder,
      ),
    );
  }
}

class FoldAwareModalSurface extends StatelessWidget {
  const FoldAwareModalSurface({
    super.key,
    required this.anchorPoint,
    required this.kind,
    required this.builder,
  });

  final Offset anchorPoint;
  final FoldAwareSurfaceKind kind;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final panes = SubScreenResolver.resolve(
          size: size,
          displayFeatures: mediaQuery.displayFeatures,
          forceDualPane: false,
        );
        final selectedPane = SubScreenResolver.nearest(
          candidates: panes,
          anchorPoint: anchorPoint,
        );

        return Stack(
          children: [
            ModalBarrier(
              color: Colors.black54,
              dismissible: true,
              semanticsLabel: '关闭弹层',
            ),
            AnimatedPositioned(
              key: const ValueKey('modal-surface'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubicEmphasized,
              left: selectedPane.left,
              top: selectedPane.top,
              width: selectedPane.width,
              height: selectedPane.height,
              child: MediaQuery(
                data: mediaQuery.removeDisplayFeatures(selectedPane),
                child: _buildSurface(context),
              ),
            ),
          ],
        );
      },
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
    final hinge = _verticalDisplayFeature(displayFeatures, size);

    if (hinge != null) {
      final bounds = hinge.bounds;
      final left = Rect.fromLTWH(0, 0, bounds.left, size.height);
      final right = Rect.fromLTWH(
        bounds.right,
        0,
        math.max(0, size.width - bounds.right),
        size.height,
      );

      return [left, right].where((item) => item.width > 0).toList();
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

  static Rect nearest({
    required List<Rect> candidates,
    required Offset anchorPoint,
  }) {
    for (final candidate in candidates) {
      if (candidate.contains(anchorPoint)) {
        return candidate;
      }
    }

    return candidates.reduce((best, current) {
      return _distanceToRect(current, anchorPoint) <
          _distanceToRect(best, anchorPoint)
          ? current
          : best;
    });
  }

  static DisplayFeature? _verticalDisplayFeature(
      List<DisplayFeature> displayFeatures,
      Size size,
      ) {
    for (final feature in displayFeatures) {
      if (feature.bounds.height >= size.height * 0.6) {
        return feature;
      }
    }
    return null;
  }

  static double _distanceToRect(Rect rect, Offset point) {
    final dx = math.max(rect.left - point.dx, 0) +
        math.max(point.dx - rect.right, 0);
    final dy = math.max(rect.top - point.dy, 0) +
        math.max(point.dy - rect.bottom, 0);

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

  static const _skus = [
    '星云紫 / 256GB',
    '曜石黑 / 256GB',
    '月光银 / 512GB',
  ];

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
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 390,
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
                Text(
                  '选择规格',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sku in _skus)
                      ChoiceChip(
                        label: Text(sku),
                        selected: _selectedSku == sku,
                        onSelected: (_) {
                          setState(() => _selectedSku = sku);
                        },
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
}

class StockDialog extends StatelessWidget {
  const StockDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('库存说明'),
      content: const Text(
        '库存会在提交订单前再次校验。折叠或展开设备不会重置当前弹层，'
            '你可以继续完成这次操作。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}
