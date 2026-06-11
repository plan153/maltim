/// 음성 합성(TTS) 추상 인터페이스.
///
/// 구현체(Azure Neural TTS, flutter_tts 등)는 앱에서 제공한다.
/// 엔진 패키지는 이 인터페이스에만 의존하므로 특정 플러그인에 묶이지 않는다.
abstract class TtsEngine {
  /// 주어진 텍스트를 읽어준다. 진행 중인 음성은 중단한다.
  Future<void> speak(String text);

  /// 현재 재생 중인 음성을 멈춘다.
  Future<void> stop();
}
