/// 연습 단위(granularity).
///
/// 초보자가 긴 문장을 한 번에 소화하기 어려우므로,
/// 문장 → 청크(의미 덩어리/문절) → 단어 순서로 쉽게 쪼개 연습할 수 있다.
/// 일본어처럼 단어 분리가 어려운 언어는 '단어' 레벨을 비활성화할 수 있다
/// (LanguageConfig.supportsWordLevel 참조).
enum PracticeLevel {
  /// 문장 전체.
  sentence,

  /// 의미 단위 청크 (구/절/문절).
  chunk,

  /// 단어 하나.
  word,
}

extension PracticeLevelLabel on PracticeLevel {
  /// 한국어 라벨.
  String get labelKo {
    switch (this) {
      case PracticeLevel.sentence:
        return '문장';
      case PracticeLevel.chunk:
        return '청크';
      case PracticeLevel.word:
        return '단어';
    }
  }

  /// 영어 라벨.
  String get labelEn {
    switch (this) {
      case PracticeLevel.sentence:
        return 'Sentence';
      case PracticeLevel.chunk:
        return 'Chunk';
      case PracticeLevel.word:
        return 'Word';
    }
  }
}
