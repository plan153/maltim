/// 플랫폼별 웹 TTS 헬퍼 (조건부 import).
library;

export 'web_tts_helper_stub.dart'
    if (dart.library.html) 'web_tts_helper_web.dart'
    if (dart.library.io) 'web_tts_helper_mobile.dart';
