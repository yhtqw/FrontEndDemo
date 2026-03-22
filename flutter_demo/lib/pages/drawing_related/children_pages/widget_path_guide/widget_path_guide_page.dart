import 'package:flutter/material.dart';

// import './widgets/path_guide_wrapper/path_guide_wrapper.dart';
import './widgets/path_guide_wrapper/path_guide_wrapper_01.dart';
import './widgets/path_guide_wrapper/path_guide_shader_mask.dart';

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

            // ...[1,2,3,4,5,6,7].map((item) => PathGuideWrapper(
            //   color: Colors.orange,
            //   strokeWidth: 6,
            //   trailLengthPercent: 0.4,
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            //     decoration: BoxDecoration(
            //       color: Colors.grey[900],
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: const Text(
            //       "点击这里",
            //       style: TextStyle(color: Colors.white, fontSize: 18),
            //     ),
            //   ),
            // )),

            // ShaderMask(
            //   // 定义着色器：这里用一个横向的线性渐变
            //   shaderCallback: (Rect bounds) {
            //     return LinearGradient(
            //       colors: [Colors.blue, Colors.purple, Colors.red],
            //       tileMode: TileMode.mirror,
            //     ).createShader(bounds);
            //   },
            //   // 混合模式：srcIn 表示只在文字有内容的地方显示渐变色
            //   blendMode: BlendMode.srcIn,
            //   child: const Text(
            //     '测试文本测试文本测试文本',
            //     style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            //   ),
            // ),
            //
            // SizedBox(height: 20,),
            //
            // ShaderMask(
            //   shaderCallback: (Rect bounds) {
            //     return LinearGradient(
            //       begin: Alignment.topCenter,
            //       end: Alignment.bottomCenter,
            //       colors: [
            //         Colors.black, // 顶部不透明（黑色代表完全保留）
            //         Colors.transparent // 底部透明（透明代表完全遮蔽）
            //       ],
            //       // 前20%保留，最后80%开始淡出
            //       stops: [0.2, 1.0],
            //     ).createShader(bounds);
            //   },
            //   // dstIn 常用于基于透明度的遮罩
            //   blendMode: BlendMode.dstIn,
            //   child: Image.asset(
            //     'assets/images/icon_next_level.png',
            //     fit: BoxFit.cover,
            //     color: Colors.blueAccent,
            //   ),
            // ),
            //
            // SizedBox(height: 20,),

            // 给一个简单的 Text 加边框
            PathGuideShaderMask(
              borderWidth: 6,
              borderRadius: 20,
              duration: const Duration(seconds: 1),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '我是文字',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.black
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 给卡片加边框
            PathGuideShaderMask(
              borderWidth: 4,
              borderRadius: 15,
              duration: const Duration(seconds: 3),
              child: Container(
                width: 250,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black,
                ),
                child: Text(
                  '我是卡片',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white
                  ),
                ),
              ),
            ),

            SizedBox(height: 20,),

            // PathGuideWrapper(
            //   child: Text('测试文本测试文本测试文本'),
            // ),
          ],
        ),
      )
    );
  }
}
