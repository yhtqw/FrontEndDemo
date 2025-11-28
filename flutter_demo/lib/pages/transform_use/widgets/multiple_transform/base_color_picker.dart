import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class BaseColorPicker extends StatefulWidget {
  const BaseColorPicker({
    super.key,
    required this.color,
    required this.onChange,
  });

  final Color color;
  final Function(Color) onChange;

  @override
  State<BaseColorPicker> createState() => _BaseColorPickerState();
}

class _BaseColorPickerState extends State<BaseColorPicker> {
  void _onShowColorPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => IntrinsicHeight(
        child: Column(
          children: [
            SizedBox(height: 20,),
            ColorPicker(
              pickerColor: widget.color,
              onColorChanged: widget.onChange,
            ),
            SizedBox(height: 20,),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onShowColorPicker,
      child: Container(
        height: 20,
        color: widget.color,
      ),
    );
  }
}
