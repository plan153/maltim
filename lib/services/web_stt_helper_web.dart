import 'dart:js_interop';

/// index.html의 전역 JS 함수 바인딩 (dart:js_interop).
@JS('startAzureSttWeb')
external JSPromise<JSAny?> _startAzureSttWeb(
    String key, String region, String locale, String referenceText);

@JS('stopAzureSttWeb')
external void _stopAzureSttWeb();

/// 웹 전용 Azure STT + 발음 평가(Pronunciation Assessment) 헬퍼.
///
/// [recognizeWithPronunciation]은 한 번의 발화를 인식하고, 결과를 JSON 문자열로
/// 반환한다: { "text": "...", "pronunciation": { accuracyScore, fluencyScore,
/// completenessScore, pronScore } | null, "error": "..." | undefined }
class WebSttHelper {
  static const bool isSupported = true;

  static Future<String> recognizeWithPronunciation(
    String key,
    String region,
    String locale,
    String referenceText,
  ) async {
    final result = await _startAzureSttWeb(key, region, locale, referenceText).toDart;
    return (result as JSString).toDart;
  }

  static void stop() {
    _stopAzureSttWeb();
  }
}
