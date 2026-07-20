import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;

class OnDeviceVisionResult {
  const OnDeviceVisionResult({required this.looksLikeFood, this.foodBoundingBox});

  final bool looksLikeFood;

  /// Union of the bounding boxes of all objects classified as food, in the
  /// pixel coordinates of the analyzed image. Null when nothing was
  /// confidently classified as food.
  final Rect? foodBoundingBox;
}

/// On-device object detection (Google ML Kit, fully local — no network call)
/// used to pre-check that a photo actually contains food before spending a
/// Claude Vision API call on it, and to crop tightly to the food region when
/// it only occupies part of the frame.
class OnDeviceVisionService {
  OnDeviceVisionService()
      : _detector = ObjectDetector(
          options: ObjectDetectorOptions(
            mode: DetectionMode.single,
            classifyObjects: true,
            multipleObjects: true,
          ),
        );

  final ObjectDetector _detector;

  static const _confidenceThreshold = 0.5;
  static const _foodLabel = 'food';

  /// Padding added around the detected food region before cropping, as a
  /// fraction of that region's width/height.
  static const _cropPadding = 0.08;

  /// If the food region already covers this fraction of the frame or more,
  /// cropping wouldn't meaningfully help — skip it.
  static const _skipCropAreaRatio = 0.85;

  Future<OnDeviceVisionResult> analyze(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final objects = await _detector.processImage(inputImage);

      Rect? union;
      for (final object in objects) {
        final isFood = object.labels.any(
          (label) =>
              label.text.toLowerCase() == _foodLabel &&
              label.confidence >= _confidenceThreshold,
        );
        if (!isFood) continue;
        union = union == null
            ? object.boundingBox
            : union.expandToInclude(object.boundingBox);
      }

      return OnDeviceVisionResult(looksLikeFood: union != null, foodBoundingBox: union);
    } catch (_) {
      // Fail open: on-device detection is a nice-to-have, never a blocker.
      return const OnDeviceVisionResult(looksLikeFood: true, foodBoundingBox: null);
    }
  }

  /// Crops [originalBytes] to [boundingBox] (plus padding) and re-encodes as
  /// JPEG. Returns [originalBytes] unchanged if decoding fails, the region
  /// already fills most of the frame, or the computed crop is degenerate.
  Uint8List cropToFoodRegion({
    required Uint8List originalBytes,
    required Rect boundingBox,
  }) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) return originalBytes;

    final width = decoded.width;
    final height = decoded.height;
    final imageArea = width * height;
    final boxArea = boundingBox.width * boundingBox.height;
    if (imageArea == 0 || boxArea / imageArea > _skipCropAreaRatio) {
      return originalBytes;
    }

    final padX = boundingBox.width * _cropPadding;
    final padY = boundingBox.height * _cropPadding;

    final left = (boundingBox.left - padX).clamp(0, width.toDouble()).round();
    final top = (boundingBox.top - padY).clamp(0, height.toDouble()).round();
    final right = (boundingBox.right + padX).clamp(0, width.toDouble()).round();
    final bottom = (boundingBox.bottom + padY).clamp(0, height.toDouble()).round();

    final cropWidth = right - left;
    final cropHeight = bottom - top;
    if (cropWidth <= 0 || cropHeight <= 0) return originalBytes;

    final cropped = img.copyCrop(
      decoded,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  }

  void close() => _detector.close();
}
