import '../scoring/text_normalizer.dart';
import 'vocab_entry.dart';

/// 한 개의 연습 문장과 그 메타데이터.
///
/// 문장은 의미 단위 [chunks](일본어는 문절)로 나뉜다.
/// [reading]은 일본어 요미가나(읽기) 등 발음 표기를 담는 선택 필드다.
class PracticeSentence {
  final String id;
  final String text;
  final String category;
  final List<String> chunks;
  final String translation;

  /// 발음 읽기 표기 (예: 일본어 요미가나 'わたしはがくせいです'). 없으면 빈 문자열.
  final String reading;

  /// 문장에 등장하는 핵심 단어 목록 (한자/요미가나/뜻/품사/활용형). 없으면 빈 목록.
  final List<VocabEntry> vocabulary;

  const PracticeSentence({
    required this.id,
    required this.text,
    required this.category,
    required this.chunks,
    required this.translation,
    this.reading = '',
    this.vocabulary = const [],
  });

  /// 본문을 공백 기준으로 나눈 개별 단어 목록 (구두점 보존, 빈 토큰 제거).
  /// 일본어처럼 띄어쓰기가 없는 언어에서는 의미가 없으므로 사용하지 않는다.
  List<String> get words => TextNormalizer.tokenize(text);

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'category': category,
        'chunks': chunks,
        'translation': translation,
        if (reading.isNotEmpty) 'reading': reading,
        if (vocabulary.isNotEmpty)
          'vocabulary': vocabulary.map((v) => v.toJson()).toList(),
      };

  factory PracticeSentence.fromJson(
    Map<String, dynamic> json,
    String fallbackId,
  ) {
    return PracticeSentence(
      id: json['id']?.toString() ?? fallbackId,
      text: json['text']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      chunks: (json['chunks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [json['text']?.toString() ?? ''],
      translation: json['translation']?.toString() ?? '',
      reading: json['reading']?.toString() ?? '',
      vocabulary: (json['vocabulary'] as List<dynamic>?)
              ?.map((e) => VocabEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
