import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/element_model.dart';

class ImageElementAdd extends StatefulWidget {
  const ImageElementAdd({
    super.key,
    required this.transformWidth,
    required this.transformHeight,
    required this.addElement,
  });

  /// 变换区域的宽，用于计算选择图片的初始宽度
  final double transformWidth;
  /// 变换区域的高，用于计算选择图片的初始高度
  final double transformHeight;
  /// 新增元素方法，用于将选择的图片添加到元素列表中
  final Function(ElementModel) addElement;

  @override
  State<ImageElementAdd> createState() => _ImageElementAddState();
}

class _ImageElementAddState extends State<ImageElementAdd> {
  /// 选择图片
  Future<void> _imagePicker() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (imageFile != null) {
      final imageInfo = await _loadImageFromFile(imageFile.path);

      widget.addElement(ElementModel(
        id: DateTime.now().millisecondsSinceEpoch,
        elementWidth: imageInfo.$1,
        elementHeight: imageInfo.$2,
        type: ElementType.imageType.type,
        imagePath: imageFile.path,
      ));
    }
  }

  /// 从本地文件加载图片并获取宽高
  ///
  /// 通过[filePath]获取这张图片的宽高
  Future<(double, double)> _loadImageFromFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imageInfo = frame.image;

    final double imageWidth = imageInfo.width.toDouble();
    final double imageHeight = imageInfo.height.toDouble();
    final double tempContainerWidth = widget.transformWidth / 2;
    final double tempContainerHeight = widget.transformHeight / 2;
    double tempWidth = imageWidth;
    double tempHeight = imageHeight;

    // 以长边来设置图片的最终初始宽高
    if (imageWidth >= imageHeight) {
      tempWidth = imageWidth > tempContainerWidth ? tempContainerWidth : imageWidth;
      tempHeight = (tempWidth / imageWidth) * imageHeight;
    } else {
      tempHeight = imageHeight > tempContainerHeight ? tempContainerHeight : imageHeight;
      tempWidth = (tempHeight / imageHeight) * imageWidth;
    }

    return (tempWidth, tempHeight);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _imagePicker,
      child: Text(
        '图片',
        style: TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }
}
