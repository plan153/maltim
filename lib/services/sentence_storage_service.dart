import 'dart:convert';
import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 연습 문장 영속화 서비스 (shared_preferences).
///
/// 시드 데이터는 한국인 초보 학습자용 일상 일본어 문장이다.
/// 청크는 문절(文節) 단위: 명사+조사를 한 덩어리, 활용된 동사/형용사를 한 덩어리.
/// (말트임 30일 커리큘럼 전체 예문으로 교체/확장 예정 — JSON 가져오기 사용)
class SentenceStorageService {
  static const String _key = 'practice_sentences_ja_v1';

  /// 기본 시드 문장.
  static final List<PracticeSentence> _defaults = [
    // ─ Day 1 · 인사 ─
    PracticeSentence(
      id: 'ja_001',
      text: 'おはようございます。',
      reading: 'おはようございます',
      category: 'Day 1 · 인사',
      chunks: ['おはようございます'],
      translation: '안녕하세요. (아침 인사)',
    ),
    PracticeSentence(
      id: 'ja_002',
      text: 'こんにちは。',
      reading: 'こんにちは',
      category: 'Day 1 · 인사',
      chunks: ['こんにちは'],
      translation: '안녕하세요. (낮 인사)',
    ),
    PracticeSentence(
      id: 'ja_003',
      text: 'ありがとうございます。',
      reading: 'ありがとうございます',
      category: 'Day 1 · 인사',
      chunks: ['ありがとうございます'],
      translation: '감사합니다.',
    ),
    PracticeSentence(
      id: 'ja_004',
      text: 'すみません。',
      reading: 'すみません',
      category: 'Day 1 · 인사',
      chunks: ['すみません'],
      translation: '실례합니다/죄송합니다.',
    ),
    // ─ Day 2 · 자기소개 ─
    PracticeSentence(
      id: 'ja_005',
      text: '私は学生です。',
      reading: 'わたしはがくせいです',
      category: 'Day 2 · 자기소개',
      chunks: ['私は', '学生です'],
      translation: '저는 학생입니다.',
    ),
    PracticeSentence(
      id: 'ja_006',
      text: '私は韓国人です。',
      reading: 'わたしはかんこくじんです',
      category: 'Day 2 · 자기소개',
      chunks: ['私は', '韓国人です'],
      translation: '저는 한국인입니다.',
    ),
    PracticeSentence(
      id: 'ja_007',
      text: 'はじめまして、よろしくお願いします。',
      reading: 'はじめまして、よろしくおねがいします',
      category: 'Day 2 · 자기소개',
      chunks: ['はじめまして', 'よろしく', 'お願いします'],
      translation: '처음 뵙겠습니다, 잘 부탁드립니다.',
    ),
    // ─ Day 3 · 일상 표현 ─
    PracticeSentence(
      id: 'ja_008',
      text: 'これは何ですか。',
      reading: 'これはなんですか',
      category: 'Day 3 · 일상',
      chunks: ['これは', '何ですか'],
      translation: '이것은 무엇입니까?',
    ),
    PracticeSentence(
      id: 'ja_009',
      text: 'トイレはどこですか。',
      reading: 'トイレはどこですか',
      category: 'Day 3 · 일상',
      chunks: ['トイレは', 'どこですか'],
      translation: '화장실은 어디입니까?',
    ),
    PracticeSentence(
      id: 'ja_010',
      text: 'いくらですか。',
      reading: 'いくらですか',
      category: 'Day 3 · 일상',
      chunks: ['いくらですか'],
      translation: '얼마입니까?',
    ),
    PracticeSentence(
      id: 'ja_011',
      text: 'これをください。',
      reading: 'これをください',
      category: 'Day 3 · 일상',
      chunks: ['これを', 'ください'],
      translation: '이것을 주세요.',
    ),
    // ─ Day 4 · 식당 ─
    PracticeSentence(
      id: 'ja_012',
      text: 'コーヒーをお願いします。',
      reading: 'コーヒーをおねがいします',
      category: 'Day 4 · 식당',
      chunks: ['コーヒーを', 'お願いします'],
      translation: '커피를 부탁합니다.',
    ),
    PracticeSentence(
      id: 'ja_013',
      text: 'おすすめは何ですか。',
      reading: 'おすすめはなんですか',
      category: 'Day 4 · 식당',
      chunks: ['おすすめは', '何ですか'],
      translation: '추천 메뉴는 무엇입니까?',
    ),
    PracticeSentence(
      id: 'ja_014',
      text: 'とてもおいしいです。',
      reading: 'とてもおいしいです',
      category: 'Day 4 · 식당',
      chunks: ['とても', 'おいしいです'],
      translation: '아주 맛있습니다.',
    ),
    // ─ Day 5 · 동사 문장 ─
    PracticeSentence(
      id: 'ja_015',
      text: '私は日本語を勉強しています。',
      reading: 'わたしはにほんごをべんきょうしています',
      category: 'Day 5 · 동사',
      chunks: ['私は', '日本語を', '勉強しています'],
      translation: '저는 일본어를 공부하고 있습니다.',
    ),
    PracticeSentence(
      id: 'ja_016',
      text: '明日、東京に行きます。',
      reading: 'あした、とうきょうにいきます',
      category: 'Day 5 · 동사',
      chunks: ['明日', '東京に', '行きます'],
      translation: '내일 도쿄에 갑니다.',
    ),
    PracticeSentence(
      id: 'ja_017',
      text: '日本のドラマをよく見ます。',
      reading: 'にほんのドラマをよくみます',
      category: 'Day 5 · 동사',
      chunks: ['日本の', 'ドラマを', 'よく', '見ます'],
      translation: '일본 드라마를 자주 봅니다.',
    ),
    PracticeSentence(
      id: 'ja_018',
      text: 'ちょっと待ってください。',
      reading: 'ちょっとまってください',
      category: 'Day 5 · 동사',
      chunks: ['ちょっと', '待ってください'],
      translation: '잠깐 기다려 주세요.',
    ),
    // ─ Day 6 · 감정/상태 ─
    PracticeSentence(
      id: 'ja_019',
      text: '今日はとても楽しかったです。',
      reading: 'きょうはとてもたのしかったです',
      category: 'Day 6 · 감정',
      chunks: ['今日は', 'とても', '楽しかったです'],
      translation: '오늘은 아주 즐거웠습니다.',
    ),
    PracticeSentence(
      id: 'ja_020',
      text: '少し疲れました。',
      reading: 'すこしつかれました',
      category: 'Day 6 · 감정',
      chunks: ['少し', '疲れました'],
      translation: '조금 피곤합니다.',
    ),
    PracticeSentence(
      id: 'ja_021',
      text: '日本語は難しいですが、面白いです。',
      reading: 'にほんごはむずかしいですが、おもしろいです',
      category: 'Day 6 · 감정',
      chunks: ['日本語は', '難しいですが', '面白いです'],
      translation: '일본어는 어렵지만 재미있습니다.',
    ),
    PracticeSentence(
      id: 'ja_022',
      text: 'また会いましょう。',
      reading: 'またあいましょう',
      category: 'Day 6 · 감정',
      chunks: ['また', '会いましょう'],
      translation: '또 만나요.',
    ),
  ];

  /// 저장된 문장을 불러온다. 없으면 시드를 저장 후 반환.
  static Future<List<PracticeSentence>> loadSentences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      await saveSentences(_defaults);
      return List.of(_defaults);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (var i = 0; i < list.length; i++)
          PracticeSentence.fromJson(
              list[i] as Map<String, dynamic>, 'ja_imported_$i'),
      ];
    } catch (_) {
      return List.of(_defaults);
    }
  }

  static Future<void> saveSentences(List<PracticeSentence> sentences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(sentences.map((s) => s.toJson()).toList()));
  }

  static Future<List<PracticeSentence>> addSentence(
      PracticeSentence sentence) async {
    final sentences = await loadSentences()
      ..add(sentence);
    await saveSentences(sentences);
    return sentences;
  }

  static Future<List<PracticeSentence>> deleteSentence(String id) async {
    final sentences = await loadSentences()
      ..removeWhere((s) => s.id == id);
    await saveSentences(sentences);
    return sentences;
  }

  static Future<List<PracticeSentence>> resetToDefaults() async {
    await saveSentences(_defaults);
    return List.of(_defaults);
  }

  /// JSON 배열 문자열을 가져와 DB를 교체한다.
  /// 형식: [{"id","text","reading","category","chunks":[...],"translation"}, ...]
  static Future<List<PracticeSentence>> importFromJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException('JSON 최상위는 배열이어야 합니다.');
    }
    final sentences = [
      for (var i = 0; i < decoded.length; i++)
        PracticeSentence.fromJson(
            decoded[i] as Map<String, dynamic>, 'ja_imported_$i'),
    ];
    if (sentences.isEmpty) {
      throw const FormatException('가져올 문장이 없습니다.');
    }
    await saveSentences(sentences);
    return sentences;
  }

  static String exportToJson(List<PracticeSentence> sentences) {
    return const JsonEncoder.withIndent('  ')
        .convert(sentences.map((s) => s.toJson()).toList());
  }
}
