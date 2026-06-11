import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TextNormalizer.clean', () {
    test('소문자로 변환하고 구두점을 제거한다', () {
      expect(TextNormalizer.clean('Hello,'), 'hello');
      expect(TextNormalizer.clean('World!'), 'world');
      expect(TextNormalizer.clean('"Quote"'), 'quote');
    });

    test('앞뒤 공백을 제거한다', () {
      expect(TextNormalizer.clean('  cat  '), 'cat');
    });

    test('빈 문자열은 빈 문자열을 반환한다', () {
      expect(TextNormalizer.clean(''), '');
      expect(TextNormalizer.clean('...'), '');
    });
  });

  group('TextNormalizer.tokenize', () {
    test('공백으로 분리하고 빈 토큰을 제거한다', () {
      expect(TextNormalizer.tokenize('the quick  fox'),
          ['the', 'quick', 'fox']);
    });

    test('빈 문자열은 빈 목록을 반환한다', () {
      expect(TextNormalizer.tokenize('   '), isEmpty);
    });
  });

  group('TextNormalizer.tokenizeClean', () {
    test('토큰화 후 정규화하고 빈 토큰을 제거한다', () {
      expect(TextNormalizer.tokenizeClean('The Quick, Fox!'),
          ['the', 'quick', 'fox']);
    });
  });
}
