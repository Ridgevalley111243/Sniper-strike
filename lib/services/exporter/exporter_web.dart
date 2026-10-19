import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browsers cannot write into arbitrary folders; this uses the normal
/// download flow, which saves to the user's Downloads folder (or asks).
Future<bool> exportBytes(String fileName, List<int> bytes, String mimeType) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final url = web.URL.createObjectURL(web.Blob([data.toJS].toJS, web.BlobPropertyBag(type: mimeType)));
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(a);
  a.click();
  a.remove();
  Future<void>.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return true;
}
