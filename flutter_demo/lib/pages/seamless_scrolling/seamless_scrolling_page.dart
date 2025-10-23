import 'package:flutter/material.dart';

import 'widgets/seamless_scrolling.dart';

class SeamlessScrollingPage extends StatefulWidget {
  const SeamlessScrollingPage({super.key});

  static final String routePath = '/seamless-scrolling';

  @override
  State<SeamlessScrollingPage> createState() => _SeamlessScrollingPageState();
}

class _SeamlessScrollingPageState extends State<SeamlessScrollingPage> {
  Widget _testChild({
    required double width,
    required double height,
    required Color color,
    required String text
  }) {
    return Container(
      width: width,
      height: height,
      color: color,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('无缝滚动案例'),
      ),
      body: Column(
        children: [
          SeamlessScrolling(
            containerWidth: 300,
            containerHeight: 200,
            copyItemNumber: 1,
            children: [
              _testChild(
                width: 300,
                height: 200,
                color: const Color(0xFF111111),
                text: '1',
              ),
              _testChild(
                width: 300,
                height: 200,
                color: const Color(0xFF666666),
                text: '2',
              ),
              _testChild(
                width: 300,
                height: 200,
                color: const Color(0xFF999999),
                text: '3',
              ),
            ],
          ),

          const SizedBox(height: 10,),

          SeamlessScrolling(
            containerWidth: 300,
            containerHeight: 200,
            copyItemNumber: 2,
            milliseconds: 5000,
            children: [
              _testChild(
                width: 200,
                height: 200,
                color: const Color(0xFF111111),
                text: '1',
              ),
              _testChild(
                width: 100,
                height: 200,
                color: const Color(0xFF666666),
                text: '2',
              ),
              _testChild(
                width: 100,
                height: 200,
                color: const Color(0xFF999999),
                text: '3',
              ),
            ],
          ),

          const SizedBox(height: 10,),

          SeamlessScrolling(
            containerWidth: 300,
            containerHeight: 200,
            children: [
              _testChild(
                width: 50,
                height: 200,
                color: const Color(0xFF111111),
                text: '1',
              ),
              _testChild(
                width: 100,
                height: 200,
                color: const Color(0xFF666666),
                text: '2',
              ),
              _testChild(
                width: 150,
                height: 200,
                color: const Color(0xFF999999),
                text: '3',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
