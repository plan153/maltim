import '../models/alignment_word.dart';
import '../models/word_status.dart';

/// 정렬 결과로부터 학습자용 피드백 문구를 생성하는 순수 유틸리티.
///
/// 앱의 번역 서비스에 의존하지 않도록 한국어/영어 문구를 자체 보유한다.
class FeedbackGenerator {
  FeedbackGenerator._();

  /// 표시할 교정 팁 최대 개수.
  static const int maxTips = 3;

  /// 정렬 결과로 피드백 문구를 생성한다.
  ///
  /// [isKorean]에 따라 한국어 또는 영어 문구를 반환한다.
  static String generate(List<AlignmentWord> aligned, {bool isKorean = true}) {
    final tips = <String>[];
    var matchCount = 0;
    var totalTargetWords = 0;

    for (final word in aligned) {
      if (word.status != WordStatus.extra) {
        totalTargetWords++;
      }
      switch (word.status) {
        case WordStatus.match:
          matchCount++;
          break;
        case WordStatus.mismatch:
          tips.add(isKorean
              ? '"${word.targetWord}" 대신 "${word.spokenWord}"(으)로 발음했습니다.'
              : 'Said "${word.spokenWord}" instead of "${word.targetWord}"');
          break;
        case WordStatus.missing:
          tips.add(isKorean
              ? '"${word.targetWord}" 부분을 빠뜨리고 읽었습니다.'
              : 'Missed "${word.targetWord}"');
          break;
        case WordStatus.extra:
          tips.add(isKorean
              ? '원문에 없는 불필요한 발음 "${word.spokenWord}"(을)를 추가로 말했습니다.'
              : 'Added extra "${word.spokenWord}"');
          break;
      }
    }

    if (totalTargetWords == 0) {
      return isKorean ? '문장을 말씀해 주세요.' : 'Please try speaking.';
    }

    final matchRatio = matchCount / totalTargetWords;

    if (matchRatio == 1.0) {
      return isKorean ? '훌륭합니다! 완벽한 발음입니다!' : 'Excellent! Perfect pronunciation!';
    }

    String title;
    if (matchRatio > 0.8) {
      title = isKorean ? '훌륭한 발음입니다! 미세 교정 제안:\n' : 'Great pronunciation! Minor corrections:\n';
    } else if (matchRatio > 0.5) {
      title = isKorean
          ? '잘 시도하셨습니다. 개선해야 할 부분들:\n'
          : 'Good try. Here are a few corrections to work on:\n';
    } else {
      if (tips.isEmpty) {
        return isKorean
            ? '음성을 명확하게 인식하지 못했습니다. 조금 더 마이크에 가까이 대고 큰 소리로 말씀해 보세요.'
            : 'We couldn\'t recognize the words clearly. Try speaking a bit louder or closer to the microphone.';
      }
      title = isKorean ? '함께 더 연습해 봅시다! 집중 개선 영역:\n' : 'Let\'s practice more! Key focus areas:\n';
    }

    final buffer = StringBuffer(title);
    buffer.write(tips.take(maxTips).map((t) => '• $t').join('\n'));
    return buffer.toString();
  }
}
