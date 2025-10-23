import 'package:flutter/material.dart';

import 'widgets/customize_tab.dart';

class CustomizeTabPage extends StatefulWidget {
  const CustomizeTabPage({super.key});

  static final String routePath = '/customize-tab';

  @override
  State<CustomizeTabPage> createState() => _CustomizeTabPageState();
}

class _CustomizeTabPageState extends State<CustomizeTabPage> {
  // 用于动态切换tab bar的位置
  TabBarPosition _tabBarPosition = TabBarPosition.top;

  /// 构建tab项
  Widget _buildTab(String txt) {
    return Text(
      txt,
      style: const TextStyle(
        fontSize: 14,
      ),
    );
  }

  /// 构建tab view
  Widget _buildTabView(String txt) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.grey,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(txt),
          )
        ],
      ),
    );
  }

  /// 改变tab bar的位置
  void _onChangePosition(TabBarPosition tabBarPosition) {
    setState(() {
      _tabBarPosition = tabBarPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('tab 测试'),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomizeTab(
              tabBarHeight: 80,
              tabBarBackgroundColor: Colors.amber,
              tabBarPadding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              unselectedColor: Colors.black,
              selectedColor: Colors.white,
              tabBarOptionPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5,
              ),
              indicatorColor: Colors.orange,
              position: _tabBarPosition,
              onChangeTabIndex: (index) {
                print('当前的索引为：$index');
              },
              tabs: ['tab1', 'tab2', 'tab3', 'tab4', 'tab5'].map(
                  (item) => _buildTab(item),
              ).toList(),
              tabViews: ['1', '2', '3', '4', '5'].map(
                  (item) => _buildTabView(item),
              ).toList(),
            ),
          ),

          Container(
            height: 120,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _onChangePosition(TabBarPosition.left),
                  child: const Text('左'),
                ),
                ElevatedButton(
                  onPressed: () => _onChangePosition(TabBarPosition.right),
                  child: const Text('右'),
                ),
                ElevatedButton(
                  onPressed: () => _onChangePosition(TabBarPosition.top),
                  child: const Text('上'),
                ),
                ElevatedButton(
                  onPressed: () => _onChangePosition(TabBarPosition.bottom),
                  child: const Text('下'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
