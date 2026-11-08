import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum RevealEffect { iris, diamond, dissolve }

class RevealRoute extends PageRouteBuilder<void> {
  RevealRoute({
    required ui.FragmentProgram? program,
    required RevealEffect effect,
    required Widget page,
    Offset origin = const Offset(0.5, 0.5),
    bool reducedMotion = false,
    Duration duration = const Duration(milliseconds: 900),
  }) : super(
         opaque: true,
         maintainState: true,
         transitionDuration: reducedMotion ? Duration.zero : duration,
         reverseTransitionDuration: reducedMotion ? Duration.zero : duration,
         pageBuilder: (_, _, _) => page,
         transitionsBuilder: (_, animation, _, child) => RevealTransition(
           program: program,
           animation: animation,
           effect: effect,
           origin: origin,
           child: child,
         ),
       );
}

// 固定包装层级，完成态只切换绘制路径。
class RevealTransition extends SingleChildRenderObjectWidget {
  const RevealTransition({
    super.key,
    required this.program,
    required this.animation,
    required this.effect,
    required this.origin,
    required super.child,
  });
  
  final ui.FragmentProgram? program;
  final Animation<double> animation;
  final RevealEffect effect;
  final Offset origin;

  @override
  RenderReveal createRenderObject(BuildContext context) => RenderReveal(
    program: program,
    animation: animation,
    effect: effect,
    origin: origin,
  );

  @override
  void updateRenderObject(BuildContext context, RenderReveal renderObject) {
    renderObject
      ..program = program
      ..animation = animation
      ..effect = effect
      ..origin = origin;
  }
}

class RenderReveal extends RenderProxyBox {
  RenderReveal({
    required ui.FragmentProgram? program,
    required this._animation,
    required this._effect,
    required this._origin,
  }) : _program = program,
       _shader = program?.fragmentShader();

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  Animation<double> _animation;
  RevealEffect _effect;
  Offset _origin;
  bool get _complete => _animation.status == AnimationStatus.completed;

  set program(ui.FragmentProgram? value) {
    if (identical(value, _program)) return;
    
    layer = null;
    
    _shader?.dispose();
    
    _program = value;
    _shader = value?.fragmentShader();
    
    markNeedsPaint();
  }

  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    
    if (attached) _unlisten();
    
    _animation = value;
    
    if (attached) _listen();
    
    _statusChanged(value.status);
  }

  set effect(RevealEffect value) {
    if (value == _effect) return;
    
    _effect = value;
    
    markNeedsPaint();
  }

  set origin(Offset value) {
    if (value == _origin) return;
    
    _origin = value;
    
    markNeedsPaint();
  }

  void _listen() {
    _animation.addListener(markNeedsPaint);
    _animation.addStatusListener(_statusChanged);
  }

  void _unlisten() {
    _animation.removeListener(markNeedsPaint);
    _animation.removeStatusListener(_statusChanged);
  }

  void _statusChanged(AnimationStatus _) {
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    
    _listen();
    _statusChanged(_animation.status);
  }

  @override
  void detach() {
    _unlisten();
    
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && !_complete;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _complete && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_complete) super.visitChildrenForSemantics(visitor);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    
    if (_complete) {
      layer = null; // 不再创建遮罩层，页面子树仍在原位。
      super.paint(context, offset);
    
      return;
    }
    
    final t = Curves.easeInOutCubic.transform(_animation.value.clamp(0.0, 1.0));
    
    if (t <= 0 || size.isEmpty) {
      layer = null;
     
      return;
    }
    
    final shader = _shader;
    
    if (shader == null) {
      final previous = layer;
      
      layer = context.pushOpacity(
        offset,
        (t * 255).round(),
        super.paint,
        oldLayer: previous is OpacityLayer ? previous : null,
      );
      
      return;
    }
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, t)
      ..setFloat(3, _effect.index.toDouble())
      ..setFloat(4, _origin.dx)
      ..setFloat(5, _origin.dy)
      ..setFloat(6, _effect == RevealEffect.dissolve ? 5.0 : 40.0)
      ..setFloat(7, _effect == RevealEffect.dissolve ? 0.25 : 1.5);
    
    final mask = layer is ShaderMaskLayer
        ? layer! as ShaderMaskLayer
        : ShaderMaskLayer();
    
    mask
      ..shader = shader
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    
    layer = mask;
    context.pushLayer(mask, super.paint, offset);
  }

  @override
  void dispose() {
    layer = null;
    _shader?.dispose();
    
    super.dispose();
  }
}
