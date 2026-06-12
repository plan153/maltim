import 'dart:math';

import 'package:string_similarity/string_similarity.dart';

import '../models/alignment_word.dart';
import '../models/practice_result.dart';
import '../models/word_status.dart';
import 'language_config.dart';

/// [LanguageConfig]를 주입받아 동작하는 언어 중립 채점기.
///
/// 토큰화/정규화 방식만 언어별로 다르고, 정렬(DP 편집거리)·점수 계산 로직은
/// 영어용 PronunciationScorer와 동일하다.
/// 일본어처럼 띄어쓰기가 없는 언어는 문자 단위 토큰으로 정렬된다.
class LanguageScorer {
  final LanguageConfig config;

  const LanguageScorer(this.config);

  /// 유사도가 이 값 이상이면 정확한 발음(match)으로 간주.
  static const double matchSimilarityThreshold = 0.8;

  /// 한자 ↔ 가나(히라가나) 표기 차이로 비교되는 1글자 토큰 쌍에 부여하는 유사도.
  /// 발음 일치 여부를 판단할 수 없으므로 완전 불일치(0.0)보다는 낮은 비용을
  /// 부여해, 정렬 시 단순 삭제/삽입보다는 같은 위치로 짝지어지도록 한다.
  static const double _crossScriptSim = 0.5;

  /// 전체 점수(0~100): 정규화 문자열 전체의 Dice 유사도.
  double overallScore(String target, String spoken) {
    final cleanTarget = config.normalize(target);
    final cleanSpoken = config.normalize(spoken);
    if (cleanTarget.isEmpty && cleanSpoken.isEmpty) return 100.0;
    if (cleanTarget.isEmpty || cleanSpoken.isEmpty) return 0.0;
    return StringSimilarity.compareTwoStrings(cleanTarget, cleanSpoken) * 100.0;
  }

  /// 목표/발화를 언어별 토큰 단위로 정렬한다.
  List<AlignmentWord> align(String target, String spoken) {
    final targetTokens = config.tokenize(target);
    final spokenTokens = config.tokenize(spoken);

    final n = targetTokens.length;
    final m = spokenTokens.length;

    if (n == 0 && m == 0) return const [];
    if (n == 0) {
      return spokenTokens
          .map((w) => AlignmentWord(
              targetWord: '', spokenWord: w, status: WordStatus.extra))
          .toList();
    }
    if (m == 0) {
      return targetTokens
          .map((w) => AlignmentWord(
              targetWord: w, spokenWord: '', status: WordStatus.missing))
          .toList();
    }

    final cleanTarget = targetTokens.map(config.normalize).toList();
    final cleanSpoken = spokenTokens.map(config.normalize).toList();

    double sim(String a, String b) {
      if (a.isEmpty || b.isEmpty) return a == b ? 1.0 : 0.0;
      // 1글자 토큰(일본어 문자 단위)은 동일성으로 판정.
      if (a.length < 2 || b.length < 2) {
        if (a == b) return 1.0;
        // 목표(히라가나)와 STT 결과(한자)처럼 표기 체계가 다른 경우,
        // 발음 일치 여부를 알 수 없으므로 완전 불일치로 단정하지 않는다.
        if ((_isKanji(a) && _isKana(b)) || (_isKana(a) && _isKanji(b))) {
          return _crossScriptSim;
        }
        return 0.0;
      }
      return StringSimilarity.compareTwoStrings(a, b);
    }

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
        final subCost =
            dp[i - 1][j - 1] + (1.0 - sim(cleanTarget[i - 1], cleanSpoken[j - 1]));
        dp[i][j] = min(deleteCost, min(insertCost, subCost));
      }
    }

    final aligned = <AlignmentWord>[];
    var i = n;
    var j = m;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final s = sim(cleanTarget[i - 1], cleanSpoken[j - 1]);
        final current = dp[i][j];
        final subCost = dp[i - 1][j - 1] + (1.0 - s);
        final deleteCost = dp[i - 1][j] + 1.0;

        if ((current - subCost).abs() < 1e-4) {
          WordStatus status;
          if (cleanTarget[i - 1] == cleanSpoken[j - 1] ||
              s > matchSimilarityThreshold) {
            status = WordStatus.match;
          } else if (s == _crossScriptSim) {
            status = WordStatus.unknown;
          } else {
            status = WordStatus.mismatch;
          }
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
              status: WordStatus.missing));
          i--;
          continue;
        }
        aligned.add(AlignmentWord(
            targetWord: '',
            spokenWord: spokenTokens[j - 1],
            status: WordStatus.extra));
        j--;
      } else if (i > 0) {
        aligned.add(AlignmentWord(
            targetWord: targetTokens[i - 1],
            spokenWord: '',
            status: WordStatus.missing));
        i--;
      } else {
        aligned.add(AlignmentWord(
            targetWord: '',
            spokenWord: spokenTokens[j - 1],
            status: WordStatus.extra));
        j--;
      }
    }
    return aligned.reversed.toList();
  }

  /// 한자(CJK 통합 한자, U+4E00–U+9FFF) 한 글자인지 여부.
  static bool _isKanji(String s) {
    if (s.isEmpty) return false;
    final r = s.runes.single;
    return r >= 0x4E00 && r <= 0x9FFF;
  }

  /// 히라가나(U+3040–U+309F) 한 글자인지 여부.
  /// (가타카나는 [config.normalize]에서 이미 히라가나로 정규화됨)
  static bool _isKana(String s) {
    if (s.isEmpty) return false;
    final r = s.runes.single;
    return r >= 0x3040 && r <= 0x309F;
  }

  /// 한 번에 채점하여 [PracticeResult] 생성.
  PracticeResult evaluate(String target, String spoken) {
    return PracticeResult(
      target: target,
      rawSpokenText: spoken,
      overallScore: overallScore(target, spoken),
      alignedWords: align(target, spoken),
    );
  }
}
