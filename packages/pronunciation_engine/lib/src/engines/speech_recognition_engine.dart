/// 음성 인식 부분/최종 결과 콜백.
typedef SpeechResultCallback = void Function(
    String recognizedText, bool isFinal);

/// 음성 인식 엔진 상태 콜백 (listening/notListening/done/error 등).
typedef SpeechStatusCallback = void Function(String status);

/// 음성 인식(STT) 추상 인터페이스.
///
/// 구현체(speech_to_text 등)는 앱에서 제공한다.
abstract class SpeechRecognitionEngine {
  /// 엔진을 초기화한다. 성공 시 true.
  Future<bool> initialize();

  /// 인식 가능 여부.
  bool get isAvailable;

  /// 현재 듣고 있는지 여부.
  bool get isListening;

  /// 음성 인식을 시작한다.
  Future<void> startListening({
    required SpeechResultCallback onResult,
    required SpeechStatusCallback onStatus,
    String localeId,
  });

  /// 인식을 멈추고 지금까지 인식된 결과를 확정한다.
  Future<void> stopListening();

  /// 인식을 취소하고 결과를 버린다.
  Future<void> cancelListening();
}
