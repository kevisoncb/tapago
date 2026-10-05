import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String?> readReceiptText(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    final text = result.text.trim();
    return text.isEmpty ? null : text;
  } finally {
    await recognizer.close();
  }
}
