import '../models/element_model.dart';
import '../models/response_area_model.dart';

/// 用于设置一些初始化值
class ConstantsConfig {
  /// 元素的初始化x坐标
  static const double initX = 10;
  /// 元素的初始化y坐标
  static const double initY = 10;
  /// 元素的初始化旋转角度
  static const double initRotationAngle = 0;
  /// 元素的最小宽高
  static const double minSize = 20;
  /// 元素操作区域的icon边距
  static const double areaIconMargin = 8;
  /// 元素的操作区域
  static final List<ResponseAreaModel> baseAreaList = [
    // 旋转
    ResponseAreaModel(
      areaWidth: 20,
      areaHeight: 20,
      xRatio: 1,
      yRatio: 0,
      status: ElementStatus.rotate.value,
      icon: 'assets/images/icon_rotate.png',
      trigger: TriggerMethod.move,
    ),
    // 缩放
    ResponseAreaModel(
      areaWidth: 20,
      areaHeight: 20,
      xRatio: 1,
      yRatio: 1,
      status: ElementStatus.scale.value,
      icon: 'assets/images/icon_scale.png',
      trigger: TriggerMethod.move,
      iconConfig: {
        ElementType.textType.type: 'assets/images/icon_scale_text.png',
      },
    ),
    // 删除
    ResponseAreaModel(
      areaWidth: 20,
      areaHeight: 20,
      xRatio: 0,
      yRatio: 0,
      status: ElementStatus.deleteStatus.value,
      icon: 'assets/images/icon_delete.png',
      trigger: TriggerMethod.down,
    ),
  ];
  /// 底部功能区域的高度
  static const double bottomHeight = 100;
  /// 变换区域的左右margin
  static const double transformMargin = 20;
  /// 初始化的文本大小
  static const double initFontSize = 12;
  /// 初始化的行高
  static const double initFontHeight = 1;
  /// 初始化的文本对齐方式
  static const String initFontAlign = 'left';
  /// 文本属性部件的高度
  static const double fontOptionsWidgetHeight = 200;
}
