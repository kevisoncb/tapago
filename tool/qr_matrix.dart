// Imprime a matriz de um QR code (uma linha de 0/1 por linha do código).
// Uso: dart run tool/qr_matrix.dart arquivo-com-a-url.txt
// (a URL vem de um arquivo porque o "&" quebra o argumento no Windows).
import 'dart:io';

import 'package:qr/qr.dart';

void main(List<String> args) {
  final qr = QrCode.fromData(
    data: File(args.first).readAsStringSync().trim(),
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final image = QrImage(qr);
  for (var row = 0; row < image.moduleCount; row++) {
    final line = StringBuffer();
    for (var col = 0; col < image.moduleCount; col++) {
      line.write(image.isDark(row, col) ? '1' : '0');
    }
    print(line);
  }
}
