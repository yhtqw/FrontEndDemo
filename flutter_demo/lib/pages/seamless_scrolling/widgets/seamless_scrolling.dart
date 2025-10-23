import 'package:flutter/cupertino.dart';

class SeamlessScrolling extends StatefulWidget {
  const SeamlessScrolling({
    super.key,
    required this.containerWidth,
    required this.containerHeight,
    required this.children,
    this.copyItemNumber,
    this.milliseconds
  });

  /// 容器宽度
  final double containerWidth;
  /// 容器高度
  final double containerHeight;
  /// 要复制的子元素个数，如果存在就只复制对应的子元素，如果不存在就复制整个子元素列表
  final int? copyItemNumber;
  /// 子元素列表
  final List<Widget> children;
  /// 动画持续时间，默认 10000 毫秒
  final int? milliseconds;

  @override
  State<SeamlessScrolling> createState() => _SeamlessScrollingState();
}

class _SeamlessScrollingState extends State<SeamlessScrolling>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final GlobalKey _rowKey = GlobalKey();
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onStart();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStart() {
    double rowWidth = _measureWidth();

    _controller = AnimationController(
      duration: Duration(milliseconds: widget.milliseconds ?? 10000),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: -rowWidth)
      .animate(_controller)
      ..addListener(() {
        setState(() {});
      });
  }

  /// 获取子部件排列的宽度
  double _measureWidth() {
    final RenderBox box = _rowKey.currentContext!.findRenderObject() as RenderBox;
    return box.size.width;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.containerWidth,
      height: widget.containerHeight,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: _animation == null ? 0 : _animation!.value,
            child: Row(
              children: [
                Row(
                  key: _rowKey,
                  children: widget.children,
                ),

                // 如果传递了要复制的元素个数，就只复制这几个
                if (widget.copyItemNumber != null
                    && widget.copyItemNumber! <= widget.children.length
                ) ...widget.children.sublist(0, widget.copyItemNumber),

                // 否则全部复制一份
                if (widget.copyItemNumber == null) ...widget.children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}