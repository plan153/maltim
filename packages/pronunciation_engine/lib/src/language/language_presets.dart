import '../scoring/text_normalizer.dart';
import 'japanese_text_normalizer.dart';
import 'language_config.dart';

/// 기본 제공 언어 프리셋.
class LanguagePresets {
  LanguagePresets._();

  /// 영어 (미국): 공백 단어 토큰화 + 소문자/구두점 정규화.
  static final LanguageConfig english = LanguageConfig(
    code: 'en',
    ttsVoice: 'en-US-AriaNeural',
    ttsLocale: 'en-US',
    sttLocale: 'en_US',
    normalize: TextNormalizer.clean,
    tokenize: TextNormalizer.tokenize,
    splitWords: TextNormalizer.tokenize,
  );

  /// 일본어: 문자 단위 토큰화 + 히라가나 정규화.
  ///
  /// - 띄어쓰기가 없으므로 정렬은 문자 단위로 수행한다.
  /// - 가타카나는 히라가나로 정규화해 표기 차이에 의한 감점을 막는다.
  /// - '단어' 레벨은 미지원(형태소 분석 필요) → 청크(문절) 레벨 사용.
  static final LanguageConfig japanese = LanguageConfig(
    code: 'ja',
    ttsVoice: 'ja-JP-NanamiNeural',
    ttsLocale: 'ja-JP',
    sttLocale: 'ja_JP',
    normalize: JapaneseTextNormalizer.clean,
    tokenize: JapaneseTextNormalizer.tokenizeChars,
    splitWords: null,
  );
}
