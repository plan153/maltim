import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerHelper {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static void prePlay() {
    // No-op on mobile
  }

  static Future<void> playBytes(Uint8List bytes) async {
    try {
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      print('Mobile Audio playBytes error: $e');
      rethrow;
    }
  }

  static Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Mobile Audio stop error: $e');
    }
  }
}
