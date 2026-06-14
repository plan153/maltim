import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_language.dart';
import 'tts_service.dart';
import 'web_stt_helper.dart';

/// Azure 발음 평가(Pronunciation Assessment) 결과.
/// 웹에서만 지원되며, 미지원 환경에서는 [supported]가 false이다.
class PronunciationResult {
  final bool supported;
  final String text;
  final double? accuracyScore;
  final double? fluencyScore;
  final double? completenessScore;
  final double? pronScore;
  final String? error;

  const PronunciationResult({
    required this.supported,
    this.text = '',
    this.accuracyScore,
    this.fluencyScore,
    this.completenessScore,
    this.pronScore,
    this.error,
  });

  bool get hasScores => pronScore != null;
}

/// 일본어 음성 인식(STT) 서비스. (speech_to_text + 데모 시뮬레이션)
class SpeechService {
  SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _useDemoMode = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _speech.isListening;
  bool get useDemoMode => _useDemoMode;

  set useDemoMode(bool value) {
    _useDemoMode = value;
  }

  /// 마이크 권한 요청.
  Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true; // 브라우저 프롬프트가 처리

    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final requestStatus = await Permission.microphone.request();
    return requestStatus.isGranted;
  }

  /// STT 초기화. 실패 시 데모 모드로 전환.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // 이전 초기화 시도가 실패했거나 인식기가 permanent 오류로 깨진 경우,
    // 같은 SpeechToText 인스턴스를 재사용하면 내부 상태(특히 웹의
    // webkitSpeechRecognition 객체)가 복구되지 않아 이후 인식이 계속
    // 실패한다. 새 인스턴스로 교체해 깨끗한 상태에서 다시 초기화한다.
    _speech = SpeechToText();

    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('Microphone permission denied.');
        _useDemoMode = true;
        return false;
      }

      _isInitialized = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (error) {
          debugPrint(
              'STT Error: ${error.errorMsg} (permanent: ${error.permanent})');
          // 복구 불가(permanent) 오류가 발생하면 인식기가 더 이상 정상 동작하지
          // 않는 상태로 남는 경우가 있다(특히 iOS Safari). 다음 startListening
          // 호출 시 재초기화하도록 플래그를 내린다.
          if (error.permanent) {
            _isInitialized = false;
          }
        },
      );

      if (!_isInitialized) {
        debugPrint('Speech recognition unavailable. Activating Demo Mode.');
        _useDemoMode = true;
      }
    } catch (e) {
      debugPrint('Speech initialization exception: $e. Demo Mode on.');
      _isInitialized = false;
      _useDemoMode = true;
    }

    return _isInitialized;
  }

  /// 음성 인식 시작 (로케일: appLanguage.sttLocale = ja_JP).
  Future<void> startListening({
    required Function(String recognizedText, bool isFinal) onResult,
    required Function(String status) onStatus,
    String? localeId,
  }) async {
    if (_useDemoMode) {
      onStatus('listening');
      return;
    }

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        onStatus('error');
        return;
      }
    }

    final effectiveLocale = localeId ?? appLanguage.sttLocale;
    // 웹 Web Speech API는 BCP-47 하이픈 형식(예: ja-JP)을 요구한다.
    // sttLocale은 네이티브(Android Locale) 표기인 언더스코어 형식(ja_JP)이라
    // 웹에서는 인식 언어가 적용되지 않아 STT가 제대로 동작하지 않는 문제가 있었다.
    final webLocale =
        kIsWeb ? effectiveLocale.replaceAll('_', '-') : effectiveLocale;

    Future<void> doListen() => _speech.listen(
          onResult: (result) {
            onResult(result.recognizedWords, result.finalResult);
          },
          listenFor: const Duration(seconds: 30),
          // 너무 짧으면 한 문장을 다 말하기 전에 인식이 끊겨 결과가 비거나
          // 일부만 인식된다. 문장 연습이므로 충분한 침묵 허용 시간을 둔다.
          pauseFor: kIsWeb
              ? const Duration(milliseconds: 3000)
              : const Duration(milliseconds: 2000),
          localeId: webLocale,
          listenOptions: SpeechListenOptions(
            // iOS Safari는 인식 시작 직후 "no-speech" 오류를 자주 발생시키는데,
            // cancelOnError: true이면 이때 인식 자체가 즉시 취소되어 결과가
            // 전혀 나오지 않는다(인식이 너무 빨리 끝나는 현상의 원인). 오류가
            // 나도 계속 듣도록 false로 되돌린다.
            cancelOnError: false,
            partialResults: true,
            // dictation 모드가 confirmation/search보다 문장 전체를 끝까지
            // 듣고 인식하는 데 더 적합하다.
            listenMode: ListenMode.dictation,
          ),
        );

    try {
      await doListen();
    } catch (e) {
      // listen() 호출 자체가 실패하면(예: 이전 오류로 인식기가 망가진 상태)
      // 한 번 재초기화 후 재시도한다. 그래도 안 되면 한 번의 실패가
      // 이후 모든 시도를 막는 문제를 방지하기 위해 초기화 상태를 다시
      // 내려 다음 시도에서도 재초기화를 유도한다.
      debugPrint('STT listen() 예외: $e. 재초기화 후 재시도.');
      _isInitialized = false;
      final success = await initialize();
      if (!success) {
        onStatus('error');
        return;
      }
      try {
        await doListen();
      } catch (e2) {
        debugPrint('STT listen() 재시도 실패: $e2');
        _isInitialized = false;
        onStatus('error');
        return;
      }
    }
    onStatus('listening');
  }

  Future<void> stopListening() async {
    if (_useDemoMode) return;
    await _speech.stop();
  }

  Future<void> cancelListening() async {
    if (_useDemoMode) return;
    await _speech.cancel();
  }

  /// 연속듣기 루프 시작 전 마이크 스트림을 미리 초기화한다 (Azure STT cold-start 방지).
  /// getUserMedia 한 번 호출 후 즉시 해제하면 이후 Azure SDK의 마이크 획득이 빠르다.
  Future<void> prewarmAzureStt() async {
    if (!kIsWeb) return;
    await WebSttHelper.prewarmMic();
  }
  /// Azure 발음 평가(Pronunciation Assessment)로 한 번 인식한다.
  /// [referenceText]를 기준으로 정확도/유창성/완성도/종합 점수를 함께 반환한다.
  /// 웹에서만 지원되며, 그 외 환경에서는 supported=false를 반환한다.
  Future<PronunciationResult> recognizeWithPronunciation({
    required String referenceText,
    String? localeId,
  }) async {
    if (!kIsWeb || !WebSttHelper.isSupported || !TtsService.isAzureEnabled) {
      return const PronunciationResult(supported: false);
    }

    final effectiveLocale = localeId ?? appLanguage.sttLocale;
    final webLocale = effectiveLocale.replaceAll('_', '-');

    try {
      final raw = await WebSttHelper.recognizeWithPronunciation(
        TtsService.azureKey,
        TtsService.azureRegion,
        webLocale,
        referenceText,
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final pronunciation = json['pronunciation'] as Map<String, dynamic>?;
      return PronunciationResult(
        supported: true,
        text: (json['text'] as String?) ?? '',
        accuracyScore: (pronunciation?['accuracyScore'] as num?)?.toDouble(),
        fluencyScore: (pronunciation?['fluencyScore'] as num?)?.toDouble(),
        completenessScore:
            (pronunciation?['completenessScore'] as num?)?.toDouble(),
        pronScore: (pronunciation?['pronScore'] as num?)?.toDouble(),
        error: json['error'] as String?,
      );
    } catch (e) {
      debugPrint('Azure 발음평가 오류: $e');
      return PronunciationResult(supported: true, error: e.toString());
    }
  }

  /// 진행 중인 Azure 발음평가 인식을 중단한다.
  void cancelPronunciationRecognition() {
    if (kIsWeb) WebSttHelper.stop();
  }

  /// 데모 모드용 가상 발화 생성.
  /// 일본어는 띄어쓰기가 없으므로 문자 단위로 정확도를 시뮬레이션한다.
  void simulateSpeechInput({
    required String targetSentence,
    required double accuracy,
    required Function(String text, bool isFinal) onResult,
  }) {
    final chars = targetSentence.runes
        .map((r) => String.fromCharCode(r))
        .where((c) => c.trim().isNotEmpty)
        .toList();
    final simulated = StringBuffer();

    for (final c in chars) {
      final rand = (c.hashCode % 100) / 100.0;
      if (rand < accuracy) {
        simulated.write(c);
      }
      // 정확도 미달 문자는 누락 시뮬레이션
    }

    Timer(const Duration(milliseconds: 500), () {
      onResult(simulated.toString(), true);
    });
  }
}
