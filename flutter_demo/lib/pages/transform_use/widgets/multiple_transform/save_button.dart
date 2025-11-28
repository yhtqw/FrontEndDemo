import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.onSave});

  /// 保存
  final Function() onSave;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onSave,
      child: Text(
        '保存',
        style: TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }
}
