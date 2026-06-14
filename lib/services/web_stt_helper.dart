/// 플랫폼별 Azure STT+발음평가 헬퍼 (조건부 import).
library;

export 'web_stt_helper_stub.dart'
    if (dart.library.html) 'web_stt_helper_web.dart'
    if (dart.library.io) 'web_stt_helper_stub.dart';
