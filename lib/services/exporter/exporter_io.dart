import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Opens the system "Save as" picker so the user chooses a device folder.
Future<bool> exportBytes(String fileName, List<int> bytes, String mimeType) async {
  try {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      mimeType: mimeType,
      dialogTitle: 'Save a copy',
    );
    return uri != null;
  } catch (_) {
    return false;
  }
}
