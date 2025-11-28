import 'dart:io';

import 'package:flutter/material.dart';

// import 'widgets/multiple_transform/models/element_model.dart';
import 'widgets/multiple_transform/models/response_area_model.dart';
import 'widgets/multiple_transform/multiple_transform_container.dart';
// import 'widgets/transform_container.dart';

class TransformUsePage extends StatefulWidget {
  const TransformUsePage({super.key});

  static final String routePath = '/transform-use';

  @override
  State<TransformUsePage> createState() => _TransformUsePageState();
}

class _TransformUsePageState extends State<TransformUsePage> {
  late List<CustomAreaConfig> _customAreaList;

  @override
  void initState() {
    super.initState();

    _customAreaList = [
      // // 不使用缩放区域
      // CustomAreaConfig(
      //   status: ElementStatus.scale.value,
      //   use: false,
      // ),
      // // 将旋转移到右下角
      // CustomAreaConfig(
      //   status: ElementStatus.rotate.value,
      //   xRatio: 1,
      //   yRatio: 1,
      // ),
      // // 测试自定义区域
      // CustomAreaConfig(
      //   status: 'center',
      //   xRatio: 0,
      //   yRatio: 1,
      //   icon: 'assets/images/icon_center.png',
      //   trigger: TriggerMethod.down,
      //   fn: _centerFn,
      // ),
    ];
  }

  void _onSave({required String imgSrc, required String data}) {
    print(imgSrc);
    print(data);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: EdgeInsets.zero,
        content: IntrinsicHeight(
          child: Center(
            child: Image.file(File(imgSrc)),
          ),
        ),
      ),
    );
  }

  // /// 测试自定义区域的函数
  // ElementModel _centerFn({
  //   /// 点击的坐标
  //   required Offset tapPoint,
  //   /// 选中的元素
  //   required ElementModel element,
  //   /// 容器的宽度
  //   required double containerWidth,
  //   /// 容器的高度
  //   required double containerHeight,
  //   /// 移动的坐标
  //   Offset? movePoint,
  // }) {
  //   final double x = (containerWidth - element.elementWidth) / 2;
  //   final double y = (containerHeight - element.elementHeight) / 2;
  //
  //   return ElementModel(
  //     id: element.id,
  //     elementWidth: element.elementWidth,
  //     elementHeight: element.elementHeight,
  //     x: x,
  //     y: y,
  //     type: element.type,
  //     rotationAngle: element.rotationAngle,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).colorScheme.inversePrimary,
        child: Column(
          children: [
            // TransformContainer(),
            SizedBox(height: 54,),
            Expanded(
              child: MultipleTransformContainer(
                areaConfigList: _customAreaList,
                onSave: _onSave,
              ),
            ),
          ],
        ),
      )
    );
  }
}
