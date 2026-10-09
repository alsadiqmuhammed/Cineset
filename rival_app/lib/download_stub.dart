import 'dart:typed_data';

/// بالتلفون الملفات تنحفظ وتنشارك من مسارها، فهذي ما تنستعمل.
Future<void> downloadBytes(Uint8List bytes, String name, String mime) async =>
    throw UnsupportedError('downloadBytes is web-only');
