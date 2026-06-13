import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_language.dart';

/// 일본어 음성 인식(STT) 서비스. (speech_to_text + 데모 시뮬레이션)
class SpeechService {
  final SpeechToText _speech = SpeechToText();
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

    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('Microphone permission denied.');
        _useDemoMode = true;
        return false;
      }

      _isInitialized = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (error) => debugPrint(
            'STT Error: ${error.errorMsg} (permanent: ${error.permanent})'),
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

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenFor: const Duration(seconds: 20),
      // pauseFor가 길면 말을 멈춘 뒤 인식 확정까지 그만큼 기다리게 되어
      // "반응이 늦다"고 느껴진다. 짧은 문장 연습이므로 침묵 판정을 짧게.
      pauseFor: kIsWeb
          ? const Duration(milliseconds: 1800)
          : const Duration(milliseconds: 1500),
      localeId: webLocale,
      cancelOnError: false,
      partialResults: true,
    );
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
