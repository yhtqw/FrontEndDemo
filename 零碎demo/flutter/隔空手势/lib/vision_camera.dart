import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'gesture_engine.dart';
import 'pixel_converter.dart';

class VisionCamera extends ChangeNotifier {
  final _clock = Stopwatch()..start();
  CameraController? controller;
  GestureRecognizer? _recognizer;
  PixelConverter? _converter;
  StreamSubscription<GestureRecognizerResult>? _subscription;
  Future<void> _serial = Future.value();
  bool _wanted = false, _closed = false, _busy = false;
  int _generation = 0, _lastSubmit = -1000;
  HandSample? hand;
  Size imageSize = const Size(480, 640);
  int resultMs = -1, trackingEpoch = 0;
  int latencyMs = 0;
  String? error;
  String? _side;

  int get nowMs => _clock.elapsedMilliseconds;
  bool get ready => controller?.value.isStreamingImages ?? false;

  // 初始化与释放串行执行，快速切后台也不会同时占用相机。
  Future<void> setEnabled(bool enabled) {
    if (_closed) return Future.value();
    _wanted = enabled;
    _serial = _serial.then((_) async {
      try {
        if (!_wanted || _closed) {
          await _stop();
        } else if (controller == null) {
          await _start();
          if (!_wanted || _closed) await _stop();
        }
      } catch (e) {
        error = e.toString();
        _wanted = false;
        await _stop();
      }
      _notify();
    });
    return _serial;
  }

  Future<void> _start() async {
    error = null;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('未找到摄像头');
    final front = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    final camera = front.isNotEmpty ? front.first : cameras.first;
    final ctrl = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    controller = ctrl;
    await ctrl.initialize();
    await ctrl.lockCaptureOrientation(DeviceOrientation.portraitUp);
    final converter = PixelConverter();
    _converter = converter;
    await converter.start();
    final task = await GestureRecognizer.create(
      GestureRecognizerOptions(
        model: VisionModels.gestureRecognizer,
        runningMode: RunningMode.liveStream,
        delegate: Delegate.cpu,
        numHands: 1,
      ),
    );
    _recognizer = task;
    final generation = _generation;
    _subscription = task.results.listen(
      (result) {
        if (generation == _generation) _onResult(result);
      },
      onError: (Object e) {
        error = e.toString();
        unawaited(setEnabled(false));
      },
    );
    await ctrl.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage frame) async {
    final captured = nowMs;
    // 转换前限流；整个管线最多一帧在途，避免旧结果排队。
    if (!_wanted || _closed || _busy || captured - _lastSubmit < 65) return;
    _busy = true;
    _lastSubmit = captured;
    final generation = _generation;
    try {
      final description = controller!.description;
      // iOS 插件已旋转输出，且前置帧已镜像；先还原成非镜像输入。
      final rotation = Platform.isIOS ? 0 : description.sensorOrientation;
      final pixels = await _converter!.convert(
        frame,
        rotation,
        mirror:
            Platform.isIOS &&
            description.lensDirection == CameraLensDirection.front,
      );
      if (generation != _generation || !_wanted || _closed) return;
      _recognizer!.recognizeAsync(
        VisionImage.fromPixels(
          pixels: pixels.rgba,
          width: pixels.width,
          height: pixels.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: captured,
      );
    } catch (e) {
      if (generation != _generation || _closed) return;
      _busy = false;
      error = e.toString();
      unawaited(setEnabled(false));
    }
  }

  void _onResult(GestureRecognizerResult result) {
    _busy = false;
    final timestamp = result.timestampMilliseconds;
    if (_closed || !_wanted || timestamp == null || timestamp <= resultMs) {
      return;
    }
    resultMs = timestamp;
    latencyMs = nowMs - timestamp;
    imageSize = Size(
      result.imageWidth.toDouble(),
      result.imageHeight.toDouble(),
    );
    if (latencyMs > 250 || result.handLandmarks.isEmpty) {
      hand = null;
    } else {
      final points = result.handLandmarks.first;
      final mirror =
          controller!.description.lensDirection == CameraLensDirection.front;
      final categories = result.gestures.firstOrNull ?? [];
      final side =
          (result.handedness.firstOrNull ?? []).firstOrNull?.categoryName;
      if (_side != null && side != _side) trackingEpoch++;
      _side = side;
      hand = HandSample(
        timestampMs: timestamp,
        points: points
            .map(
              (p) => Offset(
                (mirror ? 1 - p.x : p.x) * imageSize.width,
                p.y * imageSize.height,
              ),
            )
            .toList(growable: false),
        openPalm: categories.any(
          (c) => c.categoryName == 'Open_Palm' && c.score >= 0.7,
        ),
      );
    }
    _notify();
  }

  Future<void> _stop() async {
    _generation++;
    trackingEpoch++;
    final ctrl = controller;
    Future<void> release(Future<void> Function() operation) async {
      try {
        await operation();
      } catch (e) {
        error ??= e.toString();
      }
    }

    if (ctrl?.value.isStreamingImages ?? false) {
      await release(() => ctrl!.stopImageStream());
    }
    if (_converter != null) await release(_converter!.close);
    if (_recognizer != null) await release(_recognizer!.dispose);
    if (_subscription != null) await release(_subscription!.cancel);
    if (ctrl != null) await release(ctrl.dispose);
    controller = null;
    _converter = null;
    _recognizer = null;
    _subscription = null;
    _busy = false;
    hand = null;
    _side = null;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> close() async {
    _closed = true;
    _wanted = false;
    await _serial;
    await _stop();
    super.dispose();
  }
}
