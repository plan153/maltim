/// 플랫폼별 오디오 재생 헬퍼 (조건부 import).
library;

export 'audio_player_helper_stub.dart'
    if (dart.library.html) 'audio_player_helper_web.dart'
    if (dart.library.io) 'audio_player_helper_mobile.dart';
