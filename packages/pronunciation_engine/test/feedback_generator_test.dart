import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:test/test.dart';

void main() {
  group('FeedbackGenerator.generate', () {
    test('완벽한 정렬은 칭찬 문구 (한국어)', () {
      final aligned = PronunciationScorer.align('the cat', 'the cat');
      final feedback = FeedbackGenerator.generate(aligned, isKorean: true);
      expect(feedback, contains('완벽한 발음'));
    });

    test('완벽한 정렬은 칭찬 문구 (영어)', () {
      final aligned = PronunciationScorer.align('the cat', 'the cat');
      final feedback = FeedbackGenerator.generate(aligned, isKorean: false);
      expect(feedback, contains('Perfect pronunciation'));
    });

    test('빈 정렬은 안내 문구', () {
      final feedback = FeedbackGenerator.generate(const [], isKorean: true);
      expect(feedback, contains('말씀해'));
    });

    test('오발음에 대한 교정 팁을 포함한다', () {
      final aligned =
          PronunciationScorer.align('the quick cat', 'the slow dog');
      final feedback = FeedbackGenerator.generate(aligned, isKorean: false);
      expect(feedback.toLowerCase(), contains('instead of'));
    });

    test('팁은 최대 maxTips개로 제한된다', () {
      final aligned =
          PronunciationScorer.align('a b c d e f g', 'x y z w v u t');
      final feedback = FeedbackGenerator.generate(aligned, isKorean: false);
      final bulletCount = '•'.allMatches(feedback).length;
      expect(bulletCount, lessThanOrEqualTo(FeedbackGenerator.maxTips));
    });
  });
}
