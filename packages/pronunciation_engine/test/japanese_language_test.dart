import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:test/test.dart';

void main() {
  group('JapaneseTextNormalizer', () {
    test('가타카나를 히라가나로 변환한다', () {
      expect(JapaneseTextNormalizer.katakanaToHiragana('カタカナ'), 'かたかな');
      expect(JapaneseTextNormalizer.katakanaToHiragana('コーヒー'), 'こーひー');
    });

    test('한자/히라가나는 그대로 유지한다', () {
      expect(JapaneseTextNormalizer.katakanaToHiragana('私はがくせい'), '私はがくせい');
    });

    test('clean: 구두점·공백 제거 + 가나 정규화', () {
      expect(JapaneseTextNormalizer.clean('私は 学生です。'), '私は学生です');
      expect(JapaneseTextNormalizer.clean('コーヒー、ください！'), 'こひください');
    });

    test('clean: 전각 영숫자/기호 폭 정규화', () {
      expect(JapaneseTextNormalizer.clean('ＡＢＣ１２３'), 'abc123');
    });

    test('tokenizeChars: 문자 단위 토큰', () {
      expect(JapaneseTextNormalizer.tokenizeChars('私は学生です。'),
          ['私', 'は', '学', '生', 'で', 'す']);
    });
  });

  group('LanguageScorer (일본어)', () {
    final scorer = LanguageScorer(LanguagePresets.japanese);

    test('동일 문장은 100점', () {
      expect(scorer.overallScore('私は学生です。', '私は学生です'), 100.0);
    });

    test('가타카나/히라가나 표기 차이는 무시한다', () {
      expect(scorer.overallScore('すし', 'スシ'), 100.0);
    });

    test('일부 누락은 0~100 사이 점수', () {
      final s = scorer.overallScore('私は学生です', '私は学生');
      expect(s, greaterThan(0));
      expect(s, lessThan(100));
    });

    test('문자 단위 정렬: 완전 일치', () {
      final aligned = scorer.align('学生です', '学生です');
      expect(aligned.length, 4);
      expect(aligned.every((w) => w.status == WordStatus.match), isTrue);
    });

    test('문자 단위 정렬: 누락 문자는 missing', () {
      final aligned = scorer.align('学生です', '学生で');
      final missing =
          aligned.where((w) => w.status == WordStatus.missing).toList();
      expect(missing.length, 1);
      expect(missing.first.targetWord, 'す');
    });

    test('문자 단위 정렬: 치환은 mismatch', () {
      final aligned = scorer.align('ねこ', 'ねく');
      expect(aligned[0].status, WordStatus.match);
      expect(aligned[1].status, WordStatus.mismatch);
    });

    test('evaluate: PracticeResult 생성 + 합격 판정', () {
      final r = scorer.evaluate('おはようございます', 'おはようございます');
      expect(r.overallScore, 100.0);
      expect(r.isPassed(), isTrue);
    });
  });

  group('LanguageScorer (영어 프리셋 회귀)', () {
    final scorer = LanguageScorer(LanguagePresets.english);

    test('대소문자/구두점 무시 100점', () {
      expect(scorer.overallScore('Hello, World!', 'hello world'), 100.0);
    });

    test('단어 정렬 동작', () {
      final aligned = scorer.align('the cat', 'the dog');
      expect(aligned[0].status, WordStatus.match);
      expect(aligned[1].status, WordStatus.mismatch);
    });
  });

  group('LanguageConfig', () {
    test('일본어는 단어 레벨 미지원', () {
      expect(LanguagePresets.japanese.supportsWordLevel, isFalse);
      expect(LanguagePresets.english.supportsWordLevel, isTrue);
    });

    test('일본어 로케일 설정', () {
      expect(LanguagePresets.japanese.ttsLocale, 'ja-JP');
      expect(LanguagePresets.japanese.sttLocale, 'ja_JP');
      expect(LanguagePresets.japanese.ttsVoice, contains('ja-JP'));
    });
  });
}
