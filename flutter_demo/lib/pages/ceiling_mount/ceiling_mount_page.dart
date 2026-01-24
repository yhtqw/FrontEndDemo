import 'package:flutter/material.dart';

// import 'widgets/ceiling_mount_scroll.dart';
import 'widgets/ceiling_mount_scroll_ceiling2.dart';

class CeilingMountPage extends StatefulWidget {
  const CeilingMountPage({super.key});

  static final String routePath = '/ceiling_mount';

  @override
  State<CeilingMountPage> createState() => _CeilingMountPageState();
}

class _CeilingMountPageState extends State<CeilingMountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("吸顶"),
      ),
      body: CeilingMountScroll2(),
    );
  }
}
