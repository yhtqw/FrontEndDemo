import 'package:flutter/material.dart';

// import './widgets/path_guide_wrapper/path_guide_wrapper.dart';
import './widgets/path_guide_wrapper/path_guide_wrapper_01.dart';

class WidgetPathGuidePage extends StatefulWidget {
  const WidgetPathGuidePage({super.key});

  static final String routePath = '/widget-path-guide';

  @override
  State<WidgetPathGuidePage> createState() => _WidgetPathGuidePageState();
}

class _WidgetPathGuidePageState extends State<WidgetPathGuidePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 50,),

            ...[1,2,3,4,5,6,7].map((item) => PathGuideWrapper(
              color: Colors.orange,
              strokeWidth: 6,
              trailLengthPercent: 0.4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "点击这里",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            )),

            SizedBox(height: 20,),

            PathGuideWrapper(
              child: Text('测试文本测试文本测试文本'),
            ),
          ],
        ),
      )
    );
  }
}
