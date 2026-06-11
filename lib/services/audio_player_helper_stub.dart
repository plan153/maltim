import 'dart:typed_data';

class AudioPlayerHelper {
  static void prePlay() {
    throw UnsupportedError('Cannot play audio without html or io libraries.');
  }

  static Future<void> playBytes(Uint8List bytes) async {
    throw UnsupportedError('Cannot play audio without html or io libraries.');
  }

  static Future<void> stop() async {
    throw UnsupportedError('Cannot play audio without html or io libraries.');
  }
}
