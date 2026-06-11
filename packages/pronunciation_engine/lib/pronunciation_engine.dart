/// 재사용 가능한 발음 학습 핵심 엔진.
///
/// 목표 텍스트(문장·청크·단어)와 사용자의 음성 인식 결과를 비교하여
/// 단위별 정렬, 0~100 점수, 학습자용 피드백을 생성한다.
///
/// 이 패키지는 순수 Dart로 작성되어 Flutter에 의존하지 않으며,
/// 음성 합성(TTS)과 음성 인식(STT)은 추상 인터페이스로만 노출한다.
/// 언어별 차이(토큰화·정규화·로케일)는 [LanguageConfig]로 주입한다.
library;

// Models
export 'src/models/word_status.dart';
export 'src/models/alignment_word.dart';
export 'src/models/practice_level.dart';
export 'src/models/practice_sentence.dart';
export 'src/models/practice_result.dart';

// Scoring (영어 기본 채점기 — 하위 호환)
export 'src/scoring/text_normalizer.dart';
export 'src/scoring/pronunciation_scorer.dart';
export 'src/scoring/feedback_generator.dart';

// Language (다국어: 설정 주입형 채점기)
export 'src/language/language_config.dart';
export 'src/language/language_presets.dart';
export 'src/language/language_scorer.dart';
export 'src/language/japanese_text_normalizer.dart';

// Engine interfaces (구현은 앱에서 플러그인으로 주입)
export 'src/engines/tts_engine.dart';
export 'src/engines/speech_recognition_engine.dart';

// Playback (반복/연속 듣기 시퀀서)
export 'src/playback/playback_sequencer.dart';
