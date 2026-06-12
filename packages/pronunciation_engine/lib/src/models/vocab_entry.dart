/// 연습 문장에 등장하는 단어 한 개에 대한 학습 정보.
///
/// 동사·형용사처럼 활용하는 단어는 [forms]에 주요 활용형과 뜻을 담는다.
class VocabEntry {
  /// 히라가나 표제어 (문장에 등장하는 형태, 예: 'いきます').
  final String word;

  /// 한자 표기. 없으면 빈 문자열.
  final String kanji;

  /// 한글 발음 표기 (예: '이키마스').
  final String reading;

  /// 한글 뜻.
  final String meaning;

  /// 품사 (예: '명사', '동사(1군)', 'な형용사').
  final String pos;

  /// 주요 활용형과 뜻 (예: ['いく(사전형) - 가다', 'いきました - 갔습니다']).
  /// 활용하지 않는 단어는 빈 목록.
  final List<String> forms;

  const VocabEntry({
    required this.word,
    this.kanji = '',
    required this.reading,
    required this.meaning,
    required this.pos,
    this.forms = const [],
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        if (kanji.isNotEmpty) 'kanji': kanji,
        'reading': reading,
        'meaning': meaning,
        'pos': pos,
        if (forms.isNotEmpty) 'forms': forms,
      };

  factory VocabEntry.fromJson(Map<String, dynamic> json) {
    return VocabEntry(
      word: json['word']?.toString() ?? '',
      kanji: json['kanji']?.toString() ?? '',
      reading: json['reading']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      pos: json['pos']?.toString() ?? '',
      forms: (json['forms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
