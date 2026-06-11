import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:test/test.dart';

const _zero = Duration.zero;

void main() {
  group('PlaybackSequencer', () {
    test('단일 항목을 repeatCount회 반복한다', () async {
      final spoken = <String>[];
      final seq = PlaybackSequencer(speak: (t) async => spoken.add(t));
      await seq.play(['Hello'],
          repeatCount: 3, repeatGap: _zero, itemGap: _zero);
      expect(spoken, ['Hello', 'Hello', 'Hello']);
    });

    test('여러 항목을 각각 repeatCount회 반복 후 다음으로 (순서 보존)', () async {
      final spoken = <String>[];
      final seq = PlaybackSequencer(speak: (t) async => spoken.add(t));
      await seq.play(['A', 'B', 'C'],
          repeatCount: 2, repeatGap: _zero, itemGap: _zero);
      expect(spoken, ['A', 'A', 'B', 'B', 'C', 'C']);
    });

    test('진행 콜백은 itemIndex/회차(1-based)를 보고한다', () async {
      final progress = <List<int>>[];
      final seq = PlaybackSequencer(speak: (t) async {});
      await seq.play(['A', 'B'],
          repeatCount: 2,
          repeatGap: _zero,
          itemGap: _zero,
          onProgress: (i, r) => progress.add([i, r]));
      expect(progress, [
        [0, 1],
        [0, 2],
        [1, 1],
        [1, 2],
      ]);
    });

    test('항목 경계 콜백은 항목 사이에서만 호출된다(첫 항목 전/마지막 후 제외)', () async {
      final events = <String>[];
      final seq = PlaybackSequencer(speak: (t) async => events.add('say:$t'));
      await seq.play(['A', 'B', 'C'],
          repeatCount: 1,
          repeatGap: _zero,
          itemGap: _zero,
          onItemBoundary: () async => events.add('chime'));
      expect(events, ['say:A', 'chime', 'say:B', 'chime', 'say:C']);
    });

    test('repeatCount<1은 1로 클램프된다', () async {
      final spoken = <String>[];
      final seq = PlaybackSequencer(speak: (t) async => spoken.add(t));
      await seq.play(['A'], repeatCount: 0, repeatGap: _zero, itemGap: _zero);
      expect(spoken, ['A']);
    });

    test('stop() 호출 시 이후 재생을 멈춘다', () async {
      final spoken = <String>[];
      late PlaybackSequencer seq;
      seq = PlaybackSequencer(speak: (t) async {
        spoken.add(t);
        if (t == 'B') seq.stop();
      });
      await seq.play(['A', 'B', 'C', 'D'],
          repeatCount: 1, repeatGap: _zero, itemGap: _zero);
      expect(spoken, ['A', 'B']);
    });

    test('실행 중에는 isRunning이 true, 끝나면 false', () async {
      final seq = PlaybackSequencer(speak: (t) async {});
      expect(seq.isRunning, isFalse);
      final f =
          seq.play(['A'], repeatCount: 1, repeatGap: _zero, itemGap: _zero);
      expect(seq.isRunning, isTrue);
      await f;
      expect(seq.isRunning, isFalse);
    });

    test('빈 목록은 아무 것도 재생하지 않는다', () async {
      final spoken = <String>[];
      final seq = PlaybackSequencer(speak: (t) async => spoken.add(t));
      await seq.play([], repeatCount: 3, repeatGap: _zero, itemGap: _zero);
      expect(spoken, isEmpty);
    });

    test('speak가 완료될 때까지 다음 재생을 시작하지 않는다(겹침 없음)', () async {
      var active = 0;
      var maxActive = 0;
      final seq = PlaybackSequencer(speak: (t) async {
        active++;
        if (active > maxActive) maxActive = active;
        await Future.delayed(const Duration(milliseconds: 5));
        active--;
      });
      await seq.play(['A', 'B'],
          repeatCount: 2, repeatGap: _zero, itemGap: _zero);
      expect(maxActive, 1); // 동시에 1건만 재생 (메아리 방지)
    });
  });
}
