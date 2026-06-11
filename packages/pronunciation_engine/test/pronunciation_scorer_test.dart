import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PronunciationScorer.overallScore', () {
    test('완벽히 일치하면 100점', () {
      expect(PronunciationScorer.overallScore('hello world', 'hello world'),
          100.0);
    });

    test('대소문자/구두점 차이는 무시하고 100점', () {
      expect(PronunciationScorer.overallScore('Hello, World!', 'hello world'),
          100.0);
    });

    test('둘 다 비어 있으면 100점', () {
      expect(PronunciationScorer.overallScore('', ''), 100.0);
    });

    test('한쪽만 비어 있으면 0점', () {
      expect(PronunciationScorer.overallScore('hello', ''), 0.0);
      expect(PronunciationScorer.overallScore('', 'hello'), 0.0);
    });

    test('부분 일치는 0과 100 사이', () {
      final score =
          PronunciationScorer.overallScore('the quick brown fox', 'the quick');
      expect(score, greaterThan(0.0));
      expect(score, lessThan(100.0));
    });
  });

  group('PronunciationScorer.align', () {
    test('완벽 일치는 모두 match', () {
      final aligned = PronunciationScorer.align('the cat', 'the cat');
      expect(aligned.length, 2);
      expect(aligned.every((w) => w.status == WordStatus.match), isTrue);
    });

    test('누락된 단어는 missing', () {
      final aligned = PronunciationScorer.align('the big cat', 'the cat');
      final missing =
          aligned.where((w) => w.status == WordStatus.missing).toList();
      expect(missing.length, 1);
      expect(missing.first.targetWord, 'big');
    });

    test('추가된 단어는 extra', () {
      final aligned = PronunciationScorer.align('the cat', 'the big cat');
      final extra = aligned.where((w) => w.status == WordStatus.extra).toList();
      expect(extra.length, 1);
      expect(extra.first.spokenWord, 'big');
    });

    test('다른 단어로 바꾸면 mismatch', () {
      final aligned = PronunciationScorer.align('the cat', 'the dog');
      final mismatch =
          aligned.where((w) => w.status == WordStatus.mismatch).toList();
      expect(mismatch.length, 1);
      expect(mismatch.first.targetWord, 'cat');
      expect(mismatch.first.spokenWord, 'dog');
    });

    test('목표가 비면 모든 발화는 extra', () {
      final aligned = PronunciationScorer.align('', 'hello there');
      expect(aligned.length, 2);
      expect(aligned.every((w) => w.status == WordStatus.extra), isTrue);
    });

    test('발화가 비면 모든 목표는 missing', () {
      final aligned = PronunciationScorer.align('hello there', '');
      expect(aligned.length, 2);
      expect(aligned.every((w) => w.status == WordStatus.missing), isTrue);
    });

    test('정렬 순서가 원문 순서를 보존한다', () {
      final aligned = PronunciationScorer.align('one two three', 'one two three');
      expect(aligned.map((w) => w.targetWord).toList(),
          ['one', 'two', 'three']);
    });
  });

  group('PronunciationScorer.evaluate', () {
    test('PracticeResult를 종합 생성한다', () {
      final result =
          PronunciationScorer.evaluate('the quick fox', 'the quick fox');
      expect(result.target, 'the quick fox');
      expect(result.rawSpokenText, 'the quick fox');
      expect(result.overallScore, 100.0);
      expect(result.matchedWordCount, 3);
      expect(result.targetWordCount, 3);
      expect(result.wordAccuracy, 1.0);
      expect(result.isPassed(), isTrue);
    });

    test('낮은 점수는 합격하지 못한다', () {
      final result = PronunciationScorer.evaluate('the quick brown fox', 'cat');
      expect(result.isPassed(), isFalse);
    });
  });
}
