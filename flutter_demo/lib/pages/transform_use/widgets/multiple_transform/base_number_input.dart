import 'package:flutter/material.dart';

import 'base_options_title.dart';

class BaseNumberInput extends StatelessWidget {
  const BaseNumberInput({
    super.key,
    required this.onReduce,
    required this.onAdd,
    required this.value,
    required this.title,
  });

  final Function() onReduce;
  final Function() onAdd;
  final String value;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BaseOptionsTitle(
          title: title,
        ),
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: onReduce,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Text('-'),
                ),
              ),
              Container(
                width: 40,
                margin: EdgeInsets.symmetric(horizontal: 5,),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Text('+'),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
