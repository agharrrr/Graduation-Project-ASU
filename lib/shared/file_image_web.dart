import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Widget buildPickedImagePreview({
  required Uint8List? bytes,
  required String? filePath,
  BoxFit fit = BoxFit.cover,
}) {
  if (bytes != null) {
    return Image.memory(bytes, fit: fit);
  }

  // On mobile you may still have a file path
  if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
    // ignore: avoid_web_libraries_in_flutter
    // Image.file is fine on mobile
    return Image.file(
      // ignore: deprecated_member_use
      // (use dart:io File only in mobile files)
      // You'll import dart:io in the calling file, not here.
      throw UnimplementedError('Use Image.file in mobile-only branch'),
    );
  }

  return const SizedBox.shrink();

}

Widget fileImageWidget(
    String path, {
      BoxFit fit = BoxFit.cover,
    }) {
  // Web does not support Image.file; this should never be called on web.
  return const SizedBox.shrink();
}
