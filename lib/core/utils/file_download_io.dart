import 'dart:typed_data';

Future<void> downloadBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  // Non-web targets are expected to use platform-native sharing/saving
  // (e.g. Share.shareXFiles) instead of this helper.
}
