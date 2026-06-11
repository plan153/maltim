// 웹 전용 구현. 조건부 import로 웹에서만 컴파일된다.
// 웹의 Azure 재생은 web_tts_helper(Speech SDK)가 담당하므로 여기는 보조 역할.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class AudioPlayerHelper {
  static html.AudioElement? _audioElement;
  static String? _currentBlobUrl;

  static void prePlay() {
    try {
      if (_audioElement == null) {
        _audioElement = html.AudioElement();
        html.document.body?.append(_audioElement!);
      }
      _cleanupBlob();
      _audioElement!.src =
          'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAIlYAAESsAAACABAAZGF0YQAAAAA=';
      _audioElement!.load();
      _audioElement!.play().catchError((e) {
        print('Web Audio priming failed/prevented: $e');
      });
    } catch (e) {
      print('Web Audio prePlay error: $e');
    }
  }

  static Future<void> playBytes(Uint8List bytes) async {
    try {
      if (_audioElement == null) {
        prePlay();
      }
      final blob = html.Blob([bytes], 'audio/mpeg');
      _currentBlobUrl = html.Url.createObjectUrlFromBlob(blob);
      _audioElement!.src = _currentBlobUrl!;
      _audioElement!.load();
      await _audioElement!.play();
    } catch (e) {
      print('Web Audio playBytes error: $e');
      rethrow;
    }
  }

  static Future<void> stop() async {
    try {
      if (_audioElement != null) {
        _audioElement!.pause();
        try {
          _audioElement!.currentTime = 0;
        } catch (_) {}
      }
      _cleanupBlob();
    } catch (e) {
      print('Web Audio stop error: $e');
    }
  }

  static void _cleanupBlob() {
    if (_currentBlobUrl != null) {
      try {
        if (_audioElement != null && _audioElement!.src == _currentBlobUrl) {
          _audioElement!.src = '';
        }
      } catch (_) {}
      try {
        html.Url.revokeObjectUrl(_currentBlobUrl!);
      } catch (_) {}
      _currentBlobUrl = null;
    }
  }
}
