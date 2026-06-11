import 'package:pronunciation_engine/pronunciation_engine.dart';

/// 이 앱의 학습 대상 언어 — 단일 소스.
///
/// TTS 음성/로케일, STT 로케일, 채점 토큰화·정규화가 모두 여기서 결정된다.
/// 다른 언어 앱을 만들 때 이 한 줄만 바꾸면 된다.
final LanguageConfig appLanguage = LanguagePresets.japanese;

/// 앱 전역 채점기 (appLanguage 기반).
final LanguageScorer appScorer = LanguageScorer(appLanguage);
