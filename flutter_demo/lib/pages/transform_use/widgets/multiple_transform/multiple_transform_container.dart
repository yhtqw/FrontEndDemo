import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'all_optional_element_list.dart';
import 'configs/constants_config.dart';
import 'grid_painter.dart';
import 'models/bar_model.dart';
import 'models/element_model.dart';
import 'models/response_area_model.dart';
import 'text_options.dart';
import 'transform_function_bar.dart';
import 'transform_item.dart';
import 'transform_top_bar.dart';
import 'utils/transform_utils.dart';

class MultipleTransformContainer extends StatefulWidget {
  const MultipleTransformContainer({
    super.key,
    this.containerWidth,
    this.containerHeight,
    this.areaConfigList,
    required this.onSave,
  });

  /// 容器的宽，不传默认为父容器的最大宽度
  final double? containerWidth;
  /// 容器的高，不传默认为父容器的最大高度
  final double? containerHeight;
  /// 区域配置
  final List<CustomAreaConfig>? areaConfigList;
  final Function({required String imgSrc, required String data}) onSave;

  @override
  State<MultipleTransformContainer> createState() => _MultipleTransformContainerState();
}

class _MultipleTransformContainerState extends State<MultipleTransformContainer> {
  final GlobalKey _saveGlobalKey = GlobalKey();
  /// 用于获取容器的宽高
  final GlobalKey _multipleTransformContainerGlobalKey = GlobalKey();
  final List<ElementModel> _elementList = [];
  final List<ElementModel> _allOptionalElement = [];
  final ScrollController _scrollableX = ScrollController();
  final ScrollController _scrollableY = ScrollController();

  /// 记录一份容器的宽高，用于没传递的时候有个真实的容器宽高
  double _containerWidth = 0;
  double _containerHeight = 0;
  /// 当前选中的元素
  ElementModel? _currentElement;
  /// 临时的中间变量，用于计算
  TemporaryModel? _temporary;
  /// 开始点击的位置
  Offset _startPosition = Offset(0, 0);
  /// 容器响应操作区域
  List<ResponseAreaModel> _areaList = [];
  /// 是否展示文本属性部件
  bool _isShowTextOptions = false;
  bool _isLoading = false;
  bool _useGrid = false;
  bool _useAuxiliaryLine = false;
  bool _usePosition = false;
  bool _isMove = false;
  double _expandWidthRatio = 1;
  double _expandHeightRatio = 1;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getContainerSize();
      _initArea();
    });
  }

  @override
  void dispose() {
    _saveGlobalKey.currentState?.dispose();
    _multipleTransformContainerGlobalKey.currentState?.dispose();
    super.dispose();
  }

  /// 初始化响应区域
  void _initArea() {
    // 初始为配置里面定义的
    List<ResponseAreaModel> areaList = [...ConstantsConfig.baseAreaList];

    if (widget.areaConfigList != null) {
      // 将外界传递的配置合并
      for (var area in widget.areaConfigList!) {
        final int index = areaList.indexWhere(
          (item) => item.status == area.status,
        );

        // 如果是内置的区域，则修改配置
        if (index > -1) {
          // 如果是不使用，则移除
          if (area.use == false) {
            areaList.removeAt(index);
          } else {
            // 否则进行修改配置
            areaList[index].copyWith(
              xRatio: area.xRatio,
              yRatio: area.yRatio,
              icon: area.icon,
              fn: area.fn,
            );
          }
        } else {
          // 如果是自定义的区域，我们默认该有的参数是存在的
          areaList.add(ResponseAreaModel(
            areaWidth: ConstantsConfig.minSize,
            areaHeight: ConstantsConfig.minSize,
            xRatio: area.xRatio!,
            yRatio: area.yRatio!,
            trigger: area.trigger,
            icon: area.icon!,
            status: area.status,
            fn: area.fn,
          ));
        }
      }
    }

    setState(() {
      _areaList = areaList;
    });
  }

  /// 获取容器的宽高属性，用于没传递容器宽高的时候有个真实的容器宽高
  void _getContainerSize() {
    double tempWidth = 0;
    double tempHeight = 0;

    if (widget.containerHeight != null && widget.containerWidth != null) {
      tempHeight = widget.containerHeight!;
      tempWidth = widget.containerWidth!;
    } else {
      tempWidth = _multipleTransformContainerGlobalKey.currentContext?.size?.width ?? 0;
      tempHeight = _multipleTransformContainerGlobalKey.currentContext?.size?.height ?? 0;
    }

    setState(() {
      _containerHeight = tempHeight;
      _containerWidth = tempWidth;
    });
  }

  /// 按下事件
  void _onPanDown(PointerDownEvent details) {
    // 当存在选中元素的时候，记录点击点和初始化数据
    if (_currentElement != null) {
      final double dx = details.localPosition.dx;
      final double dy = details.localPosition.dy;
      final (String, TriggerMethod)? status = _onDownZone(
        x: dx,
        y: dy,
        item: _currentElement!,
      );

      _temporary = TemporaryModel(
        x: _currentElement!.x,
        y: _currentElement!.y,
        width: _currentElement!.elementWidth,
        height: _currentElement!.elementHeight,
        rotationAngle: _currentElement!.rotationAngle,
        status: status?.$1 ?? ElementStatus.move.value,
        trigger: status?.$2 ?? TriggerMethod.move,
      );
      _startPosition = Offset(dx, dy);

      setState(() {});
    }
  }

  /// 按下移动事件
  void _onPanUpdate(PointerMoveEvent details) {
    final double x = details.localPosition.dx;
    final double y = details.localPosition.dy;

    if (
      _currentElement == null
        || _temporary == null
        || ((x - _startPosition.dx).abs() < 1 && (y - _startPosition.dy).abs() < 1 && !_isMove)
    ) {
      return;
    }
    // 新增一个判断，如果发生了一个单位的移动且移动状态未false，则标记移动为true
    _isMove = true;

    final Function? fn = _onElementStatus(x: x, y: y)[_temporary?.status];

    if (_temporary?.trigger == TriggerMethod.move) {
      if (fn != null) {
        fn();
      } else {
        _onCustomFn(
          element: _currentElement!,
          tapPoint: _startPosition,
          movePoint: Offset(x, y),
          status: _temporary?.status,
        );
      }
    }
  }

  /// 结束事件
  void _onPanEnd(PointerUpEvent details) {
    final double dx = details.localPosition.dx;
    final double dy = details.localPosition.dy;

    // 每次结束后置空选中
    setState(() {
      _allOptionalElement.clear();
    });
    ElementModel? currentElement;

    // 判断抬起点的区域是否存在元素
    for (var i = (_elementList.length - 1); i >= 0; i--) {
      final item = _elementList[i];
      final (String, TriggerMethod)? status = _onDownZone(
        x: dx,
        y: dy,
        item: item,
      );

      if (status != null) {
        _allOptionalElement.add(item);
        currentElement ??= item;
        // break;
      }
    }

    if (_currentElement == null && currentElement != null) {
      // 如果不存在当前元素，但是抬起的区域内存在元素，
      // 则选中这个元素
      _currentElement = currentElement;
      setState(() {});
    } else {
      if (!_isMove) {
        if (currentElement == null) {
          // 如果抬起的区域内不存在任何的元素，
          // 则说明是空白区域，这执行清空
          _clean();
        } else {
          if (currentElement.id == _currentElement?.id) {
            // 如果响应区域的元素和选中的元素是同一个，
            // 则判断点击区域，如果点击区域是响应down的区域，
            // 则执行对应的down方法
            final (String, TriggerMethod)? status = _onDownZone(
              x: dx,
              y: dy,
              item: _currentElement!,
            );

            if (status != null && status.$2 == TriggerMethod.down) {
              final Function? fn = _onElementStatus(x: dx, y: dy)[status.$1];

              if (fn != null) {
                fn();
              } else {
                _onCustomFn(
                  element: _currentElement!,
                  tapPoint: Offset(dx, dy),
                  status: status.$1,
                );
              }

              if (status.$1 == ElementStatus.deleteStatus.value) {
                // 因为是删除，就置空选中，让下面代码执行最后的清除
                _clean();
              }
            } else {
              // 如果不存在down方法，则说明是二次点击，
              // 则取消选中
              _clean();
            }
          } else {
            // 如果不是同一个元素，则选中另外的那个元素
            _currentElement = currentElement;
            setState(() {});
          }
        }
      }
    }

    // 之前的逻辑
    if (_currentElement?.type != ElementType.textType.type && _isShowTextOptions) {
      setState(() {
        _isShowTextOptions = false;
      });
    } else if (_currentElement?.type == ElementType.textType.type && !_isShowTextOptions) {
      setState(() {
        _isShowTextOptions = true;
      });
    }

    // 重置移动状态
    _isMove = false;
  }

  /// 优化处理函数
  ///
  /// [x]和[y]坐标代表当前处理函数需要的坐标值
  Map<String, Function> _onElementStatus({
    required double x,
    required double y
  }) {
    return {
      ElementStatus.move.value: () => _onMove(x: x, y: y),
      ElementStatus.rotate.value: () => _onRotate(x: x, y: y),
      ElementStatus.scale.value: () => _onScale(x: x, y: y),
      ElementStatus.deleteStatus.value: () => _onDelete(),
    };
  }

  /// 处理删除元素
  void _onDelete() {
    if (_currentElement == null) return;

    _elementList.removeWhere((item) => item.id == _currentElement?.id);
  }

  /// 通过两个坐标距离中心点的距离计算缩放比例
  ///
  /// 通过移动中的点坐标[x]和[y]来计算缩放比例
  double _calcResizeRatio({required double x, required double y}) {
    final double oWidth = _temporary!.width;
    final double oHeight = _temporary!.height;
    final double oX = _temporary!.x;
    final double oY = _temporary!.y;
    // 中心点坐标，因为缩放不涉及到移动，
    // 所以中心点其实是没变的，用最初的值计算就行
    final double centerX = oX + oWidth / 2;
    final double centerY = oY + oHeight / 2;
    // 按下点与中心点的距离
    final double lineStart = sqrt(
      pow(centerX - _startPosition.dx, 2) + pow(centerY - _startPosition.dy, 2),
    );
    final double lineEnd = sqrt(pow(centerX - x, 2) + pow(centerY - y, 2));
    return lineEnd / lineStart;
  }

  /// 处理元素缩放
  ///
  /// 通过移动点坐标[x]和[y]与按下的初始坐标，
  void _onScale({required double x, required double y}) {
    if (_currentElement?.type == ElementType.textType.type) {
      _onScaleText(x: x, y: y);
    } else {
      _onScaleBase(x: x, y: y);
    }
  }

  /// 抽取获取缩放需要的基础参数
  (double, double, double, double, double) _getScaleParams({
    required double x,
    required double y,
  }) {
    final double oWidth = _temporary!.width;
    final double oHeight = _temporary!.height;
    final double oX = _temporary!.x;
    final double oY = _temporary!.y;
    final double resizeRatio = _calcResizeRatio(x: x, y: y);

    return (oWidth, oHeight, oX, oY, resizeRatio);
  }

  /// 处理非文本元素的缩放
  void _onScaleBase({required double x, required double y}) {
    if (_currentElement == null || _temporary == null) return;

    final (oWidth, oHeight, oX, oY, resizeRatio) = _getScaleParams(x: x, y: y);
    double newW = oWidth * resizeRatio;
    double newH = oHeight * resizeRatio;
    final double minSize = ConstantsConfig.minSize;

    // 以短边为基准来计算最小宽高
    if (oWidth <= oHeight && newW < minSize) {
      newW = minSize;
      newH = minSize * oHeight / oWidth;
    } else if (oHeight < oWidth && newH < minSize) {
      newH = minSize;
      newW = minSize * oWidth / oHeight;
    }

    // 以长边为基准来计算最大宽高
    if (oWidth >= oHeight && newW >= _expandTransformWidth) {
      newW = _expandTransformWidth;
      newH = _expandTransformWidth * oHeight / oWidth;
    } else if (oHeight > oWidth && newH >= _expandTransformHeight) {
      newH = _expandTransformHeight;
      newW = _expandTransformHeight * oWidth / oHeight;
    }

    if (
      newW == _currentElement?.elementWidth &&
        newH == _currentElement?.elementHeight
    ) {
      return;
    }

    _currentElement = _currentElement?.copyWith(
      elementWidth: newW,
      elementHeight: newH,
      x: oX - (newW - oWidth) / 2,
      y: oY - (newH - oHeight) / 2,
    );
    _onChange();
  }

  /// 文本元素的缩放
  void _onScaleText({required double x, required double y}) {
    if (_currentElement == null || _temporary == null) return;

    final (oWidth, oHeight, oX, oY, resizeRatio) = _getScaleParams(x: x, y: y);
    double newW = oWidth * resizeRatio;
    final double minSize = ConstantsConfig.minSize;

    // 以短边为基准来计算最小宽高
    if (oWidth <= oHeight && newW < minSize) {
      newW = minSize;
    }

    // 以长边为基准来计算最大宽高
    if (oWidth >= oHeight && newW >= _expandTransformWidth) {
      newW = _expandTransformWidth;
    }

    final TextStyle style = _getTextStyle(_currentElement!.textOptions!);
    final (tempWidth, tempHeight) = TransformUtils.calculateTextSize(
      text: _currentElement!.textOptions!.text,
      style: style,
      maxWidth: newW,
    );

    _currentElement = _currentElement?.copyWith(
      elementWidth: newW,
      elementHeight: tempHeight,
      x: oX - (newW - oWidth) / 2,
      y: oY - (tempHeight - oHeight) / 2,
    );
    _onChange();
  }

  /// 处理元素旋转
  ///
  /// 通过移动点坐标[x]和[y]与按下的初始坐标计算旋转的角度
  void _onRotate({required double x, required double y}) {
    if (_currentElement == null || _temporary == null) return;

    final double centerX = _currentElement!.x + _currentElement!.elementWidth / 2;
    final double centerY = _currentElement!.y + _currentElement!.elementHeight / 2;
    final double angleStart = atan2(
      _startPosition.dy - centerY,
      _startPosition.dx - centerX,
    );
    final double angleEnd = atan2(y - centerY, x - centerX);

    double angle = _temporary!.rotationAngle + angleEnd - angleStart;
    if (angle < 0) {
      angle += 2 * pi;
    }

    final double angleThreshold = pi / 180 * ConstantsConfig.angleThreshold;

    // 在特殊角度处
    if ((angle - pi / 2).abs() <= angleThreshold) {
      angle = pi / 2;
    } else if ((angle - pi).abs() <= angleThreshold) {
      angle = pi;
    } else if ((angle - pi * 3 / 2).abs() <= angleThreshold) {
      angle = pi * 3 / 2;
    } else if ((angle - pi * 2).abs() <= angleThreshold || angle.abs() <= angleThreshold) {
      angle = 0;
    }

    _currentElement = _currentElement!.copyWith(
      rotationAngle: angle,
    );
    _onChange();
  }

  /// 处理元素移动
  void _onMove({required double x, required double y}) {
    if (_currentElement == null || _temporary == null) return;

    double tempX = _temporary!.x + x - _startPosition.dx;
    double tempY = _temporary!.y + y - _startPosition.dy;

    if (_useGrid) {
      (tempX, tempY) = _getUseGridXY(x: tempX, y: tempY);
    }

    (tempX, tempY) = _getMoveBoundary(x: tempX, y: tempY);

    _onScroll(x: tempX, y: tempY);

    _currentElement = _currentElement!.copyWith(
      x: tempX,
      y: tempY,
    );
    _onChange();
  }

  /// 处理滚动
  ///
  /// 用当前元素的坐标[x]和[y]计算出最大最小的坐标值，
  /// 用最大和最小坐标值确定滚动条的位置
  _onScroll({required double x, required double y}) {
    // 最开始的
    final (prevLeftTop, prevLeftBottom, prevRightBottom, prevRightTop) = _getElementVertex(
      item: _currentElement!,
    );
    final List<Offset> prevVertexList = [
      prevLeftTop,
      prevLeftBottom,
      prevRightBottom,
      prevRightTop
    ];
    final (prevMinDx, prevMinDy, prevMaxDx, prevMaxDy) = _getExtremeVertex(
      vertexList: prevVertexList,
    );

    // 当前移动的
    final (leftTop, leftBottom, rightBottom, rightTop) = _getElementVertex(
      item: _currentElement!.copyWith(x: x, y: y),
    );
    final List<Offset> vertexList = [
      leftTop,
      leftBottom,
      rightBottom,
      rightTop
    ];
    final (minDx, minDy, maxDx, maxDy) = _getExtremeVertex(
      vertexList: vertexList,
    );

    final double offsetX = _scrollableX.offset;
    final double offsetY = _scrollableY.offset;
    final double maxScrollX = _scrollableX.position.maxScrollExtent;
    final double minScrollX = _scrollableX.position.minScrollExtent;
    final double maxScrollY = _scrollableY.position.maxScrollExtent;
    final double minScrollY = _scrollableY.position.minScrollExtent;

    if (prevMinDx > minDx) {
      // 左移
      if (offsetX > minScrollX && offsetX > minDx) {
        _scrollableX.jumpTo(offsetX - (prevMinDx - minDx));
      }
    } else if (prevMinDx < minDx) {
      // 右移
      if (offsetX < maxScrollX && offsetX < (maxDx - _transformWidth)) {
        _scrollableX.jumpTo(offsetX + (minDx - prevMinDx));
      }
    }

    if (prevMinDy > minDy) {
      // 上移
      if (offsetY > minScrollY && offsetY > minDy) {
        _scrollableY.jumpTo(offsetY - (prevMinDy - minDy));
      }
    } else if (prevMinDy < minDy) {
      // 下移
      if (offsetY < maxScrollY && offsetY < (maxDy - _transformHeight)) {
        _scrollableY.jumpTo(offsetY + (minDy - prevMinDy));
      }
    }
  }

  /// 获取开启网格辅助线时低于阈值的x和y
  ///
  /// 通过当前的[x]坐标和[y]坐标计算吸附坐标，如果低于阈值，则不吸附
  (double, double) _getUseGridXY({required double x, required double y}) {
    double tempX = x;
    double tempY = y;
    final double gridSize = ConstantsConfig.gridSize;
    // 吸附的阈值
    final double snapThreshold = ConstantsConfig.snapThreshold;
    // 当旋转的移动过程中，计算出来的x和y其实就是原始矩形的x和y
    // 所以此时我们将item的x和y改成计算出来的，通过这个来计算真实的顶点
    final (leftTop, leftBottom, rightBottom, rightTop) = _getElementVertex(
      item: _currentElement!.copyWith(x: x, y: y),
    );
    final List<Offset> vertexList = [
      leftTop,
      leftBottom,
      rightBottom,
      rightTop
    ];
    final (minDx, minDy, maxDx, maxDy) = _getExtremeVertex(
      vertexList: vertexList,
    );

    // 计算最近（最小顶点坐标点）的网格点
    double snappedLeftX = (minDx / gridSize).roundToDouble() * gridSize;
    double snappedLeftY = (minDy / gridSize).roundToDouble() * gridSize;
    // 计算最近（最大顶点坐标点）的网格点
    double snappedRightX = (maxDx / gridSize).roundToDouble() * gridSize;
    double snappedRightY = (maxDy / gridSize).roundToDouble() * gridSize;

    // 检查是否在吸附范围内
    double dxLeftDistance = minDx - snappedLeftX;
    double dyLeftDistance = minDy - snappedLeftY;
    double dxRightDistance = maxDx - snappedRightX;
    double dyRightDistance = maxDy - snappedRightY;
    // 计算旋转中心
    double cx = (maxDx - minDx) / 2 + minDx;
    double cy = (maxDy - minDy) / 2 + minDy;
    // 元素的一半宽高
    double halfWidth = _currentElement!.elementWidth / 2;
    double halfHeight = _currentElement!.elementHeight / 2;

    if (!(minDx == snappedLeftX || maxDx == snappedRightX)) {
      // 在X轴方向上应用吸附
      if (dxLeftDistance.abs() < dxRightDistance.abs() && dxLeftDistance.abs() < snapThreshold) {
        // 如果靠近左边且小于阈值，则吸附到左边
        tempX = cx - dxLeftDistance - halfWidth;
      } else if (dxRightDistance.abs() < dxLeftDistance.abs() && dxRightDistance.abs() < snapThreshold) {
        // 如果靠近右边且小于阈值，则吸附到右边
        tempX = cx - dxRightDistance - halfWidth;
      }
    }

    if (!(minDy == snappedLeftY || maxDy == snappedRightY)) {
      // 在Y轴方向上应用吸附
      if (dyLeftDistance.abs() < dyRightDistance.abs() && dyLeftDistance.abs() < snapThreshold) {
        // 如果靠近上面且小于阈值，则吸附到上面
        tempY = cy - dyLeftDistance - halfHeight;
      } else if (dyRightDistance.abs() < dyLeftDistance.abs() && dyRightDistance.abs() < snapThreshold) {
        // 如果靠近下面且小于阈值，则吸附到下面
        tempY = cy - dyRightDistance - halfHeight;
      }
    }

    return (tempX, tempY);
  }

  /// 获取移动时的边界
  ///
  /// 通过当前移动的[x]坐标和[y]坐标来计算中心点是否达到边界，
  /// 如果达到边界，则中心点坐标应用边界值
  (double, double) _getMoveBoundary({required double x, required double y}) {
    final double tempWidth = _currentElement!.elementWidth / ConstantsConfig.boundaryRatio;
    final double tempHeight = _currentElement!.elementHeight / ConstantsConfig.boundaryRatio;
    double centerX = x + tempWidth;
    double centerY = y + tempHeight;

    // 限制左边界
    if (centerX < 0) {
      centerX = 0;
    }
    // 限制右边界
    if (centerX > _expandTransformWidth) {
      centerX = _expandTransformWidth;
    }
    // 限制上边界
    if (centerY < 0) {
      centerY = 0;
    }
    // 限制下边界
    if (centerY > _expandTransformHeight) {
      centerY = _expandTransformHeight;
    }

    return (centerX - tempWidth, centerY - tempHeight);
  }

  /// 处理自定义事件
  ///
  /// 通过当前状态[status]来确定是否是自定义区域, 如果是,
  /// 则将按下坐标 [tapPoint], 移动坐标 [movePoint] (如果是移动状态),
  /// 和当前元素[element]传递过去用于自定义的计算
  void _onCustomFn({
    required ElementModel element,
    required Offset tapPoint,
    required String? status,
    Offset? movePoint,
  }) {
    final int index = _areaList.indexWhere((item) => item.status == status);

    if (index > -1) {
      final ResponseAreaModel item = _areaList[index];

      if (item.fn != null) {
        final ElementModel data = item.fn!(
          tapPoint: tapPoint,
          element: element,
          movePoint: movePoint,
          containerHeight: _expandTransformHeight,
          containerWidth: _expandTransformWidth,
        );
        _onChange(data: data);
      }
    }
  }

  /// 当前元素属性变化的时候更新列表中对应元素的属性
  ///
  /// 因为可能是触发用户的自定义区域，
  /// 所以如果是用户自定义的区域，则将对应元素的属性修改成用户计算后的元素属性
  void _onChange({ElementModel? data}) {
    if (_currentElement == null) return;

    final ElementModel? tempElement = data ?? _currentElement;

    for (var i = 0; i < _elementList.length; i++) {
      final ElementModel item = _elementList[i];

      if (item.id == tempElement?.id) {
        _elementList[i] = item.copyWith(
          x: tempElement?.x,
          y: tempElement?.y,
          elementWidth: tempElement?.elementWidth,
          elementHeight: tempElement?.elementHeight,
          rotationAngle: tempElement?.rotationAngle,
          textOptions: tempElement?.textOptions,
        );

        setState(() {});

        break;
      }
    }
  }

  /// 判断点击的区域
  ///
  /// 以传入的[item]元素为参考，
  /// 判断当前点击的坐标[x]和[y]落在[item]元素的哪个响应区域
  (String, TriggerMethod)? _onDownZone({
    required double x,
    required double y,
    required ElementModel item
  }) {
    // 先判断是否在响应对应操作的区域
    final (String, TriggerMethod)? areaStatus = _getElementZone(
      x: x,
      y: y,
      item: item,
    );
    if (areaStatus != null) {
      return areaStatus;
    } else if (_insideElement(x: x, y: y, item: item)) {
      // 因为加入旋转，所以单独抽取落点是否在元素内部的方法
      return (ElementStatus.move.value, TriggerMethod.move);
    }

    return null;
  }

  /// 判断点击落点是否在元素内部
  ///
  /// 以传入的[item]元素为参考，
  /// 判断当前点击的坐标[x]和[y]是否落在[item]元素的内部
  bool _insideElement({
    required double x,
    required double y,
    required ElementModel item
  }) {
    bool isInside = false;

    // 计算元素的四个顶点坐标
    final squareRes = _getElementVertex(item: item);

    final List<Offset> square = [
      squareRes.$1, squareRes.$2, squareRes.$3, squareRes.$4
    ];

    // 判断按下的坐标是否在元素内部
    for (var i = 0, j = square.length - 1; i < square.length; j = i++) {
      final double xi = square[i].dx;
      final double yi = square[i].dy;
      final double xj = square[j].dx;
      final double yj = square[j].dy;

      final bool intersect = yi > y != yj > y && x < (xj - xi) * (y - yi) / (yj - yi) + xi;

      if (intersect) isInside = !isInside;
    }

    return isInside;
  }

  /// 计算元素的顶点坐标
  ///
  /// 计算传入元素[item]的顶点坐标，返回顺序为左上，右上，右下，左下
  (Offset, Offset, Offset, Offset) _getElementVertex({
    required ElementModel item
  }) {
    // 计算元素的四个顶点坐标
    return (
      _rotatePoint(
        x: item.x,
        y: item.y,
        item: item,
      ),
      _rotatePoint(
        x: item.x + item.elementWidth,
        y: item.y,
        item: item,
      ),
      _rotatePoint(
        x: item.x + item.elementWidth,
        y: item.y + item.elementHeight,
        item: item,
      ),
      _rotatePoint(
        x: item.x,
        y: item.y + item.elementHeight,
        item: item,
      ),
    );
  }

  /// 获取顶点坐标中的最大xy和最小xy
  ///
  /// 通过顶点坐标列表[vertexList]对比出最大和最小
  (double, double, double, double) _getExtremeVertex({
    required List<Offset> vertexList
  }) {
    double minDx = vertexList[0].dx;
    double minDy = vertexList[0].dy;
    double maxDx = vertexList[3].dx;
    double maxDy = vertexList[3].dy;

    for (var item in vertexList) {
      if (item.dx < minDx) {
        minDx = item.dx;
      } else if (item.dx > maxDx) {
        maxDx = item.dx;
      }
      if (item.dy < minDy) {
        minDy = item.dy;
      } else if (item.dy > maxDy) {
        maxDy = item.dy;
      }
    }

    return (minDx, minDy, maxDx, maxDy);
  }

  /// 快速的获取元素的最小的顶点坐标值和最大的顶点坐标值
  (double, double, double, double) get _elementVertex {
    if (_currentElement == null) {
      return (0, 0, _expandTransformWidth, _expandTransformHeight);
    }

    final (leftTop, rightTop, rightBottom, leftBottom) = _getElementVertex(
      item: _currentElement!,
    );
    final List<Offset> vertexList = [
      leftTop,
      leftBottom,
      rightBottom,
      rightTop
    ];

    return _getExtremeVertex(vertexList: vertexList);
  }

  /// 判断点击落点是否在元素的某个操作区域
  ///
  /// 以传入的[item]元素为参考，
  /// 判断当前点击的坐标[x]和[y]是否落在[item]元素的某个响应区域
  (String, TriggerMethod)? _getElementZone({
    required double x,
    required double y,
    required ElementModel item
  }) {
    (String, TriggerMethod)? tempStatus;

    for (var i = 0; i < _areaList.length; i++) {
      final ResponseAreaModel currentArea = _areaList[i];
      // 计算操旋转过后的操作区域的中心点坐标
      final Offset pos = _rotatePoint(
        x: item.x + item.elementWidth * currentArea.xRatio,
        y: item.y + item.elementHeight * currentArea.yRatio,
        item: item,
      );
      final double dx = pos.dx;
      final double dy = pos.dy;
      final double areaCW = currentArea.areaWidth / 2;
      final double areaCH = currentArea.areaHeight / 2;

      // 以区域中心点计算区域边界值和坐标进行比较
      if (
        x >= dx - areaCW &&
        x <= dx + areaCW &&
        y >= dy - areaCH &&
        y <= dy + areaCH
      ) {
        tempStatus = (currentArea.status, currentArea.trigger);
        break;
      }
    }

    return tempStatus;
  }

  /// 以传入元素为参考确定某点旋转后的坐标
  ///
  /// 以传入的[item]为参考，计算原坐标[x]和[y]旋转后的坐标
  Offset _rotatePoint({
    required double x,
    required double y,
    required ElementModel item
  }) {
    final double deg = item.rotationAngle;
    // 确定旋转中心，坐标系是以外层容器为基准
    final double centerX = item.x + item.elementWidth / 2;
    final double centerY = item.y + item.elementHeight / 2;
    final double diffX = x - centerX;
    final double diffY = y - centerY;

    final double dx = diffX * cos(deg) - diffY * sin(deg) + centerX;
    final double dy = diffX * sin(deg) + diffY * cos(deg) + centerY;

    return Offset(dx, dy);
  }

  void _addElement(ElementModel item) {
    if (_currentElement != null) {
      _clean();
    }
    setState(() {
      _elementList.add(item);
      _currentElement = item;
    });
  }

  /// 变换区域的宽
  double get _transformWidth {
    return _width - ConstantsConfig.transformMargin * 2;
  }

  /// 扩展变换区域的宽
  double get _expandTransformWidth {
    return _transformWidth * _expandWidthRatio;
  }

  /// 变换区域的高
  double get _transformHeight {
    return _height - ConstantsConfig.bottomHeight - ConstantsConfig.topHeight;
  }

  /// 扩展变换区域的高
  double get _expandTransformHeight {
    return _transformHeight * _expandHeightRatio;
  }

  /// 最终容器的宽
  double get _width {
    return _containerWidth == 0 ? (widget.containerWidth ?? double.infinity) : _containerWidth;
  }

  /// 最终容器的高
  double get _height {
    return _containerHeight == 0 ? (widget.containerHeight ?? double.infinity) : _containerHeight;
  }

  /// 展示文本属性设置部件
  void _onShowTextOptions(bool isShow) {
    setState(() {
      _isShowTextOptions = isShow;
    });
  }

  /// 获取文本属性
  TextStyle _getTextStyle(ElementTextOptions textOptions) {
    return TextStyle(
      fontSize: textOptions.fontSize,
      height: textOptions.textHeight,
      letterSpacing: textOptions.letterSpacing,
      fontWeight: TransformUtils.getFontWeight(
        textOptions.fontWeight,
      ),
    );
  }

  /// 设置文本的属性
  void _setTextOptions(ElementTextOptions textOptions) {
    if (_currentElement?.type == ElementType.textType.type) {
      final TextStyle style = _getTextStyle(textOptions);
      final (tempWidth, tempHeight) = TransformUtils.calculateTextSize(
        text: textOptions.text,
        style: style,
        maxWidth: _currentElement!.elementWidth,
      );

      _currentElement = _currentElement?.copyWith(
        // elementWidth: tempWidth,
        elementHeight: tempHeight,
        textOptions: _currentElement?.textOptions?.copyWith(
          text: textOptions.text,
          textHeight: textOptions.textHeight,
          fontSize: textOptions.fontSize,
          fontColor: textOptions.fontColor,
          fontWeight: textOptions.fontWeight,
          fontFamily: textOptions.fontFamily,
          textAlign: textOptions.textAlign,
          letterSpacing: textOptions.letterSpacing,
        ),
      );
      _onChange();
    }
  }

  /// 获取结构的图片
  Future<String> _getImagePath() async {
    try {
      // 获取RenderObject
      RenderRepaintBoundary boundary = _saveGlobalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // 转换为图片
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      // 获取字节数据
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 获取临时目录
      Directory tempDir = await getTemporaryDirectory();
      String fileName = 'temp_transform_${DateTime.now().millisecondsSinceEpoch}.png';
      File file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(pngBytes);

      return file.path;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _onSave() async {
    if (_isLoading) return;
    _isLoading = true;

    if (_currentElement != null) {
      _clean();

      Future.delayed(Duration(milliseconds: 200), () {
        _isLoading = false;
        _onSave();
      });
    } else {
      final String imagePath = await _getImagePath();
      final List<Map<String, dynamic>> tempStringList = _elementList.map((item) => ElementModel.toJson(item)).toList();

      widget.onSave(imgSrc: imagePath, data: jsonEncode(tempStringList));

      _isLoading = false;
    }
  }

  void _clean() {
    _allOptionalElement.clear();
    setState(() {
      _currentElement = null;
      _temporary = null;
      _useGrid =  false;
      _useAuxiliaryLine = false;
      _usePosition = false;
      _isShowTextOptions = false;
    });
  }

  void _onChangeUseGrid() {
    setState(() {
      _useGrid = !_useGrid;
    });
  }

  void _onChangeUseAuxiliaryLine() {
    setState(() {
      _useAuxiliaryLine = !_useAuxiliaryLine;
    });
  }

  void _onChangeUsePosition() {
    if (_currentElement == null) return;

    setState(() {
      _usePosition = !_usePosition;
    });
  }

  /// 处理层级
  void _onLevel(LevelType type) {
    final index = _elementList.indexWhere((ele) => ele.id == _currentElement?.id);
    if (index > -1) {
      final len = _elementList.length;
      final tempItem = _elementList[index];

      if (type == LevelType.top && index != (len -1)) {
        _elementList.removeAt(index);
        _elementList.insert(len - 1, tempItem);
        setState(() {});
      } else if (type == LevelType.bottom && index != 0) {
        _elementList.removeAt(index);
        _elementList.insert(0, tempItem);
        setState(() {});
      } else if (type == LevelType.upper && index < (len -1)) {
        _elementList[index] = _elementList[index + 1];
        _elementList[index + 1] = tempItem;
        setState(() {});
      } else if (type == LevelType.next && index > 0) {
        _elementList[index] = _elementList[index - 1];
        _elementList[index - 1] = tempItem;
        setState(() {});
      }
    }
  }

  void _selectedElement(ElementModel item) {
    if (item.id != _currentElement?.id) {
      setState(() {
        _isShowTextOptions = false;
        _currentElement = item;
      });
    }
  }

  void _onExpandWidth() {
    if (_expandWidthRatio < ConstantsConfig.maxSizeRatio) {
      setState(() {
        _expandWidthRatio += ConstantsConfig.expandSizeRatio;
      });
    }
  }

  void _onReduceWidth() {
    if (_expandWidthRatio > ConstantsConfig.minSizeRatio) {
      setState(() {
        _expandWidthRatio -= ConstantsConfig.expandSizeRatio;
      });
    }
  }

  void _onExpandHeight() {
    if (_expandHeightRatio < ConstantsConfig.maxSizeRatio) {
      setState(() {
        _expandHeightRatio += ConstantsConfig.expandSizeRatio;
      });
    }
  }

  void _onReduceHeight() {
    if (_expandHeightRatio > ConstantsConfig.minSizeRatio) {
      setState(() {
        _expandHeightRatio -= ConstantsConfig.expandSizeRatio;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _multipleTransformContainerGlobalKey,
      width: _width,
      height: _height,
      child: _containerWidth == 0 || _containerHeight == 0 ? null : Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: _width,
              height: _height,
              child: Column(
                children: [
                  // 顶部功能区
                  TransformTopBar(
                    onSave: _onSave,
                    onUseGrid: _onChangeUseGrid,
                    useGrid: _useGrid,
                    useAuxiliaryLine: _useAuxiliaryLine,
                    onChangeUseAuxiliaryLine: _onChangeUseAuxiliaryLine,
                    usePosition: _usePosition,
                    onChangeUsePosition: _onChangeUsePosition,
                    currentElement: _currentElement,
                    onLevel: _onLevel,
                  ),

                  // 变换区域
                  Container(
                    width: _transformWidth,
                    height: _transformHeight,
                    margin: EdgeInsets.symmetric(
                      horizontal: ConstantsConfig.transformMargin,
                    ),
                    // decoration: BoxDecoration(
                    //   color: Colors.white,
                    // ),
                    // 处理横向
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _scrollableX,
                      physics: _currentElement == null ? ClampingScrollPhysics() : NeverScrollableScrollPhysics(),
                      // 纵向
                      child: SingleChildScrollView(
                        controller: _scrollableY,
                        physics: _currentElement == null ? ClampingScrollPhysics() : NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RepaintBoundary(
                              key: _saveGlobalKey,
                              // child: GestureDetector(
                              child: Listener(
                                // onPanDown: _onPanDown,
                                // onPanUpdate: _onPanUpdate,
                                // onPanEnd: _onPanEnd,
                                onPointerDown: _onPanDown,
                                onPointerMove: _onPanUpdate,
                                onPointerUp: _onPanEnd,
                                // onPanCancel: _onPanEnd,
                                child: Container(
                                  width: _expandTransformWidth,
                                  height: _expandTransformHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Stack(
                                    children: [
                                      // 网格线
                                      if (_useGrid) CustomPaint(
                                        painter: GridPainter(),
                                        size: Size.infinite,
                                      ),

                                      ..._elementList.map((item) => TransformItem(
                                        key: ValueKey('${item.id}'),
                                        elementItem: item,
                                        selected: item.id == _currentElement?.id,
                                        areaList: _areaList,
                                      )),

                                      // 辅助线
                                      if (_useAuxiliaryLine) Positioned(
                                        top: 0,
                                        left: _elementVertex.$1,
                                        child: Container(
                                          width: 1,
                                          height: _expandTransformHeight,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                      if (_useAuxiliaryLine) Positioned(
                                        top: _elementVertex.$2,
                                        left: 0,
                                        child: Container(
                                          width: _expandTransformWidth,
                                          height: 1,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                      if (_useAuxiliaryLine) Positioned(
                                        top: 0,
                                        left: _elementVertex.$3,
                                        child: Container(
                                          width: 1,
                                          height: _expandTransformHeight,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                      if (_useAuxiliaryLine) Positioned(
                                        top: _elementVertex.$4,
                                        left: 0,
                                        child: Container(
                                          width: _expandTransformWidth,
                                          height: 1,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 底部功能区域
                  TransformFunctionBar(
                    transformWidth: _transformWidth,
                    transformHeight: _transformHeight,
                    addElement: _addElement,
                    onShowTextOptions: _onShowTextOptions,
                    onExpandHeight: _onExpandHeight,
                    onExpandWidth: _onExpandWidth,
                    onReduceHeight: _onReduceHeight,
                    onReduceWidth: _onReduceWidth,
                  ),
                ],
              ),
            ),
          ),

          // 可选中的所有元素
          if (_allOptionalElement.isNotEmpty && _allOptionalElement.length > 1) Positioned(
            left: 5,
            bottom: ConstantsConfig.fontOptionsWidgetHeight + 5,
            child: AllOptionalElementList(
              list: _allOptionalElement,
              onSelected: _selectedElement,
            ),
          ),

          // 文本属性设置部件
          TextOptions(
            transformWidth: _expandTransformWidth,
            isShow: _isShowTextOptions,
            textOptions: _currentElement?.textOptions,
            addElement: _addElement,
            setTextOptions: _setTextOptions,
          ),
        ],
      ),
    );
  }
}
