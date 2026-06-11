/// 언어별 설정 주입 모델.
///
/// 엔진(채점·정렬·시퀀서)은 언어 중립이지만, 텍스트 정규화·토큰화 방식과
/// TTS/STT 로케일은 언어마다 다르다. 이 객체 하나로 앱에 주입한다.
///
/// 예) 영어: 공백 토큰화 + 소문자 정규화, en-US
///     일본어: 문자 토큰화 + 가나(히라가나) 정규화, ja-JP
class LanguageConfig {
  /// 언어 코드 (예: 'en', 'ja').
  final String code;

  /// Azure Neural TTS 음성 이름 (예: 'ja-JP-NanamiNeural').
  final String ttsVoice;

  /// TTS 로케일 (SSML xml:lang / flutter_tts setLanguage, 예: 'ja-JP').
  final String ttsLocale;

  /// STT 로케일 (speech_to_text localeId, 예: 'ja_JP').
  final String sttLocale;

  /// 채점 비교 전 텍스트 정규화 함수.
  /// 일본어: NFKC + 가타카나→히라가나 + 구두점/공백 제거.
  final String Function(String) normalize;

  /// 정렬 단위 토큰화 함수.
  /// 영어: 공백 단어. 일본어: 문자 단위(띄어쓰기 없음).
  final List<String> Function(String) tokenize;

  /// 단어(최소 연습 단위) 분리 함수. null이면 '단어' 레벨 미지원
  /// (일본어는 형태소 분석 없이는 단어 분리가 불가하므로 청크=문절 사용).
  final List<String> Function(String)? splitWords;

  const LanguageConfig({
    required this.code,
    required this.ttsVoice,
    required this.ttsLocale,
    required this.sttLocale,
    required this.normalize,
    required this.tokenize,
    this.splitWords,
  });

  /// '단어' 연습 레벨 지원 여부.
  bool get supportsWordLevel => splitWords != null;
}
