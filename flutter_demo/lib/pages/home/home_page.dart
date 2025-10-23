import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../customize_tab/customize_tab_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static final String routePath = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Flutter Demo'),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        children: [
          ElevatedButton(
            onPressed: () {
              context.push(CustomizeTabPage.routePath);
            },
            child: Text('封装一个tab部件'),
          ),
        ],
      ),
    );
  }
}