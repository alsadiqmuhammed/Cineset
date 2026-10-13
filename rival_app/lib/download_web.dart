import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// ينزّل الملف للكمبيوتر برابط مؤقت.
Future<void> downloadBytes(Uint8List bytes, String name, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.appendChild(a);
  a.click();
  a.remove();
  Future.delayed(
    const Duration(seconds: 2),
    () => web.URL.revokeObjectURL(url),
  );
}
