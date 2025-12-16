import 'dart:io';

import 'package:flutter/material.dart';

import 'models/element_model.dart';

class AllOptionalElementList extends StatelessWidget {
  const AllOptionalElementList({
    super.key,
    required this.onSelected,
    required this.list,
  });

  final List<ElementModel> list;
  final Function(ElementModel) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      padding: EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Color(0xFFF0F0F0),
        border: Border.all(
          color: Colors.blueAccent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: BoxConstraints(
        maxHeight: 200,
      ),
      child: SingleChildScrollView(
        child: Column(
          spacing: 10,
          children: [
            ...list.map((item) => GestureDetector(
              onTap: () => onSelected(item),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.type == ElementType.imageType.type) Image.file(
                    File(item.imagePath!),
                    width: 50,
                    height: 50,
                    fit: BoxFit.scaleDown,
                  ),

                  if (item.type == ElementType.textType.type && item.textOptions != null) SizedBox(
                    width: 50,
                    child: Text(
                      item.textOptions!.text,
                      style: TextStyle(
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
