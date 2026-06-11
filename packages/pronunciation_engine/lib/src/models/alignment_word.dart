import 'word_status.dart';

/// 목표 토큰과 사용자가 말한 토큰의 정렬 결과 한 쌍.
class AlignmentWord {
  /// 원문(목표)의 토큰. [WordStatus.extra]인 경우 빈 문자열.
  final String targetWord;

  /// 사용자가 말한 토큰. [WordStatus.missing]인 경우 빈 문자열.
  final String spokenWord;

  /// 이 토큰 쌍의 정렬 상태.
  final WordStatus status;

  const AlignmentWord({
    required this.targetWord,
    required this.spokenWord,
    required this.status,
  });

  @override
  String toString() =>
      'AlignmentWord(target: "$targetWord", spoken: "$spokenWord", status: $status)';

  @override
  bool operator ==(Object other) =>
      other is AlignmentWord &&
      other.targetWord == targetWord &&
      other.spokenWord == spokenWord &&
      other.status == status;

  @override
  int get hashCode => Object.hash(targetWord, spokenWord, status);
}
