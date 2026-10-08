import 'package:flutter/services.dart';

/// يصنع فيديو MP4 على التلفون (MediaCodec بأندرويد): يبدأ بإطار "قبل"،
/// يتحول تدريجياً لـ "بعد" مع تقريب خفيف، ويثبت على "بعد".
/// القالب (overlay) يبقى ثابت فوق كل الإطارات بدون تقريب.
class VideoMaker {
  static const _channel = MethodChannel('rival/video');

  static Future<String> make({
    required String beforeFrame,
    required String afterFrame,
    String? overlay,
    required String output,
    double holdBefore = 1.2,
    double morph = 2.0,
    double holdAfter = 2.0,
    int fps = 30,
  }) async {
    final path = await _channel.invokeMethod<String>('make', {
      'before': beforeFrame,
      'after': afterFrame,
      'overlay': overlay,
      'output': output,
      'holdBefore': holdBefore,
      'morph': morph,
      'holdAfter': holdAfter,
      'fps': fps,
    });
    return path!;
  }
}
