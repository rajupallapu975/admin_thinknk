import 'dart:typed_data';

void downloadBytes(Uint8List bytes, String fileName) {
  throw UnsupportedError('Cannot use web download on non-web platform');
}
