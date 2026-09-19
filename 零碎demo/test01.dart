import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const FoldableDetailApp());
}

class FoldableDetailApp extends StatelessWidget {
  const FoldableDetailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const ProductDetailPage(),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final PageController _galleryController;
  late final ScrollController _scrollController;
  late final TextEditingController _noteController;
  late final FocusNode _noteFocusNode;

  String _selectedSku = '星云紫 / 256GB';
  bool _simulateDualPane = false;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
    _scrollController = ScrollController();
    _noteController = TextEditingController();
    _noteFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _scrollController.dispose();
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('折叠屏商品详情'),
        actions: [
          Row(
            children: [
              const Text('模拟双栏'),
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
      body: SafeArea(
        child: FoldAwareDetailLayout(
          mediaQuery: mediaQuery,
          forceDualPane: _simulateDualPane,
          gallery: ProductGallery(controller: _galleryController),
          purchasePanel: PurchasePanel(
            selectedSku: _selectedSku,
            onSkuChanged: (sku) {
              setState(() => _selectedSku = sku);
            },
            noteController: _noteController,
            noteFocusNode: _noteFocusNode,
          ),
          reviews: const ReviewSection(),
          scrollController: _scrollController,
        ),
      ),
    );
  }
}

class FoldAwareDetailLayout extends StatelessWidget {
  const FoldAwareDetailLayout({
    super.key,
    required this.mediaQuery,
    required this.forceDualPane,
    required this.gallery,
    required this.purchasePanel,
    required this.reviews,
    required this.scrollController,
  });

  final MediaQueryData mediaQuery;
  final bool forceDualPane;
  final Widget gallery;
  final Widget purchasePanel;
  final Widget reviews;
  final ScrollController scrollController;

  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final hinge = _verticalHinge(mediaQuery.displayFeatures, size);
        final isDualPane = forceDualPane || hinge != null || size.width >= 840;

        final spec = DetailLayoutSpec.create(
          size: size,
          hinge: hinge,
          isDualPane: isDualPane,
        );

        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(_gap),
          child: SizedBox(
            height: spec.totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _positionedRect(spec.galleryRect, gallery),
                _positionedRect(spec.purchaseRect, purchasePanel),
                _positionedRect(spec.reviewRect, reviews),
              ],
            ),
          ),
        );
      },
    );
  }

  DisplayFeature? _verticalHinge(
      List<DisplayFeature> features,
      Size screenSize,
      ) {
    for (final feature in features) {
      final bounds = feature.bounds;
      final isTall = bounds.height >= screenSize.height * 0.6;
      final hasWidth = bounds.width > 0;

      if (isTall && hasWidth) {
        return feature;
      }
    }
    return null;
  }

  Widget _positionedRect(Rect rect, Widget child) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubicEmphasized,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }
}

class DetailLayoutSpec {
  const DetailLayoutSpec({
    required this.galleryRect,
    required this.purchaseRect,
    required this.reviewRect,
    required this.totalHeight,
  });

  final Rect galleryRect;
  final Rect purchaseRect;
  final Rect reviewRect;
  final double totalHeight;

  static DetailLayoutSpec create({
    required Size size,
    required DisplayFeature? hinge,
    required bool isDualPane,
  }) {
    const gap = 16.0;
    const galleryHeight = 300.0;
    const purchaseHeight = 430.0;
    const reviewHeight = 700.0;

    if (!isDualPane) {
      final galleryRect = Rect.fromLTWH(0, 0, size.width, galleryHeight);
      final purchaseRect = Rect.fromLTWH(
        0,
        galleryHeight + gap,
        size.width,
        purchaseHeight,
      );
      final reviewRect = Rect.fromLTWH(
        0,
        purchaseRect.bottom + gap,
        size.width,
        reviewHeight,
      );

      return DetailLayoutSpec(
        galleryRect: galleryRect,
        purchaseRect: purchaseRect,
        reviewRect: reviewRect,
        totalHeight: reviewRect.bottom,
      );
    }

    final leftWidth = hinge?.bounds.left ?? (size.width - gap) / 2;
    final rightLeft = hinge?.bounds.right ?? leftWidth + gap;
    final rightWidth = math.max(0, size.width - rightLeft);

    final galleryRect = Rect.fromLTWH(0, 0, leftWidth, galleryHeight);
    final purchaseRect = Rect.fromLTWH(
      rightLeft,
      0,
      rightWidth.toDouble(),
      purchaseHeight,
    );
    final reviewTop = math.max(galleryRect.bottom, purchaseRect.bottom) + gap;
    final reviewRect = Rect.fromLTWH(
      0,
      reviewTop,
      size.width,
      reviewHeight,
    );

    return DetailLayoutSpec(
      galleryRect: galleryRect,
      purchaseRect: purchaseRect,
      reviewRect: reviewRect,
      totalHeight: reviewRect.bottom,
    );
  }
}

// 商品展示图片
class ProductGallery extends StatelessWidget {
  const ProductGallery({
    super.key,
    required this.controller,
  });

  final PageController controller;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF5B3F9B),
      Color(0xFF1E7A8A),
      Color(0xFFE78A4E),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: PageView.builder(
        controller: controller,
        itemCount: colors.length,
        itemBuilder: (context, index) {
          return ColoredBox(
            color: colors[index],
            child: Center(
              child: Text(
                '商品展示图 ${index + 1}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 商品的一些属性选择
class PurchasePanel extends StatelessWidget {
  const PurchasePanel({
    super.key,
    required this.selectedSku,
    required this.onSkuChanged,
    required this.noteController,
    required this.noteFocusNode,
  });

  final String selectedSku;
  final ValueChanged<String> onSkuChanged;
  final TextEditingController noteController;
  final FocusNode noteFocusNode;

  @override
  Widget build(BuildContext context) {
    const skus = [
      '星云紫 / 256GB',
      '曜石黑 / 256GB',
      '月光银 / 512GB',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Text(
              'Fold X Pro',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '¥ 6,999',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '已选：$selectedSku',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sku in skus)
                  ChoiceChip(
                    label: Text(sku),
                    selected: selectedSku == sku,
                    onSelected: (_) => onSkuChanged(sku),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              focusNode: noteFocusNode,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '购买备注',
                hintText: '比如周末送到，提前联系我',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已加入购物车')),
                );
              },
              child: const Text('加入购物车'),
            ),
          ],
        ),
      ),
    );
  }
}

// 模拟评论组件
class ReviewSection extends StatelessWidget {
  const ReviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 12,
        separatorBuilder: (_, _) => const Divider(height: 28),
        itemBuilder: (context, index) {
          return Text(
            '用户 ${index + 1}：测试评论测试评论测试评论测试评论测试评论测试评论测试评论',
          );
        },
      ),
    );
  }
}
