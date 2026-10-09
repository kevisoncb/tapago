import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String?> readReceiptText(String path) async {
  if (path.trim().isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return _read(InputImage.fromFilePath(path));
}

Future<String?> readReceiptBytes(List<int> bytes) async {
  if (bytes.isEmpty) return null;
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}pago_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  try {
    return readReceiptText(file.path);
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

Future<String?> _read(InputImage image) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(image);
    final text = result.text.trim();
    return text.isEmpty ? null : text;
  } finally {
    await recognizer.close();
  }
}
