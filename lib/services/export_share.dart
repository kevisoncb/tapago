import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Files leave the app only after an explicit user action and through the
/// platform share sheet (or the browser download fallback).
Future<ShareResult> shareExport(
  BuildContext context, {
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  required String subject,
}) {
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize && !box.size.isEmpty
      ? box.localToGlobal(Offset.zero) & box.size
      : const Rect.fromLTWH(0, 0, 1, 1);
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
      fileNameOverrides: [filename],
      subject: subject,
      sharePositionOrigin: origin,
    ),
  );
}
