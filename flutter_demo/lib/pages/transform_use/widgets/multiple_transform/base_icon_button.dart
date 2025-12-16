import 'package:flutter/material.dart';

class BaseIconButton extends StatelessWidget {
  const BaseIconButton({
    super.key,
    required this.onPressed,
    required this.iconSrc,
    this.isSelected,
    this.disabled,
  });

  final Function() onPressed;
  final String iconSrc;
  final bool? isSelected;
  final bool? disabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: AnimatedContainer(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected == true ? Colors.blueAccent : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(milliseconds: 500),
        child: Image.asset(
          iconSrc,
          width: 20,
          height: 20,
          color: disabled == true ? Colors.grey : isSelected == true ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
