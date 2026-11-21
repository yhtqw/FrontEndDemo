import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';

typedef Pixels = ({Uint8List rgba, int width, int height});

// 复用一个 isolate，像素转换不占用 UI isolate。
class PixelConverter {
  final _responses = ReceivePort();
  final _ready = Completer<SendPort>();
  late final StreamSubscription<dynamic> _subscription;
  Isolate? _worker;
  SendPort? _port;
  Completer<Pixels>? _pending;

  Future<void> start() async {
    _subscription = _responses.listen((dynamic message) {
      if (message is SendPort) {
        _port = message;
        _ready.complete(message);
      } else if (message is String) {
        _pending?.completeError(StateError(message));
        _pending = null;
      } else {
        final data = message as (TransferableTypedData, int, int);
        _pending?.complete((
          rgba: data.$1.materialize().asUint8List(),
          width: data.$2,
          height: data.$3,
        ));
        _pending = null;
      }
    });
    _worker = await Isolate.spawn(_convertLoop, _responses.sendPort);
    await _ready.future;
  }

  Future<Pixels> convert(
    CameraImage image,
    int rotation, {
    bool mirror = false,
  }) async {
    if (_pending != null) throw StateError('转换任务尚未完成');
    final bgra = image.format.group == ImageFormatGroup.bgra8888;
    if (!bgra && image.planes.length != 3) {
      throw UnsupportedError('需要 BGRA 或三平面 YUV420 图像');
    }
    final port = _port;
    if (port == null) throw StateError('转换器尚未就绪');
    final request = (
      width: image.width,
      height: image.height,
      rotation: rotation,
      bgra: bgra,
      mirror: mirror,
      planes: image.planes
          .map((p) => TransferableTypedData.fromList([p.bytes]))
          .toList(),
      rows: image.planes.map((p) => p.bytesPerRow).toList(),
      steps: image.planes.map((p) => p.bytesPerPixel ?? 1).toList(),
    );
    final result = Completer<Pixels>();
    _pending = result;
    port.send(request);
    return result.future;
  }

  Future<void> close() async {
    _worker?.kill(priority: Isolate.immediate);
    _pending?.completeError(StateError('转换器已关闭'));
    _pending = null;
    await _subscription.cancel();
    _responses.close();
  }
}

typedef PixelRequest = ({
  int width,
  int height,
  int rotation,
  bool bgra,
  bool mirror,
  List<TransferableTypedData> planes,
  List<int> rows,
  List<int> steps,
});

void _convertLoop(SendPort output) {
  final input = ReceivePort();
  output.send(input.sendPort);
  input.listen((dynamic message) {
    try {
      final request = message as PixelRequest;
      final result = convertPixels(request);
      output.send((
        TransferableTypedData.fromList([result.rgba]),
        result.width,
        result.height,
      ));
    } catch (error) {
      output.send(error.toString());
    }
  });
}

// 转为 RGBA 并实际旋转像素，交给模型时 rotationDegrees 保持 0。
Pixels convertPixels(PixelRequest request) {
  final w = request.width, h = request.height;
  final turn = request.rotation % 360;
  if (turn % 90 != 0) throw ArgumentError('旋转角度必须是 90 的倍数');
  final swap = turn == 90 || turn == 270;
  final outW = swap ? h : w, outH = swap ? w : h;
  final rgba = Uint8List(outW * outH * 4);
  final planes = request.planes
      .map((p) => p.materialize().asUint8List())
      .toList();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final (dx, dy) = switch (turn) {
        90 => (h - 1 - y, x),
        180 => (w - 1 - x, h - 1 - y),
        270 => (y, w - 1 - x),
        _ => (x, y),
      };
      final outputX = request.mirror ? outW - 1 - dx : dx;
      final dst = (dy * outW + outputX) * 4;
      if (request.bgra) {
        final src = y * request.rows[0] + x * 4;
        rgba[dst] = planes[0][src + 2];
        rgba[dst + 1] = planes[0][src + 1];
        rgba[dst + 2] = planes[0][src];
      } else {
        final luma = planes[0][y * request.rows[0] + x * request.steps[0]];
        final u =
            planes[1][(y ~/ 2) * request.rows[1] +
                (x ~/ 2) * request.steps[1]] -
            128;
        final v =
            planes[2][(y ~/ 2) * request.rows[2] +
                (x ~/ 2) * request.steps[2]] -
            128;
        // BT.601 有限范围；分别尊重每个平面的 row/pixel stride。
        final c = (luma - 16).clamp(0, 255);
        rgba[dst] = ((298 * c + 409 * v + 128) >> 8).clamp(0, 255);
        rgba[dst + 1] = ((298 * c - 100 * u - 208 * v + 128) >> 8).clamp(
          0,
          255,
        );
        rgba[dst + 2] = ((298 * c + 516 * u + 128) >> 8).clamp(0, 255);
      }
      rgba[dst + 3] = 255;
    }
  }
  return (rgba: rgba, width: outW, height: outH);
}
