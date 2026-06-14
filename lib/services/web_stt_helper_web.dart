import 'dart:js_interop';

/// index.html의 전역 JS 함수 바인딩 (dart:js_interop).
@JS('prewarmMicWeb')
external JSPromise<JSAny?> _prewarmMicWeb();

@JS('startAzureSttWeb')
external JSPromise<JSAny?> _startAzureSttWeb(
    String key, String region, String locale);

@JS('stopAzureSttWeb')
external void _stopAzureSttWeb();

/// 웹 전용 Azure STT 헬퍼.
///
/// [recognizeSpeech]은 한 번의 발화를 인식하고, 결과를 JSON 문자열로
/// 반환한다: { "text": "...", "error": "..." | undefined }
class WebSttHelper {
  static const bool isSupported = true;

  static Future<void> prewarmMic() async {
    try {
      await _prewarmMicWeb().toDart;
    } catch (e) {}
  }

  static Future<String> recognizeSpeech(
    String key,
    String region,
    String locale,
  ) async {
    final result = await _startAzureSttWeb(key, region, locale).toDart;
    return (result as JSString).toDart;
  }

  static void stop() {
    _stopAzureSttWeb();
  }
}
