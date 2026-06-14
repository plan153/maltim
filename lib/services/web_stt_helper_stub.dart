/// 네이티브/미지원 플랫폼용 스텁. Azure STT는 웹에서만 지원한다.
class WebSttHelper {
  static const bool isSupported = false;

  static Future<void> prewarmMic() async {}

  static Future<String> recognizeSpeech(
    String key,
    String region,
    String locale,
  ) async {
    return '{"text":"","error":"unsupported_platform"}';
  }

  static void stop() {}
}
