import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pronunciation_engine/pronunciation_engine.dart';

import '../app/theme.dart';
import '../services/alignment_service.dart';
import '../services/app_language.dart';
import '../services/progress_service.dart';
import '../services/recall_scorer.dart';
import '../services/sentence_storage_service.dart';
import '../services/speech_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import 'widgets/comparison_text.dart';
import 'widgets/mic_button.dart';

/// 말툭튀(장면 회상) 모드의 방향.
enum RecallDirection { jpToKo, koToJp }

/// 말툭튀 모드의 채점 방식.
enum RecallScoringMode { selfRating, keyword }

/// 듣기 + 따라 말하기 연습 화면 (일본어).
///
/// 상단의 문장/문절 세그먼트로 연습 단위를 고르고, 듣기(TTS)로 원어민 발음을
/// 들은 뒤(반복 1~3회/연속듣기) 마이크로 따라 말하면 문자 단위 채점 결과를
/// 보여준다. 요미가나(읽기) 표시를 켜고 끌 수 있다.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final SpeechService _speechService = SpeechService();

  List<PracticeSentence> _sentences = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  PracticeLevel _level = PracticeLevel.sentence;
  int _chunkIndex = 0;

  bool _isListening = false;
  bool _azureListening = false;
  PronunciationResult? _pronunciationResult;
  String _recognizedText = '';
  bool _showTranslation = true;
  bool _showReading = true;
  bool _showVocab = false;

  // 결과
  bool _hasResult = false;
  double _score = 0.0;
  List<AlignmentWord> _alignedWords = [];
  String _feedback = '';
  String _statusMessage = '';

  // 데모(시뮬레이션) 모드
  bool _useDemoMode = false;
  double _simAccuracy = 0.8;

  // 반복/연속 듣기
  int _repeatCount = 1;
  bool _isPlaying = false;
  int _playRepeat = 0;
  late final PlaybackSequencer _sequencer;

  // 말툭튀(장면 회상) 모드
  RecallDirection _recallDirection = RecallDirection.jpToKo;
  RecallScoringMode _recallScoringMode = RecallScoringMode.keyword;
  bool _recallRevealed = false;
  bool _recallPeeking = false;
  bool _isRecallListening = false;
  String _recallRecognized = '';

  String _t(String key) => TranslationService.get(key);

  @override
  void initState() {
    super.initState();
    _sequencer = PlaybackSequencer(
      speak: (t) => TtsService.speak(t),
      repeatGap: const Duration(milliseconds: 700),
      itemGap: const Duration(milliseconds: 1200),
    );
    _initSpeech();
    _loadSentences();
    _loadTtsSettings();
  }

  @override
  void dispose() {
    _sequencer.stop();
    TtsService.stop();
    super.dispose();
  }

  Future<void> _loadTtsSettings() async {
    await TtsService.loadSettings();
    if (mounted) setState(() {});
  }

  Future<void> _initSpeech() async {
    await _speechService.initialize();
    if (!mounted) return;
    setState(() => _useDemoMode = _speechService.useDemoMode);
  }

  Future<void> _loadSentences() async {
    final loaded = await SentenceStorageService.loadSentences();
    if (!mounted) return;
    setState(() {
      _sentences = loaded;
      if (_currentIndex >= _sentences.length) {
        _currentIndex = _sentences.isEmpty ? 0 : _sentences.length - 1;
      }
      _isLoading = false;
      _resetSession();
    });
  }

  PracticeSentence? get _current =>
      _sentences.isEmpty ? null : _sentences[_currentIndex];

  /// 현재 연습 단위에 해당하는 목표 텍스트.
  String get _target {
    final s = _current;
    if (s == null) return '';
    switch (_level) {
      case PracticeLevel.sentence:
        return s.text;
      case PracticeLevel.chunk:
        if (s.chunks.isNotEmpty && _chunkIndex < s.chunks.length) {
          return s.chunks[_chunkIndex];
        }
        return s.text;
      case PracticeLevel.word:
        return s.text; // 일본어 미지원 — 방어적 폴백
      case PracticeLevel.recall:
        return s.text;
    }
  }

  /// 결과 표시에 사용할 청크 그룹.
  List<String> get _comparisonChunks {
    final s = _current;
    if (s == null) return const [];
    switch (_level) {
      case PracticeLevel.sentence:
        return s.chunks.isNotEmpty ? s.chunks : [s.text];
      case PracticeLevel.chunk:
      case PracticeLevel.word:
      case PracticeLevel.recall:
        return [_target];
    }
  }

  /// 말툭튀: 앱이 먼저 읽어주는 문장(원본 언어).
  String get _recallSourceText {
    final s = _current;
    if (s == null) return '';
    return _recallDirection == RecallDirection.jpToKo ? s.text : s.translation;
  }

  /// 말툭튀: 학습자가 떠올려 말해야 하는 문장(목표 언어).
  String get _recallTargetText {
    final s = _current;
    if (s == null) return '';
    return _recallDirection == RecallDirection.jpToKo ? s.translation : s.text;
  }

  void _resetSession() {
    _recognizedText = '';
    _score = 0.0;
    _alignedWords = [];
    _feedback = '';
    _hasResult = false;
    _isListening = false;
    _azureListening = false;
    _pronunciationResult = null;
    _showVocab = false;
    _recallRevealed = false;
    _recallPeeking = false;
    _isRecallListening = false;
    _recallRecognized = '';
    _statusMessage =
        _useDemoMode ? _t('instruction_demo') : _t('instruction_default');
  }

  void _changeLevel(PracticeLevel level) {
    setState(() {
      _level = level;
      _chunkIndex = 0;
      _resetSession();
    });
  }

  void _onPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _chunkIndex = 0;
        _resetSession();
      });
    }
  }

  void _onNext() {
    if (_currentIndex < _sentences.length - 1) {
      setState(() {
        _currentIndex++;
        _chunkIndex = 0;
        _resetSession();
      });
    }
  }

  // ── 반복/연속 듣기 ──

  Future<void> _playSingle() async {
    if (_isPlaying) return;
    await TtsService.unlockAudioEngine();
    setState(() {
      _isPlaying = true;
      _playRepeat = 0;
    });
    await _sequencer.play(
      [_target],
      repeatCount: _repeatCount,
      itemGap: Duration.zero,
      onProgress: (i, r) {
        if (mounted) setState(() => _playRepeat = r);
      },
    );
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playRepeat = 0;
      });
    }
  }

  Future<void> _playContinuous() async {
    if (_isPlaying || _sentences.isEmpty) return;
    await TtsService.unlockAudioEngine();
    final startIndex = _currentIndex;
    final items = _sentences.sublist(startIndex).map((s) => s.text).toList();
    setState(() {
      _isPlaying = true;
      _playRepeat = 0;
      _level = PracticeLevel.sentence;
    });
    await _sequencer.play(
      items,
      repeatCount: _repeatCount,
      onItemBoundary: () => TtsService.playTransitionChime(),
      onProgress: (i, r) {
        if (!mounted) return;
        setState(() {
          _currentIndex = startIndex + i;
          _chunkIndex = 0;
          _hasResult = false;
          _playRepeat = r;
        });
      },
    );
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playRepeat = 0;
      });
    }
  }

  void _stopPlayback() {
    _sequencer.stop();
    TtsService.stop();
    if (_isRecallListening) {
      _speechService.stopListening();
    }
    setState(() {
      _isPlaying = false;
      _playRepeat = 0;
    });
  }

  // ── 말툭튀(장면 회상) ──

  /// 원본 문장을 방향에 맞는 음성으로 재생한다.
  Future<void> _speakRecallSource() async {
    await TtsService.unlockAudioEngine();
    if (_recallDirection == RecallDirection.koToJp) {
      await TtsService.speak(_recallSourceText,
          voice: 'ko-KR-SunHiNeural', locale: 'ko-KR');
    } else {
      await TtsService.speak(_recallSourceText);
    }
  }

  /// 재생이 끝난 뒤 자동으로 마이크를 켠다 (듣기/연속듣기 종료 시 공통 사용).
  Future<void> _autoStartRecallListening() async {
    if (!mounted || _isRecallListening || _isPlaying) return;
    await _toggleRecallListening();
  }

  /// 듣기 버튼: 원본 문장 재생 후 자동으로 마이크를 켠다.
  Future<void> _onRecallListenTap() async {
    await _speakRecallSource();
    await _autoStartRecallListening();
  }

  /// 키워드 채점 점수 (0~100).
  double get _recallKeywordScore {
    final s = _current;
    if (s == null || _recallRecognized.isEmpty) return 0;
    if (_recallDirection == RecallDirection.jpToKo) {
      return RecallScorer.scoreKorean(_recallRecognized, _recallTargetText);
    }
    return RecallScorer.scoreJapanese(_recallRecognized, s);
  }

  void _recordRecallScore(double score) {
    final s = _current;
    if (s == null) return;
    ProgressService.recordAttempt(PracticeAttempt(
      sentenceId: s.id,
      level: PracticeLevel.recall,
      score: score,
      timestamp: DateTime.now(),
    ));
  }

  /// 자가채점 버튼 선택 → 기록 후 다음 문장으로.
  void _recallSelfRate(double score) {
    _recordRecallScore(score);
    if (_currentIndex < _sentences.length - 1) {
      _onNext();
    } else {
      setState(() {
        _recallRevealed = false;
        _recallRecognized = '';
      });
    }
  }

  Future<void> _toggleRecallListening() async {
    if (_isRecallListening) {
      setState(() => _isRecallListening = false);
      TtsService.setMicActive(false);
      await _speechService.stopListening();
      return;
    }

    // 이전 세션이 완전히 종료되지 않은 채로 남아있으면 새 listen() 호출이
    // 무시되어 말툭튀에서 마이크가 켜진 것처럼 보여도 인식이 시작되지 않는
    // 문제가 있었다. 새로 시작하기 전에 항상 한 번 정지시킨다.
    // stop()은 마지막 인식 결과를 처리할 때까지 대기해 인식기가 완전히
    // 초기화되지 않은 상태로 남을 수 있어, cancel()로 즉시 폐기한다.
    if (_speechService.isListening) {
      await _speechService.cancelListening();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    TtsService.setMicActive(true);
    setState(() {
      _isRecallListening = true;
      _recallRecognized = '';
    });

    // 학습자가 말해야 하는 언어(목표 언어)에 맞는 인식 로케일.
    final localeId = _recallDirection == RecallDirection.jpToKo
        ? 'ko-KR'
        : appLanguage.sttLocale;

    if (_useDemoMode) {
      _speechService.simulateSpeechInput(
        targetSentence: _recallTargetText,
        accuracy: _simAccuracy,
        onResult: (text, isFinal) {
          setState(() {
            _recallRecognized = text;
            if (text.isNotEmpty) _recallRevealed = true;
            if (isFinal) _isRecallListening = false;
          });
          if (isFinal &&
              _recallScoringMode == RecallScoringMode.keyword &&
              text.isNotEmpty) {
            _recordRecallScore(_recallKeywordScore);
          }
        },
      );
      return;
    }

    try {
      await _speechService.startListening(
        localeId: localeId,
        onResult: (text, isFinal) {
          setState(() {
            _recallRecognized = text;
            if (text.isNotEmpty) _recallRevealed = true;
            if (isFinal) _isRecallListening = false;
          });
          if (isFinal) {
            TtsService.setMicActive(false);
            if (_recallScoringMode == RecallScoringMode.keyword &&
                text.isNotEmpty) {
              _recordRecallScore(_recallKeywordScore);
            }
          }
        },
        onStatus: (status) {
          if ((status == 'notListening' || status == 'done') &&
              _isRecallListening) {
            setState(() => _isRecallListening = false);
            TtsService.setMicActive(false);
          }
        },
      );
    } catch (e) {
      debugPrint('말툭튀 STT 시작 오류: $e');
      if (mounted) setState(() => _isRecallListening = false);
      TtsService.setMicActive(false);
    }
  }

  /// 연속 모드용 1회 STT 인식.
  ///
  /// `_toggleRecallListening`과 달리 인식이 끝나거나(최종 결과/상태 종료)
  /// 일정 시간 무응답이면 자동으로 반환되어, 연속 재생 루프가 다음 문장으로
  /// 진행할 수 있다.
  Future<void> _listenOnceForRecall() async {
    if (!mounted) return;

    if (_speechService.isListening) {
      await _speechService.cancelListening();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    TtsService.setMicActive(true);
    setState(() {
      _isRecallListening = true;
      _recallRecognized = '';
    });

    final localeId = _recallDirection == RecallDirection.jpToKo
        ? 'ko-KR'
        : appLanguage.sttLocale;

    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    if (_useDemoMode) {
      _speechService.simulateSpeechInput(
        targetSentence: _recallTargetText,
        accuracy: _simAccuracy,
        onResult: (text, isFinal) {
          if (!mounted) return;
          setState(() {
            _recallRecognized = text;
            if (text.isNotEmpty) _recallRevealed = true;
            if (isFinal) _isRecallListening = false;
          });
          if (isFinal) {
            if (_recallScoringMode == RecallScoringMode.keyword &&
                text.isNotEmpty) {
              _recordRecallScore(_recallKeywordScore);
            }
            finish();
          }
        },
      );
    } else {
      try {
        await _speechService.startListening(
          localeId: localeId,
          onResult: (text, isFinal) {
            if (!mounted) return;
            setState(() {
              _recallRecognized = text;
              if (text.isNotEmpty) _recallRevealed = true;
              if (isFinal) _isRecallListening = false;
            });
            if (isFinal) {
              TtsService.setMicActive(false);
              if (_recallScoringMode == RecallScoringMode.keyword &&
                  text.isNotEmpty) {
                _recordRecallScore(_recallKeywordScore);
              }
              finish();
            }
          },
          onStatus: (status) {
            if (status == 'notListening' || status == 'done') {
              if (mounted && _isRecallListening) {
                setState(() => _isRecallListening = false);
              }
              TtsService.setMicActive(false);
              finish();
            }
          },
        );
      } catch (e) {
        debugPrint('말툭튀 연속 STT 오류: $e');
        if (mounted) setState(() => _isRecallListening = false);
        TtsService.setMicActive(false);
        finish();
      }
    }

    // 무응답 시 다음 문장으로 넘어가기 위한 최대 대기 시간.
    await completer.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    if (_speechService.isListening) {
      await _speechService.stopListening();
    }
    if (mounted && _isRecallListening) {
      setState(() => _isRecallListening = false);
    }
    TtsService.setMicActive(false);
  }

  /// 연속 모드: 문장마다 (재생 → 마이크로 발화 인식 → 정답 공개) 후 다음 문장으로.
  Future<void> _playRecallContinuous() async {
    if (_isPlaying || _sentences.isEmpty) return;
    setState(() {
      _isPlaying = true;
      _recallRevealed = false;
      _recallRecognized = '';
    });

    for (var i = _currentIndex; i < _sentences.length; i++) {
      if (!_isPlaying || !mounted) break;
      setState(() {
        _currentIndex = i;
        _recallRevealed = false;
        _recallRecognized = '';
      });
      await _speakRecallSource();
      if (!_isPlaying || !mounted) break;

      // 학습자가 대응 문장을 말할 시간을 주고 STT로 인식한다.
      await _listenOnceForRecall();
      if (!_isPlaying || !mounted) break;

      setState(() => _recallRevealed = true);
      await Future.delayed(const Duration(seconds: 2));
    }

    if (mounted) setState(() => _isPlaying = false);
  }

  // ── 발음 평가 ──

  /// 발음 평가에 Azure STT + Pronunciation Assessment를 사용할지 여부.
  /// 웹 + Azure 설정 + 문장 모드에서만 사용하며, 기존 텍스트 일치 채점은
  /// 그대로 유지하고 발음 점수를 추가 정보로 표시한다.
  bool get _useAzurePronunciation =>
      kIsWeb &&
      !_useDemoMode &&
      _level == PracticeLevel.sentence &&
      TtsService.isAzureEnabled;

  Future<void> _toggleListening() async {
    if (_isListening) {
      if (_azureListening) {
        // Azure recognizeOnceAsync는 자체 무음 감지로 종료되므로, 수동 중단
        // 시에는 인식기를 닫고 상태만 정리한다 (결과는 받지 않음).
        _speechService.cancelPronunciationRecognition();
        TtsService.setMicActive(false);
        setState(() {
          _isListening = false;
          _azureListening = false;
          _statusMessage = _t('instruction_no_speech');
        });
        return;
      }
      setState(() {
        _isListening = false;
        _statusMessage = _t('instruction_analyzing');
      });
      TtsService.setMicActive(false);
      if (_useDemoMode) {
        _runDemo();
      } else {
        await _speechService.stopListening();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && !_hasResult) {
            if (_recognizedText.isNotEmpty) {
              _processResult(_recognizedText);
            } else {
              setState(() => _statusMessage = _t('instruction_no_speech'));
            }
          }
        });
      }
      return;
    }

    _resetSession();
    setState(() {
      _isListening = true;
      _statusMessage = _t('instruction_listening');
    });

    if (_useDemoMode) return;

    TtsService.setMicActive(true);

    if (_useAzurePronunciation) {
      _azureListening = true;
      final result = await _speechService.recognizeWithPronunciation(
        referenceText: _target,
      );
      if (!mounted || !_azureListening) return;
      _azureListening = false;
      TtsService.setMicActive(false);
      if (result.text.isNotEmpty) {
        _pronunciationResult = result;
        _recognizedText = result.text;
        _processResult(result.text);
      } else {
        setState(() {
          _isListening = false;
          _statusMessage = _t('instruction_no_speech');
        });
      }
      return;
    }

    await _speechService.startListening(
      onResult: (text, isFinal) {
        setState(() {
          _recognizedText = text;
          if (isFinal) _processResult(text);
        });
        if (isFinal) TtsService.setMicActive(false);
      },
      onStatus: (status) {
        if ((status == 'notListening' || status == 'done') && _isListening) {
          TtsService.setMicActive(false);
          setState(() {
            _isListening = false;
            _statusMessage = _t('instruction_analyzing');
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_hasResult) {
              if (_recognizedText.isNotEmpty) {
                _processResult(_recognizedText);
              } else {
                setState(() => _statusMessage = _t('instruction_no_speech'));
              }
            }
          });
        }
      },
    );
  }

  void _runDemo() {
    _speechService.simulateSpeechInput(
      targetSentence: _target,
      accuracy: _simAccuracy,
      onResult: (text, isFinal) {
        setState(() {
          _recognizedText = text;
          _processResult(text);
        });
      },
    );
  }

  void _processResult(String recognized) {
    final target = _target;
    final aligned = AlignmentService.alignSentences(target, recognized);
    final score = AlignmentService.calculateOverallScore(target, recognized);
    final feedback = AlignmentService.generateFeedbackText(aligned);

    setState(() {
      _alignedWords = aligned;
      _score = score;
      _feedback = feedback;
      _hasResult = true;
      _isListening = false;
      _statusMessage = _t('instruction_complete');
    });

    final s = _current;
    if (s != null) {
      ProgressService.recordAttempt(PracticeAttempt(
        sentenceId: s.id,
        level: _level,
        score: score,
        timestamp: DateTime.now(),
      ));
    }
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgTop,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: _current == null
              ? _buildEmpty()
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLevelSelector(),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onHorizontalDragEnd: (details) {
                                final velocity =
                                    details.primaryVelocity ?? 0;
                                if (velocity < -200) {
                                  _onNext();
                                } else if (velocity > 200) {
                                  _onPrev();
                                }
                              },
                              child: _level == PracticeLevel.recall
                                  ? _buildRecallCard(_current!)
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildTargetCard(_current!),
                                        const SizedBox(height: 20),
                                        if (_hasResult) ...[
                                          _buildScore(),
                                          const SizedBox(height: 16),
                                          _buildAlignment(),
                                          const SizedBox(height: 16),
                                          _buildFeedback(),
                                        ] else
                                          _buildInstructions(),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                    _buildControlPanel(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, color: Colors.white24, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _t('no_sentences'),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('admin_guide'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: Text(_t('go_admin')),
                    onPressed: () =>
                        context.push('/admin').then((_) => _loadSentences()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const Spacer(),
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector() {
    // 일본어는 단어 레벨 미지원 → 문장/문절/말툭튀 3탭
    final levels = [
      PracticeLevel.sentence,
      PracticeLevel.chunk,
      if (appLanguage.supportsWordLevel) PracticeLevel.word,
      PracticeLevel.recall,
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final level in levels) Expanded(child: _levelTab(level)),
        ],
      ),
    );
  }

  Widget _levelTab(PracticeLevel level) {
    final selected = _level == level;
    final label = level == PracticeLevel.chunk ? '문절' : level.labelKo;
    return GestureDetector(
      onTap: () => _changeLevel(level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(PracticeSentence s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_t('sentence_label')} ${_currentIndex + 1}/${_sentences.length}'
                '  ·  ${s.category}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _showTranslation = !_showTranslation),
                child: Text(
                  _showTranslation
                      ? _t('hide_translation')
                      : _t('show_translation'),
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── 3줄 구조: ① 본문(문장) 또는 문절 칩 ② 히라가나 ③ 한국어 뜻 ──
          if (_level == PracticeLevel.chunk)
            _buildChunkChips(s)
          else
            _buildSentenceText(s),
          // ② 요미가나 (읽기) — 액센트 컬러로 동기화
          if (_showReading && s.reading.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              s.reading,
              style: TextStyle(
                color: AppColors.accent.withValues(alpha: 0.85),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
          // ③ 한국어 뜻
          if (_showTranslation) ...[
            const SizedBox(height: 6),
            Text(
              s.translation,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          // ④ 단어 사전 (아코디언)
          if (s.vocabulary.isNotEmpty && _showVocab) ...[
            const SizedBox(height: 12),
            _buildVocabPanel(s),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _listenButton(),
                  const SizedBox(width: 8),
                  // 요미가나 토글
                  GestureDetector(
                    onTap: () => setState(() => _showReading = !_showReading),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        _showReading ? 'あ✓' : 'あ',
                        style: TextStyle(
                          color: _showReading
                              ? AppColors.accent
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (s.vocabulary.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    // 단어 사전 토글
                    GestureDetector(
                      onTap: () => setState(() => _showVocab = !_showVocab),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          _showVocab ? '단어✓' : '단어',
                          style: TextStyle(
                            color: _showVocab
                                ? AppColors.accent
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _currentIndex > 0 ? _onPrev : null,
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    color: AppColors.textPrimary,
                    disabledColor: Colors.white10,
                  ),
                  IconButton(
                    onPressed:
                        _currentIndex < _sentences.length - 1 ? _onNext : null,
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    color: AppColors.textPrimary,
                    disabledColor: Colors.white10,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          _buildPlaybackControls(),
        ],
      ),
    );
  }

  /// 문장에 등장하는 핵심 단어 목록 (단어 사전 아코디언 내용).
  Widget _buildVocabPanel(PracticeSentence s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final v in s.vocabulary) _buildVocabEntry(v),
        ],
      ),
    );
  }

  Widget _buildVocabEntry(VocabEntry v) {
    final headword = v.kanji.isNotEmpty ? '${v.kanji} (${v.word})' : v.word;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                headword,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                v.reading,
                style: TextStyle(
                  color: AppColors.accent.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            '${v.meaning}  ·  ${v.pos}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          if (v.forms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in v.forms)
                    Text(
                      '· $f',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 문장 모드 본문 (한 줄, 테마 폰트 — 웹 일본어 글리프 안전).
  Widget _buildSentenceText(PracticeSentence s) {
    return Text(
      s.text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
  }

  /// 문절 칩 — 본문을 대신하는 1행. 안내 문구 없이 칩만 크게 표시한다.
  Widget _buildChunkChips(PracticeSentence s) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < s.chunks.length; i++)
          _chip(s.chunks[i], i == _chunkIndex, () {
            setState(() {
              _chunkIndex = i;
              _resetSession();
            });
          }),
      ],
    );
  }

  /// 선택 칩: 앰버 박스 + 진네이비 글자 (박스/글자 다른 색으로 대비).
  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.onAccent : AppColors.textSecondary,
            fontSize: 20,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 말툭튀(장면 회상) 모드 카드.
  Widget _buildRecallCard(PracticeSentence s) {
    final isJpToKo = _recallDirection == RecallDirection.jpToKo;
    final sourceLabel = isJpToKo ? '🇯🇵 일본어' : '🇰🇷 한국어';
    final targetLabel = isJpToKo ? '🇰🇷 한국어' : '🇯🇵 일본어';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_t('sentence_label')} ${_currentIndex + 1}/${_sentences.length}'
                '  ·  ${s.category}',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              _recallDirectionToggle(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isJpToKo
                ? '일본어 문장을 듣고, 한국어로 바로 말해보세요'
                : '한국어 문장을 듣고, 일본어로 바로 말해보세요',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // 원본 문장 (앱이 읽어주는 문장)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sourceLabel,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Text(
                  _recallSourceText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _isPlaying ? null : _onRecallListenTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_up,
                            color: AppColors.accent, size: 18),
                        const SizedBox(width: 6),
                        Text(_t('listen'),
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isPlaying ? _stopButton() : _recallContinuousButton(),
            ],
          ),
          const SizedBox(height: 16),
          // 정답 (목표 문장)
          if (_recallRevealed || _recallPeeking) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(targetLabel,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 6),
                    Text(
                      _recallTargetText,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_recallRevealed)
            if (_recallScoringMode == RecallScoringMode.selfRating)
              _recallSelfRatingButtons()
            else
              _recallKeywordResult()
          else
            // 말하면 정답이 자동으로 공개된다. 말하기 어려운 경우를 위해
            // 이 버튼을 누르고 있는 동안만 정답을 임시로 볼 수 있다.
            Row(
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _onPrev : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  color: AppColors.textPrimary,
                  disabledColor: Colors.white10,
                ),
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) =>
                        setState(() => _recallPeeking = true),
                    onTapUp: (_) =>
                        setState(() => _recallPeeking = false),
                    onTapCancel: () =>
                        setState(() => _recallPeeking = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Text(
                          '정답 보기 (누르고 있기)',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _currentIndex < _sentences.length - 1
                      ? _onNext
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  color: AppColors.textPrimary,
                  disabledColor: Colors.white10,
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          if (_recallRevealed)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _onPrev : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  color: AppColors.textPrimary,
                  disabledColor: Colors.white10,
                ),
                IconButton(
                  onPressed: _currentIndex < _sentences.length - 1
                      ? _onNext
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  color: AppColors.textPrimary,
                  disabledColor: Colors.white10,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _recallDirectionToggle() {
    final isJpToKo = _recallDirection == RecallDirection.jpToKo;
    final label = isJpToKo ? '일 → 한' : '한 → 일';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() {
          _recallDirection =
              isJpToKo ? RecallDirection.koToJp : RecallDirection.jpToKo;
          _resetSession();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Icon(Icons.swap_horiz, color: AppColors.accent, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 자가채점 버튼: 다시 / 애매 / 정확.
  Widget _recallSelfRatingButtons() {
    return Row(
      children: [
        Expanded(
          child: _recallRatingButton(
              '다시', AppColors.danger, () => _recallSelfRate(20)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _recallRatingButton(
              '애매', AppColors.warning, () => _recallSelfRate(60)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _recallRatingButton(
              '정확', AppColors.success, () => _recallSelfRate(100)),
        ),
      ],
    );
  }

  Widget _recallRatingButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 키워드 채점 결과 + 마이크로 다시 말하기.
  Widget _recallKeywordResult() {
    final hasResult = _recallRecognized.isNotEmpty;
    final score = hasResult ? _recallKeywordScore : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasResult) ...[
          Row(
            children: [
              Text('점수 ${score.toInt()}점',
                  style: TextStyle(
                      color: AppColors.forScore(score),
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🗣 $_recallRecognized',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Text(
          _isRecallListening
              ? _t('instruction_listening')
              : '마이크를 눌러 말해보세요',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _recallContinuousButton() {
    return GestureDetector(
      onTap: _playRecallContinuous,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_play, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              _t('continuous_listen'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listenButton() {
    return GestureDetector(
      onTap: _isPlaying ? null : _playSingle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_up, color: AppColors.accent, size: 18),
            const SizedBox(width: 6),
            Text(
              _repeatCount > 1
                  ? '${_t('listen')} ×$_repeatCount'
                  : _t('listen'),
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      children: [
        Text('${_t('repeat')} ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(width: 6),
        for (final n in [1, 2, 3]) ...[
          _repeatChip(n),
          const SizedBox(width: 6),
        ],
        const Spacer(),
        _isPlaying ? _stopButton() : _continuousButton(),
      ],
    );
  }

  Widget _repeatChip(int n) {
    final selected = _repeatCount == n;
    return GestureDetector(
      onTap: _isPlaying ? null : () => setState(() => _repeatCount = n),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected ? AppColors.accent : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _continuousButton() {
    return GestureDetector(
      onTap: _playContinuous,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_play, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              _t('continuous_listen'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stopButton() {
    return GestureDetector(
      onTap: _stopPlayback,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stop, color: AppColors.danger, size: 18),
            const SizedBox(width: 6),
            Text(
              _playRepeat > 0
                  ? '${_t('stop')} ($_playRepeat/$_repeatCount)'
                  : _t('stop'),
              style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        children: [
          Icon(Icons.record_voice_over,
              size: 44, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15, height: 1.5),
          ),
          if (_useDemoMode) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_t('sim_accuracy'),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                Text('${(_simAccuracy * 100).toInt()}%',
                    style: TextStyle(
                        color: _simAccuracy > 0.8
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _simAccuracy,
              min: 0.3,
              max: 1.0,
              divisions: 7,
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _simAccuracy = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScore() {
    final color = AppColors.forScore(_score);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration(),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: _score / 100.0,
                  backgroundColor: Colors.white10,
                  color: color,
                  strokeWidth: 8,
                ),
              ),
              Text('${_score.toInt()}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('score_title'),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  _score >= 85
                      ? _t('feedback_excellent')
                      : _score >= 60
                          ? _t('feedback_decent')
                          : _t('feedback_poor'),
                  style: TextStyle(
                      color: color, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (_recognizedText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🗣 $_recognizedText',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignment() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('detail_title'),
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ComparisonText(
            alignedWords: _alignedWords,
            chunks: _comparisonChunks,
            onChunkTap: (chunk) {
              final s = _current;
              if (s == null) return;
              final idx = s.chunks.indexOf(chunk);
              if (idx >= 0) {
                setState(() {
                  _level = PracticeLevel.chunk;
                  _chunkIndex = idx;
                  _resetSession();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t('tips_title'),
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(_feedback,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          if (_pronunciationResult?.hasScores == true) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            Text('Azure 발음 평가',
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPronScoreItem('정확도', _pronunciationResult!.accuracyScore),
                _buildPronScoreItem('유창성', _pronunciationResult!.fluencyScore),
                _buildPronScoreItem(
                    '완성도', _pronunciationResult!.completenessScore),
                _buildPronScoreItem('종합', _pronunciationResult!.pronScore),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPronScoreItem(String label, double? value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value != null ? value.round().toString() : '-',
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isListening || _isRecallListening)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                () {
                  final recognized = _level == PracticeLevel.recall
                      ? _recallRecognized
                      : _recognizedText;
                  return recognized.isEmpty
                      ? _t('say_words')
                      : '"$recognized"';
                }(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontStyle: FontStyle.italic),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed:
                    _hasResult ? () => setState(() => _resetSession()) : null,
                icon: const Icon(Icons.refresh),
                color: AppColors.textSecondary,
                disabledColor: Colors.white10,
                iconSize: 26,
              ),
              MicButton(
                isListening: _level == PracticeLevel.recall
                    ? _isRecallListening
                    : _isListening,
                useDemoMode: _useDemoMode,
                onTap: () async {
                  await TtsService.unlockAudioEngine();
                  if (_level == PracticeLevel.recall) {
                    await _toggleRecallListening();
                  } else {
                    await _toggleListening();
                  }
                },
              ),
              IconButton(
                onPressed: _showHelp,
                icon: const Icon(Icons.help_outline),
                color: AppColors.textSecondary,
                iconSize: 26,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_t('help_title'),
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(_t('help_content'),
            style:
                const TextStyle(color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('help_gotit')),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    var localDemo = _useDemoMode;
    var selectedVoice = TtsService.azureVoice;
    var localRate = TtsService.speechRate;
    var localScoringMode = _recallScoringMode;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(_t('settings_title'),
              style: const TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadioListTile<bool>(
                  title: Text(_t('settings_mode_real'),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  value: false,
                  groupValue: localDemo,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setDialog(() => localDemo = v!),
                ),
                RadioListTile<bool>(
                  title: Text(_t('settings_mode_demo'),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  value: true,
                  groupValue: localDemo,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setDialog(() => localDemo = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedVoice,
                  dropdownColor: AppColors.surface,
                  decoration: InputDecoration(
                    labelText: _t('settings_voice_label'),
                    labelStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  items: const [
                    DropdownMenuItem(
                        value: 'ja-JP-NanamiNeural',
                        child: Text('나나미 (여성 - 기본)')),
                    DropdownMenuItem(
                        value: 'ja-JP-KeitaNeural', child: Text('케이타 (남성)')),
                    DropdownMenuItem(
                        value: 'ja-JP-MayuNeural', child: Text('마유 (여성)')),
                    DropdownMenuItem(
                        value: 'ja-JP-DaichiNeural',
                        child: Text('다이치 (남성)')),
                    DropdownMenuItem(
                        value: 'ja-JP-AoiNeural', child: Text('아오이 (여성)')),
                  ],
                  onChanged: (v) {
                    if (v != null) selectedVoice = v;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '재생 속도: ${(localRate / 0.5).toStringAsFixed(1)}x',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
                Slider(
                  value: localRate,
                  min: 0.3,
                  max: 0.7,
                  divisions: 8,
                  activeColor: AppColors.accent,
                  inactiveColor: Colors.white10,
                  onChanged: (v) => setDialog(() => localRate = v),
                ),
                const SizedBox(height: 16),
                const Text('말툭튀 채점 방식',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                RadioListTile<RecallScoringMode>(
                  title: const Text('자가채점',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  value: RecallScoringMode.selfRating,
                  groupValue: localScoringMode,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setDialog(() => localScoringMode = v!),
                ),
                RadioListTile<RecallScoringMode>(
                  title: const Text('키워드채점',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  value: RecallScoringMode.keyword,
                  groupValue: localScoringMode,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setDialog(() => localScoringMode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('settings_cancel'),
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                setState(() {
                  _useDemoMode = localDemo;
                  _speechService.useDemoMode = localDemo;
                  TtsService.azureVoice = selectedVoice;
                  TtsService.speechRate = localRate;
                  _recallScoringMode = localScoringMode;
                  TtsService.saveSettings();
                  _resetSession();
                });
                Navigator.pop(context);
              },
              child: Text(_t('settings_save'),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
