import 'package:flutter/material.dart';

class CeilingMountScroll extends StatefulWidget {
  const CeilingMountScroll({super.key});

  @override
  State<CeilingMountScroll> createState() => _CeilingMountScrollState();
}

class _CeilingMountScrollState extends State<CeilingMountScroll> {
  // /// 模拟数据源
  // final Map<String, dynamic> data = {
  //   'title': '热门推荐',
  //   'color': Colors.red,
  //   'list': [
  //     {'name': '推荐商品1', 'description': '热销商品描述'},
  //     {'name': '推荐商品2', 'description': '热销商品描述'},
  //     {'name': '推荐商品3', 'description': '热销商品描述'},
  //     {'name': '推荐商品4', 'description': '热销商品描述'},
  //     {'name': '推荐商品5', 'description': '热销商品描述'},
  //     {'name': '推荐商品6', 'description': '热销商品描述'},
  //     {'name': '推荐商品7', 'description': '热销商品描述'},
  //     {'name': '推荐商品8', 'description': '热销商品描述'},
  //     {'name': '推荐商品9', 'description': '热销商品描述'},
  //     {'name': '推荐商品10', 'description': '热销商品描述'},
  //   ],
  // };

  /// key 列表
  final List<GlobalKey> _keyList = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];
  // final List<bool> _pinnedList = [
  //   false,
  //   false,
  //   false,
  //   false,
  //   false,
  // ];
  final List<Map<String, dynamic>> _dataPosition = [];
  /// 新增最小高度列表，用于动态设置每个模块的标题高度
  final List<double> _dataMinHeight = [0, 0, 0, 0, 0];
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
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();

    _controller.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getPosition();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollListener);
    _controller.dispose();
    for (var key in _keyList) {
      key.currentState?.dispose();
    }
    super.dispose();
  }

  /// 获取标题的位置信息
  void _getPosition() {
    for (var i = 0; i < _keyList.length; i++) {
      final key = _keyList[i];
      final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      final position = renderBox?.localToGlobal(Offset.zero);
      final size = renderBox?.size;

      _dataPosition.add({
        'position': position,
        'size': size,
      });
    }
  }

  // 滚动监听器，用来动态更新当前的吸顶标题
  void _scrollListener() {
    double offset = _controller.offset;

    for (var i = 0; i < _dataPosition.length; i++) {
      if (i == (_dataPosition.length - 1)) {
        setState(() {
          // _pinnedList[i] = true;
          _dataMinHeight[i] = 80;
        });
      } else {
        final p = _dataPosition[i];
        final n = _dataPosition[i + 1];
        // 120是估计出来的顶部高度，实际使用中可以自行获取，用于计算偏移量
        if (p['position'].dy <= offset && (n['position'].dy - 120) >= offset) {
          setState(() {
            // _pinnedList[i] = true;
            final tempHeight = n['position'].dy - offset - 120;
            _dataMinHeight[i] = tempHeight >= 0 && tempHeight <= 80 ? tempHeight : 80;
          });
        } else {
          setState(() {
            // _pinnedList[i] = false;
            _dataMinHeight[i] = 0;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _controller,
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 200,
            color: Colors.grey,
            alignment: Alignment.center,
            child: Text('这是顶部内容'),
          ),
        ),

        // SliverPersistentHeader(
        //   pinned: true,
        //   delegate: _MyHeaderDelegate(
        //     title: data['title'],
        //     color: data['color'],
        //   ),
        // ),
        //
        // SliverList.builder(
        //   itemBuilder: (_, index) => _ListItemWidget(
        //     name: data['list'][index]['name'],
        //     description: data['list'][index]['description'],
        //   ),
        //   itemCount: data['list'].length,
        // ),

        // expand 用于生成一个新的列表，它通过遍历原列表的每个元素，
        // 并对每个元素应用一个转换函数，将结果收集到一个新的列表中。
        // 与 map 方法类似，但 expand 可以返回多个元素（通过 Iterable），
        // 而 map 只能返回单个元素。
        ..._dataList.expand((item) => [
          // 因为设置了最小高度为0，所以直接将pinned设置为true
          SliverPersistentHeader(
            // pinned: _pinnedList[item['index']],
            pinned: true,
            delegate: _MyHeaderDelegate(
              minHeight: _dataMinHeight[item['index']],
              key: _keyList[item['index']],
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
        ]),

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
}

/// 自定义头部委托类
class _MyHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// 背景色
  final Color color;
  /// 标题
  final String title;
  final GlobalKey key;
  final double minHeight;

  const _MyHeaderDelegate({
    required this.key,
    required this.color,
    required this.title,
    required this.minHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => 200.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      key: key,
      color: color,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            child: Center(
              child: Text(title, style: TextStyle(fontSize: 30)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => oldDelegate.minExtent != minHeight;
}

/// 渲染列表项
class _ListItemWidget extends StatelessWidget {
  final String name;
  final String description;

  const _ListItemWidget({
    // super.key,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // key: key,
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
