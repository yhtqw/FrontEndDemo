import 'package:flutter/material.dart';

class CeilingMountScroll2 extends StatefulWidget {
  const CeilingMountScroll2({super.key});

  @override
  State<CeilingMountScroll2> createState() => _CeilingMountScroll2State();
}

class _CeilingMountScroll2State extends State<CeilingMountScroll2> {
  /*
  /// 模拟数据源
  final List<Map<String, dynamic>> _dataList = [
    {
      'title': '热门推荐',
      'color': Colors.red,
      'index': 0,
      'list': [
        {'name': '推荐商品1', 'description': '热销商品描述'},
        {'name': '推荐商品2', 'description': '热销商品描述'},
        {'name': '推荐商品3', 'description': '热销商品描述'},
        {'name': '推荐商品4', 'description': '热销商品描述'},
        {'name': '推荐商品5', 'description': '热销商品描述'},
        {'name': '推荐商品6', 'description': '热销商品描述'},
        {'name': '推荐商品7', 'description': '热销商品描述'},
        {'name': '推荐商品8', 'description': '热销商品描述'},
        {'name': '推荐商品9', 'description': '热销商品描述'},
        {'name': '推荐商品10', 'description': '热销商品描述'},
      ],
    },

    {
      'title': '新品上市',
      'color': Colors.blue,
      'index': 1,
      'list': [
        {'name': '新品1', 'description': '最新上架商品'},
        {'name': '新品2', 'description': '最新上架商品'},
        {'name': '新品3', 'description': '最新上架商品'},
        {'name': '新品4', 'description': '最新上架商品'},
      ],
    },

    {
      'title': '限时特价',
      'color': Colors.green,
      'index': 2,
      'list': [
        {'name': '特价商品1', 'description': '限时优惠商品'},
        {'name': '特价商品2', 'description': '限时优惠商品'},
        {'name': '特价商品3', 'description': '限时优惠商品'},
        {'name': '特价商品4', 'description': '限时优惠商品'},
        {'name': '特价商品5', 'description': '限时优惠商品'},
        {'name': '特价商品6', 'description': '限时优惠商品'},
      ],
    },

    {
      'title': '精选品牌',
      'color': Colors.orange,
      'index': 3,
      'list': [
        {'name': '品牌商品1', 'description': '知名品牌商品'},
        {'name': '品牌商品2', 'description': '知名品牌商品'},
        {'name': '品牌商品3', 'description': '知名品牌商品'},
        {'name': '品牌商品3', 'description': '知名品牌商品'},
        {'name': '品牌商品4', 'description': '知名品牌商品'},
        {'name': '品牌商品5', 'description': '知名品牌商品'},
        {'name': '品牌商品6', 'description': '知名品牌商品'},
        {'name': '品牌商品7', 'description': '知名品牌商品'},
      ],
    },

    {
      'title': '反季捡漏',
      'color': Colors.purple,
      'index': 4,
      'list': [
        {'name': '捡漏商品1', 'description': '捡漏商品'},
        {'name': '捡漏商品2', 'description': '捡漏商品'},
        {'name': '捡漏商品3', 'description': '捡漏商品'},
        {'name': '捡漏商品3', 'description': '捡漏商品'},
        {'name': '捡漏商品4', 'description': '捡漏商品'},
        {'name': '捡漏商品5', 'description': '捡漏商品'},
        {'name': '捡漏商品6', 'description': '捡漏商品'},
        {'name': '捡漏商品7', 'description': '捡漏商品'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 200,
            color: Colors.grey,
            alignment: Alignment.center,
            child: Text('这是顶部内容'),
          ),
        ),
        
        ..._dataList.map((item) => SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _MyHeaderDelegate(
                title: item['title'],
                color: item['color'],
              ),
            ),
            SliverList.builder(
              itemBuilder: (_, index) => _ListItemWidget(
                name: item['list'][index]['name'],
                description: item['list'][index]['description'],
              ),
              itemCount: item['list'].length,
            ),
          ],
        )),

        SliverToBoxAdapter(
          child: Container(
            height: 200,
            color: Colors.grey,
            alignment: Alignment.center,
            child: Text('这是底部内容'),
          ),
        ),
      ],
    );
  }

   */

  // 1. 定义滚动控制器和数据
  final ScrollController _scrollController = ScrollController();
  final List<String> _categories = ["美食", "电影", "酒店", "休闲", "亲子", "生活"];

  // 2. 为每个模块分配一个 Key
  final List<GlobalKey> _keys = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _categories.length; i++) {
      _keys.add(GlobalKey());
    }
  }

  // 3. 核心：点击跳转方法
  void _scrollToIndex(int index) {
    final keyContext = _keys[index].currentContext;
    if (keyContext != null) {
      // 获取当前 RenderObject 在 Scrollable 中的偏移量
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0, // 0.0 表示对齐顶部（吸顶位置）
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("锚点定位 + 吸顶推挤")),
      body: Column(
        children: [
          // 4. 顶部的分类导航栏
          Container(
            height: 50,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) => TextButton(
                onPressed: () => _scrollToIndex(index),
                child: Text(_categories[index]),
              ),
            ),
          ),

          // 5. 滚动列表部分
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: _categories.asMap().entries.map((entry) {
                int idx = entry.key;
                String title = entry.value;

                return SliverMainAxisGroup(
                  key: _keys[idx], // 关键：绑定 Key
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: MyStickyHeaderDelegate(title),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, i) => ListTile(title: Text("$title项目 $i")),
                        childCount: 15, // 每个模块 15 条数据
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// 6. 自定义吸顶 Delegate
class MyStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  MyStickyHeaderDelegate(this.title);

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    final bool isPinned = shrinkOffset > 0;
    return Container(
      color: isPinned ? Colors.blueAccent : Colors.grey[200],
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title,
        style: TextStyle(
          color: isPinned ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override double get maxExtent => 50;
  @override double get minExtent => 50;
  @override bool shouldRebuild(oldDelegate) => true;
}

/*
/// 自定义头部委托类
class _MyHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// 背景色
  final Color color;
  /// 标题
  final String title;

  const _MyHeaderDelegate({
    required this.color,
    required this.title,
  });

  @override
  double get minExtent => 50.0;

  @override
  double get maxExtent => 200.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: Center(
        child: Text(title, style: TextStyle(fontSize: 30)),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

/// 渲染列表项
class _ListItemWidget extends StatelessWidget {
  final String name;
  final String description;

  const _ListItemWidget({
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shopping_bag,
              color: Colors.blue,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}
*/
