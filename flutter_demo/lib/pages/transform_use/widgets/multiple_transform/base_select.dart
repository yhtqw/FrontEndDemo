import 'package:flutter/material.dart';

class BaseSelect<T> extends StatelessWidget {
  const BaseSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.buildOption,
  });

  final T value;
  final List<T> items;
  final void Function(T?) onChanged;
  final Widget Function(T)? buildOption;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      isDense: true,
      isExpanded: true,
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: buildOption == null ? Text(
          '$item',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black,
          ),
        ) : buildOption!(item),
      )).toList(),
      onChanged: (T? value) {
        onChanged(value);
      },
    );
  }
}
