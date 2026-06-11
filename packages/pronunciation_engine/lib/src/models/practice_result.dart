import 'alignment_word.dart';
import 'word_status.dart';

/// 한 번의 발음 시도에 대한 채점 결과.
class PracticeResult {
  /// 사용자가 연습한 목표 텍스트 (문장/청크/단어).
  final String target;

  /// 음성 인식으로 받아쓴 원문.
  final String rawSpokenText;

  /// 전체 발음 점수 (0.0 ~ 100.0).
  final double overallScore;

  /// 토큰 단위 정렬 결과.
  final List<AlignmentWord> alignedWords;

  const PracticeResult({
    required this.target,
    required this.rawSpokenText,
    required this.overallScore,
    required this.alignedWords,
  });

  /// 정확히 일치한(match) 토큰 수.
  int get matchedWordCount =>
      alignedWords.where((w) => w.status == WordStatus.match).length;

  /// 목표에 존재하는 토큰 수 (extra 제외).
  int get targetWordCount =>
      alignedWords.where((w) => w.status != WordStatus.extra).length;

  /// 토큰 정확도 비율 (0.0 ~ 1.0). 목표 토큰이 없으면 0.
  double get wordAccuracy =>
      targetWordCount == 0 ? 0.0 : matchedWordCount / targetWordCount;

  /// 합격 기준(기본 85점) 이상 여부.
  bool isPassed({double threshold = 85.0}) => overallScore >= threshold;
}
