/// 텍스트 하나를 재생하고 **완료되면** 끝나는 Future를 돌려주는 함수.
typedef SpeakFn = Future<void> Function(String text);

/// 재생 진행 콜백. [itemIndex]는 0-based 항목 인덱스, [repeat]은 1-based 반복 회차.
typedef SequenceProgress = void Function(int itemIndex, int repeat);

/// 항목 전환 직전 호출되는 콜백 (예: 효과음 재생). 완료까지 await 된다.
typedef ItemBoundary = Future<void> Function();

/// 반복 듣기 + 여러 항목 연속 듣기를 오케스트레이션하는 순수 Dart 시퀀서.
///
/// TTS 엔진이나 Flutter에 의존하지 않고, 주입된 [speak] 콜백만 사용한다.
/// [speak]는 **실제 재생이 끝난 뒤** resolve 되어야 반복/연속이 겹치지 않는다.
///
/// - 같은 항목의 반복 사이에는 [repeatGap] 만큼 쉰다.
/// - 다른 항목으로 넘어갈 때는 [onItemBoundary](효과음 등) 후 [itemGap] 만큼 쉰다.
class PlaybackSequencer {
  /// 실제 음성 재생 함수 (재생 완료 시 resolve 되어야 한다).
  final SpeakFn speak;

  /// 같은 항목 반복 사이 간격.
  final Duration repeatGap;

  /// 다른 항목 사이 간격 (연속 듣기 구분용, 보통 repeatGap보다 길게).
  final Duration itemGap;

  bool _cancelled = false;
  bool _running = false;

  PlaybackSequencer({
    required this.speak,
    this.repeatGap = const Duration(milliseconds: 700),
    this.itemGap = const Duration(milliseconds: 1200),
  });

  /// 현재 재생 시퀀스가 진행 중인지 여부.
  bool get isRunning => _running;

  /// 진행 중인 시퀀스를 취소한다. (현재 재생 중인 음성 자체의 중단은 호출 측에서
  /// 별도로 처리해야 한다 — 시퀀서는 다음 재생 예약만 멈춘다.)
  void stop() {
    _cancelled = true;
  }

  /// [items]의 각 항목을 [repeatCount]회 반복 재생한다.
  ///
  /// 한 항목을 repeatCount회 모두 재생(반복 사이 [repeatGap])한 뒤, 항목 경계에서
  /// [onItemBoundary]를 호출하고 [itemGap]을 쉬고 다음 항목으로 넘어간다.
  /// [onProgress]는 각 회차 재생 시작 직전에 호출된다(텍스트 싱크용).
  Future<void> play(
    List<String> items, {
    int repeatCount = 1,
    SequenceProgress? onProgress,
    ItemBoundary? onItemBoundary,
    Duration? repeatGap,
    Duration? itemGap,
  }) async {
    if (_running) return;
    final reps = repeatCount < 1 ? 1 : repeatCount;
    final rGap = repeatGap ?? this.repeatGap;
    final iGap = itemGap ?? this.itemGap;

    _cancelled = false;
    _running = true;
    try {
      for (var i = 0; i < items.length; i++) {
        if (_cancelled) break;

        // 항목 경계: 효과음 + 긴 간격 (첫 항목 제외)
        if (i > 0) {
          if (onItemBoundary != null) {
            await onItemBoundary();
            if (_cancelled) break;
          }
          if (iGap > Duration.zero) {
            await Future.delayed(iGap);
            if (_cancelled) break;
          }
        }

        for (var r = 1; r <= reps; r++) {
          if (_cancelled) break;
          // 반복 사이 간격 (첫 회차 제외)
          if (r > 1 && rGap > Duration.zero) {
            await Future.delayed(rGap);
            if (_cancelled) break;
          }
          onProgress?.call(i, r);
          await speak(items[i]);
          if (_cancelled) break;
        }
      }
    } finally {
      _running = false;
    }
  }
}
