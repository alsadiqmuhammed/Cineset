import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'models.dart';

/// محاذاة تلقائية: يكشف الوجه بالذكاء الاصطناعي على التلفون (ML Kit، بدون إنترنت)
/// ويأخذ زاويتي الفم كنقطتي محاذاة. إذا ما لگى وجه (صور داخل الفم مثلاً) يرجع null
/// والمستخدم يحدد النقطتين بيده.
class AutoAligner {
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<Photo?> align(Photo photo) async {
    final faces = await _detector.processImage(
      InputImage.fromFilePath(photo.path),
    );
    if (faces.isEmpty) return null;
    faces.sort(
      (x, y) => (y.boundingBox.width * y.boundingBox.height).compareTo(
        x.boundingBox.width * x.boundingBox.height,
      ),
    );
    final lm = faces.first.landmarks;
    final left = lm[FaceLandmarkType.leftMouth]?.position;
    final right = lm[FaceLandmarkType.rightMouth]?.position;
    if (left == null || right == null) return null;
    return photo.withPoints(
      Offset(left.x.toDouble(), left.y.toDouble()),
      Offset(right.x.toDouble(), right.y.toDouble()),
    );
  }

  void close() => _detector.close().catchError((_) {});
}
