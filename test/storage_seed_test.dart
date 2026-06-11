import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_japanese_app/services/sentence_storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('시드 문장이 로드되고 문절 청크/읽기/뜻을 갖는다', () async {
    final sentences = await SentenceStorageService.loadSentences();
    expect(sentences.length, greaterThanOrEqualTo(20));
    for (final s in sentences) {
      expect(s.text, isNotEmpty);
      expect(s.chunks, isNotEmpty);
      expect(s.translation, isNotEmpty);
      expect(s.reading, isNotEmpty, reason: '${s.id}에 읽기(요미가나)가 없음');
    }
  });

  test('JSON 가져오기/내보내기 round-trip', () async {
    final sentences = await SentenceStorageService.loadSentences();
    final json = SentenceStorageService.exportToJson(sentences);
    final imported = await SentenceStorageService.importFromJson(json);
    expect(imported.length, sentences.length);
    expect(imported.first.text, sentences.first.text);
    expect(imported.first.chunks, sentences.first.chunks);
    expect(imported.first.reading, sentences.first.reading);
  });

  test('잘못된 JSON은 예외', () async {
    expect(() => SentenceStorageService.importFromJson('{not json'),
        throwsA(anything));
    expect(() => SentenceStorageService.importFromJson('{"a":1}'),
        throwsA(isA<FormatException>()));
  });
}
