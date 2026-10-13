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
    VideoStyle style = VideoStyle.dissolve,
    int lineColor = 0xFFFFFFFF,
    double lineWidth = 0.006,
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
            'style': style.index,
            'lineColor': lineColor,
            'lineWidth': lineWidth,
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

/// أنماط الانتقال من قبل لبعد (نفس ترتيب الأرقام بالكود الأصلي على التلفون).
enum VideoStyle {
  dissolve('ذوبان', 'قبل تذوب لبعد'),
  wipe('مسح', 'خط يمسح من قبل لبعد'),
  slider('سلايدر', 'الخط يتحرك ويستقر بالنص'),
  rise('صعود', 'بعد تطلع من الأسفل'),
  circle('دائرة', 'بعد تنفتح من النص');

  final String label, hint;
  const VideoStyle(this.label, this.hint);
}
