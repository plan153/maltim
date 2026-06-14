/// 네이티브/미지원 플랫폼용 스텁. Azure 발음평가는 웹에서만 지원한다.
class WebSttHelper {
  static const bool isSupported = false;

  static Future<void> prewarmMic() async {}

  static Future<String> recognizeWithPronunciation(
    String key,
    String region,
    String locale,
    String referenceText,
  ) async {
    return '{"text":"","pronunciation":null,"error":"unsupported_platform"}';
  }

  static void stop() {}
}
