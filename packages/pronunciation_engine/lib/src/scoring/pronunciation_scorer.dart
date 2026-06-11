import 'dart:math';

import 'package:string_similarity/string_similarity.dart';

import '../models/alignment_word.dart';
import '../models/practice_result.dart';
import '../models/word_status.dart';
import 'text_normalizer.dart';

/// 목표 텍스트와 음성 인식 결과를 비교하여 점수와 단어 정렬을 계산하는
/// 순수 Dart 채점 엔진 (영어 등 공백 분리 언어용 — 하위 호환).
///
/// 다국어 지원이 필요하면 LanguageScorer + LanguageConfig를 사용한다.
class PronunciationScorer {
  PronunciationScorer._();

  /// 유사도가 이 값 이상이면 정확한 발음(match)으로 간주한다.
  static const double matchSimilarityThreshold = 0.8;

  /// 전체 점수(0~100)를 계산한다.
  static double overallScore(String target, String spoken) {
    if (target.isEmpty && spoken.isEmpty) return 100.0;
    if (target.isEmpty || spoken.isEmpty) return 0.0;

    final cleanTarget = TextNormalizer.clean(target);
    final cleanSpoken = TextNormalizer.clean(spoken);
    if (cleanTarget.isEmpty && cleanSpoken.isEmpty) return 100.0;
    if (cleanTarget.isEmpty || cleanSpoken.isEmpty) return 0.0;

    return StringSimilarity.compareTwoStrings(cleanTarget, cleanSpoken) * 100.0;
  }

  /// 목표 문장과 발화 문장을 단어 단위로 정렬한다.
  static List<AlignmentWord> align(String target, String spoken) {
    final targetTokens = TextNormalizer.tokenize(target);
    final spokenTokens = TextNormalizer.tokenize(spoken);

    final n = targetTokens.length;
    final m = spokenTokens.length;

    if (n == 0 && m == 0) return const [];
    if (n == 0) {
      return spokenTokens
          .map((w) => AlignmentWord(
                targetWord: '',
                spokenWord: w,
                status: WordStatus.extra,
              ))
          .toList();
    }
    if (m == 0) {
      return targetTokens
          .map((w) => AlignmentWord(
                targetWord: w,
                spokenWord: '',
                status: WordStatus.missing,
              ))
          .toList();
    }

    final cleanTarget = targetTokens.map(TextNormalizer.clean).toList();
    final cleanSpoken = spokenTokens.map(TextNormalizer.clean).toList();

    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0.0));
    for (var i = 0; i <= n; i++) {
      dp[i][0] = i * 1.0;
    }
    for (var j = 0; j <= m; j++) {
      dp[0][j] = j * 1.0;
    }

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final deleteCost = dp[i - 1][j] + 1.0;
        final insertCost = dp[i][j - 1] + 1.0;
        final wordSim = StringSimilarity.compareTwoStrings(
            cleanTarget[i - 1], cleanSpoken[j - 1]);
        final subCost = dp[i - 1][j - 1] + (1.0 - wordSim);
        dp[i][j] = min(deleteCost, min(insertCost, subCost));
      }
    }

    final aligned = <AlignmentWord>[];
    var i = n;
    var j = m;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final wordSim = StringSimilarity.compareTwoStrings(
            cleanTarget[i - 1], cleanSpoken[j - 1]);
        final current = dp[i][j];
        final subCost = dp[i - 1][j - 1] + (1.0 - wordSim);
        final deleteCost = dp[i - 1][j] + 1.0;

        if ((current - subCost).abs() < 1e-4) {
          final status =
              (cleanTarget[i - 1] == cleanSpoken[j - 1] ||
                      wordSim > matchSimilarityThreshold)
                  ? WordStatus.match
                  : WordStatus.mismatch;
          aligned.add(AlignmentWord(
            targetWord: targetTokens[i - 1],
            spokenWord: spokenTokens[j - 1],
            status: status,
          ));
          i--;
          j--;
          continue;
        }

        if ((current - deleteCost).abs() < 1e-4) {
          aligned.add(AlignmentWord(
            targetWord: targetTokens[i - 1],
            spokenWord: '',
            status: WordStatus.missing,
          ));
          i--;
          continue;
        }

        aligned.add(AlignmentWord(
          targetWord: '',
          spokenWord: spokenTokens[j - 1],
          status: WordStatus.extra,
        ));
        j--;
      } else if (i > 0) {
        aligned.add(AlignmentWord(
          targetWord: targetTokens[i - 1],
          spokenWord: '',
          status: WordStatus.missing,
        ));
        i--;
      } else {
        aligned.add(AlignmentWord(
          targetWord: '',
          spokenWord: spokenTokens[j - 1],
          status: WordStatus.extra,
        ));
        j--;
      }
    }

    return aligned.reversed.toList();
  }

  /// 목표와 발화를 한 번에 채점하여 [PracticeResult]로 반환하는 편의 메서드.
  static PracticeResult evaluate(String target, String spoken) {
    return PracticeResult(
      target: target,
      rawSpokenText: spoken,
      overallScore: overallScore(target, spoken),
      alignedWords: align(target, spoken),
    );
  }
}
