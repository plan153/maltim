/// 일본어 텍스트 정규화/토큰화 유틸리티 (순수 Dart).
///
/// 일본어는 띄어쓰기가 없고 한자/히라가나/가타카나 표기가 섞이므로,
/// 발음 채점 비교 전에 다음을 수행한다:
/// 1. 전각/반각 폭 정규화 (영숫자·가타카나)
/// 2. 가타카나 → 히라가나 변환 ("히라가나로 정규화")
/// 3. 일본어/일반 구두점·공백 제거
///
/// 한자→읽기(요미가나) 변환은 일반적으로 사전(형태소 분석)이 필요하지만,
/// 커리큘럼에 등장하는 어휘는 한정적이므로 [KanjiReadingMap]으로 그 범위만
/// 처리한다 (4. 구두점/공백 제거 전, 한자 변환).
library;

import 'kanji_reading_map.dart';

class JapaneseTextNormalizer {
  JapaneseTextNormalizer._();

  /// 일본어 구두점 + 일반 구두점 + 공백류.
  static final RegExp _punctuation = RegExp(
      r'''[。、・「」『』（）()｛｝\[\]【】〈〉《》！？!?．，,\.　\s'"“”‘’~〜ー?…:;ｰ-]''');

  /// 장음 기호(ー)는 발음상 의미가 있으므로 별도 보존 여부를 선택할 수 있다.
  /// 기본 [clean]은 채점 안정성을 위해 장음·촉음 표기 차이에 관대하도록 제거한다.

  /// 가타카나 문자를 히라가나로 변환한다 (U+30A1–U+30F6 → -0x60).
  static String katakanaToHiragana(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x30A1 && rune <= 0x30F6) {
        buffer.writeCharCode(rune - 0x60);
      } else if (rune == 0x30FD) {
        buffer.writeCharCode(0x309D); // ヽ → ゝ
      } else if (rune == 0x30FE) {
        buffer.writeCharCode(0x309E); // ヾ → ゞ
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// 반각 가타카나/전각 영숫자 등 호환 문자를 표준 폭으로 정규화한다.
  /// (Dart 코어에는 NFKC가 없어 자주 쓰이는 범위만 직접 매핑한다.)
  static String normalizeWidth(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      // 전각 영숫자/기호 (FF01-FF5E) → 반각
      if (code >= 0xFF01 && code <= 0xFF5E) {
        buffer.writeCharCode(code - 0xFEE0);
        continue;
      }
      // 반각 가타카나 (FF66-FF9D) → 전각 가타카나 (간이 매핑, 탁점 결합은 미처리)
      if (code >= 0xFF66 && code <= 0xFF9F) {
        buffer.write(_halfToFullKatakana[code] ?? input[i]);
        continue;
      }
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  /// 채점 비교용 정규화: 폭 정규화 → 가타카나→히라가나 → 한자→읽기 변환
  /// → 구두점/공백 제거 → 소문자.
  static String clean(String input) {
    var s = normalizeWidth(input);
    s = katakanaToHiragana(s);
    s = KanjiReadingMap.convert(s);
    s = s.replaceAll(_punctuation, '');
    return s.toLowerCase().trim();
  }

  /// 일본어는 띄어쓰기가 없으므로 문자(grapheme에 준하는 rune) 단위로 토큰화한다.
  /// 정렬·채점은 이 문자 시퀀스로 수행한다.
  static List<String> tokenizeChars(String input) {
    final cleaned = clean(input);
    return cleaned.runes.map((r) => String.fromCharCode(r)).toList();
  }

  /// 표시용 토큰화: 원문을 공백 기준으로 나누되(분かち書き 입력 지원),
  /// 공백이 없으면 전체를 하나의 토큰으로 반환한다.
  static List<String> tokenizeDisplay(String input) {
    final parts =
        input.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? [input] : parts;
  }

  static const Map<int, String> _halfToFullKatakana = {
    0xFF66: 'ヲ', 0xFF67: 'ァ', 0xFF68: 'ィ', 0xFF69: 'ゥ', 0xFF6A: 'ェ',
    0xFF6B: 'ォ', 0xFF6C: 'ャ', 0xFF6D: 'ュ', 0xFF6E: 'ョ', 0xFF6F: 'ッ',
    0xFF70: 'ー', 0xFF71: 'ア', 0xFF72: 'イ', 0xFF73: 'ウ', 0xFF74: 'エ',
    0xFF75: 'オ', 0xFF76: 'カ', 0xFF77: 'キ', 0xFF78: 'ク', 0xFF79: 'ケ',
    0xFF7A: 'コ', 0xFF7B: 'サ', 0xFF7C: 'シ', 0xFF7D: 'ス', 0xFF7E: 'セ',
    0xFF7F: 'ソ', 0xFF80: 'タ', 0xFF81: 'チ', 0xFF82: 'ツ', 0xFF83: 'テ',
    0xFF84: 'ト', 0xFF85: 'ナ', 0xFF86: 'ニ', 0xFF87: 'ヌ', 0xFF88: 'ネ',
    0xFF89: 'ノ', 0xFF8A: 'ハ', 0xFF8B: 'ヒ', 0xFF8C: 'フ', 0xFF8D: 'ヘ',
    0xFF8E: 'ホ', 0xFF8F: 'マ', 0xFF90: 'ミ', 0xFF91: 'ム', 0xFF92: 'メ',
    0xFF93: 'モ', 0xFF94: 'ヤ', 0xFF95: 'ユ', 0xFF96: 'ヨ', 0xFF97: 'ラ',
    0xFF98: 'リ', 0xFF99: 'ル', 0xFF9A: 'レ', 0xFF9B: 'ロ', 0xFF9C: 'ワ',
    0xFF9D: 'ン',
  };
}
