/// 발음 비교 전 텍스트를 정규화하는 순수 유틸리티 (영어 등 공백 분리 언어용).
class TextNormalizer {
  TextNormalizer._();

  /// 구두점 및 특수문자 제거용 정규식.
  static final RegExp _punctuation =
      RegExp(r'''[.,\/#!$%\^&\*;:{}=\-_`~()?"“”'’]''');

  /// 단어 하나에서 구두점을 제거하고 소문자로 변환한다.
  static String clean(String word) {
    return word.replaceAll(_punctuation, '').trim().toLowerCase();
  }

  /// 텍스트를 공백 기준으로 토큰화한다 (빈 토큰 제거, 원형 보존).
  static List<String> tokenize(String text) {
    return text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  }

  /// 토큰화 후 각 토큰을 [clean] 처리한 목록.
  static List<String> tokenizeClean(String text) {
    return tokenize(text).map(clean).where((s) => s.isNotEmpty).toList();
  }
}
