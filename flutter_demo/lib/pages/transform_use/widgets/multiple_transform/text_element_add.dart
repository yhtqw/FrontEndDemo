import 'package:flutter/material.dart';

class TextElementAdd extends StatefulWidget {
  const TextElementAdd({
    super.key,
    required this.onShowTextOptions,
  });

  /// 展示文本属性部件
  final Function(bool) onShowTextOptions;

  @override
  State<TextElementAdd> createState() => _TextElementAddState();
}

class _TextElementAddState extends State<TextElementAdd> {
  void _onShowText() {
    widget.onShowTextOptions(true);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _onShowText,
      child: Text(
        '文本',
        style: TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }
}
