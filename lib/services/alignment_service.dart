import 'package:pronunciation_engine/pronunciation_engine.dart';

import 'app_language.dart';
import 'translation_service.dart';

/// 앱 ↔ 재사용 엔진 어댑터 (일본어).
///
/// 채점·정렬은 [LanguageScorer]+[LanguagePresets.japanese]에 위임한다.
/// 일본어는 가타카나→히라가나 정규화 후 문자 단위로 비교한다.
class AlignmentService {
  /// 채점 비교용 정규화 (가나 정규화 + 구두점 제거).
  static String cleanWord(String word) => appLanguage.normalize(word);

  /// 전체 점수 (0~100).
  static double calculateOverallScore(String target, String spoken) =>
      appScorer.overallScore(target, spoken);

  /// 문자 단위 정렬.
  static List<AlignmentWord> alignSentences(String target, String spoken) =>
      appScorer.align(target, spoken);

  /// 현재 언어 설정에 맞춘 피드백 문구.
  static String generateFeedbackText(List<AlignmentWord> aligned) =>
      FeedbackGenerator.generate(aligned,
          isKorean: TranslationService.isKorean);
}
