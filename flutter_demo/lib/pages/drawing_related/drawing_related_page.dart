import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'children_pages/widget_path_guide/widget_path_guide_page.dart';

class DrawingRelatedPage extends StatefulWidget {
  const DrawingRelatedPage({super.key});

  static final String routePath = '/drawing-related';

  @override
  State<DrawingRelatedPage> createState() => _DrawingRelatedPageState();
}

class _DrawingRelatedPageState extends State<DrawingRelatedPage> {
  int? clickedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('绘制相关'),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                context.push("${DrawingRelatedPage.routePath}${WidgetPathGuidePage.routePath}");
              },
              child: Text('组件的边框路径包裹动画'),
            ),
          ],
        ),
      ),
    );
  }
}
