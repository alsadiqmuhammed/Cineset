import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'brand.dart';
import 'models.dart';

/// محاذاة تلقائية: يكشف الوجه بالذكاء الاصطناعي على التلفون (ML Kit، بدون إنترنت).
/// للأسنان يأخذ زاويتي الفم، وللتجميل العينين. إذا ما لگى وجه (صور داخل الفم
/// مثلاً) يرجع null والطبيب يحدد النقطتين بإيده.
class AutoAligner {
  final AlignTarget target;
  AutoAligner(this.target);

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
    final face = faces.first;
    final lm = face.landmarks;
    if (target == AlignTarget.eyes) return _faceBox(photo, face);
    final (l, r) = target == AlignTarget.mouth
        ? (FaceLandmarkType.leftMouth, FaceLandmarkType.rightMouth)
        : (FaceLandmarkType.leftEye, FaceLandmarkType.rightEye);
    final left = lm[l]?.position;
    final right = lm[r]?.position;
    if (left == null || right == null) return null;
    return photo.withPoints(
      Offset(left.x.toDouble(), left.y.toDouble()),
      Offset(right.x.toDouble(), right.y.toDouble()),
    );
  }

  /// التجميل: المعيار الوجه كله مو الفم. النقطتين على خط العينين (للميلان)
  /// ويمرّن بمركز الوجه، والمسافة بيناتهن من عرض الوجه، فالوجه يطلع بنفس
  /// الحجم والمكان بالصورتين حتى لو الصورة من بعيد أو قريب. إذا ما بانت
  /// العينين (وجه جانبي) يبقى أفقي ويعتمد على مربع الوجه بس.
  Photo _faceBox(Photo photo, Face face) {
    final box = face.boundingBox;
    final c = Offset(box.center.dx, box.center.dy);
    var dir = const Offset(1, 0);
    final le = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final re = face.landmarks[FaceLandmarkType.rightEye]?.position;
    if (le != null && re != null) {
      final d = Offset((re.x - le.x).toDouble(), (re.y - le.y).toDouble());
      if (d.distance > 1) dir = d / d.distance;
      if (dir.dx < 0) dir = -dir;
    }
    // عرض الوجه يصير ~٦٠٪ من الشباك (الشباك يحط مسافة النقطتين على ٤٢٪).
    final half = box.width * (0.42 / 0.6) / 2;
    return photo.withPoints(c - dir * half, c + dir * half);
  }

  void close() => _detector.close().catchError((_) {});
}
