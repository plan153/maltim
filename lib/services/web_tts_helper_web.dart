import 'dart:js_interop';

/// index.html의 전역 JS 함수 바인딩 (dart:js_interop).
@JS('playAzureTtsWeb')
external JSPromise<JSAny?> _playAzureTtsWeb(String text, String key,
    String region, String voice, String rate, String? lang);

@JS('stopAzureTtsWeb')
external void _stopAzureTtsWeb();

@JS('playChimeWeb')
external JSPromise<JSAny?> _playChimeWeb();

@JS('unlockTtsAudioWeb')
external void _unlockTtsAudioWeb();

/// 웹 전용 Azure TTS / 효과음 헬퍼.
///
/// 반환된 JS Promise를 [JSPromise.toDart]로 Future로 변환해 **실제 재생 종료까지
/// await** 한다. (await하지 않으면 반복 듣기 시 음성이 겹쳐 메아리처럼 들린다.)
class WebTtsHelper {
  static Future<void> playAzureTts(String text, String key, String region,
      String voice, double rateMultiplier, [String? lang]) async {
    await _playAzureTtsWeb(
            text, key, region, voice, rateMultiplier.toString(), lang)
        .toDart;
  }

  static Future<void> stopAzureTts() async {
    _stopAzureTtsWeb();
  }

  /// 문장 전환용 효과음 재생 (완료까지 await).
  static Future<void> playChime() async {
    try {
      await _playChimeWeb().toDart;
    } catch (_) {
      // 효과음 실패는 무시
    }
  }

  /// 사용자 제스처 안에서 오디오 엘리먼트를 언락 (iOS 자동재생 정책 대응).
  static void unlockAudio() {
    try {
      _unlockTtsAudioWeb();
    } catch (_) {}
  }
}
