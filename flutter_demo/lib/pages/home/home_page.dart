import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../customize_tab/customize_tab_page.dart';
import '../seamless_scrolling/seamless_scrolling_page.dart';

class HomeRouteItem {
  const HomeRouteItem({
    required this.name,
    required this.routePath,
  });

  final String name;
  final String routePath;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static final String routePath = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<HomeRouteItem> _list = [
    HomeRouteItem(name: '封装一个tab部件', routePath: CustomizeTabPage.routePath,),
    HomeRouteItem(name: '无缝滚动案例', routePath: SeamlessScrollingPage.routePath,),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Flutter Demo'),
      ),
      body: LayoutBuilder(
        builder: (_, BoxConstraints boxConstraints) => GridView.builder(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 60,),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: boxConstraints.maxWidth < 600 ? 3 : boxConstraints.maxWidth < 1200 ? 5 : 8,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            mainAxisExtent: 60,
          ),
          itemCount: _list.length,
          itemBuilder: (_, int index) => ElevatedButton(
            onPressed: () {
              context.push(_list[index].routePath);
            },
            child: Text(
              _list[index].name,
              style: TextStyle(
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}