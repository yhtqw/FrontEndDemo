import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'base_color_picker.dart';
import 'base_number_input.dart';
import 'base_options_title.dart';
import 'base_select.dart';
import 'configs/constants_config.dart';
import 'models/element_model.dart';
import 'utils/transform_utils.dart';

class TextOptions extends StatefulWidget {
  const TextOptions({
    super.key,
    required this.transformWidth,
    required this.isShow,
    required this.addElement,
    required this.setTextOptions,
    this.textOptions,
  });

  /// 变换区域的宽，用于计算选择文本元素的最大宽度
  final double transformWidth;
  /// 文本元素属性部件是否展示
  final bool isShow;
  final ElementTextOptions? textOptions;
  /// 新增元素方法，用于新增文本部件
  final Function(ElementModel) addElement;
  /// 设置文本的属性
  final Function(ElementTextOptions) setTextOptions;

  @override
  State<TextOptions> createState() => _TextOptionsState();
}

class _TextOptionsState extends State<TextOptions> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  @override
  void didUpdateWidget(covariant TextOptions oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.textOptions?.text != widget.textOptions?.text) {
      _controller.text = widget.textOptions?.text ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _init() {
    if (widget.textOptions != null) {
      _controller.text = widget.textOptions!.text;
    }
  }

  /// 新增文本元素
  void _onSubmitText(String text) {
    if (text == '') return;

    // 如果存在传入的文本属性，说明是编辑
    if (widget.textOptions != null) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          text: text,
        ),
      );
      return;
    }

    // 一些初始化的文本属性
    TextStyle style = TextStyle(
      fontSize: ConstantsConfig.initFontSize,
      height: ConstantsConfig.initFontHeight,
    );

    final (tempWidth, tempHeight) = TransformUtils.calculateTextSize(
      text: text,
      style: style,
      maxWidth: widget.transformWidth,
    );

    widget.addElement(ElementModel(
      id: DateTime.now().millisecondsSinceEpoch,
      elementHeight: tempHeight,
      elementWidth: tempWidth,
      type: ElementType.textType.type,
      textOptions: ElementTextOptions(text: text),
    ));
  }

  void _onReduceFontHeight() {
    if (widget.textOptions != null && widget.textOptions!.textHeight > 0) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          textHeight: (
              Decimal.parse('${widget.textOptions!.textHeight}') - Decimal.parse('0.1')
          ).toDouble(),
        ),
      );
    }
  }

  void _onAddFontHeight() {
    if (widget.textOptions != null) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          textHeight: (
              Decimal.parse('${widget.textOptions!.textHeight}') + Decimal.parse('0.1')
          ).toDouble(),
        ),
      );
    }
  }

  void _onReduceLetterSpacing() {
    if (widget.textOptions != null && (widget.textOptions!.letterSpacing ?? 0) > 0) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          letterSpacing: (
              Decimal.parse('${widget.textOptions!.letterSpacing ?? 0}') - Decimal.parse('0.1')
          ).toDouble(),
        ),
      );
    }
  }

  void _onAddLetterSpacing() {
    if (widget.textOptions != null) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          letterSpacing: (
              Decimal.parse('${widget.textOptions!.letterSpacing ?? 0}') + Decimal.parse('0.1')
          ).toDouble(),
        ),
      );
    }
  }

  void _onReduceFontSize() {
    if (widget.textOptions != null && (widget.textOptions!.fontSize) > 8) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          fontSize: (
              Decimal.parse('${widget.textOptions!.fontSize}') - Decimal.parse('1')
          ).toDouble(),
        ),
      );
    }
  }

  void _onAddFontSize() {
    if (widget.textOptions != null) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          fontSize: (
              Decimal.parse('${widget.textOptions!.fontSize}') + Decimal.parse('1')
          ).toDouble(),
        ),
      );
    }
  }

  void _onReduceFontWeight() {
    if (widget.textOptions != null && (widget.textOptions!.fontWeight ?? 400) > 100) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          fontWeight: (widget.textOptions!.fontWeight ?? 400) - 100,
        ),
      );
    }
  }

  void _onAddFontWeight() {
    if (widget.textOptions != null && (widget.textOptions!.fontWeight ?? 400) < 1000) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(
          fontWeight: (widget.textOptions!.fontWeight ?? 400) + 100,
        ),
      );
    }
  }

  void _onChangeColor(Color color) {
    if (widget.textOptions != null) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(fontColor: color,),
      );
    }
  }

  void _onChangeTextAlign(String? textAlign) {
    if (widget.textOptions != null && textAlign != null) {
      widget.setTextOptions(
        widget.textOptions!.copyWith(textAlign: textAlign,),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 200),
      left: 0,
      right: 0,
      bottom: widget.isShow ? 0 : -ConstantsConfig.fontOptionsWidgetHeight,
      child: Container(
        padding: EdgeInsets.all(20),
        height: ConstantsConfig.fontOptionsWidgetHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            topLeft: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _controller,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    counter: const Offstage(),
                    hintText: '请输入',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  onSubmitted: _onSubmitText,
                  onTapOutside: (event) {
                    FocusScopeNode currentFocus = FocusScope.of(context);
                    currentFocus.focusedChild?.unfocus();
                  },
                ),
              ),
              SizedBox(height: 10,),
              if (widget.textOptions != null) Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: BaseNumberInput(
                          onAdd: _onAddFontHeight,
                          onReduce: _onReduceFontHeight,
                          title: '行高：',
                          value: '${widget.textOptions!.textHeight}',
                        ),
                      ),
                      Expanded(
                        child: BaseNumberInput(
                          onAdd: _onAddLetterSpacing,
                          onReduce: _onReduceLetterSpacing,
                          title: '字间距：',
                          value: '${widget.textOptions!.letterSpacing ?? 0}',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: BaseNumberInput(
                          onAdd: _onAddFontSize,
                          onReduce: _onReduceFontSize,
                          title: '字体大小：',
                          value: '${widget.textOptions!.fontSize}',
                        ),
                      ),
                      Expanded(
                        child: BaseNumberInput(
                          onAdd: _onAddFontWeight,
                          onReduce: _onReduceFontWeight,
                          title: '字重：',
                          value: '${widget.textOptions!.fontWeight ?? 400}',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            BaseOptionsTitle(title: '字体颜色：',),
                            Expanded(
                              child: BaseColorPicker(
                                color: widget.textOptions!.fontColor,
                                onChange: _onChangeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            BaseOptionsTitle(title: '对齐方式：',),
                            Expanded(
                              child: BaseSelect<String>(
                                value: widget.textOptions!.textAlign!,
                                items: [
                                  TextAlignType.left.type,
                                  TextAlignType.right.type,
                                  TextAlignType.center.type,
                                  TextAlignType.justify.type,
                                ],
                                onChanged: _onChangeTextAlign,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            BaseOptionsTitle(title: '字体：',),
                            // Expanded(
                            //   child: BaseSelect<String>(
                            //     value: widget.textOptions!.fontFamily ?? '',
                            //     items: [
                            //       '字体1',
                            //       '字体2',
                            //       '字体3',
                            //       '字体4',
                            //     ],
                            //     onChanged: _onChangeTextAlign,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 30,),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
