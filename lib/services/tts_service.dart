import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';
import 'audio_player_helper.dart';
import 'web_tts_helper.dart';

/// 일본어 TTS 서비스.
///
/// - 네이티브: Azure Neural TTS(REST) 우선, 실패 시 기기 내장 TTS 폴백.
/// - 웹: Azure Speech SDK(WebSocket)로 데이터 합성 → 단일 오디오 엘리먼트 재생
///   (CORS/iOS AudioContext 제한 회피). 실패 시 브라우저 내장 TTS 폴백.
class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;
  static int _currentSpeechId = 0;

  static double speechRate = 0.5; // 1.0x
  static String azureRegion = 'koreacentral';
  static String azureVoice = appLanguage.ttsVoice; // ja-JP-NanamiNeural

  // Azure Neural TTS configuration fields (Pre-configured default credentials)
  static String get azureKey {
    const encoded =
        'Nm9tbkZ0U2VSQVZPbmcydVlxc2dZZ1IycE5COWhIclduQ09DR2RJOXBZRWc0VTJSM2h2aUpRUUo5OUNGQUNObnM3UlhKM3czQUFBWUFDT0d0bVJR';
    return utf8.decode(base64.decode(encoded));
  }

  static Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      speechRate = prefs.getDouble('tts_speech_rate') ?? 0.5;
      final savedVoice = prefs.getString('tts_azure_voice');
      // 이전 버전(영어 프리셋 등)에서 저장된 'en-US-...' 같은 잘못된 보이스 값이
      // 남아있으면 무시한다. (예: en-US-AriaNeural 저장 시 Azure 합성이
      // 조용히 실패해 듣기 버튼이 무음이 됨)
      azureVoice = (savedVoice != null && savedVoice.startsWith('ja-JP'))
          ? savedVoice
          : appLanguage.ttsVoice;
    } catch (e) {
      print('TtsService loadSettings error: $e');
    }
  }

  static Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tts_speech_rate', speechRate);
      await prefs.setString('tts_azure_voice', azureVoice);
    } catch (e) {
      print('TtsService saveSettings error: $e');
    }
  }

  /// Check whether Azure credentials are provided
  static bool get isAzureEnabled =>
      azureKey.trim().isNotEmpty && azureRegion.trim().isNotEmpty;

  /// 기기 내장 TTS 초기화 (일본어 로케일 + 학습자용 속도).
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      // speak()가 재생 완료 시점에 resolve 되도록 설정.
      // 반복/연속 듣기 시퀀서가 다음 재생을 정확히 이어가려면 필수.
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setLanguage(appLanguage.ttsLocale); // ja-JP
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      print('TTS initialization error: $e');
    }
  }

  /// iOS/Safari 등 브라우저 정책상 사용자 제스처 컨텍스트에서 오디오 엔진을
  /// 언락하기 위한 함수. 시작/듣기 버튼 onTap 첫 부분에서 호출한다.
  static Future<void> unlockAudioEngine() async {
    // 제스처 컨텍스트가 유효한 동안(첫 await 이전) 오디오 엘리먼트를 동기적으로 언락.
    if (kIsWeb) {
      WebTtsHelper.unlockAudio();
      // 웹에서는 위 호출로 충분하다. flutter_tts.speak(' ')는 일부 브라우저에서
      // 'end' 이벤트가 발생하지 않아 awaitSpeakCompletion(true) 상태에서 영원히
      // resolve되지 않고, 이로 인해 _playSingle()의 이후 Azure TTS 호출이
      // 전혀 실행되지 않는 문제(듣기 버튼 무음)가 있었다.
      return;
    }
    try {
      await init();
      await _flutterTts.setVolume(0.0);
      await _flutterTts.speak(' ');
      await _flutterTts.setVolume(1.0);
    } catch (e) {
      print('TtsService unlockAudioEngine error: $e');
    }
  }

  /// 마이크 듣기 시작/종료를 알려 TTS 출력 볼륨을 보정한다.
  /// (마이크 사용 시 브라우저의 에코 제거 처리로 TTS 음량이 작아지는 문제 보정)
  static void setMicActive(bool active) {
    if (kIsWeb) {
      WebTtsHelper.setMicActive(active);
    }
  }

  /// 문장 전환용 효과음 (연속 듣기에서 다음 문장으로 넘어갈 때 구분음).
  static Future<void> playTransitionChime() async {
    if (kIsWeb) {
      await WebTtsHelper.playChime();
    }
  }

  /// Speaks the given text aloud. Interrupts any active speech.
  ///
  /// [voice]/[locale]를 지정하면 기본 일본어 음성 대신 해당 음성/언어로
  /// 합성한다 (예: 말툭튀 KO→JP 모드에서 한국어 문장을 읽을 때
  /// voice='ko-KR-SunHiNeural', locale='ko-KR').
  static Future<void> speak(String text, {String? voice, String? locale}) async {
    if (text.trim().isEmpty) return;
    final speakVoice = voice ?? azureVoice;
    final speakLocale = locale ?? appLanguage.ttsLocale;

    // 이 요청의 ID 확보. (stop()은 카운터를 증가시키지 않는다 — speak() 진입
    // 시점 한 곳에서만 무효화해야 자기 가드가 깨지지 않는다.)
    final speechId = ++_currentSpeechId;

    if (kIsWeb) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 150));
      if (speechId != _currentSpeechId) return;

      if (isAzureEnabled) {
        try {
          final rateMultiplier = speechRate / 0.5;
          await WebTtsHelper.playAzureTts(text, azureKey, azureRegion,
              speakVoice, rateMultiplier, speakLocale);
          return;
        } catch (e) {
          print('Web Azure Speech SDK synthesis failed: $e. '
              'Falling back to browser TTS.');
        }
      }

      await init();
      if (speechId != _currentSpeechId) return;
      try {
        await _flutterTts.setSpeechRate(speechRate);
        await _flutterTts.speak(text);
      } catch (e) {
        print('Web TTS speak error for "$text": $e');
      }
      return;
    }

    // 네이티브: 사용자 제스처 컨텍스트에서 오디오 엘리먼트를 동기적으로 언락
    if (isAzureEnabled) {
      AudioPlayerHelper.prePlay();
    }

    await stop();

    if (isAzureEnabled) {
      try {
        final bytes =
            await _fetchAzureTtsAudio(text, voice: speakVoice, locale: speakLocale);
        if (speechId != _currentSpeechId) return;
        if (bytes != null) {
          await AudioPlayerHelper.playBytes(bytes);
          return;
        }
      } catch (e) {
        print('Azure Neural TTS playback failed ($e). '
            'Falling back to local TTS.');
      }
    }

    if (speechId != _currentSpeechId) return;
    await _speakLocal(text);
  }

  static Future<void> _speakLocal(String text) async {
    await init();
    try {
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.speak(text);
    } catch (e) {
      print('Local TTS speak error for "$text": $e');
    }
  }

  /// Azure Neural TTS REST API 호출 (네이티브 전용).
  static Future<Uint8List?> _fetchAzureTtsAudio(String text,
      {String? voice, String? locale}) async {
    final region = azureRegion.trim();
    final key = azureKey.trim();
    final ttsVoice = (voice ?? azureVoice).trim();

    final url = Uri.parse(
        'https://$region.tts.speech.microsoft.com/cognitiveservices/v1');

    final escapedText = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    // prosody rate는 실수 배율 문자열 (백분율은 일부 엔진이 relative로 오독함)
    final rateMultiplier = speechRate / 0.5;
    final lang = locale ?? appLanguage.ttsLocale; // ja-JP
    final ssml = '''
<speak version='1.0' xml:lang='$lang'>
  <voice xml:lang='$lang' name='$ttsVoice'>
    <prosody rate="$rateMultiplier">
      $escapedText
    </prosody>
  </voice>
</speak>
''';

    final response = await http.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': key,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
        'User-Agent': 'MaltuimJapanese',
      },
      body: ssml,
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print('Azure TTS request failed. Status: ${response.statusCode}, '
          'Body: ${response.body}');
      return null;
    }
  }

  /// Stops any currently playing speech.
  ///
  /// 주의: 여기서 _currentSpeechId를 증가시키면 안 된다. speak()가 내부에서
  /// stop()을 호출하므로, 증가시키면 자기 자신의 speechId 가드가 깨져
  /// 재생 직전에 항상 return 되는 버그가 발생한다.
  static Future<void> stop() async {
    try {
      await AudioPlayerHelper.stop();
    } catch (e) {
      print('AudioPlayer stop error: $e');
    }
    if (kIsWeb) {
      try {
        await WebTtsHelper.stopAzureTts();
      } catch (e) {
        print('WebTtsHelper stop error: $e');
      }
    }
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('FlutterTts stop error: $e');
    }
  }
}
