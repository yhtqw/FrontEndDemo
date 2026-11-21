import 'package:material_ui/material_ui.dart';

void main() => runApp(const MallApp());

class MallApp extends StatelessWidget {
  const MallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF236854)),
        scaffoldBackgroundColor: const Color(0xFFDFEDE6),
        useMaterial3: true,
      ),
      home: const MallHomePage(),
    );
  }
}

class MallHomePage extends StatefulWidget {
  const MallHomePage({
    super.key,
    this.clipProducts = true,
    this.overlapBehavior = ClipOverlapBehavior.followEdge,
  });

  final bool clipProducts;
  final ClipOverlapBehavior overlapBehavior;

  @override
  State<MallHomePage> createState() => _MallHomePageState();
}

class _MallHomePageState extends State<MallHomePage> {
  static const _radius = BorderRadius.vertical(top: Radius.circular(28));
  static const _categories = ['精选', '数码', '穿搭', '生活'];
  static const _products = [
    (name: '轻量运动鞋', price: 299, icon: Icons.directions_run_rounded),
    (name: '无线耳机', price: 199, icon: Icons.headphones_rounded),
    (name: '通勤背包', price: 159, icon: Icons.backpack_rounded),
    (name: '便携音箱', price: 129, icon: Icons.speaker_rounded),
    (name: '随行水杯', price: 89, icon: Icons.local_cafe_rounded),
    (name: '户外腕表', price: 399, icon: Icons.watch_rounded),
  ];
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final products = SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      sliver: SliverGrid.builder(
        itemCount: 24,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 224,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final product = _products[(index + _selected) % _products.length];
          return _ProductCard(
            name: product.name,
            price: product.price,
            icon: product.icon,
            color: index.isEven
                ? const Color(0xFFE1EEE6)
                : const Color(0xFFF3E9DA),
          );
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('山野好物')),
      // AppBar 已处理顶部安全区，这里只处理左右和底部。
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const ValueKey('mall-scroll'),
          slivers: [
            const SliverToBoxAdapter(child: _HeroBanner()),
            // 同一轮廓内同时裁剪背景、分类栏和商品区。
            SliverClipRRect(
              borderRadius: _radius,
              clipOverlap: ClipOverlapBehavior.none,
              sliver: DecoratedSliver(
                decoration: const BoxDecoration(color: Color(0xFFF8FAF7)),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    PinnedHeaderSliver(
                      child: _CategoryBar(
                        categories: _categories,
                        selected: _selected,
                        onSelected: (index) =>
                            setState(() => _selected = index),
                      ),
                    ),
                    // 这里收到的是前方分类栏造成的 overlap。
                    SliverClipRect(
                      clipBehavior: widget.clipProducts
                          ? Clip.hardEdge
                          : Clip.none,
                      clipOverlap: widget.overlapBehavior,
                      sliver: products,
                    ),
                  ],
                ),
              ),
            ),
            // 留出组外空间，便于观察分类栏随分区一起退出。
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 960,
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('更多好物，下次见', textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 236),
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF316951), Color(0xFF9AB89A)],
        ),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            right: -12,
            bottom: -32,
            child: Icon(
              Icons.landscape_rounded,
              size: 180,
              color: Colors.white.withValues(alpha: 0.24),
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '把日子过成喜欢的样子',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '秋日精选 · 简单出发',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              SizedBox(height: 24),
              Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('category-bar'),
      // 保留少量透明度，让有无重叠裁剪的差异更容易观察。
      color: const Color(0xCCF8FAF7),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (var index = 0; index < categories.length; index++)
                ChoiceChip(
                  label: Text(categories[index]),
                  selected: selected == index,
                  showCheckmark: false,
                  onSelected: (_) => onSelected(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
  });

  final String name;
  final int price;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, size: 64, color: const Color(0xFF346752)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              '¥$price',
              style: const TextStyle(
                color: Color(0xFFB45032),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
