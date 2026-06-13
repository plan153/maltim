import 'package:pronunciation_engine/pronunciation_engine.dart';

/// 입툭튀(장면 회상) 모드의 키워드 기반 자동 채점.
///
/// 정확한 번역 일치가 아니라 "핵심 단어가 들어갔는가"만 확인한다.
/// - 한국어: 문장을 공백으로 나눈 뒤 조사를 제거해 핵심어를 뽑는다.
/// - 일본어: 띄어쓰기가 없어 형태소 분석이 어려우므로, 커리큘럼에 이미
///   등록된 어휘(VocabEntry.word) 목록을 핵심어로 사용한다.
class RecallScorer {
  // 길이가 긴 조사부터 매칭해야 "에서"가 "서"보다 먼저 제거된다.
  static const _particlesByLengthDesc = [
    '이라고',
    '이라는',
    '에서',
    '에게',
    '한테',
    '까지',
    '부터',
    '으로',
    '로서',
    '로써',
    '라고',
    '라는',
    '보다',
    '마저',
    '조차',
    '밖에',
    '만큼',
    '이랑',
    '이나',
    '와',
    '과',
    '랑',
    '나',
    '은',
    '는',
    '이',
    '가',
    '을',
    '를',
    '의',
    '에',
    '도',
    '만',
    '요',
  ];

  /// 한국어 문장에서 조사를 제거한 핵심어 집합을 추출한다.
  static Set<String> koreanKeywords(String text) {
    final clean = text.replaceAll(RegExp(r'[.?!,~]'), '');
    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final result = <String>{};
    for (var token in tokens) {
      for (final particle in _particlesByLengthDesc) {
        if (token.length > particle.length && token.endsWith(particle)) {
          token = token.substring(0, token.length - particle.length);
          break;
        }
      }
      if (token.isNotEmpty) result.add(token);
    }
    return result;
  }

  /// 일본어 핵심어 = 해당 문장의 등록 어휘(단어 표기).
  static Set<String> japaneseKeywords(PracticeSentence sentence) {
    return sentence.vocabulary
        .map((v) => v.word)
        .where((w) => w.isNotEmpty)
        .toSet();
  }

  /// 한국어 발화 채점: 목표 핵심어 중 인식된 문장에 포함된(또는 서로 포함
  /// 관계인) 비율을 0~100 점수로 환산한다.
  static double scoreKorean(String recognized, String target) {
    final targetKeywords = koreanKeywords(target);
    if (targetKeywords.isEmpty) return 0;
    final recognizedKeywords = koreanKeywords(recognized);
    var matched = 0;
    for (final t in targetKeywords) {
      if (recognizedKeywords.any((r) => r.contains(t) || t.contains(r))) {
        matched++;
      }
    }
    return matched / targetKeywords.length * 100;
  }

  /// 일본어 발화 채점: 문장 어휘 중 인식된 문장에 등장하는 비율을 0~100
  /// 점수로 환산한다.
  static double scoreJapanese(String recognized, PracticeSentence sentence) {
    final keywords = japaneseKeywords(sentence);
    if (keywords.isEmpty) return 0;
    final normalized = recognized.replaceAll(RegExp(r'\s+'), '');
    var matched = 0;
    for (final k in keywords) {
      if (normalized.contains(k)) matched++;
    }
    return matched / keywords.length * 100;
  }
}
