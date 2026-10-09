import 'dart:async';

import 'package:flutter/services.dart';

/// يصنع فيديو MP4 على التلفون (OpenGL + MediaCodec بأندرويد): يبدأ بإطار "قبل"،
/// يتحول تدريجياً لـ "بعد" مع تقريب خفيف، ويثبت على "بعد".
/// القالب (overlay) يبقى ثابت فوق كل الإطارات بدون تقريب.
class VideoMaker {
  static const _channel = MethodChannel('rival/video');

  static Future<String> make({
    required String beforeFrame,
    required String afterFrame,
    String? overlay,
    required String output,
    String? log,
    void Function(double progress)? onProgress,
    double holdBefore = 1.2,
    double morph = 2.0,
    double holdAfter = 2.0,
    int fps = 30,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        onProgress?.call((call.arguments as num).toDouble());
      }
    });
    try {
      final path = await _channel
          .invokeMethod<String>('make', {
            'before': beforeFrame,
            'after': afterFrame,
            'overlay': overlay,
            'output': output,
            'log': log,
            'holdBefore': holdBefore,
            'morph': morph,
            'holdAfter': holdAfter,
            'fps': fps,
          })
          .timeout(timeout);
      return path!;
    } on TimeoutException {
      throw Exception('الفيديو أخذ وقت أكثر من اللازم وتوقف');
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }
}
