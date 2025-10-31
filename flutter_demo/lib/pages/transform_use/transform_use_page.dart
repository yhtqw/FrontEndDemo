import 'package:flutter/material.dart';

import 'widgets/transform_container.dart';

class TransformUsePage extends StatefulWidget {
  const TransformUsePage({super.key});

  static final String routePath = '/transform-use';

  @override
  State<TransformUsePage> createState() => _TransformUsePageState();
}

class _TransformUsePageState extends State<TransformUsePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TransformContainer(),
          ],
        ),
      )
    );
  }
}
