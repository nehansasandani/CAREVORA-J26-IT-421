import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/localization/app_language.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../core/localization/sinhala_typing_helper.dart';
import '../../../core/responsive/responsive_builder.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_carevora_data.dart';
import '../../../data/models/carevora_models.dart';
import '../../../shared/widgets/carevora_avatar.dart';
import '../../../shared/widgets/sinhala_virtual_keyboard.dart';
import '../../auth/application/auth_controller.dart';
import '../application/cognitive_assessment_service.dart';
import '../domain/cognitive_scoring.dart';

class AssessmentSessionPage extends ConsumerStatefulWidget {
  const AssessmentSessionPage({super.key});

  @override
  ConsumerState<AssessmentSessionPage> createState() =>
      _AssessmentSessionPageState();
}

class _AssessmentSessionPageState extends ConsumerState<AssessmentSessionPage>
    with TickerProviderStateMixin {
  // Navigation & session index (10 questions battery, separate per language)
  int _currentIndexEn = 0;
  int _currentIndexSi = 0;

  int get _currentIndex =>
      ref.read(languageProvider).isSinhala ? _currentIndexSi : _currentIndexEn;

  set _currentIndex(int value) {
    if (ref.read(languageProvider).isSinhala) {
      _currentIndexSi = value;
    } else {
      _currentIndexEn = value;
    }
  }

  final List<CognitiveQuestionItem> _questions = CognitiveScoring.questions;

  // Separate English & Sinhala response and grade maps so answers in one language
  // do not appear in the other language view.
  final Map<int, double?> _gradesEn = {};
  final Map<int, double?> _gradesSi = {};
  final Map<int, String> _responsesEn = {};
  final Map<int, String> _responsesSi = {};

  Map<int, double?> get _grades =>
      ref.read(languageProvider).isSinhala ? _gradesSi : _gradesEn;
  Map<int, String> get _responses =>
      ref.read(languageProvider).isSinhala ? _responsesSi : _responsesEn;
  late TextEditingController _responseController;

  // Timing: active question viewing duration (separate per language)
  final Map<int, double> _questionTimesEn = {};
  final Map<int, double> _questionTimesSi = {};
  Map<int, double> get _questionTimes =>
      ref.read(languageProvider).isSinhala ? _questionTimesSi : _questionTimesEn;

  late DateTime _questionStartTime;
  int _sessionElapsedSecondsEn = 0;
  int _sessionElapsedSecondsSi = 0;
  int get _sessionElapsedSeconds => ref.read(languageProvider).isSinhala
      ? _sessionElapsedSecondsSi
      : _sessionElapsedSecondsEn;
  set _sessionElapsedSeconds(int value) {
    if (ref.read(languageProvider).isSinhala) {
      _sessionElapsedSecondsSi = value;
    } else {
      _sessionElapsedSecondsEn = value;
    }
  }

  Timer? _sessionTimer;

  // Speech & TTS
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _isSpeaking = false;
  bool _isSpeakingPrompt = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _speechAvailable = false;
  String? _speechStatusMessage;
  int _activeListeningSessionId = 0;
  bool _isTogglingMic = false;
  int _listeningQId = -1;
  bool _listeningWasSinhala = false;

  // Resident Context
  CognitiveResidentProfile? _resident;
  List<CognitiveResidentProfile> _availableResidents = [];
  bool _isLoadingResidents = false;
  String? _residentLoadError;

  // Demographic inputs if missing in resident profile
  int? _customEducationYears;
  int? _customAge;

  // Submission state
  bool _isSubmitting = false;
  String? _submitError;

  // Session lifecycle & persistence (separate per language)
  String? _sessionIdEn;
  String? _sessionIdSi;
  String? get _sessionId =>
      ref.read(languageProvider).isSinhala ? _sessionIdSi : _sessionIdEn;
  set _sessionId(String? value) {
    if (ref.read(languageProvider).isSinhala) {
      _sessionIdSi = value;
    } else {
      _sessionIdEn = value;
    }
  }

  String _sessionStatusEn = 'IN_PROGRESS'; // 'IN_PROGRESS', 'PENDING_CAREGIVER_REVIEW', 'COMPLETED'
  String _sessionStatusSi = 'IN_PROGRESS';
  String get _sessionStatus =>
      ref.read(languageProvider).isSinhala ? _sessionStatusSi : _sessionStatusEn;
  set _sessionStatus(String value) {
    if (ref.read(languageProvider).isSinhala) {
      _sessionStatusSi = value;
    } else {
      _sessionStatusEn = value;
    }
  }

  // Elder welcome start screen state (elder view only, separate per language)
  bool _hasStartedElderAssessmentEn = false;
  bool _hasStartedElderAssessmentSi = false;
  bool _isSpeakingWelcome = false;

  // Hybrid Sinhala typing state (Singlish auto-convert + virtual keyboard)
  bool? _sinhalaSinglishAuto;
  bool? _showSinhalaKeyboard;

  bool get _isSinglishAutoEnabled => _sinhalaSinglishAuto ?? true;
  bool get _isSinhalaKeyboardOpen => _showSinhalaKeyboard ?? false;

  bool get _hasStartedElderAssessment => ref.read(languageProvider).isSinhala
      ? _hasStartedElderAssessmentSi
      : _hasStartedElderAssessmentEn;

  set _hasStartedElderAssessment(bool value) {
    if (ref.read(languageProvider).isSinhala) {
      _hasStartedElderAssessmentSi = value;
    } else {
      _hasStartedElderAssessmentEn = value;
    }
  }

  // Navigation transition direction (1: next/forward, -1: prev/backward)
  int _transitionDirection = 1;

  // Background slow therapeutic breathing controller for elderly wellness
  late AnimationController _ambientBgController;
  late Animation<double> _ambientBgAnimation;

  // Animated waveform controller
  late AnimationController _waveformController;

  // Floating & ambient micro-animation controllers
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;
  late AnimationController _ambientPulseController;
  late Animation<double> _ambientPulseAnimation;

  // Answer saved pulse & glow animation
  late AnimationController _savePulseController;
  late Animation<double> _saveScaleAnimation;
  late Animation<double> _saveGlowAnimation;
  late Animation<double> _saveCheckmarkAnimation;
  Timer? _saveDebounceTimer;
  DateTime? _lastSaveAnimationTime;

  @override
  void initState() {
    super.initState();
    _questionStartTime = DateTime.now();
    _responseController = TextEditingController();
    _initTts();
    _initSpeech();
    _initWaveformAnimation();
    _initFloatingAnimation();
    _initAmbientBgAnimation();
    _initSaveAnimation();
    _startSessionTimer();
    _loadResidentContext();
    _scheduleElderWelcomeVoice();
  }

  @override
  void dispose() {
    _activeListeningSessionId++;
    _saveDebounceTimer?.cancel();
    _sessionTimer?.cancel();
    _ambientBgController.dispose();
    _waveformController.dispose();
    _floatingController.dispose();
    _ambientPulseController.dispose();
    _savePulseController.dispose();
    TtsService.instance.stop();
    _flutterTts.stop();
    _speech.statusListener = null;
    _speech.errorListener = null;
    _speech.cancel();
    _responseController.dispose();
    super.dispose();
  }

  void _initWaveformAnimation() {
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _initAmbientBgAnimation() {
    _ambientBgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _ambientBgAnimation = CurvedAnimation(
      parent: _ambientBgController,
      curve: Curves.easeInOutSine,
    );
  }

  void _initFloatingAnimation() {
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _floatingAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _ambientPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _ambientPulseAnimation = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _ambientPulseController, curve: Curves.easeInOut),
    );
  }

  void _initSaveAnimation() {
    _savePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _saveScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.90, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 65,
      ),
    ]).animate(_savePulseController);

    _saveGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _savePulseController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    _saveCheckmarkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _savePulseController,
        curve: const Interval(0.15, 0.75, curve: Curves.elasticOut),
      ),
    );
  }

  void _triggerSaveAnimation() {
    final now = DateTime.now();
    if (_lastSaveAnimationTime != null &&
        now.difference(_lastSaveAnimationTime!).inMilliseconds < 350) {
      return;
    }
    _lastSaveAnimationTime = now;
    if (mounted) {
      _savePulseController.forward(from: 0.0);
    }
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48);
      _flutterTts.setStartHandler(() {
        if (mounted && _isSpeakingPrompt) setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _isSpeakingPrompt = false;
          });
        }
      });
      _flutterTts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _isSpeakingPrompt = false;
          });
        }
      });
      _flutterTts.setErrorHandler((_) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _isSpeakingPrompt = false;
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();

    void statusHandler(String status) {
      debugPrint(
        '[CARE-STT] [5. Status Change] [6. Stop/Cancel Reason] status="$status", '
        'speechListening=${_speech.isListening}, isListeningState=$_isListening, '
        'buffer="${_responseController.text}"',
      );
      if (mounted) {
        if (status == 'notListening' || status == 'done') {
          final currentQId =
              _currentIndex < _questions.length ? _questions[_currentIndex].id : -1;

          // If this end-status belongs to a previous question or another language session,
          // do NOT cancel the listening state or overwrite the status/responses!
          if (_listeningQId != -1 &&
              ((currentQId != -1 && _listeningQId != currentQId) ||
                  ref.read(languageProvider).isSinhala != _listeningWasSinhala)) {
            debugPrint(
              '[CARE-STT] Ignoring late end status "$status" from Q$_listeningQId while active on Q$currentQId',
            );
            return;
          }

          setState(() {
            _isListening = false;
            final isSinhala = ref.read(languageProvider).isSinhala;
            final text = _responseController.text.trim();
            debugPrint(
              '[CARE-STT] [7. Final Save Tracking] End status "$status". '
              'Buffer to save: "$text", targetQ=$currentQId',
            );
            if (currentQId != -1) {
              if (text.isNotEmpty) {
                _responses[currentQId] = text;
                _grades[currentQId] = CognitiveScoring.scoreQuestion(currentQId, text);
                _speechStatusMessage = isSinhala
                    ? 'හඬ පිළිතුර සටහන් විය.'
                    : 'Voice response captured.';
                _persistResponses();
              } else {
                if (_speechStatusMessage == 'Listening... Speak now.' ||
                    _speechStatusMessage == 'සවන් දෙමින්... දැන් කතා කරන්න.') {
                  _speechStatusMessage = isSinhala
                      ? 'හඬ හඳුනාගත නොහැකි විය. කරුණාකර නැවත උත්සාහ කරන්න හෝ පිළිතුර ටයිප් කරන්න.'
                      : 'Speech not recognized. Please tap the microphone to retry or type your answer.';
                }
              }
            }
          });
        }
      }
    }

    void errorHandler(dynamic val) {
      String errorMsg = 'Unknown error';
      bool permanent = false;
      try {
        errorMsg = val?.errorMsg?.toString() ?? val?.toString() ?? 'Unknown error';
        permanent = val?.permanent == true;
      } catch (_) {
        errorMsg = val.toString();
      }
      debugPrint(
        '[CARE-STT] [5. Recognition Error] [6. Stop/Cancel Reason] '
        'errorMsg="$errorMsg", permanent=$permanent',
      );
      if (mounted) {
        if (_listeningQId != -1 &&
            ref.read(languageProvider).isSinhala != _listeningWasSinhala) {
          return;
        }
        setState(() {
          _isListening = false;
          final isSinhala = ref.read(languageProvider).isSinhala;
          final existing = _responseController.text.trim();
          if (existing.isNotEmpty && _currentIndex < _questions.length) {
            final qId = _questions[_currentIndex].id;
            _responses[qId] = existing;
            _grades[qId] = CognitiveScoring.scoreQuestion(qId, existing);
            _speechStatusMessage = isSinhala
                ? 'හඬ පිළිතුර සටහන් විය.'
                : 'Voice response captured.';
            _persistResponses();
          } else {
            if (errorMsg.contains('aborted')) {
              return;
            }
            if (errorMsg.contains('no-speech') || errorMsg.contains('error_no_match')) {
              _speechStatusMessage = isSinhala
                  ? 'හඬ හඳුනාගත නොහැකි විය. කරුණාකර නැවත උත්සාහ කරන්න හෝ පිළිතුර ටයිප් කරන්න.'
                  : 'Speech not recognized. Please tap the microphone to retry or type your answer.';
            } else if (errorMsg.contains('not-allowed') || errorMsg.contains('permission')) {
              _speechStatusMessage = isSinhala
                  ? 'මයික්‍රොෆෝන අවසරය ලබා දී නොමැත. කරුණාකර අවසර ලබා දෙන්න හෝ පිළිතුර ටයිප් කරන්න.'
                  : 'Microphone permission denied. Please allow microphone access in Chrome or type your answer.';
            } else if (errorMsg.contains('network')) {
              _speechStatusMessage = isSinhala
                  ? 'ජාල ගැටලුවකි. කරුණාකර පිළිතුර පහතින් ටයිප් කරන්න.'
                  : 'Speech service network issue. Please check connection or type your answer.';
            } else if (errorMsg.contains('already started') || errorMsg.contains('invalidstateerror')) {
              _speechStatusMessage = isSinhala
                  ? 'කතා කිරීමට නැවත මයික්‍රොෆෝනය ඔබන්න.'
                  : 'Please tap the microphone again to speak.';
            } else {
              _speechStatusMessage = isSinhala
                  ? 'කරුණාකර නැවත උත්සාහ කරන්න හෝ ඔබේ පිළිතුර ටයිප් කරන්න.'
                  : 'Audio note: $errorMsg. Please retry or type your answer.';
            }
          }
        });
      }
    }

    _speech.statusListener = statusHandler;
    _speech.errorListener = errorHandler;

    try {
      debugPrint('[CARE-STT] [2. Init] Initializing SpeechToText engine...');
      final available = await _speech.initialize(
        onStatus: statusHandler,
        onError: errorHandler,
      );
      bool hasPerm = false;
      try {
        hasPerm = await _speech.hasPermission;
      } catch (_) {}
      debugPrint(
        '[CARE-STT] [2. Init Status] available=$available, hasPermission=$hasPerm, '
        'isAvailable=${_speech.isAvailable}, hasError=${_speech.hasError}',
      );
      if (mounted) {
        setState(() {
          _speechInitialized = true;
          _speechAvailable = available;
          if (!available) {
            _speechStatusMessage =
                'Microphone/speech recognition unavailable. Please use manual entry or scoring.';
          }
        });
      }
    } catch (e) {
      debugPrint('[CARE-STT] [2. Init Status] Exception during initialize: $e');
      if (mounted) {
        setState(() {
          _speechInitialized = true;
          _speechAvailable = false;
          _speechStatusMessage =
              'Audio capture unavailable. Manual entry is supported.';
        });
      }
    }
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final isElder = ref.read(authProvider).state.isElder;
        if (!isElder || _hasStartedElderAssessment) {
          setState(() => _sessionElapsedSeconds++);
        }
      }
    });
  }

  void _scheduleElderWelcomeVoice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        final isElder = ref.read(authProvider).state.isElder;
        if (isElder && !_hasStartedElderAssessment) {
          _speakElderWelcomeIntro();
        }
      });
    });
  }

  Future<void> _speakElderWelcomeIntro({bool toggleIfSpeaking = false}) async {
    if (!mounted) return;
    if (toggleIfSpeaking && _isSpeakingWelcome) {
      TtsService.instance.stop();
      await _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isSpeakingWelcome = false;
          _isSpeaking = false;
          _isSpeakingPrompt = false;
        });
      }
      return;
    }

    final isSinhala = ref.read(languageProvider).isSinhala;
    final phrase = isSinhala
        ? 'දැන් අපි මතක පරීක්ෂාව ආරම්භ කරමු.'
        : "Now let's start the assessment";

    try {
      TtsService.instance.stop();
      await _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isSpeakingWelcome = true;
          _isSpeakingPrompt = false;
        });
      }

      if (kIsWeb) {
        await TtsService.instance.speak(phrase, isSinhala: isSinhala);
        Future.delayed(const Duration(milliseconds: 3200), () {
          if (mounted && !TtsService.instance.isSpeaking) {
            setState(() => _isSpeakingWelcome = false);
          }
        });
      } else {
        await _flutterTts.setLanguage(isSinhala ? 'si-LK' : 'en-US');
        await _flutterTts.setSpeechRate(isSinhala ? 0.42 : 0.48);
        await _flutterTts.speak(phrase);
        Future.delayed(const Duration(milliseconds: 3200), () {
          if (mounted && !_isSpeaking) {
            setState(() => _isSpeakingWelcome = false);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSpeakingWelcome = false);
      }
    }
  }

  void _handleResponseTextChanged(int qId, String rawVal, bool isSinhala) {
    String effectiveVal = rawVal;
    if (isSinhala && _isSinglishAutoEnabled) {
      final converted = SinhalaTypingHelper.convertCompletedWords(rawVal);
      if (converted != rawVal) {
        effectiveVal = converted;
        final oldOffset = _responseController.selection.baseOffset;
        final delta = converted.length - rawVal.length;
        final newOffset = (oldOffset >= 0 ? oldOffset + delta : converted.length)
            .clamp(0, converted.length);
        _responseController.value = TextEditingValue(
          text: converted,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      }
    }

    setState(() {
      final targetResponses = isSinhala ? _responsesSi : _responsesEn;
      final targetGrades = isSinhala ? _gradesSi : _gradesEn;
      targetResponses[qId] = effectiveVal;
      targetGrades[qId] = CognitiveScoring.scoreQuestion(qId, effectiveVal);
    });
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _persistResponses(forSinhala: isSinhala);
    });
  }

  void _commitActiveSinglishWord(int qId) {
    final current = _responseController.text;
    final converted = SinhalaTypingHelper.convertAllLatinWords(current);
    if (converted == current) return;
    _responseController.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
    setState(() {
      _responsesSi[qId] = converted;
      _gradesSi[qId] = CognitiveScoring.scoreQuestion(qId, converted);
    });
    _saveDebounceTimer?.cancel();
    _persistResponses(forSinhala: true);
  }

  Widget _buildSinhalaTypingControls(int qId) {
    final preview = _isSinglishAutoEnabled
        ? SinhalaTypingHelper.previewActiveWord(_responseController.text)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Singlish Auto-Convert Toggle
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(
                  () => _sinhalaSinglishAuto = !_isSinglishAutoEnabled,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isSinglishAutoEnabled
                        ? const Color(0xFFEDE9FE)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isSinglishAutoEnabled
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFFE2D9F9),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 13.5,
                        color: _isSinglishAutoEnabled
                            ? const Color(0xFF6C3FC5)
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSinglishAutoEnabled
                            ? 'සිංහල ටයිප් (Singlish): ON'
                            : 'සිංහල ටයිප් (Singlish): OFF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isSinglishAutoEnabled
                              ? const Color(0xFF5B21B6)
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // On-Screen Sinhala Virtual Keyboard Toggle
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(
                  () => _showSinhalaKeyboard = !_isSinhalaKeyboardOpen,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isSinhalaKeyboardOpen
                        ? const Color(0xFF6C3FC5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isSinhalaKeyboardOpen
                          ? const Color(0xFF6C3FC5)
                          : const Color(0xFFD8B4FE),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.keyboard,
                        size: 14,
                        color: _isSinhalaKeyboardOpen
                            ? Colors.white
                            : const Color(0xFF6C3FC5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSinhalaKeyboardOpen
                            ? 'යතුරුපුවරුව වසන්න'
                            : 'සිංහල යතුරුපුවරුව',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isSinhalaKeyboardOpen
                              ? Colors.white
                              : const Color(0xFF5B21B6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Live Singlish -> Sinhala Preview Pill (tap or press Space to convert)
            if (preview != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _commitActiveSinglishWord(qId),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF34D399),
                        width: 1.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${preview.rawWord} → ${preview.sinhala}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '(Space / ඔබන්න)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Collapsible Elder-Friendly On-Screen Sinhala Keyboard
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _isSinhalaKeyboardOpen
              ? SinhalaVirtualKeyboard(
                  controller: _responseController,
                  onTextChanged: (val) =>
                      _handleResponseTextChanged(qId, val, true),
                  onClose: () => setState(() => _showSinhalaKeyboard = false),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _beginElderAssessment() {
    TtsService.instance.stop();
    _flutterTts.stop();
    final isSinhala = ref.read(languageProvider).isSinhala;
    final targetIndex = isSinhala ? _currentIndexSi : _currentIndexEn;
    final targetResponses = isSinhala ? _responsesSi : _responsesEn;
    setState(() {
      _isSpeakingWelcome = false;
      _isSpeaking = false;
      _isSpeakingPrompt = false;
      if (isSinhala) {
        _hasStartedElderAssessmentSi = true;
      } else {
        _hasStartedElderAssessmentEn = true;
      }
      _questionStartTime = DateTime.now();
      if (targetIndex < _questions.length) {
        _responseController.text =
            targetResponses[_questions[targetIndex].id] ?? '';
      }
    });
    _ensureBackendSessionForLanguage(isSinhala);
  }

  Future<void> _ensureBackendSessionForLanguage(bool forSinhala) async {
    final existingSessionId = forSinhala ? _sessionIdSi : _sessionIdEn;
    if (existingSessionId != null) return;
    final residentId = _resident?.id ?? ref.read(authProvider).state.residentId;
    if (residentId == null) return;
    final token = ref.read(authProvider).state.token;
    try {
      final newSession = await CognitiveAssessmentService.startSession(
        residentId: residentId,
        token: token,
      );
      if (mounted) {
        setState(() {
          if (forSinhala) {
            _sessionIdSi = newSession.sessionId;
            _sessionStatusSi = 'IN_PROGRESS';
          } else {
            _sessionIdEn = newSession.sessionId;
            _sessionStatusEn = 'IN_PROGRESS';
          }
        });
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          forSinhala
              ? 'cognitive_session_id_si_$residentId'
              : 'cognitive_session_id_en_$residentId',
          newSession.sessionId,
        );
      } catch (_) {}
    } catch (_) {}
  }

  void _returnToElderWelcomeScreen() {
    TtsService.instance.stop();
    _flutterTts.stop();
    if (_isListening || _speech.isListening) {
      _activeListeningSessionId++;
      try {
        _speech.stop();
      } catch (_) {}
    }
    final isSinhala = ref.read(languageProvider).isSinhala;
    setState(() {
      _isSpeaking = false;
      _isSpeakingPrompt = false;
      _isSpeakingWelcome = false;
      _isListening = false;
      if (isSinhala) {
        _hasStartedElderAssessmentSi = false;
      } else {
        _hasStartedElderAssessmentEn = false;
      }
    });
  }

  Future<void> _loadResidentContext() async {
    final authState = ref.read(authProvider).state;
    final token = authState.token;

    // 1. ELDER Role: The elder user is strictly taking the assessment for themselves
    if (authState.isElder) {
      CognitiveResidentProfile profile;
      try {
        final residentId = authState.residentId ?? 1;
        final fetched = await CognitiveAssessmentService.fetchResident(
          residentId: residentId,
          token: token,
        );
        profile = fetched ??
            CognitiveResidentProfile(
              id: residentId,
              name: authState.userName ?? 'Sarah Jenkins',
              roomNumber: 'Room 204',
              avatarUrl: authState.avatarUrl,
            );
      } catch (_) {
        profile = CognitiveResidentProfile(
          id: authState.residentId ?? 1,
          name: authState.userName ?? 'Sarah Jenkins',
          roomNumber: 'Room 204',
          avatarUrl: authState.avatarUrl,
        );
      }
      if (mounted) {
        setState(() {
          _isLoadingResidents = false;
          _residentLoadError = null;
          _resident = profile;
          _availableResidents = [profile];
        });
        await _loadSavedResidentResponses(profile.id);
      }
      return;
    }

    // 2. CAREGIVER / DOCTOR Role: Load residents from assigned elder home
    if (mounted) {
      setState(() {
        _isLoadingResidents = true;
        _residentLoadError = null;
      });
    }

    try {
      final list = await CognitiveAssessmentService.fetchResidents(
        token: token,
      );
      if (mounted) {
        setState(() {
          _isLoadingResidents = false;
          _availableResidents = list;
          if (list.isNotEmpty) {
            // Keep selected resident if still in the list, else select first item safely
            final currentId = _resident?.id;
            if (currentId != null && list.any((r) => r.id == currentId)) {
              _resident = list.firstWhere((r) => r.id == currentId);
            } else {
              _resident = list.first;
            }
          } else {
            _resident = null;
          }
        });
        if (_resident != null) {
          await _loadSavedResidentResponses(_resident!.id);
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isLoadingResidents = false;
          _residentLoadError = 'Unable to connect to resident directory: $err';
          _availableResidents = [];
          _resident = null;
        });
      }
    }
  }

  void _selectResident(int residentId) {
    if (_resident?.id == residentId) return;
    _saveCurrentQuestionState();
    final found = _availableResidents.firstWhere(
      (r) => r.id == residentId,
      orElse: () => _availableResidents.first,
    );
    setState(() {
      _resident = found;
      _customEducationYears = null;
      _customAge = null;
      _responsesEn.clear();
      _responsesSi.clear();
      _gradesEn.clear();
      _gradesSi.clear();
      _questionTimesEn.clear();
      _questionTimesSi.clear();
      _currentIndexEn = 0;
      _currentIndexSi = 0;
      _sessionElapsedSecondsEn = 0;
      _sessionElapsedSecondsSi = 0;
      _hasStartedElderAssessmentEn = false;
      _hasStartedElderAssessmentSi = false;
      _responseController.clear();
      _isListening = false;
      _isSpeaking = false;
      _speechStatusMessage = null;
      _sessionIdEn = null;
      _sessionIdSi = null;
      _sessionStatusEn = 'IN_PROGRESS';
      _sessionStatusSi = 'IN_PROGRESS';
    });
    _loadSavedResidentResponses(residentId);
  }

  Future<void> _startNewAssessmentSession() async {
    final residentId = _resident?.id ?? ref.read(authProvider).state.residentId;
    if (residentId == null) return;
    final token = ref.read(authProvider).state.token;
    final isSinhala = ref.read(languageProvider).isSinhala;

    _saveDebounceTimer?.cancel();
    setState(() {
      if (isSinhala) {
        _gradesSi.clear();
        _responsesSi.clear();
        _questionTimesSi.clear();
        _currentIndexSi = 0;
        _sessionElapsedSecondsSi = 0;
        _sessionIdSi = null;
        _sessionStatusSi = 'IN_PROGRESS';
      } else {
        _gradesEn.clear();
        _responsesEn.clear();
        _questionTimesEn.clear();
        _currentIndexEn = 0;
        _sessionElapsedSecondsEn = 0;
        _sessionIdEn = null;
        _sessionStatusEn = 'IN_PROGRESS';
      }
      _questionStartTime = DateTime.now();
      _responseController.clear();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(
        isSinhala ? 'cognitive_responses_si_$residentId' : 'cognitive_responses_en_$residentId',
      );
      await prefs.remove(
        isSinhala ? 'cognitive_session_id_si_$residentId' : 'cognitive_session_id_en_$residentId',
      );
      await prefs.remove('cognitive_responses_$residentId');
    } catch (_) {}

    try {
      final session = await CognitiveAssessmentService.startSession(
        residentId: residentId,
        token: token,
      );
      if (mounted) {
        setState(() {
          if (isSinhala) {
            _sessionIdSi = session.sessionId;
            _sessionStatusSi = 'IN_PROGRESS';
          } else {
            _sessionIdEn = session.sessionId;
            _sessionStatusEn = 'IN_PROGRESS';
          }
        });
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          isSinhala
              ? 'cognitive_session_id_si_$residentId'
              : 'cognitive_session_id_en_$residentId',
          session.sessionId,
        );
      } catch (_) {}
    } catch (_) {}
  }

  static final RegExp _sinhalaCharRegex = RegExp(r'[\u0D80-\u0DFF]');

  Future<void> _loadSavedResidentResponses(int residentId) async {
    final token = ref.read(authProvider).state.token;
    final isElder = ref.read(authProvider).state.isElder;

    // 1. Load language-separated responses & session IDs from SharedPreferences first
    bool hasLocalEnPrefs = false;
    bool hasLocalSiPrefs = false;
    String? savedEnSessionId;
    String? savedSiSessionId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEnJson = prefs.getString('cognitive_responses_en_$residentId');
      final savedSiJson = prefs.getString('cognitive_responses_si_$residentId');
      savedEnSessionId = prefs.getString('cognitive_session_id_en_$residentId');
      savedSiSessionId = prefs.getString('cognitive_session_id_si_$residentId');

      if (savedEnJson != null && savedEnJson.isNotEmpty) {
        hasLocalEnPrefs = true;
        final decoded = json.decode(savedEnJson) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          final qId = int.tryParse(key);
          if (qId != null && val is String && val.trim().isNotEmpty) {
            if (!_sinhalaCharRegex.hasMatch(val)) {
              _responsesEn[qId] = val;
              _gradesEn[qId] = CognitiveScoring.scoreQuestion(qId, val);
            }
          }
        });
      }

      if (savedSiJson != null && savedSiJson.isNotEmpty) {
        hasLocalSiPrefs = true;
        final decoded = json.decode(savedSiJson) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          final qId = int.tryParse(key);
          if (qId != null && val is String && val.trim().isNotEmpty) {
            if (!RegExp(r'[a-zA-Z]').hasMatch(val) || _sinhalaCharRegex.hasMatch(val)) {
              _responsesSi[qId] = val;
              _gradesSi[qId] = CognitiveScoring.scoreQuestion(qId, val);
            }
          }
        });
      }
    } catch (_) {}

    // 2. Retrieve active/pending session from the backend and bind it strictly
    //    to its own language so Sinhala answers/sessions never leak into English (or vice versa).
    try {
      final pendingSession = await CognitiveAssessmentService.getPendingSession(
        residentId: residentId,
        token: token,
      );
      if (pendingSession != null && mounted) {
        final bool matchedSiSession = savedSiSessionId != null &&
            savedSiSessionId == pendingSession.sessionId;
        final bool matchedEnSession = savedEnSessionId != null &&
            savedEnSessionId == pendingSession.sessionId;
        final bool sessionHasSinhala = pendingSession.responses.values
            .any((v) => _sinhalaCharRegex.hasMatch(v));
        final bool sessionHasEnglishLetters = pendingSession.responses.values
            .any((v) => RegExp(r'[a-zA-Z]').hasMatch(v));

        bool? targetSinhala;
        if (matchedSiSession) {
          targetSinhala = true;
        } else if (matchedEnSession) {
          targetSinhala = false;
        } else if (sessionHasSinhala) {
          targetSinhala = true;
        } else if (sessionHasEnglishLetters) {
          targetSinhala = false;
        } else if (pendingSession.responses.isNotEmpty) {
          targetSinhala = ref.read(languageProvider).isSinhala;
        }

        setState(() {
          if (targetSinhala == true) {
            _sessionIdSi = pendingSession.sessionId;
            _sessionStatusSi = pendingSession.status;
            if (!hasLocalSiPrefs && pendingSession.responses.isNotEmpty) {
              for (final entry in pendingSession.responses.entries) {
                final qId = entry.key;
                final val = entry.value;
                if (val.trim().isEmpty) continue;
                _responsesSi[qId] = val;
                _gradesSi[qId] = CognitiveScoring.scoreQuestion(qId, val);
              }
            }
            if (pendingSession.questionTimes.isNotEmpty) {
              _questionTimesSi.addAll(pendingSession.questionTimes);
            }
          } else if (targetSinhala == false) {
            _sessionIdEn = pendingSession.sessionId;
            _sessionStatusEn = pendingSession.status;
            if (!hasLocalEnPrefs && pendingSession.responses.isNotEmpty) {
              for (final entry in pendingSession.responses.entries) {
                final qId = entry.key;
                final val = entry.value;
                if (val.trim().isEmpty) continue;
                _responsesEn[qId] = val;
                _gradesEn[qId] = CognitiveScoring.scoreQuestion(qId, val);
              }
            }
            if (pendingSession.questionTimes.isNotEmpty) {
              _questionTimesEn.addAll(pendingSession.questionTimes);
            }
          }
          _responseController.text =
              _responses[_questions[_currentIndex].id] ?? '';
        });
        return;
      }
    } catch (_) {}

    // 3. For caregivers only, start a backend session for the active language if none exists.
    //    For elders, wait until they explicitly tap "Start Assessment" for that language.
    if (!isElder && _sessionId == null) {
      await _ensureBackendSessionForLanguage(ref.read(languageProvider).isSinhala);
    }

    if (mounted) {
      setState(() {
        _responseController.text =
            _responses[_questions[_currentIndex].id] ?? '';
      });
    }
  }

  Future<void> _persistResponses({bool? forSinhala}) async {
    final rId = _resident?.id ?? ref.read(authProvider).state.residentId;
    if (rId == null) return;

    final token = ref.read(authProvider).state.token;
    final bool targetSinhala = forSinhala ?? ref.read(languageProvider).isSinhala;
    final String? targetSessionId = targetSinhala ? _sessionIdSi : _sessionIdEn;
    final Map<int, String> targetResponses =
        targetSinhala ? _responsesSi : _responsesEn;
    final Map<int, double> targetQuestionTimes =
        targetSinhala ? _questionTimesSi : _questionTimesEn;

    // Save strictly the target language's responses to its own backend session
    if (targetSessionId != null) {
      try {
        await CognitiveAssessmentService.saveResponses(
          sessionId: targetSessionId,
          responses: targetResponses,
          questionTimes: targetQuestionTimes,
          token: token,
        );
      } catch (_) {}
    }

    // Save strictly the target language's responses in its own SharedPreferences key
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapTarget = {
        for (final e in targetResponses.entries) e.key.toString(): e.value,
      };
      await prefs.setString(
        targetSinhala
            ? 'cognitive_responses_si_$rId'
            : 'cognitive_responses_en_$rId',
        json.encode(mapTarget),
      );
      if (targetSessionId != null) {
        await prefs.setString(
          targetSinhala
              ? 'cognitive_session_id_si_$rId'
              : 'cognitive_session_id_en_$rId',
          targetSessionId,
        );
      }
      await prefs.remove('cognitive_responses_$rId');
    } catch (_) {}
  }

  void _recordCurrentQuestionDuration() {
    final now = DateTime.now();
    final elapsedSec =
        (now.difference(_questionStartTime).inMilliseconds / 1000.0);
    final qId = _questions[_currentIndex].id;
    _questionTimes[qId] =
        (_questionTimes[qId] ?? 0.0) + (elapsedSec < 0.2 ? 0.2 : elapsedSec);
    _questionStartTime = DateTime.now();
  }

  void _saveCurrentQuestionState() {
    _saveDebounceTimer?.cancel();
    _activeListeningSessionId++;
    _recordCurrentQuestionDuration();
    if (_isSpeaking) {
      TtsService.instance.stop();
      _flutterTts.stop();
    }
    if (_isListening || _speech.isListening) {
      if (kIsWeb) {
        try {
          _speech.cancel();
        } catch (_) {}
      } else {
        _speech.stop();
      }
      _isListening = false;
    }
    final qId = _questions[_currentIndex].id;
    final text = _responseController.text;
    _responses[qId] = text;
    if (text.trim().isNotEmpty) {
      final isElder = ref.read(authProvider).state.isElder;
      final computed = CognitiveScoring.scoreQuestion(qId, text);
      if (isElder || _grades[qId] == null || (_grades[qId] == 0.0 && (computed ?? 0.0) > 0.0)) {
        _grades[qId] = computed;
      }
    }
    _persistResponses();
    if (text.trim().isNotEmpty) {
      _triggerSaveAnimation();
    }
  }

  Future<void> _toggleTts(String text) async {
    if (_isListening || _speech.isListening) {
      _activeListeningSessionId++;
      debugPrint('[CARE-STT] [6. Stop/Cancel Reason] Stopped microphone because TTS audio playback started.');
      await _speech.stop();
      if (mounted) {
        final isSinhala = ref.read(languageProvider).isSinhala;
        setState(() {
          _isListening = false;
          final text = _responseController.text.trim();
          if (text.isNotEmpty && _currentIndex < _questions.length) {
            final qId = _questions[_currentIndex].id;
            _responses[qId] = text;
            _grades[qId] = CognitiveScoring.scoreQuestion(qId, text);
            _speechStatusMessage = isSinhala
                ? 'හඬ පිළිතුර සටහන් විය.'
                : 'Voice response captured.';
            _persistResponses();
            _triggerSaveAnimation();
          }
        });
      }
    }
    if (_isSpeaking) {
      TtsService.instance.stop();
      await _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isSpeakingPrompt = false;
        });
      }
    } else {
      final isSinhala = ref.read(languageProvider).isSinhala;
      _isSpeakingPrompt = true;
      if (mounted) setState(() => _isSpeaking = true);
      if (kIsWeb) {
        await TtsService.instance.speak(text, isSinhala: isSinhala);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !TtsService.instance.isSpeaking) {
            setState(() {
              _isSpeaking = false;
              _isSpeakingPrompt = false;
            });
          }
        });
      } else {
        await _flutterTts.setLanguage(isSinhala ? 'si-LK' : 'en-US');
        await _flutterTts.setSpeechRate(isSinhala ? 0.42 : 0.48);
        await _flutterTts.speak(text);
      }
    }
  }

  Future<void> _speakNextQuestion() async {
    try {
      if (_isListening || _speech.isListening) {
        _activeListeningSessionId++;
        try {
          await _speech.stop();
        } catch (_) {}
        _isListening = false;
      }
      _isSpeakingPrompt = false;

      TtsService.instance.stop();
      await _flutterTts.stop();

      if (!mounted) return;
      final isSinhala = ref.read(languageProvider).isSinhala;
      final phrase = isSinhala ? 'ඊළඟ ප්‍රශ්නය' : 'Next question';

      if (kIsWeb) {
        await TtsService.instance.speak(phrase, isSinhala: isSinhala);
      } else {
        await _flutterTts.setLanguage(isSinhala ? 'si-LK' : 'en-US');
        await _flutterTts.setSpeechRate(isSinhala ? 0.44 : 0.50);
        await _flutterTts.speak(phrase);
      }
    } catch (e) {
      debugPrint('[CARE-TTS] Failed to speak on next question: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (_isTogglingMic) return;
    _isTogglingMic = true;

    try {
      final isSinhala = ref.read(languageProvider).isSinhala;
      final sttLocale = isSinhala
          ? (kIsWeb ? 'si-LK' : 'si_LK')
          : (kIsWeb ? 'en-US' : 'en_US');
      final qId = _currentIndex < _questions.length ? _questions[_currentIndex].id : -1;
      debugPrint(
        '[CARE-STT] [1. Mic Pressed] qId=$qId, locale=$sttLocale, isListening=$_isListening, '
        'speechListening=${_speech.isListening}, isSpeaking=$_isSpeaking, '
        'speechAvailable=$_speechAvailable, speechInitialized=$_speechInitialized, '
        'currentBuffer="${_responseController.text}"',
      );

      // 1. Promptly stop any active TTS output so audio playback does not conflict with microphone capture
      if (_isSpeaking) {
        TtsService.instance.stop();
        await _flutterTts.stop();
        if (mounted) setState(() => _isSpeaking = false);
      }

      if (_isListening || _speech.isListening) {
        _activeListeningSessionId++;
        _listeningQId = -1;
        debugPrint(
          '[CARE-STT] [6. Stop/Cancel Reason] User tapped to stop listening. '
          'qId=$qId, finalBuffer="${_responseController.text}"',
        );
        await _speech.stop();
        if (mounted) {
          setState(() {
            _isListening = false;
            final text = _responseController.text.trim();
            if (text.isNotEmpty) {
              _responses[qId] = text;
              _grades[qId] = CognitiveScoring.scoreQuestion(qId, text);
              _speechStatusMessage = isSinhala
                  ? 'හඬ පිළිතුර සටහන් විය.'
                  : 'Voice response captured.';
              _persistResponses();
              _triggerSaveAnimation();
            } else {
              _speechStatusMessage = isSinhala
                  ? 'හඬ හඳුනාගත නොහැකි විය. කරුණාකර නැවත උත්සාහ කරන්න හෝ පිළිතුර ටයිප් කරන්න.'
                  : 'Speech not recognized. Please tap the microphone to retry or type your answer.';
            }
          });
        }
        return;
      }

      if (!_speechInitialized) {
        await _initSpeech();
      }
      if (!_speechAvailable) {
        debugPrint('[CARE-STT] [3. Listen Failed] Speech not available. Cannot start listening.');
        setState(() {
          _speechStatusMessage = isSinhala
              ? 'මයික්‍රොෆෝනය භාවිතා කළ නොහැක. කරුණාකර පහතින් ඔබේ පිළිතුර ටයිප් කරන්න.'
              : 'Microphone not available. Please enter the answer manually below or apply caregiver clinical scoring.';
        });
        return;
      }

      // Pre-listen reset: If web and previous session still linger, cancel cleanly
      if (kIsWeb && _speech.isListening) {
        try {
          await _speech.cancel();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (_) {}
      }

      _listeningQId = qId;
      _listeningWasSinhala = isSinhala;
      setState(() {
        _isListening = true;
        _speechStatusMessage = isSinhala
            ? 'සවන් දෙමින්... දැන් කතා කරන්න.'
            : 'Listening... Speak now.';
      });

      final currentSessionId = ++_activeListeningSessionId;
      final targetQId = qId;
      final targetResponses = isSinhala ? _responsesSi : _responsesEn;
      final targetGrades = isSinhala ? _gradesSi : _gradesEn;

      try {
        debugPrint(
          '[CARE-STT] [3. Listen Start Attempt] Calling _speech.listen for qId=$targetQId (session $currentSessionId), '
          'locale=$sttLocale, currentText="${_responseController.text}"',
        );
        await _speech.listen(
          onResult: (result) {
            final incoming = result.recognizedWords;
            final incomingTrimmed = incoming.trim();
            final prevText = _responseController.text.trim();

            debugPrint(
              '[CARE-STT] [4. onResult] qId=$targetQId, recognizedWords="$incoming", '
              'finalResult=${result.finalResult}, confidence=${result.confidence.toStringAsFixed(2)}',
            );

            // Never wipe valid recognized text with an empty callback
            if (incomingTrimmed.isEmpty && prevText.isNotEmpty) {
              debugPrint('[CARE-STT] Preserving existing non-empty text, ignoring empty callback.');
              return;
            }

            if (currentSessionId != _activeListeningSessionId ||
                ref.read(languageProvider).isSinhala != isSinhala ||
                _currentIndex >= _questions.length ||
                _questions[_currentIndex].id != targetQId) {
              debugPrint(
                '[CARE-STT] Late callback saved for targetQ=$targetQId while current=${_currentIndex < _questions.length ? _questions[_currentIndex].id : -1}',
              );
              if (incomingTrimmed.isNotEmpty) {
                targetResponses[targetQId] = incoming;
                targetGrades[targetQId] =
                    CognitiveScoring.scoreQuestion(targetQId, incoming);
                _persistResponses(forSinhala: isSinhala);
              }
              return;
            }

            if (mounted) {
              setState(() {
                if (incomingTrimmed.isNotEmpty) {
                  _responseController.text = incoming;
                  _responseController.selection = TextSelection.collapsed(
                    offset: incoming.length,
                  );
                  targetResponses[targetQId] = incoming;
                  targetGrades[targetQId] =
                      CognitiveScoring.scoreQuestion(targetQId, incoming);
                }
              });
              // NOTE: We do not invoke _persistResponses() on partial callbacks.
              // Persistence is handled when the session ends naturally or is stopped.
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            listenFor: const Duration(seconds: 45),
            pauseFor: kIsWeb ? null : const Duration(seconds: 5),
            cancelOnError: false,
            partialResults: true,
            localeId: sttLocale,
          ),
        );
        debugPrint('[CARE-STT] [3. Listen Started] Session active: speechListening=${_speech.isListening}');
      } catch (err) {
        debugPrint('[CARE-STT] [3. Listen Failed] Exception while starting listen: $err');
        final errStr = err.toString();
        if (errStr.contains('already started') || errStr.contains('InvalidStateError')) {
          debugPrint('[CARE-STT] Recognition already started. Aborting and re-initializing fresh engine...');
          try {
            await _speech.cancel();
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 200));

          try {
            await _initSpeech();
            if (mounted &&
                ref.read(languageProvider).isSinhala == isSinhala &&
                _currentIndex < _questions.length &&
                _questions[_currentIndex].id == targetQId) {
              _listeningQId = targetQId;
              _listeningWasSinhala = isSinhala;
              final retrySessionId = ++_activeListeningSessionId;
              await _speech.listen(
                onResult: (result) {
                  final incoming = result.recognizedWords;
                  final incomingTrimmed = incoming.trim();
                  final prevText = _responseController.text.trim();

                  if (incomingTrimmed.isEmpty && prevText.isNotEmpty) {
                    return;
                  }

                  if (retrySessionId != _activeListeningSessionId ||
                      ref.read(languageProvider).isSinhala != isSinhala ||
                      _currentIndex >= _questions.length ||
                      _questions[_currentIndex].id != targetQId) {
                    if (incomingTrimmed.isNotEmpty) {
                      targetResponses[targetQId] = incoming;
                      targetGrades[targetQId] =
                          CognitiveScoring.scoreQuestion(targetQId, incoming);
                      _persistResponses(forSinhala: isSinhala);
                    }
                    return;
                  }

                  if (mounted) {
                    setState(() {
                      if (incomingTrimmed.isNotEmpty) {
                        _responseController.text = incoming;
                        _responseController.selection = TextSelection.collapsed(
                          offset: incoming.length,
                        );
                        targetResponses[targetQId] = incoming;
                        targetGrades[targetQId] =
                            CognitiveScoring.scoreQuestion(targetQId, incoming);
                      }
                    });
                  }
                },
                listenOptions: stt.SpeechListenOptions(
                  listenMode: stt.ListenMode.dictation,
                  listenFor: const Duration(seconds: 45),
                  pauseFor: kIsWeb ? null : const Duration(seconds: 5),
                  cancelOnError: false,
                  partialResults: true,
                  localeId: sttLocale,
                ),
              );
              debugPrint('[CARE-STT] Retry listen active on fresh engine!');
              return;
            }
          } catch (retryErr) {
            debugPrint('[CARE-STT] Fresh engine retry listen failed: $retryErr');
          }
        }

        if (mounted) {
          setState(() {
            _isListening = false;
            if (errStr.contains('not-allowed') || errStr.contains('permission')) {
              _speechStatusMessage = isSinhala
                  ? 'මයික්‍රොෆෝන අවසරය ලබා දී නොමැත. කරුණාකර අවසර ලබා දෙන්න හෝ පිළිතුර ටයිප් කරන්න.'
                  : 'Microphone permission denied. Please allow microphone access in Chrome or type your answer.';
            } else {
              _speechStatusMessage = isSinhala
                  ? 'කතා කිරීමට නැවත මයික්‍රොෆෝනය ඔබන්න.'
                  : 'Please tap the microphone again to speak.';
            }
          });
        }
      }
    } finally {
      _isTogglingMic = false;
    }
  }

  // Caregiver Clinical Scoring: Updates immediately without double-counting
  void _setGrade(double score) {
    final qId = _questions[_currentIndex].id;
    setState(() {
      _grades[qId] = score;
    });
  }

  void _goToQuestion(int index) {
    if (index == _currentIndex) return;
    _saveCurrentQuestionState();
    setState(() {
      _transitionDirection = index > _currentIndex ? 1 : -1;
      _currentIndex = index;
      _responseController.text = _responses[_questions[index].id] ?? '';
      _isListening = false;
      _isSpeaking = false;
      _speechStatusMessage = null;
    });
  }

  void _nextQuestion(bool isElder) {
    _saveCurrentQuestionState();

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _transitionDirection = 1;
        _currentIndex++;
        _responseController.text =
            _responses[_questions[_currentIndex].id] ?? '';
        _isListening = false;
        _isSpeaking = false;
        _speechStatusMessage = null;
      });
      _speakNextQuestion();
    } else {
      _showFinishConfirmationDialog(isElder);
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      _saveCurrentQuestionState();
      setState(() {
        _transitionDirection = -1;
        _currentIndex--;
        _responseController.text =
            _responses[_questions[_currentIndex].id] ?? '';
        _isListening = false;
        _isSpeaking = false;
        _speechStatusMessage = null;
      });
    }
  }

  String _formatElapsed(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m}m ${s < 10 ? '0' : ''}${s}s';
  }

  // --- Strict Session Metrics & Role-Specific Calculations ---
  bool _isAnswered(int qId) => _responses[qId]?.trim().isNotEmpty == true;
  bool _isGraded(int qId) =>
      _grades[qId] != null ||
      (_isAnswered(qId) && CognitiveScoring.scoreQuestion(qId, _responses[qId]) != null);
  bool _isFullyCompleted(int qId) => _isAnswered(qId);

  int get _totalCount => _questions.length; // 10
  int get _answeredCount => _questions.where((q) => _isAnswered(q.id)).length;
  int get _gradedCount => _questions.where((q) => _isGraded(q.id)).length;
  int get _fullyCompletedCount =>
      _questions.where((q) => _isFullyCompleted(q.id)).length;
  int get _remainingToCompleteCount => _totalCount - _fullyCompletedCount;
  int get _remainingToAnswerCount => _totalCount - _answeredCount;

  /// Role-appropriate progress percentage:
  /// - ELDER: progress measures questions answered by resident: (answered / 10) * 100
  /// - CAREGIVER: progress measures questions fully assessed: (fully completed / 10) * 100
  int _getProgressPct(bool isElder) {
    if (_totalCount == 0) return 0;
    final count = isElder ? _answeredCount : _fullyCompletedCount;
    final pct = (count / _totalCount) * 100.0;
    return pct.clamp(0.0, 100.0).round();
  }

  Future<void> _submitCaregiverAssessment() async {
    _saveCurrentQuestionState();
    final authState = ref.read(authProvider).state;
    final isElder = authState.isElder;
    final bool submitIsSinhala = ref.read(languageProvider).isSinhala;
    final Map<int, String> submitResponses =
        submitIsSinhala ? _responsesSi : _responsesEn;
    final Map<int, double?> submitGrades =
        submitIsSinhala ? _gradesSi : _gradesEn;
    final Map<int, double> submitQuestionTimes =
        submitIsSinhala ? _questionTimesSi : _questionTimesEn;

    // Auto-grade all answered questions using question-specific deterministic rubric
    final autoGrades = CognitiveScoring.autoScoreBattery(submitResponses);
    for (final e in autoGrades.entries) {
      if (e.value != null &&
          (isElder ||
              submitGrades[e.key] == null ||
              (submitGrades[e.key] == 0.0 && e.value! > 0.0))) {
        submitGrades[e.key] = e.value;
      }
    }

    final unanswered = CognitiveScoring.getUnansweredQuestionIds(submitResponses);
    if (unanswered.isNotEmpty) {
      setState(() {
        _isSubmitting = false;
        _submitError =
            'Cannot submit: Question(s) ${unanswered.join(', ')} are unanswered. All 10 questions must have responses before automatic evaluation.';
      });
      return;
    }

    final token = authState.token;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final accuracies = CognitiveScoring.calculateDomainAccuracies(submitGrades);
      final taskScores = CognitiveScoring.calculateDomainScores(accuracies);
      final responseTimes = CognitiveScoring.aggregateDomainResponseTimes(
        submitQuestionTimes,
      );

      final residentId = _resident?.id ??
          authState.residentId ??
          (_availableResidents.isNotEmpty ? _availableResidents.first.id : null);
      if (residentId == null) {
        setState(() {
          _isSubmitting = false;
          _submitError = 'No eligible resident selected for assessment.';
        });
        return;
      }

      String? activeSessionId = submitIsSinhala ? _sessionIdSi : _sessionIdEn;
      if (activeSessionId == null) {
        final session = await CognitiveAssessmentService.startSession(
          residentId: residentId,
          token: token,
        );
        activeSessionId = session.sessionId;
        if (submitIsSinhala) {
          _sessionIdSi = activeSessionId;
        } else {
          _sessionIdEn = activeSessionId;
        }
      }

      if (activeSessionId != null) {
        try {
          await CognitiveAssessmentService.saveResponses(
            sessionId: activeSessionId,
            responses: submitResponses,
            questionTimes: submitQuestionTimes,
            status: 'IN_PROGRESS',
            token: token,
          );
        } catch (_) {}
      }

      final effectiveAge = _customAge ?? _resident?.age;
      final effectiveEducationYears =
          _customEducationYears ?? _resident?.educationYears;

      final payload = CognitiveSubmissionPayload(
        residentId: residentId,
        memory: taskScores['memory'] ?? 0.0,
        attention: taskScores['attention'] ?? 0.0,
        orientation: taskScores['orientation'] ?? 0.0,
        recall: taskScores['recall'] ?? 0.0,
        reasoning: taskScores['reasoning'] ?? 0.0,
        age: effectiveAge,
        educationYears: effectiveEducationYears,
        accuracies: accuracies,
        responseTimes: responseTimes,
        sessionId: activeSessionId,
        responses: submitResponses,
        grades: {
          for (final e in submitGrades.entries)
            if (e.value != null) e.key: e.value!,
        },
      );

      final result = await CognitiveAssessmentService.submitAssessment(
        payload: payload,
        token: token,
      );

      final bool isHighRisk =
          (result.riskLevel?.toLowerCase().contains('high') ?? false) ||
          (result.mlPrediction?.toLowerCase().contains('high') ?? false) ||
          (result.alertTriggered == true) ||
          (result.acrfScore != null && result.acrfScore! < 50.0);

      final residentName = (result.residentName.isNotEmpty
          ? result.residentName
          : (_resident?.name ?? 'Resident')).trim();

      // Clear any prior cognitive alert for this resident so alerts reflect latest assessment
      MockCarevoraData.alerts.removeWhere((a) =>
          a.id.startsWith('ALT-COG') &&
          (a.residentName?.trim().toLowerCase() == residentName.toLowerCase() ||
           a.residentName?.trim().toLowerCase() == _resident?.name.trim().toLowerCase()));

      if (isHighRisk) {
        final alertId = 'ALT-COG-REAL-${_resident?.id ?? 0}-${result.id}';
        final scoreText = result.acrfScore != null
            ? '${result.acrfScore!.toStringAsFixed(1)}/100'
            : 'High Risk';
        final roomNumber = (_resident?.roomNumber != null && _resident!.roomNumber.isNotEmpty)
            ? _resident!.roomNumber
            : '105';

        // 1. Dispatch alert notification to facility alerts for caregivers
        MockCarevoraData.alerts.insert(
          0,
          AlertItem(
            id: alertId,
            title: 'High Cognitive Impairment Risk: $residentName',
            description:
                'Cognitive assessment score ($scoreText) indicates acute cognitive decline risk for $residentName in room $roomNumber. Urgent caregiver review and clinical attention required.',
            severity: 'High',
            timestamp: 'Just now',
            residentName: residentName,
            roomNo: roomNumber,
            residentAge: _resident?.age ?? effectiveAge,
            residentGender: _resident?.gender ?? 'Resident',
            currentStatus: 'High Cognitive Risk',
            cognitiveScore: result.acrfScore,
          ),
        );

        // 2. Display immediate in-app notification to caregiver (staff only, not elder)
        final isElderUser = ref.read(authProvider).state.isElder;
        if (mounted && !isElderUser) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🚨 High Cognitive Risk Alert: Clinical notification sent to caregiver for $residentName.',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View Alerts',
                textColor: Colors.white,
                onPressed: () => context.go('/dashboard/alerts'),
              ),
            ),
          );
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cognitive_responses_$residentId');
        await prefs.remove(
          submitIsSinhala
              ? 'cognitive_responses_si_$residentId'
              : 'cognitive_responses_en_$residentId',
        );
        await prefs.remove(
          submitIsSinhala
              ? 'cognitive_session_id_si_$residentId'
              : 'cognitive_session_id_en_$residentId',
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          if (submitIsSinhala) {
            _sessionStatusSi = result.status;
            _sessionIdSi = null;
          } else {
            _sessionStatusEn = result.status;
            _sessionIdEn = null;
          }
          if (_resident != null &&
              (effectiveEducationYears != _resident!.educationYears ||
                  effectiveAge != _resident!.age)) {
            _resident = CognitiveResidentProfile(
              id: _resident!.id,
              name: _resident!.name,
              age: effectiveAge,
              educationYears: effectiveEducationYears,
              roomNumber: _resident!.roomNumber,
              gender: _resident!.gender,
              currentStatus: _resident!.currentStatus,
              riskLevel: _resident!.riskLevel,
            );
          }
        });
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss confirm
        _showResultDialog(result);
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = err.toString();
        });
      }
    }
  }

  Future<void> _submitElderResponses() => _submitCaregiverAssessment();

  AppLanguage? _lastSpokenLanguage;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final bool isElder = authState.isElder;
    final langNotifier = ref.watch(languageProvider);
    final bool isSinhala = langNotifier.isSinhala;
    final bool hasStartedForLang = isSinhala
        ? _hasStartedElderAssessmentSi
        : _hasStartedElderAssessmentEn;
    final int currentIndexForLang = isSinhala ? _currentIndexSi : _currentIndexEn;
    final currentQ = _questions[currentIndexForLang];

    if (_lastSpokenLanguage != null &&
        _lastSpokenLanguage != langNotifier.currentLanguage) {
      _saveDebounceTimer?.cancel();
      final prevWasSinhala = _lastSpokenLanguage == AppLanguage.sinhala;
      final prevHasStarted = prevWasSinhala
          ? _hasStartedElderAssessmentSi
          : _hasStartedElderAssessmentEn;
      final prevIndex = prevWasSinhala ? _currentIndexSi : _currentIndexEn;
      final prevQ = _questions[prevIndex];
      final prevResponses = prevWasSinhala ? _responsesSi : _responsesEn;
      final prevGrades = prevWasSinhala ? _gradesSi : _gradesEn;
      final prevText = _responseController.text;
      if (!isElder || prevHasStarted) {
        if (prevText.trim().isNotEmpty || prevResponses.containsKey(prevQ.id)) {
          prevResponses[prevQ.id] = prevText;
          if (prevText.trim().isNotEmpty) {
            prevGrades[prevQ.id] =
                CognitiveScoring.scoreQuestion(prevQ.id, prevText);
          }
        }
      }
      _lastSpokenLanguage = langNotifier.currentLanguage;
      _questionStartTime = DateTime.now();
      final nextResponses = isSinhala ? _responsesSi : _responsesEn;
      _responseController.text = nextResponses[currentQ.id] ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          TtsService.instance.stop();
          _flutterTts.stop();
          if (_isListening || _speech.isListening) {
            _activeListeningSessionId++;
            _listeningQId = -1;
            try {
              _speech.stop();
            } catch (_) {}
          }
          setState(() {
            _isSpeaking = false;
            _isSpeakingPrompt = false;
            _isSpeakingWelcome = false;
            _isListening = false;
            _speechStatusMessage = null;
          });
          if (isElder && !hasStartedForLang) {
            Future.delayed(const Duration(milliseconds: 220), () {
              if (mounted &&
                  ref.read(languageProvider).isSinhala == isSinhala &&
                  !_hasStartedElderAssessment) {
                _speakElderWelcomeIntro();
              }
            });
          }
        }
      });
    } else {
      _lastSpokenLanguage ??= langNotifier.currentLanguage;
    }

    final currentGrade =
        (isSinhala ? _gradesSi : _gradesEn)[currentQ.id];
    final progressPct = _getProgressPct(isElder);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FF),
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Subtle, calm therapeutic animated background suitable for elderly users
            Positioned.fill(
              child: _buildSubtleTherapeuticBackground(),
            ),

            // Animated swaying floral garden along the bottom of the screen for Elder view
            if (isElder)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildAnimatedBottomFlowerGarden(),
              ),

            // Main scrollable workspace
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isElder ? 20 : 24,
                isElder ? 12 : 20,
                isElder ? 20 : 24,
                isElder ? 85 : 20,
              ),
              child: isElder
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.97, end: 1.0)
                                .animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: !hasStartedForLang
                          ? KeyedSubtree(
                              key: ValueKey('elder_welcome_start_screen_$isSinhala'),
                              child: _buildElderWelcomeStartScreen(isSinhala),
                            )
                          : KeyedSubtree(
                              key: ValueKey('elder_active_assessment_$isSinhala'),
                              child: _buildElderMinimalistView(
                                currentQ,
                                progressPct,
                                isSinhala,
                              ),
                            ),
                    )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Navigation Bar & Timer (Responsive Wrap)
                      _buildTopNavBar(),
                      const SizedBox(height: 16),

                      if (_isLoadingResidents) ...[
                        _buildLoadingResidentsState(),
                      ] else if (_residentLoadError != null) ...[
                        _buildResidentErrorState(_residentLoadError!),
                      ] else if (_availableResidents.isEmpty) ...[
                        _buildEmptyResidentsState(),
                      ] else ...[
                        // Resident Context Banner
                        _buildResidentBanner(isElder),
                        const SizedBox(height: 20),

                        // Main 2-Column Responsive Assessment Workspace
                        ResponsiveBuilder(
                          mobile: (context) => Column(
                            children: [
                              _buildMainQuestionWorkspace(
                                currentQ,
                                progressPct,
                                currentGrade,
                                isElder,
                              ),
                              const SizedBox(height: 20),
                              _buildRightPanel(progressPct, isElder, currentQ),
                            ],
                          ),
                          desktop: (context) => Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: _buildMainQuestionWorkspace(
                                  currentQ,
                                  progressPct,
                                  currentGrade,
                                  isElder,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 3,
                                child: _buildRightPanel(progressPct, isElder, currentQ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBottomFlowerGarden() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatingController, _ambientBgController]),
        builder: (context, _) {
          final sway = _floatingController.value; // 0.0 -> 1.0 -> 0.0 (3.2s cycle)
          final breeze = _ambientBgAnimation.value; // slow 14s drift

          return SizedBox(
            height: 115,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Custom-painted swaying meadow of flowers, stems, leaves & floating petals
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SwayingFloralMeadowPainter(
                      swayValue: sway,
                      breezeValue: breeze,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildElderWelcomeStartScreen(bool isSinhala) {
    final authState = ref.watch(authProvider).state;
    final res = _resident;
    final rawName =
        (res != null && res.name.trim().isNotEmpty && res.name.trim() != '-')
            ? res.name.trim()
            : (authState.userName?.trim().isNotEmpty == true
                ? authState.userName!.trim()
                : 'Malini Bandara');
    final displayName = isSinhala ? _toSinhalaName(rawName) : rawName;
    final initials = _getInitials(rawName);
    final avatarUrl =
        (res?.avatarUrl != null && res!.avatarUrl!.trim().isNotEmpty)
            ? res.avatarUrl
            : authState.avatarUrl;
    final Map<int, String> langResponses =
        isSinhala ? _responsesSi : _responsesEn;
    final bool hasSavedProgress = _questions
        .any((q) => langResponses[q.id]?.trim().isNotEmpty == true);
    final String voicePhrase = isSinhala
        ? 'දැන් අපි මතක පරීක්ෂාව ආරම්භ කරමු'
        : "Now let's start the assessment";

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFCF9FF),
                  Color(0xFFF5EEFF),
                  Color(0xFFEDE4FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFD8B4FE).withValues(alpha: 0.72),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3FC5).withValues(alpha: 0.13),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Symmetrical soft ambient glowing orbs (top-left & top-right)
                  Positioned(
                    top: -85,
                    right: -65,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _ambientPulseAnimation,
                        builder: (context, _) {
                          final s = _ambientPulseAnimation.value;
                          return Container(
                            width: 220 * s,
                            height: 220 * s,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFC4B5FD).withValues(alpha: 0.34),
                                  const Color(0xFFC4B5FD).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: -85,
                    left: -65,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _ambientPulseAnimation,
                        builder: (context, _) {
                          final s = _ambientPulseAnimation.value;
                          return Container(
                            width: 220 * s,
                            height: 220 * s,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFFBCFE8).withValues(alpha: 0.32),
                                  const Color(0xFFFBCFE8).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Top multi-color wellness ribbon
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF6C3FC5),
                            Color(0xFF8B5CF6),
                            Color(0xFFEC4899),
                            Color(0xFF0D9488),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Main symmetrically centered content
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Soft pill badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFFDDD6FE),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C3FC5)
                                      .withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.sparkles,
                                  size: 14,
                                  color: Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isSinhala
                                      ? 'සුවපහසු මතක පරීක්ෂාව'
                                      : 'Friendly Memory Check',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5B21B6),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Floating Glowing Elder Avatar Centerpiece
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _floatingAnimation,
                              _ambientPulseAnimation,
                            ]),
                            builder: (context, child) {
                              final pulse = _ambientPulseAnimation.value;
                              return Transform.translate(
                                offset: Offset(0, _floatingAnimation.value * 0.6),
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 98 * pulse,
                                      height: 98 * pulse,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.22),
                                            const Color(0xFFEC4899)
                                                .withValues(alpha: 0.06),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(3.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6C3FC5),
                                            Color(0xFFEC4899),
                                            Color(0xFF8B5CF6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF6C3FC5)
                                                .withValues(alpha: 0.26),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: CarevoraAvatar(
                                          key: const ValueKey(
                                            'elder_start_screen_avatar',
                                          ),
                                          avatarUrl: avatarUrl,
                                          radius: 33,
                                          initials: initials,
                                          backgroundColor: const Color(0xFFEDE9FE),
                                          foregroundColor: const Color(0xFF6C3FC5),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF10B981),
                                              Color(0xFF0D9488),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0D9488)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          LucideIcons.brain,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Warm Personal Greeting
                          Text(
                            isSinhala
                                ? 'ආයුබෝවන්, $displayName! 👋'
                                : 'Welcome, $rawName! 👋',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: -0.3,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Interactive Voice Announcement Bubble ("Now let's start the assessment")
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isSpeakingWelcome
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFFE2D9F9),
                                width: _isSpeakingWelcome ? 1.7 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C3FC5).withValues(
                                    alpha: _isSpeakingWelcome ? 0.14 : 0.05,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _isSpeakingWelcome
                                              ? const [
                                                  Color(0xFF6C3FC5),
                                                  Color(0xFFEC4899),
                                                ]
                                              : const [
                                                  Color(0xFFEDE9FE),
                                                  Color(0xFFF5F3FF),
                                                ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        LucideIcons.volume2,
                                        size: 17,
                                        color: _isSpeakingWelcome
                                            ? Colors.white
                                            : const Color(0xFF6C3FC5),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 340),
                                      child: Text(
                                        '“$voicePhrase”',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3B1F7A),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _speakElderWelcomeIntro(
                                      toggleIfSpeaking: true,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isSpeakingWelcome
                                            ? const Color(0xFF6C3FC5)
                                            : const Color(0xFFF3ECFF),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFC4B5FD),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isSpeakingWelcome)
                                            AnimatedBuilder(
                                              animation: _waveformController,
                                              builder: (context, _) {
                                                final t =
                                                    _waveformController.value *
                                                        2 *
                                                        math.pi;
                                                return Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children:
                                                      List.generate(3, (idx) {
                                                    final h = 5.0 +
                                                        6.0 *
                                                            (0.5 +
                                                                0.5 *
                                                                    math.sin(
                                                                      t +
                                                                          idx *
                                                                              1.4,
                                                                    ));
                                                    return Container(
                                                      width: 2.8,
                                                      height: h,
                                                      margin: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 1.1,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                          4,
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                );
                                              },
                                            )
                                          else
                                            const Icon(
                                              LucideIcons.volume2,
                                              size: 13.5,
                                              color: Color(0xFF6C3FC5),
                                            ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _isSpeakingWelcome
                                                ? (isSinhala
                                                    ? 'කියවමින්...'
                                                    : 'Speaking...')
                                                : (isSinhala
                                                    ? 'නැවත අසන්න'
                                                    : 'Listen Again'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _isSpeakingWelcome
                                                  ? Colors.white
                                                  : const Color(0xFF6C3FC5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Reassuring Subtitle
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Text(
                              isSinhala
                                  ? 'කිසිම කලබලයක් නැතුව සන්සුන්ව පිළිතුරු දෙන්න. ඔබට කටහඬින් හෝ ටයිප් කර පහසුවෙන් පිළිතුරු දිය හැකිය.'
                                  : 'Take your time and relax. You can answer these 10 simple questions easily using your voice or by typing.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13.8,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B4266),
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3 Friendly Reassurance Pills
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildWelcomeHighlightChip(
                                icon: LucideIcons.listChecks,
                                label: isSinhala
                                    ? 'සරල ප්‍රශ්න 10ක්'
                                    : '10 Simple Questions',
                                bgColor: const Color(0xFFF3ECFF),
                                borderColor: const Color(0xFFDDD6FE),
                                iconColor: const Color(0xFF6C3FC5),
                              ),
                              _buildWelcomeHighlightChip(
                                icon: LucideIcons.mic,
                                label: isSinhala
                                    ? 'කටහඬ සහාය ඇත'
                                    : 'Voice Support Ready',
                                bgColor: const Color(0xFFECFEFF),
                                borderColor: const Color(0xFFA5F3FC),
                                iconColor: const Color(0xFF0D9488),
                              ),
                              _buildWelcomeHighlightChip(
                                icon: LucideIcons.heart,
                                label: isSinhala
                                    ? 'නිදහසේ • කලබල නැත'
                                    : 'Relaxed • No Rush',
                                bgColor: const Color(0xFFFDF2F8),
                                borderColor: const Color(0xFFFBCFE8),
                                iconColor: const Color(0xFFDB2777),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Attractive Hero Start Assessment Button
                          AnimatedBuilder(
                            animation: _ambientPulseAnimation,
                            builder: (context, child) {
                              final glow = _ambientPulseAnimation.value;
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C3FC5),
                                      Color(0xFF8B5CF6),
                                      Color(0xFFEC4899),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C3FC5)
                                          .withValues(alpha: 0.28 * glow),
                                      blurRadius: 22 * glow,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFEC4899)
                                          .withValues(alpha: 0.16 * glow),
                                      blurRadius: 14 * glow,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: child,
                              );
                            },
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _beginElderAssessment,
                                borderRadius: BorderRadius.circular(24),
                                splashColor:
                                    Colors.white.withValues(alpha: 0.22),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        hasSavedProgress
                                            ? (isSinhala
                                                ? 'පරීක්ෂාව දිගටම කරන්න'
                                                : 'Continue Assessment')
                                            : (isSinhala
                                                ? 'පරීක්ෂාව ආරම්භ කරන්න'
                                                : 'Start Assessment'),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                        child: const Icon(
                                          LucideIcons.arrowRight,
                                          size: 17,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            isSinhala
                                ? 'සූදානම් වූ විට ඉහත බොත්තම ඔබා ආරම්භ කරන්න'
                                : 'Tap the button above whenever you are ready',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7C7199),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHighlightChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.5, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElderMinimalistView(
    CognitiveQuestionItem currentQ,
    int progressPct,
    bool isSinhala,
  ) {
    final bool isLastQuestion = _currentIndex >= _questions.length - 1;
    final bool isAnswered = _isAnswered(currentQ.id);
    final bool hasStatus = _speechStatusMessage != null;
    final bool statusOk = hasStatus &&
        (_speechStatusMessage!.contains('captured') ||
            _speechStatusMessage!.contains('සටහන් විය'));
    final String promptText = (isSinhala && currentQ.promptSinhala.isNotEmpty)
        ? currentQ.promptSinhala
        : currentQ.prompt;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Attractive Welcome Elder Hero Banner (Minimal Words + Profile Picture)
            _buildElderWelcomeHeroBanner(progressPct, isSinhala),
            const SizedBox(height: 14),

            // 2. Smart, Minimal, Attractive Question & Voice Studio Card
            _buildElderSmartQuestionStudio(
              currentQ: currentQ,
              promptText: promptText,
              progressPct: progressPct,
              isSinhala: isSinhala,
              isLastQuestion: isLastQuestion,
              isAnswered: isAnswered,
              hasStatus: hasStatus,
              statusOk: statusOk,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElderWelcomeHeroBanner(int progressPct, bool isSinhala) {
    final authState = ref.watch(authProvider).state;
    final res = _resident;
    final rawName = (res != null && res.name.trim().isNotEmpty && res.name.trim() != '-')
        ? res.name.trim()
        : (authState.userName?.trim().isNotEmpty == true
            ? authState.userName!.trim()
            : 'Malini Bandara');
    final displayName = isSinhala ? _toSinhalaName(rawName) : rawName;
    final initials = _getInitials(rawName);
    final avatarUrl = (res?.avatarUrl != null && res!.avatarUrl!.trim().isNotEmpty)
        ? res.avatarUrl
        : authState.avatarUrl;
    final facilityName = res?.elderHomeName ??
        authState.elderHomeName ??
        'Serenity Elder Home';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFAF7FF),
            Color(0xFFF3ECFF),
            Color(0xFFEDE4FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFD8B4FE).withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.12),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            // Decorative glowing AI rings on the right
            Positioned(
              top: -70,
              right: -50,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ambientPulseAnimation,
                  builder: (context, _) {
                    final s = _ambientPulseAnimation.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 260 * s,
                          height: 260 * s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFC4B5FD).withValues(alpha: 0.42),
                                const Color(0xFFC4B5FD).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Top multi-color Smart AI gradient bar
            Container(
              height: 5,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6C3FC5),
                    Color(0xFF8B5CF6),
                    Color(0xFFEC4899),
                    Color(0xFF0D9488),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing Elder Profile Picture Avatar
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6C3FC5),
                                  Color(0xFFEC4899),
                                  Color(0xFF8B5CF6),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C3FC5).withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CarevoraAvatar(
                                key: const ValueKey('elder_welcome_hero_avatar'),
                                avatarUrl: avatarUrl,
                                radius: 26,
                                initials: initials,
                                backgroundColor: const Color(0xFFEDE9FE),
                                foregroundColor: const Color(0xFF6C3FC5),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 1,
                            bottom: 1,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(
                                LucideIcons.sparkles,
                                size: 9,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Short, Clear Welcome Name & Subtitle
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSinhala
                                  ? 'ආයුබෝවන්, $displayName! 👋'
                                  : 'Welcome, $rawName! 👋',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.sparkles,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    isSinhala
                                        ? 'මතක පරීක්ෂාව • $facilityName'
                                        : 'Smart Memory Check • $facilityName',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF5B21B6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Right-side Compact Progress Ring & Quick Buttons
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 38,
                              height: 38,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _totalCount == 0 ? 0.0 : (progressPct / 100.0),
                                    strokeWidth: 4.5,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: const Color(0xFFEDE9FE),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF6C3FC5),
                                    ),
                                  ),
                                  Text(
                                    '$progressPct%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$_answeredCount / $_totalCount',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFD4C5FC),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C3FC5).withValues(alpha: 0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(17),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _returnToElderWelcomeScreen,
                            hoverColor: const Color(0xFF6C3FC5).withValues(alpha: 0.06),
                            splashColor: const Color(0xFF6C3FC5).withValues(alpha: 0.12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3EEFF),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      LucideIcons.arrowLeft,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isSinhala ? 'ආපසු' : 'Back',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF5F0FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFC4B5FD),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C3FC5).withValues(alpha: 0.13),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(17),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _startNewAssessmentSession,
                            hoverColor: const Color(0xFF6C3FC5).withValues(alpha: 0.08),
                            splashColor: const Color(0xFF6C3FC5).withValues(alpha: 0.15),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      LucideIcons.rotateCcw,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isSinhala ? 'මුල සිට' : 'Reset',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF5B21B6),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _toSinhalaName(String name) {
    return SinhalaNameTransliterator.toSinhala(name);
  }

  Widget _buildElderSmartQuestionStudio({
    required CognitiveQuestionItem currentQ,
    required String promptText,
    required int progressPct,
    required bool isSinhala,
    required bool isLastQuestion,
    required bool isAnswered,
    required bool hasStatus,
    required bool statusOk,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E1F6), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top subtle gradient strip
            Container(
              height: 4.5,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Question Header + Saved Badge + Top Prev/Next Controls (No Scrolling Needed!)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C3FC5).withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_currentIndex + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isSinhala
                                ? 'ප්‍රශ්නය ${_currentIndex + 1} / $_totalCount'
                                : 'Question ${_currentIndex + 1} of $_totalCount',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      _buildAnimatedAnswerSavedChip(currentQ.id),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Interactive 10-Step Bar
                  _buildStepIndicator(true),
                  const SizedBox(height: 16),

                  // 3. Attractive Question Card (Minimal Text + Read Aloud Button)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentIndex),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFAF7FF), Color(0xFFF3ECFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDDD6FE), width: 1.3),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildInfoChip(
                                  label: _translateCategory(currentQ.category, isSinhala),
                                  icon: LucideIcons.brain,
                                  background: Colors.white,
                                  color: AppColors.primary,
                                  borderColor: const Color(0xFFDDD6FE),
                                ),
                                _buildListenButton(promptText),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              promptText,
                              style: const TextStyle(
                                fontSize: 23,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Smart Voice + Text Input Studio (With Inline Next Button & Zero Scroll)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFF0FDF4) : const Color(0xFFFBFBFE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isListening ? const Color(0xFF86EFAC) : const Color(0xFFE5E1F6),
                        width: _isListening ? 1.8 : 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildMicButton(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isListening
                                        ? (isSinhala
                                            ? 'සවන් දෙමින් පවතී... නැවැත්වීමට ඔබන්න'
                                            : 'Listening... Tap mic to stop')
                                        : (isSinhala
                                            ? 'කතා කිරීමට මයික්‍රොෆෝනය ඔබන්න'
                                            : 'Tap the microphone to speak'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildAnimatedWaveform(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _responseController,
                                onChanged: (val) => _handleResponseTextChanged(
                                  currentQ.id,
                                  val,
                                  isSinhala,
                                ),
                                onSubmitted: (_) {
                                  if (isSinhala && _isSinglishAutoEnabled) {
                                    _commitActiveSinglishWord(currentQ.id);
                                  }
                                },
                                minLines: 1,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: isSinhala
                                      ? (_isSinglishAutoEnabled
                                          ? 'සිංහලෙන් හෝ Singlish (උදා: irida) මෙහි ටයිප් කරන්න...'
                                          : 'නැතහොත් පිළිතුර මෙහි ටයිප් කරන්න...')
                                      : 'Or type your answer here...',
                                  hintStyle: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.muted,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E1F6), width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E1F6), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_currentIndex > 0) ...[
                              OutlinedButton.icon(
                                onPressed: _prevQuestion,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.navy,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE5E1F6), width: 1.5),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(LucideIcons.chevronLeft, size: 17),
                                label: Text(
                                  isSinhala ? 'පෙර' : 'Prev',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            _buildPrimaryActionButton(
                              label: isLastQuestion
                                  ? (isSinhala ? 'අවසන් කර යොමු කරන්න' : 'Finish & Submit')
                                  : (isSinhala ? 'ඊළඟ ප්‍රශ්නය' : 'Next Question'),
                              icon: isLastQuestion ? LucideIcons.send : LucideIcons.arrowRight,
                              onTap: () {
                                if (isSinhala && _isSinglishAutoEnabled) {
                                  _commitActiveSinglishWord(currentQ.id);
                                }
                                _nextQuestion(true);
                              },
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                            ),
                          ],
                        ),
                        if (isSinhala) _buildSinhalaTypingControls(currentQ.id),
                        if (hasStatus) ...[
                          const SizedBox(height: 8),
                          Text(
                            _speechStatusMessage!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: statusOk
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtleTherapeuticBackground() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ambientBgAnimation,
        builder: (context, _) {
          final t = _ambientBgAnimation.value;
          return Stack(
            children: [
              // Gentle calming base gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF6F2FF),
                      Color(0xFFEDE4FF),
                      Color(0xFFF3ECFF),
                      Color(0xFFFAF7FF),
                    ],
                  ),
                ),
              ),

              // Therapeutic soft concentric wave ripples
              CustomPaint(
                size: Size.infinite,
                painter: _TherapeuticRipplesPainter(animationValue: t),
              ),

              // Soft lavender aura orb (top right)
              Positioned(
                top: -90 + (t * 35),
                right: -50 + ((1.0 - t) * 45),
                child: Container(
                  width: 480,
                  height: 480,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Soft serene indigo/periwinkle aura orb (center left)
              Positioned(
                top: 240 + ((1.0 - t) * 40),
                left: -90 + (t * 30),
                child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.11),
                        const Color(0xFF6366F1).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Healing mint/teal aura orb (bottom right)
              Positioned(
                bottom: -80 + (t * 30),
                right: 50 + (t * 40),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0D9488).withValues(alpha: 0.06),
                        const Color(0xFF0D9488).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Subtle rose mist aura orb (mid right)
              Positioned(
                top: 480 + (t * 25),
                right: -70 + ((1.0 - t) * 35),
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFEC4899).withValues(alpha: 0.032),
                        const Color(0xFFEC4899).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _translateCategory(String category, bool isSinhala) {
    if (!isSinhala) return category;
    switch (category) {
      case 'Orientation':
        return 'දිශානතිය';
      case 'Immediate Memory':
        return 'ක්ෂණික මතකය';
      case 'Attention & Math':
        return 'අවධානය සහ ගණිතය';
      case 'Attention & Number':
        return 'අවධානය සහ සංඛ්‍යා';
      case 'Delayed Recall':
        return 'ප්‍රමාද වූ මතකය';
      case 'Practical Reasoning':
        return 'ප්‍රායෝගික තර්කනය';
      case 'Abstract Reasoning':
        return 'වියුක්ත තර්කනය';
      default:
        return category;
    }
  }

  String _translateDomain(String domain, bool isSinhala) {
    if (!isSinhala) return 'Domain: $domain';
    switch (domain.toLowerCase()) {
      case 'orientation':
        return 'ක්ෂේත්‍රය: දිශානතිය';
      case 'memory':
        return 'ක්ෂේත්‍රය: මතකය';
      case 'attention':
        return 'ක්ෂේත්‍රය: අවධානය';
      case 'recall':
        return 'ක්ෂේත්‍රය: නැවත සිහිපත් කිරීම';
      case 'reasoning':
        return 'ක්ෂේත්‍රය: තර්කනය';
      default:
        return 'ක්ෂේත්‍රය: $domain';
    }
  }

  Widget _buildTopNavBar() {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    Color statusBg;
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (_sessionStatus == 'COMPLETED') {
      statusBg = const Color(0xFFDCFCE7);
      statusColor = const Color(0xFF15803D);
      statusLabel = isSinhala ? 'සම්පූර්ණයි' : 'Completed';
      statusIcon = LucideIcons.circleCheckBig;
    } else if (_sessionStatus == 'PENDING_CAREGIVER_REVIEW') {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFB45309);
      statusLabel = isSinhala
          ? 'රැකවරණ නිලධාරී පරීක්ෂාව අපේක්ෂාවෙන්'
          : 'Pending Caregiver Review';
      statusIcon = LucideIcons.alertCircle;
    } else {
      statusBg = const Color(0xFFEEF2FF);
      statusColor = const Color(0xFF4F46E5);
      statusLabel = isSinhala ? 'ක්‍රියාත්මක වෙමින් පවතී' : 'In Progress';
      statusIcon = LucideIcons.clock;
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/dashboard/residents'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E1F6)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.arrowLeft, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        isSinhala ? 'නේවාසික නාමාවලිය' : 'Resident Directory',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.5),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(statusIcon, size: 13, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startNewAssessmentSession,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.plus, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        isSinhala ? 'නව ඇගයීමක්' : 'New Assessment',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E1F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.timer, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    isSinhala ? 'ගතවූ කාලය: ' : 'Session Elapsed: ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatElapsed(_sessionElapsedSeconds),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'R';
    final parts = clean
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'R';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildLoadingResidentsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading resident profiles...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Retrieving residents assigned to your care community.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildResidentErrorState(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.riskHighBg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.riskHighBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.alertTriangle, color: AppColors.riskHigh, size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'Unable to Load Residents',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            errorMessage,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadResidentContext,
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Retry Loading Directory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResidentsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.lavenderBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.users, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Eligible Residents Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'There are currently no residents registered or assigned to your care facility for cognitive assessment.\nCaregivers can only assess residents enrolled in their assigned Elder Home.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/dashboard/residents'),
                icon: const Icon(LucideIcons.userPlus, size: 15),
                label: const Text('Go to Resident Directory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadResidentContext,
                icon: const Icon(LucideIcons.refreshCw, size: 15),
                label: const Text('Refresh Directory'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResidentBanner(bool isElder) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    final res = _resident;
    final initials = res != null ? _getInitials(res.name) : (isElder ? 'JP' : 'R');
    final displayName = (res != null && res.name.trim().isNotEmpty && res.name.trim() != '-')
        ? res.name.trim()
        : (isElder ? 'James Perera' : 'Resident #${res?.id ?? 5}');
    final facilityName = res?.elderHomeName ??
        ref.read(authProvider).state.elderHomeName ??
        'Serenity Elder Home';
    final ageVal = res?.age ?? 75;
    final ageDisplay = isSinhala ? 'අවු. $ageVal' : '$ageVal yrs';
    final roomNum = (res?.roomNumber != null && res!.roomNumber.isNotEmpty)
        ? res.roomNumber
        : '101';
    final roomDisplay = isSinhala
        ? 'කාමර ${roomNum.replaceAll('Room ', '').replaceAll('Suite ', '')}'
        : (roomNum.startsWith('Room') || roomNum.startsWith('Suite')
            ? roomNum
            : 'Room $roomNum');
    final eduVal = res?.educationYears ?? 12;
    final educationDisplay = isSinhala ? 'වසර $eduVal' : '$eduVal yrs';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E1F6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Resident Avatar with portrait image & active status indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  RepaintBoundary(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFDDD6FE), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C3FC5).withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CarevoraAvatar(
                        key: const ValueKey('resident_session_banner_avatar'),
                        avatarUrl: res?.avatarUrl ?? (isElder ? ref.read(authProvider).state.avatarUrl : null),
                        radius: 31,
                        initials: initials,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Resident Identity & Demographic Information
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEDE9FE), Color(0xFFF3E8FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.userCheck,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isElder
                                  ? (isSinhala ? 'වැඩිහිටි / නේවාසික' : 'ELDER / RESIDENT')
                                  : 'ID: ${res?.id ?? 5}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (facilityName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.building2,
                                size: 11,
                                color: Color(0xFF475569),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                facilityName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Rich Demographic Attribute Pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildResidentDetailPill(
                        icon: LucideIcons.calendar,
                        label: isSinhala ? 'වයස: $ageDisplay' : 'Age: $ageDisplay',
                        color: const Color(0xFF4F46E5),
                        bg: const Color(0xFFEEF2FF),
                        border: const Color(0xFFE0E7FF),
                      ),
                      _buildResidentDetailPill(
                        icon: LucideIcons.doorOpen,
                        label: roomDisplay,
                        color: const Color(0xFF059669),
                        bg: const Color(0xFFECFDF5),
                        border: const Color(0xFFA7F3D0),
                      ),
                      _buildResidentDetailPill(
                        icon: LucideIcons.graduationCap,
                        label: isSinhala
                            ? 'අධ්‍යාපනය: $educationDisplay'
                            : 'Education: $educationDisplay',
                        color: const Color(0xFF7C3AED),
                        bg: const Color(0xFFF5F3FF),
                        border: const Color(0xFFDDD6FE),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Caregiver Switcher if multiple residents
              if (!isElder && _availableResidents.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: (_resident != null &&
                              _availableResidents.any((r) => r.id == _resident!.id))
                          ? _resident!.id
                          : (_availableResidents.isNotEmpty
                              ? _availableResidents.first.id
                              : null),
                      icon: const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.primary),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                      items: _availableResidents.map((r) {
                        final clean = (r.name.trim().isNotEmpty && r.name.trim() != '-')
                            ? r.name.trim()
                            : 'Resident #${r.id}';
                        return DropdownMenuItem<int>(
                          value: r.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.user, size: 13, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('$clean (ID: ${r.id})'),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) {
                          _selectResident(id);
                        }
                      },
                    ),
                  ),
                ),
              // Floating Session Battery Badge
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatingAnimation.value * 0.5),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C3FC5).withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.sparkles, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        isElder
                            ? (isSinhala
                                ? 'ස්වයං ප්‍රතිචාර සැසිය (ප්‍රශ්න $_totalCount)'
                                : 'Self-Response Session ($_totalCount Items)')
                            : (isSinhala
                                ? 'සම්මත ප්‍රජානන ඇගයීම (ප්‍රශ්න $_totalCount)'
                                : 'Standard Cognitive Battery ($_totalCount Items)'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResidentDetailPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Presentation helpers (UI only — no business logic)
  // ---------------------------------------------------------------------------
  BoxDecoration _cardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildPanelHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildInfoChip({
    required String label,
    IconData? icon,
    Color color = AppColors.primary,
    Color background = Colors.white,
    Color borderColor = AppColors.lilac,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner({
    required String text,
    required IconData icon,
    required Color color,
    required Color background,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainQuestionWorkspace(
    CognitiveQuestionItem currentQ,
    int progressPct,
    double? currentGrade,
    bool isElder,
  ) {
    final bool isLastQuestion = !(_currentIndex < _questions.length - 1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: question number, summary & completion chip
          _buildWorkspaceHeader(progressPct, isElder),
          const SizedBox(height: 16),

          // Segmented step indicator (one segment per question)
          _buildStepIndicator(isElder),
          const SizedBox(height: 22),

          // Question card with smooth directional animated transition between questions
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final isIncoming = child.key == ValueKey<int>(_currentIndex);
              final double dx = isIncoming
                  ? (_transitionDirection >= 0 ? 0.04 : -0.04)
                  : (_transitionDirection >= 0 ? -0.04 : 0.04);
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(dx, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_currentIndex),
              child: _buildQuestionCard(currentQ, isElder),
            ),
          ),
          const SizedBox(height: 20),

          // Response panel: voice capture, typed answer & scoring
          _buildResponsePanel(currentQ, currentGrade, isElder),
          const SizedBox(height: 20),

          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 18),

          // Bottom navigation actions
          _buildBottomActions(currentQ, isElder, isLastQuestion),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader(int progressPct, bool isElder) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Row(
      children: [
        AnimatedBuilder(
          animation: _floatingAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _floatingAnimation.value * 0.4),
            child: child,
          ),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3FC5).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '${_currentIndex + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSinhala
                    ? 'ප්‍රශ්න $_totalCount න් ${_currentIndex + 1} වන ප්‍රශ්නය'
                    : 'Question ${_currentIndex + 1} of $_totalCount',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isElder
                    ? (isSinhala
                        ? 'පිළිතුරු දුන් ප්‍රශ්න: $_answeredCount/$_totalCount ($progressPct%) • ඔබේ වේගයෙන් පිළිතුරු දෙන්න'
                        : 'Questions Answered: $_answeredCount/$_totalCount ($progressPct%) • Self-Paced Wellness')
                    : (isSinhala
                        ? 'සම්පූර්ණ: $_fullyCompletedCount/$_totalCount ($progressPct%) • පිළිතුරු: $_answeredCount • ලකුණු: $_gradedCount'
                        : 'Completed: $_fullyCompletedCount/$_totalCount ($progressPct%) • Answered: $_answeredCount • Graded: $_gradedCount'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.body,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildInfoChip(
          label: isSinhala ? '$progressPct% ක් සම්පූර්ණයි' : '$progressPct% completed',
          icon: LucideIcons.listChecks,
          background: const Color(0xFFF5F3FF),
          color: AppColors.primary,
          borderColor: const Color(0xFFDDD6FE),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(bool isElder) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Row(
      children: List.generate(_questions.length, (i) {
        final q = _questions[i];
        final bool isCurrent = i == _currentIndex;
        final bool isDone = isElder ? _isAnswered(q.id) : _isFullyCompleted(q.id);

        return Expanded(
          flex: isCurrent ? 3 : 2,
          child: Tooltip(
            message: isSinhala
                ? 'ප්‍රශ්නය ${i + 1}: ${_translateCategory(q.category, true)}${isDone ? ' (සම්පූර්ණයි)' : ''}'
                : 'Question ${i + 1}: ${q.category}${isDone ? ' (Completed)' : ''}',
            child: InkWell(
              onTap: () => _goToQuestion(i),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: isCurrent ? 28 : 22,
                margin: EdgeInsets.only(right: i == _questions.length - 1 ? 0 : 6),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: isCurrent
                      ? const LinearGradient(
                          colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : isDone
                          ? const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                  color: (isCurrent || isDone) ? null : const Color(0xFFF3EDFD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF8B5CF6)
                        : isDone
                            ? const Color(0xFF059669)
                            : const Color(0xFFDDD6FE),
                    width: isCurrent ? 1.5 : 1.0,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6C3FC5).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : isDone
                          ? [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                ),
                alignment: Alignment.center,
                child: isCurrent
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Q${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      )
                    : isDone
                        ? const Icon(
                            LucideIcons.check,
                            size: 12,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8CA3),
                            ),
                          ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQuestionCard(CognitiveQuestionItem currentQ, bool isElder) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E4F7), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top subtle gradient accent strip
          Container(
            height: 4.5,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Category & Domain pills, Listen TTS button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _floatingAnimation,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(0, _floatingAnimation.value * 0.35),
                              child: child,
                            ),
                            child: _buildInfoChip(
                              label: _translateCategory(currentQ.category, isSinhala),
                              icon: LucideIcons.brain,
                              background: const Color(0xFFF5F3FF),
                              color: AppColors.primary,
                              borderColor: const Color(0xFFDDD6FE),
                            ),
                          ),
                          _buildInfoChip(
                            label: _translateDomain(currentQ.domain, isSinhala),
                            icon: LucideIcons.compass,
                            color: const Color(0xFF475569),
                            background: const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFFE2E8F0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildListenButton(
                      (isSinhala && currentQ.promptSinhala.isNotEmpty)
                          ? currentQ.promptSinhala
                          : currentQ.prompt,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Question Prompt (Strictly single-language based on selected language)
                Text(
                  (isSinhala && currentQ.promptSinhala.isNotEmpty)
                      ? currentQ.promptSinhala
                      : currentQ.prompt,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 18),

                // Helpful Tip / AI Guidance Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _ambientPulseAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _ambientPulseAnimation.value,
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isElder ? LucideIcons.lightbulb : LucideIcons.sparkles,
                            size: 16,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            isElder
                                ? (isSinhala
                                    ? 'උපදෙස්: කලබල නොවී ඔබේ කාලය ගන්න. මයික්‍රොෆෝනයට පැහැදිලිව කතා කරන්න හෝ ඔබේ පිළිතුර ටයිප් කරන්න.'
                                    : 'Helpful Tip: Take your time. Speak clearly into the microphone or type your answer.')
                                : 'AI Guidance: ${currentQ.aiTip}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenButton(String prompt) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    final bool isPlaying = _isSpeaking;
    return Tooltip(
      message: isPlaying
          ? (isSinhala ? 'හඬ නවත්වන්න' : 'Stop reading')
          : (isSinhala ? 'ප්‍රශ්නය හඬින් කියවන්න' : 'Read question aloud'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleTts(prompt),
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: isPlaying
                  ? const LinearGradient(
                      colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFAF7FF), Color(0xFFF3EDFD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isPlaying ? const Color(0xFF6C3FC5) : const Color(0xFFDDD6FE),
                width: 1.3,
              ),
              boxShadow: isPlaying
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6C3FC5).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPlaying) ...[
                  // Mini 3-bar animated soundwave equalizer
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (barIdx) {
                      return AnimatedBuilder(
                        animation: _waveformController,
                        builder: (context, _) {
                          final phase = (_waveformController.value + barIdx * 0.33) % 1.0;
                          final barHeight = 6.0 + 8.0 * (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2);
                          return Container(
                            width: 2.5,
                            height: barHeight,
                            margin: const EdgeInsets.only(right: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  const SizedBox(width: 5),
                  const Icon(LucideIcons.square, size: 14, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    isSinhala ? 'හඬ නවත්වන්න' : 'Stop Audio',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ] else ...[
                  const Icon(LucideIcons.volume2, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    isSinhala ? 'හඬින් කියවන්න' : 'Read Aloud',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return Tooltip(
      message: _isListening ? 'Stop listening' : 'Tap to speak your answer',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggleListening,
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer breathing or ripple ring
                if (_isListening) ...[
                  AnimatedBuilder(
                    animation: _waveformController,
                    builder: (context, _) {
                      final v = _waveformController.value;
                      return Container(
                        width: 66 + 18 * v,
                        height: 66 + 18 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.25 * (1.0 - v)),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _waveformController,
                    builder: (context, _) {
                      final v = (_waveformController.value + 0.5) % 1.0;
                      return Container(
                        width: 66 + 18 * v,
                        height: 66 + 18 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.18 * (1.0 - v)),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  AnimatedBuilder(
                    animation: _ambientPulseAnimation,
                    builder: (context, child) => Container(
                      width: 66 + (8 * _ambientPulseAnimation.value),
                      height: 66 + (8 * _ambientPulseAnimation.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.14 * _ambientPulseAnimation.value),
                      ),
                    ),
                  ),
                ],
                // Main tactile circle button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isListening
                        ? const LinearGradient(
                            colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? const Color(0xFFE11D48) : const Color(0xFF6C3FC5))
                            .withValues(alpha: 0.38),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isListening ? LucideIcons.micOff : LucideIcons.mic,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedAnswerSavedChip(int qId) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    final isAnswered = _isAnswered(qId);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: isAnswered
          ? AnimatedBuilder(
              key: const ValueKey('answered_chip'),
              animation: _savePulseController,
              builder: (context, child) {
                final scale = _savePulseController.isAnimating ? _saveScaleAnimation.value : 1.0;
                final glow = _savePulseController.isAnimating ? _saveGlowAnimation.value : 0.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDCFCE7), Color(0xFFD1FAE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF86EFAC),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12 + 0.25 * glow),
                          blurRadius: 6 + 8 * glow,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: _savePulseController.isAnimating
                              ? (0.8 + 0.4 * _saveCheckmarkAnimation.value)
                              : 1.0,
                          child: const Text('✨', style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSinhala ? 'පිළිතුර සුරැකිණි' : 'Answer Saved',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14532D),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : const SizedBox.shrink(key: ValueKey('empty_chip')),
    );
  }

  Widget _buildAnimatedSavedBanner(bool isElder, int qId) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    final answered = _isAnswered(qId);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: answered
            ? const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFBFBFE), Color(0xFFF5F3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: answered ? const Color(0xFF86EFAC) : const Color(0xFFDDD6FE),
          width: 1.2,
        ),
        boxShadow: answered
            ? [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: answered ? const Color(0xFFBBF7D0) : const Color(0xFFEDE9FE),
            ),
            child: answered
                ? const Text('✨', style: TextStyle(fontSize: 15))
                : const Icon(
                    LucideIcons.userCheck,
                    size: 16,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      answered
                          ? (isSinhala ? 'පිළිතුර සුරැකිණි' : 'Answer Saved')
                          : (isSinhala ? 'නිදහස් පිළිතුරු සැසිය' : 'Self-Paced Response'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: answered ? const Color(0xFF14532D) : AppColors.navy,
                      ),
                    ),
                    if (answered) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF15803D).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          isSinhala ? '✅ ස්වයංක්‍රීයව සුරැකිණි' : '✅ Auto-Saved',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  answered
                      ? (isSinhala
                          ? 'ඔබේ පිළිතුර ආරක්ෂිතව සටහන් කර ඇත. යොමු කළ පසු පද්ධතිය මගින් එය ඇගයීමට ලක් කෙරේ.'
                          : 'Your answer is securely recorded. The clinical engine evaluates and scores it upon submission.')
                      : (isSinhala
                          ? 'ඉහත ඔබේ පිළිතුර ටයිප් කරන්න හෝ මයික්‍රොෆෝනයෙන් කතා කරන්න.'
                          : 'Type or speak your answer above. The system will safely evaluate your response.'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: answered ? const Color(0xFF166534) : AppColors.body,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsePanel(
    CognitiveQuestionItem currentQ,
    double? currentGrade,
    bool isElder,
  ) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    final bool hasStatus = _speechStatusMessage != null;
    final bool statusOk = hasStatus &&
        (_speechStatusMessage!.contains('captured') ||
            _speechStatusMessage!.contains('සටහන් විය'));
    final bool isLastQuestion = !(_currentIndex < _questions.length - 1);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isListening
              ? AppColors.riskLow.withValues(alpha: 0.6)
              : const Color(0xFFE5E1F6),
          width: _isListening ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isListening
                ? AppColors.riskLow.withValues(alpha: 0.08)
                : const Color(0xFF6C3FC5).withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _isListening ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isListening ? LucideIcons.audioLines : LucideIcons.messageSquare,
                  size: 16,
                  color: _isListening ? AppColors.riskLow : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isListening
                    ? (isSinhala ? 'ඔබේ හඬට සවන් දෙමින්...' : 'Listening to speech...')
                    : (isElder
                        ? (isSinhala ? 'ඔබේ පිළිතුර' : 'Your Answer')
                        : (isSinhala ? 'පිළිතුරු සටහන' : 'Response Capture')),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildAnimatedAnswerSavedChip(currentQ.id),
                      Text(
                        isElder
                            ? (isSinhala ? 'හඬ හෝ යතුරුපුවරුව' : 'Voice or Keyboard')
                            : (isSinhala ? 'හඬ සහ ලකුණු ලබාදීම' : 'Voice & Clinical Grading'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      _buildPrimaryActionButton(
                        label: isLastQuestion
                            ? (isElder
                                ? (isSinhala ? 'අවසන් කර යොමු කරන්න' : 'Finish & Submit')
                                : (isSinhala ? 'ඇගයීම අවසන් කරන්න' : 'Finish Assessment'))
                            : (isSinhala ? 'ඊළඟ ප්‍රශ්නය →' : 'Next Question →'),
                        icon: isLastQuestion ? LucideIcons.send : LucideIcons.arrowRight,
                        onTap: () => _nextQuestion(isElder),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Voice capture area: large mic button + live waveform
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _isListening
                  ? const Color(0xFFF0FDF4)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isListening
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFE5E1F6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildMicButton(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isListening
                            ? (isSinhala
                                ? 'සවන් දෙමින්… නැවැත්වීමට මයික්‍රොෆෝනය ඔබන්න'
                                : 'Listening… tap the mic to stop')
                            : (isSinhala
                                ? 'කතා කිරීමට මයික්‍රොෆෝනය ඔබන්න'
                                : 'Tap the microphone to speak'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isListening
                            ? (isSinhala
                                ? 'පැහැදිලිව කතා කරන්න — ඔබේ වචන පහත කොටුවේ සටහන් වේ.'
                                : 'Speak clearly — your words will appear in the box below.')
                            : (isElder
                                ? (isSinhala
                                    ? 'නැතහොත් පහත කොටුවේ ඔබේ පිළිතුර ටයිප් කරන්න.'
                                    : 'Or simply type your answer in the box below.')
                                : (isSinhala
                                    ? 'නැතහොත් නේවාසිකයාගේ පිළිතුර පහත කොටුවේ ටයිප් කරන්න.'
                                    : 'Or type the resident\'s answer in the box below.')),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.body,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildAnimatedWaveform(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Editable Response Text Field
          TextField(
            controller: _responseController,
            onChanged: (val) => _handleResponseTextChanged(
              currentQ.id,
              val,
              isSinhala,
            ),
            onSubmitted: (_) {
              if (isSinhala && _isSinglishAutoEnabled) {
                _commitActiveSinglishWord(currentQ.id);
              }
            },
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: isElder
                  ? (isSinhala
                      ? 'ඔබේ පිළිතුර මෙහි ටයිප් කරන්න, නැතහොත් කතා කිරීමට මයික්‍රොෆෝනය ඔබන්න...'
                      : 'Type your answer here, or tap the microphone to speak...')
                  : (isSinhala
                      ? 'නේවාසිකයාගේ පිළිතුර මෙහි ටයිප් කරන්න...'
                      : 'Type resident answer here, or tap the microphone to dictate...'),
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E1F6), width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E1F6), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
              height: 1.45,
            ),
          ),
          if (isSinhala) _buildSinhalaTypingControls(currentQ.id),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.keyboard, size: 13, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    isSinhala
                        ? 'ඔබට පිළිතුර ටයිප් කිරීමටද හැකිය.'
                        : 'You can also type your answer.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_isAnswered(currentQ.id))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        isSinhala ? 'ගිණුමට සුරැකිණි' : 'Saved to profile',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (hasStatus) ...[
            const SizedBox(height: 12),
            _buildNoticeBanner(
              text: _speechStatusMessage!,
              icon: statusOk ? LucideIcons.checkCircle2 : LucideIcons.info,
              color: statusOk ? const Color(0xFF15803D) : const Color(0xFF92400E),
              background: statusOk ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderColor: statusOk ? const Color(0xFF86EFAC) : const Color(0xFFF59E0B),
            ),
          ],
          const SizedBox(height: 16),

          if (!isElder) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E1F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        isSinhala
                            ? 'ස්වයංක්‍රීය ලකුණු ලබාදීම:'
                            : 'Automatic Scoring (Deterministic Rubric):',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        isSinhala
                            ? 'පද්ධතිය ස්වයංක්‍රීයව ලකුණු ලබා දෙයි'
                            : 'System auto-grades answers • Optional override',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGradeButton(
                          label: isSinhala ? 'නිවැරදියි (1.0)' : 'Correct (1.0)',
                          icon: LucideIcons.checkCircle,
                          scoreValue: 1.0,
                          selectedColor: AppColors.riskLow,
                          selectedBg: const Color(0xFFDCFCE7),
                          isSelected: currentGrade == 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGradeButton(
                          label: isSinhala ? 'අර්ධ නිවැරදි (0.5)' : 'Partial (0.5)',
                          icon: LucideIcons.minusCircle,
                          scoreValue: 0.5,
                          selectedColor: AppColors.riskModerate,
                          selectedBg: const Color(0xFFFEF3C7),
                          isSelected: currentGrade == 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGradeButton(
                          label: isSinhala ? 'වැරදියි (0.0)' : 'Incorrect (0.0)',
                          icon: LucideIcons.xCircle,
                          scoreValue: 0.0,
                          selectedColor: AppColors.riskHigh,
                          selectedBg: const Color(0xFFFEE2E2),
                          isSelected: currentGrade == 0.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildAnimatedSavedBanner(isElder, currentQ.id),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(
    CognitiveQuestionItem currentQ,
    bool isElder,
    bool isLastQuestion,
  ) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _toggleTts(
                (isSinhala && currentQ.promptSinhala.isNotEmpty)
                    ? currentQ.promptSinhala
                    : currentQ.prompt,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFDDD6FE), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: Text(
                isSinhala ? 'ප්‍රශ්නය නැවත අසන්න' : 'Repeat Question',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            _buildInfoChip(
              label: isElder
                  ? (isSinhala
                      ? 'කලබල නොවී ඔබේ කාලය ගන්න'
                      : 'Self-Paced • Take Your Time')
                  : (isSinhala
                      ? 'කාලය: ${(_questionTimes[currentQ.id] ?? 0.0).toStringAsFixed(0)} තත්.'
                      : 'Time: ${(_questionTimes[currentQ.id] ?? 0.0).toStringAsFixed(0)}s'),
              icon: LucideIcons.timer,
              color: AppColors.body,
              background: const Color(0xFFF8FAFC),
              borderColor: const Color(0xFFE2E8F0),
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_currentIndex > 0)
              OutlinedButton.icon(
                onPressed: _prevQuestion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE5E1F6), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.chevronLeft, size: 17),
                label: Text(
                  isSinhala ? '← පෙර ප්‍රශ්නය' : '← Prev',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    EdgeInsetsGeometry? padding,
  }) {
    return AnimatedBuilder(
      animation: _ambientPulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: 0.985 + (0.02 * _ambientPulseAnimation.value),
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C3FC5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C3FC5).withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(icon, size: 17, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeButton({
    required String label,
    required IconData icon,
    required double scoreValue,
    required Color selectedColor,
    required Color selectedBg,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setGrade(scoreValue),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? selectedColor : const Color(0xFFE5E1F6),
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? selectedColor : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? selectedColor : AppColors.body,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedWaveform() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return SizedBox(
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(24, (i) {
                final double phase = (i / 24.0 + _waveformController.value) % 1.0;
                final double waveHeight = _isListening
                    ? (8.0 + 18.0 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi).abs()))
                    : 4.5;
                return Container(
                  width: 3.5,
                  height: waveHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: _isListening
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                    color: _isListening ? null : const Color(0xFFDDD6FE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRightPanel(int progressPct, bool isElder, CognitiveQuestionItem currentQ) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Column(
      children: [
        // 1. Circular Progress Card
        _buildProgressCard(progressPct, isElder),
        const SizedBox(height: 18),

        // 2. Questions Overview Checklist
        _buildQuestionsOverviewCard(isElder),
        const SizedBox(height: 18),

        // 3. Clinical Scoring Rubric Guidance (or Elder Session Tips)
        _buildGuidanceCard(isElder),
        const SizedBox(height: 18),

        // 4. Floating Live Cognitive Wellness Companion Card
        _buildCognitiveWellnessCompanionCard(currentQ),
        const SizedBox(height: 18),

        // 5. End / Finish Assessment Button
        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showFinishConfirmationDialog(isElder),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isElder ? const Color(0xFFF5F3FF) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isElder ? const Color(0xFFDDD6FE) : const Color(0xFFFECACA),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isElder ? AppColors.primary : AppColors.riskHigh).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isElder ? LucideIcons.send : LucideIcons.alertOctagon,
                      size: 16,
                      color: isElder ? AppColors.primary : AppColors.riskHigh,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isElder
                          ? (_answeredCount == _totalCount
                              ? (isSinhala
                                  ? 'පරීක්ෂාව සඳහා යොමු කරන්න'
                                  : 'Submit for Caregiver Review')
                              : (isSinhala
                                  ? 'සැසිය අවසන් කර සුරකින්න'
                                  : 'End & Save Session'))
                          : (isSinhala ? 'ඇගයීම අවසන් කරන්න' : 'End Assessment'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isElder ? AppColors.primary : AppColors.riskHigh,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(int progressPct, bool isElder) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E1F6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPanelHeader(
            LucideIcons.chartPie,
            isElder
                ? (isSinhala ? 'ඔබේ පිළිතුරු ප්‍රගතිය' : 'Your Answer Progress')
                : (isSinhala ? 'ඇගයීම් ප්‍රගතිය' : 'Assessment Progress'),
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0.0,
              end: _totalCount == 0 ? 0.0 : (progressPct / 100.0),
            ),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (context, animatedVal, _) {
              final pctInt = (animatedVal * 100).round();
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: animatedVal,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFF3EDFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pctInt%',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        isElder
                            ? (isSinhala ? 'පිළිතුරු දුන්' : 'Answered')
                            : (isSinhala ? 'සම්පූර්ණයි' : 'Completed'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (isElder) ...[
            _buildStatGrid([
              _buildStatItem(
                isSinhala ? 'පිළිතුරු දුන්' : 'Answered',
                '$_answeredCount/$_totalCount',
                AppColors.primary,
                LucideIcons.checkCircle2,
                const Color(0xFFEDE9FE),
              ),
              _buildStatItem(
                isSinhala ? 'ඉතිරි' : 'Remaining',
                '$_remainingToAnswerCount',
                const Color(0xFFD97706),
                LucideIcons.clock,
                const Color(0xFFFEF3C7),
              ),
              _buildStatItem(
                isSinhala ? 'තත්ත්වය' : 'Status',
                _answeredCount == _totalCount
                    ? (isSinhala ? 'සූදානම්' : 'Ready')
                    : (isSinhala ? 'ක්‍රියාත්මකයි' : 'In Progress'),
                _answeredCount == _totalCount
                    ? const Color(0xFF15803D)
                    : const Color(0xFF4F46E5),
                LucideIcons.activity,
                _answeredCount == _totalCount
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFEEF2FF),
              ),
              _buildStatItem(
                isSinhala ? 'AI සහායක' : 'AI Companion',
                isSinhala ? 'සජීවී හඬ සහ පෙළ' : 'Smart Voice & Text',
                AppColors.primary,
                LucideIcons.sparkles,
                const Color(0xFFF5F3FF),
              ),
            ]),
            const SizedBox(height: 14),
            if (_remainingToAnswerCount > 0)
              _buildNoticeBanner(
                text: isSinhala
                    ? 'පිළිතුරු දීමට තවත් ප්‍රශ්න $_remainingToAnswerCount ක් ඉතිරිව ඇත'
                    : '$_remainingToAnswerCount question(s) pending your answer',
                icon: LucideIcons.clock,
                color: const Color(0xFF92400E),
                background: const Color(0xFFFEF3C7),
                borderColor: const Color(0xFFF59E0B),
              )
            else
              _buildNoticeBanner(
                text: isSinhala
                    ? 'ප්‍රශ්න 10 ටම පිළිතුරු ලබා දී ඇත — යොමු කිරීමට සූදානම්!'
                    : 'All 10 questions answered — Ready for review!',
                icon: LucideIcons.circleCheckBig,
                color: const Color(0xFF15803D),
                background: const Color(0xFFDCFCE7),
                borderColor: const Color(0xFF86EFAC),
              ),
          ] else ...[
            _buildStatGrid([
              _buildStatItem(
                isSinhala ? 'සම්පූර්ණ' : 'Completed',
                '$_fullyCompletedCount/$_totalCount',
                AppColors.primary,
                LucideIcons.checkCircle2,
                const Color(0xFFEDE9FE),
              ),
              _buildStatItem(
                isSinhala ? 'පිළිතුරු දුන්' : 'Answered',
                '$_answeredCount/$_totalCount',
                const Color(0xFFB45309),
                LucideIcons.messageSquare,
                const Color(0xFFFEF3C7),
              ),
              _buildStatItem(
                isSinhala ? 'ලකුණු දුන්' : 'Graded',
                '$_gradedCount/$_totalCount',
                AppColors.riskLow,
                LucideIcons.sparkles,
                const Color(0xFFDCFCE7),
              ),
              _buildStatItem(
                isSinhala ? 'ඉතිරි' : 'Remaining',
                '$_remainingToCompleteCount',
                AppColors.muted,
                LucideIcons.clock,
                const Color(0xFFF1F5F9),
              ),
            ]),
            if (_remainingToCompleteCount > 0) ...[
              const SizedBox(height: 14),
              _buildNoticeBanner(
                text: isSinhala
                    ? 'ප්‍රශ්න $_remainingToCompleteCount ක් සඳහා පිළිතුරු හෝ ලකුණු ඉතිරිව ඇත'
                    : '$_remainingToCompleteCount item(s) pending response or score',
                icon: LucideIcons.clock,
                color: const Color(0xFF92400E),
                background: const Color(0xFFFEF3C7),
                borderColor: const Color(0xFFF59E0B),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatGrid(List<Widget> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: items[i]),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < items.length ? items[i + 1] : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < items.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _buildQuestionsOverviewCard(bool isElder) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E1F6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            LucideIcons.listChecks,
            isSinhala ? 'ප්‍රශ්න දළ විශ්ලේෂණය' : 'Questions Overview',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Text(
                isElder
                    ? (isSinhala
                        ? '$_answeredCount / $_totalCount පිළිතුරු දී ඇත'
                        : '$_answeredCount / $_totalCount Answered')
                    : (isSinhala
                        ? '$_fullyCompletedCount / $_totalCount සම්පූර්ණයි'
                        : '$_fullyCompletedCount / $_totalCount Completed'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _questions.length,
              itemBuilder: (context, idx) {
                final q = _questions[idx];
                final isCurrent = idx == _currentIndex;
                final isGraded = _isGraded(q.id);
                final isAnswered = _isAnswered(q.id);
                final isComplete = _isFullyCompleted(q.id);
                final gradeValue = _grades[q.id];
                final bool isDone = isElder ? isAnswered : isComplete;
                final bool isPartial = !isDone && (isAnswered || isGraded);

                final Color rowBg = isCurrent
                    ? const Color(0xFFF5F3FF)
                    : isDone
                        ? const Color(0xFFF0FDF4)
                        : isPartial
                            ? const Color(0xFFFEF3C7)
                            : Colors.transparent;
                final Color numberBg = isCurrent
                    ? AppColors.primary
                    : isDone
                        ? const Color(0xFF15803D)
                        : isPartial
                            ? const Color(0xFFD97706)
                            : const Color(0xFFEDE9FE);
                final Color numberFg = (isCurrent || isDone)
                    ? Colors.white
                    : isPartial
                        ? Colors.white
                        : AppColors.primary;
                final Color labelColor = isCurrent
                    ? AppColors.primary
                    : isDone
                        ? const Color(0xFF14532D)
                        : isPartial
                            ? const Color(0xFF92400E)
                            : AppColors.navy;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _goToQuestion(idx),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: rowBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.primary.withValues(alpha: 0.6)
                                : isDone
                                    ? const Color(0xFFBBF7D0)
                                    : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: numberBg,
                                shape: BoxShape.circle,
                              ),
                              child: (isDone && !isCurrent)
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '${q.id}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: numberFg,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _translateCategory(q.category, isSinhala),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: labelColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isElder) ...[
                              if (isAnswered) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Text(
                                    isSinhala ? 'පිළිතුර සුරැකිණි' : 'Answer Saved',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  isCurrent
                                      ? LucideIcons.circleDot
                                      : LucideIcons.circle,
                                  size: 14,
                                  color: isCurrent
                                      ? AppColors.primary
                                      : const Color(0xFFCBD5E1),
                                ),
                              ],
                            ] else ...[
                              if (isComplete) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.lilac),
                                  ),
                                  child: Text(
                                    gradeValue!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.riskLow,
                                    ),
                                  ),
                                ),
                              ] else if (isGraded && !isAnswered) ...[
                                Text(
                                  isSinhala ? 'පිළිතුරක් නැත' : 'Missing answer',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  LucideIcons.alertCircle,
                                  size: 13,
                                  color: Color(0xFFB45309),
                                ),
                              ] else if (isAnswered && !isGraded) ...[
                                Text(
                                  isSinhala ? 'ලකුණු අපේක්ෂාවෙන්' : 'Awaiting score',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  LucideIcons.clock,
                                  size: 13,
                                  color: Color(0xFFB45309),
                                ),
                              ] else ...[
                                Icon(
                                  isCurrent
                                      ? LucideIcons.circleDot
                                      : LucideIcons.circle,
                                  size: 14,
                                  color: isCurrent
                                      ? AppColors.primary
                                      : const Color(0xFFCBD5E1),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(bool isElder) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E1F6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            isElder ? LucideIcons.info : LucideIcons.helpCircle,
            isElder
                ? (isSinhala ? 'වැඩිහිටි ඇගයීම් මාර්ගෝපදේශය' : 'Elder Assessment Guidance')
                : (isSinhala ? 'සායනික ඇගයීම් උපදෙස්' : 'Clinical Evaluation Tips'),
          ),
          const SizedBox(height: 12),
          Text(
            isElder
                ? (isSinhala
                    ? 'සෑම ප්‍රශ්නයකටම ඔබට අවශ්‍ය තරම් කාලය ගන්න. මයික්‍රොෆෝනය හෝ යතුරුපුවරුව භාවිතා කර පිළිතුරු ලබා දිය හැකිය. ඔබේ සත්කාරක කණ්ඩායම ඔබේ පිළිතුරු පරීක්ෂා කරනු ඇත.'
                    : 'Take as much time as you need for each question. You can answer using the microphone or keyboard. Your care team will review your responses.')
                : 'Guidance: ${_questions[_currentIndex].recommendedAnswerGuide}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.body,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCognitiveWellnessCompanionCard(CognitiveQuestionItem currentQ) {
    final isSinhala = ref.watch(languageProvider).isSinhala;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAF7FF), Color(0xFFF3EDFF), Color(0xFFEDE9FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatingAnimation.value * 0.7),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6C3FC5)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C3FC5).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(LucideIcons.sparkles, size: 14, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSinhala ? 'ප්‍රජානන සුවතා අවධානය' : 'Cognitive Vitality Focus',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _ambientPulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _ambientPulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSinhala ? 'සජීවී' : 'LIVE',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E1F6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.brain, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      isSinhala
                          ? 'අදාළ අංශය: ${_translateCategory(currentQ.category, true)}'
                          : 'Target Domain: ${currentQ.category}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _getDomainEncouragement(currentQ.domain, isSinhala),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.body,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Text(
                isSinhala ? 'ඇගයීම් රිද්මය' : 'Assessment Rhythm',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (index) {
                  return AnimatedBuilder(
                    animation: _waveformController,
                    builder: (context, child) {
                      final double phase = (_waveformController.value + (index * 0.22)) % 1.0;
                      final double height = 6.0 + 10.0 * (0.5 + 0.5 * (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2));
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 3.5,
                        height: height,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.5 + (0.5 * (index / 3.0))),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniWellnessPill(
                isSinhala ? 'ද්වි-භාෂා සහාය' : 'Dual-Language Sync',
                LucideIcons.languages,
              ),
              _buildMiniWellnessPill(
                isSinhala ? 'AI සහායක' : 'Conversational AI',
                LucideIcons.heart,
              ),
              _buildMiniWellnessPill(
                isSinhala ? 'කාරුණික රැකවරණය' : 'Empathetic Care',
                LucideIcons.sparkles,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDomainEncouragement(String domain, [bool isSinhala = false]) {
    final d = domain.toLowerCase();
    if (isSinhala) {
      if (d.contains('orientation')) {
        return 'කාලය සහ පරිසරය පිළිබඳ අවබෝධය වැඩිහිටි මානසික සන්සුන්තාවය වර්ධනය කරයි.';
      } else if (d.contains('memory') || d.contains('recall')) {
        return 'සන්සුන්ව සහ ඉවසීමෙන් මතකය අවදි කිරීමට ඉඩ ලබා දෙන්න.';
      } else if (d.contains('attention') || d.contains('calculation')) {
        return 'සන්සුන් මනසකින් පිළිතුරු දීම අවධානය සහ මතක ශක්තිය වැඩි කරයි.';
      } else if (d.contains('reasoning') || d.contains('judgment')) {
        return 'එදිනෙදා ජීවිතයේ ප්‍රායෝගික තීරණ ගැනීමේ හැකියාව මෙමගින් පරීක්ෂා කෙරේ.';
      }
      return 'සුහදශීලී සංවාදය මගින් ප්‍රජානන සුවතාවය වඩාත් නිවැරදිව හඳුනාගත හැක.';
    }
    if (d.contains('orientation')) {
      return 'Temporal and spatial grounding fosters resident security and reduces anxiety.';
    } else if (d.contains('memory') || d.contains('recall')) {
      return 'Allow a comfortable pause. Gentle patience enhances spontaneous memory recall.';
    } else if (d.contains('attention') || d.contains('calculation')) {
      return 'Focus on encouragement. High-stress environments hinder working memory.';
    } else if (d.contains('reasoning') || d.contains('judgment')) {
      return 'Logical reasoning questions measure practical problem-solving in daily elder living.';
    }
    return 'Conversational warmth and active listening improve assessment accuracy by over 30%.';
  }

  Widget _buildMiniWellnessPill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color, [
    IconData? icon,
    Color? iconBg,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBg ?? color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _speakDialogVoiceOver(String text, bool isSinhala) async {
    try {
      TtsService.instance.stop();
      await _flutterTts.stop();
      if (kIsWeb) {
        await TtsService.instance.speak(text, isSinhala: isSinhala);
      } else {
        await _flutterTts.setLanguage(isSinhala ? 'si-LK' : 'en-US');
        await _flutterTts.setSpeechRate(isSinhala ? 0.42 : 0.48);
        await _flutterTts.speak(text);
      }
    } catch (_) {}
  }

  void _stopDialogVoiceOver() {
    try {
      TtsService.instance.stop();
      _flutterTts.stop();
    } catch (_) {}
  }

  void _showFinishConfirmationDialog(bool isElder) {
    _saveCurrentQuestionState();
    final isSinhala = ref.read(languageProvider).isSinhala;
    final initialUnanswered = _questions
        .where((q) => !_isAnswered(q.id))
        .map((q) => q.id)
        .toList();
    final bool initialAllAnswered = initialUnanswered.isEmpty;
    final String elderSubmitVoice = initialAllAnswered
        ? (isSinhala
            ? 'හරිම හොඳයි! ඔබ ප්‍රශ්න දහයටම පිළිතුරු දී අවසන්. ප්‍රතිඵල බැලීමට පහත බොත්තම ඔබන්න.'
            : 'Well done! You answered all 10 questions. Tap Finish and See Result whenever you are ready.')
        : (isSinhala
            ? 'තව ප්‍රශ්න කිහිපයක් ඉතිරියි. අවසන් කිරීමට පෙර ඒවාටත් පිළිතුරු දෙන්න.'
            : 'Almost there! Please answer the remaining questions before finishing.');

    if (isElder) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          _speakDialogVoiceOver(elderSubmitVoice, isSinhala);
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final unansweredIds = _questions
                .where((q) => !_isAnswered(q.id))
                .map((q) => q.id)
                .toList();

            if (isElder) {
              final bool isAllAnswered = unansweredIds.isEmpty;
              final String voiceLine = isAllAnswered
                  ? (isSinhala
                      ? 'හරිම හොඳයි! ඔබ ප්‍රශ්න දහයටම පිළිතුරු දී අවසන්. ප්‍රතිඵල බැලීමට පහත බොත්තම ඔබන්න.'
                      : 'Well done! You answered all 10 questions. Tap Finish and See Result whenever you are ready.')
                  : (isSinhala
                      ? 'තව ප්‍රශ්න කිහිපයක් ඉතිරියි. අවසන් කිරීමට පෙර ඒවාටත් පිළිතුරු දෙන්න.'
                      : 'Almost there! Please answer the remaining questions before finishing.');

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: _AnimatedElderModalEntrance(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _SmartAiGradientBorderFrame(
                      borderRadius: 28,
                      isWarmAmber: !isAllAnswered,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Smart AI Luminous Animated Header Band
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isAllAnswered
                                            ? const [
                                                Color(0xFF1E1B4B),
                                                Color(0xFF4C1D95),
                                                Color(0xFF0F766E),
                                              ]
                                            : const [
                                                Color(0xFF451A03),
                                                Color(0xFFB45309),
                                                Color(0xFFD97706),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: AnimatedBuilder(
                                              animation: _floatingController,
                                              builder: (context, _) => CustomPaint(
                                                painter: _DialogCelebrationSparklesPainter(
                                                  progress: _floatingController.value,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Column(
                                          children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                            color: const Color(0xFF5EEAD4)
                                                .withValues(alpha: 0.50),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              LucideIcons.sparkles,
                                              size: 12.5,
                                              color: Color(0xFF5EEAD4),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              isSinhala
                                                  ? 'ප්‍රශ්න $_answeredCount / $_totalCount'
                                                  : '$_answeredCount / $_totalCount Completed',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _speakDialogVoiceOver(
                                            voiceLine,
                                            isSinhala,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  LucideIcons.volume2,
                                                  size: 13.5,
                                                  color: Color(0xFFFDE68A),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  isSinhala
                                                      ? 'නැවත අසන්න'
                                                      : 'Listen',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _ambientPulseAnimation,
                                        builder: (context, child) {
                                          final s = _ambientPulseAnimation.value;
                                          return Transform.scale(
                                            scale: 0.94 + 0.08 * s,
                                            child: child,
                                          );
                                        },
                                        child: Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: isAllAnswered
                                                  ? const [
                                                      Color(0xFF34D399),
                                                      Color(0xFF0D9488),
                                                    ]
                                                  : const [
                                                      Color(0xFFFDE68A),
                                                      Color(0xFFF59E0B),
                                                    ],
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isAllAnswered
                                                        ? const Color(0xFF34D399)
                                                        : const Color(0xFFF59E0B))
                                                    .withValues(alpha: 0.50),
                                                blurRadius: 18,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            isAllAnswered
                                                ? LucideIcons.checkCircle2
                                                : LucideIcons.alertCircle,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isAllAnswered
                                                  ? (isSinhala
                                                      ? 'හරිම හොඳයි! සියල්ල අවසන් 🎉'
                                                      : 'Well Done! All Done 🎉')
                                                  : (isSinhala
                                                      ? 'තව ප්‍රශ්න කිහිපයක් ඉතිරියි!'
                                                      : 'Almost Finished!'),
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              isAllAnswered
                                                  ? (isSinhala
                                                      ? 'පිළිතුරු 10ම සුරැකී ඇත'
                                                      : 'All 10 answers safely saved')
                                                  : (isSinhala
                                                      ? 'ප්‍රශ්න ${unansweredIds.length} කට පිළිතුරු දෙන්න'
                                                      : '${unansweredIds.length} question(s) left'),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white
                                                    .withValues(alpha: 0.88),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Clean Compact Body
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Cascading Animated 10-Dot Completion Strip
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      alignment: WrapAlignment.center,
                                      children: _questions.map((q) {
                                        final done = _isAnswered(q.id);
                                        return TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: Duration(
                                            milliseconds: 260 + (q.id * 55),
                                          ),
                                          curve: Curves.easeOutBack,
                                          builder: (context, val, child) =>
                                              Transform.scale(
                                            scale: val.clamp(0.0, 1.15),
                                            child: Opacity(
                                              opacity: val.clamp(0.0, 1.0),
                                              child: child,
                                            ),
                                          ),
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              gradient: done
                                                  ? const LinearGradient(
                                                      colors: [
                                                        Color(0xFF10B981),
                                                        Color(0xFF0D9488),
                                                      ],
                                                    )
                                                  : null,
                                              color: done
                                                  ? null
                                                  : const Color(0xFFFEF3C7),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: done
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFFF59E0B),
                                                width: 1.4,
                                              ),
                                            ),
                                            child: Center(
                                              child: done
                                                  ? const Icon(
                                                      LucideIcons.check,
                                                      size: 15,
                                                      color: Colors.white,
                                                    )
                                                  : Text(
                                                      '${q.id}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFFB45309),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 14),

                                  // Short Clear Prompt Box
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F6FF),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE5DEFA),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          isAllAnswered
                                              ? (isSinhala
                                                  ? 'ප්‍රතිඵල බැලීමට පහත බොත්තම ඔබන්න.'
                                                  : 'Tap Finish below to see your result.')
                                              : (isSinhala
                                                  ? 'අවසන් කිරීමට පෙර පහත ප්‍රශ්නවලට පිළිතුරු දෙන්න:'
                                                  : 'Tap a question below to finish answering:'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                        if (!isAllAnswered) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            alignment: WrapAlignment.center,
                                            children: unansweredIds.map((id) {
                                              return Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    _stopDialogVoiceOver();
                                                    Navigator.of(context).pop();
                                                    _goToQuestion(id - 1);
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        14,
                                                      ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFC4B5FD,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      isSinhala
                                                          ? 'ප්‍රශ්නය $id'
                                                          : 'Go to Q$id',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(0xFF6C3FC5),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  if (_submitError != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.riskHighBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.riskHigh,
                                        ),
                                      ),
                                      child: Text(
                                        _submitError!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.riskHigh,
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 18),

                                  // Crisp Action Buttons
                                  if (isAllAnswered) ...[
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6C3FC5),
                                            Color(0xFF8B5CF6),
                                            Color(0xFFEC4899),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF6C3FC5)
                                                .withValues(alpha: 0.30),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _isSubmitting
                                              ? null
                                              : () async {
                                                  _stopDialogVoiceOver();
                                                  setDialogState(
                                                    () => _isSubmitting = true,
                                                  );
                                                  await _submitElderResponses();
                                                  if (mounted) {
                                                    setDialogState(() {});
                                                  }
                                                },
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 15,
                                              horizontal: 18,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: _isSubmitting
                                                  ? [
                                                      const SizedBox(
                                                        width: 19,
                                                        height: 19,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2.4,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        isSinhala
                                                            ? 'යොමු කරමින්...'
                                                            : 'Submitting...',
                                                        style: const TextStyle(
                                                          fontSize: 16.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ]
                                                  : [
                                                      const Icon(
                                                        LucideIcons.send,
                                                        size: 17,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        isSinhala
                                                            ? 'අවසන් කර ප්‍රතිඵල බලන්න'
                                                            : 'Finish & See Result',
                                                        style: const TextStyle(
                                                          fontSize: 16.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                  ],

                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () {
                                              _stopDialogVoiceOver();
                                              Navigator.of(context).pop();
                                            },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF5B21B6),
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Color(0xFFDDD6FE),
                                          width: 1.4,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                          horizontal: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                      ),
                                      icon: const Icon(
                                        LucideIcons.arrowLeft,
                                        size: 15,
                                      ),
                                      label: Text(
                                        isAllAnswered
                                            ? (isSinhala
                                                ? 'පිළිතුරු නැවත බලන්න'
                                                : 'Review My Answers')
                                            : (isSinhala
                                                ? 'ප්‍රශ්න වෙත ආපසු යන්න'
                                                : 'Back to Questions'),
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
                ),
              );
            }

            // CAREGIVER Flow: Requires all 10 responses, then automatically evaluates and finalizes
            final uncompletedIds = unansweredIds;
            final bool isAllCompleted = uncompletedIds.isEmpty;
            final bool canSubmit = !_isSubmitting && isAllCompleted;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isAllCompleted
                        ? LucideIcons.checkCircle2
                        : LucideIcons.alertTriangle,
                    color: isAllCompleted
                        ? AppColors.riskLow
                        : const Color(0xFFB45309),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAllCompleted
                        ? 'Submit & Auto-Score Assessment'
                        : 'Assessment Incomplete',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Summary: $_answeredCount of $_totalCount questions answered for ${_resident?.name ?? 'Resident'}.',
                      style: const TextStyle(fontSize: 12, color: AppColors.body),
                    ),
                    if (!isAllCompleted) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.riskModerateBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.riskModerate),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.alertCircle,
                                  size: 16,
                                  color: Color(0xFFB45309),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${uncompletedIds.length} Question(s) Require Resident Response',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (unansweredIds.isNotEmpty) ...[
                              Text(
                                '• Unanswered: Question(s) ${unansweredIds.join(', ')}.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Text(
                              'Every question must have a recorded response before finalizing. Missing responses remain incomplete and cannot be graded as incorrect.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF92400E),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: uncompletedIds.map((id) {
                                return ActionChip(
                                  label: Text(
                                    'Go to Q$id',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _goToQuestion(id - 1);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.riskLowBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.riskLow),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              LucideIcons.checkCircle2,
                              size: 16,
                              color: AppColors.riskLow,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'All 10 questions have valid saved responses. Ready for automatic scoring and AI evaluation.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.riskLow,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.riskHighBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.riskHigh),
                        ),
                        child: Text(
                          _submitError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.riskHigh,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    isAllCompleted ? 'Review Answers' : 'Return to Assessment',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                ElevatedButton(
                  onPressed: canSubmit
                      ? () async {
                          setDialogState(() => _isSubmitting = true);
                          await _submitCaregiverAssessment();
                          if (mounted) setDialogState(() {});
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isAllCompleted
                              ? 'Submit & Calculate Score'
                              : 'Complete All 10 Items to Submit',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResultDialog(CognitiveSubmissionResult result) {
    final isSinhala = ref.read(languageProvider).isSinhala;
    final bool isElder = ref.read(authProvider).state.isElder;
    final bool isHighRisk =
        (result.riskLevel?.toLowerCase().contains('high') ?? false) ||
        (result.mlPrediction?.toLowerCase().contains('high') ?? false) ||
        (result.alertTriggered == true) ||
        (result.acrfScore != null && result.acrfScore! < 50.0);

    final String elderResultVoice = isHighRisk
        ? (isSinhala
            ? 'හොඳ උත්සාහයක්! අපි දැන් සතුටින් සැහැල්ලු මතක ක්‍රීඩාවක් කරමු.'
            : 'Great try! Let\'s play a fun and relaxing memory game together now.')
        : (isSinhala
            ? 'හරිම විශිෂ්ටයි! ඔබේ පිළිතුරු සුරැකුණා. කැමති නම් මතක ක්‍රීඩා කරන්න, නැතහොත් මුල් පිටුවට යන්න.'
            : 'Wonderful job! Your answers are saved. You can play fun memory games or go back home.');

    if (isElder) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) {
          _speakDialogVoiceOver(elderResultVoice, isSinhala);
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        if (isElder) {
          return _buildElderResultDialog(
            context: context,
            result: result,
            isSinhala: isSinhala,
            isHighRisk: isHighRisk,
            voiceText: elderResultVoice,
          );
        }
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE5E1F6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4C1D95).withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Decorative Header Band
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                      decoration: BoxDecoration(
                        gradient: isHighRisk
                            ? const LinearGradient(
                                colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFFE5E1F6), width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Icon Badge
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isHighRisk
                                  ? const LinearGradient(
                                      colors: [Color(0xFF8B5CF6), Color(0xFF6C3FC5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isHighRisk
                                          ? const Color(0xFF7C3AED)
                                          : const Color(0xFF10B981))
                                      .withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              isHighRisk ? LucideIcons.gamepad2 : LucideIcons.checkCheck,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isHighRisk
                                ? (isSinhala
                                    ? 'අපි මතක ක්‍රීඩා කරමු! 🧠🎮'
                                    : 'Let\'s Play Some Games! 🧠🎮')
                                : (isSinhala
                                    ? 'ප්‍රජානන ඇගයීම සාර්ථකව සුරැකිණි! 🎉'
                                    : 'Cognitive Assessment Saved! 🎉'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!isElder) ...[
                            const SizedBox(height: 4),
                            Text(
                              isSinhala
                                  ? '${result.residentName} • ඇගයීම: ${result.assessedBy ?? 'සුවතා විශේෂඥ'}'
                                  : '${result.residentName} • Evaluated by ${result.assessedBy ?? 'Care Specialist'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Dialog Body
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // High-Risk Dedicated Recommendation Hero Card
                          if (isHighRisk) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFFFAF5FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0xFFC4B5FD),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            LucideIcons.gamepad2,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isSinhala
                                                  ? 'අපි මතක ක්‍රීඩා කිහිපයක් කරමු! 🧠🎮'
                                                  : 'Let\'s play some memory games! 🧠🎮',
                                              style: const TextStyle(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF4C1D95),
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isSinhala
                                                  ? 'විනෝදජනක දෛනික මොළයේ ව්‍යායාම'
                                                  : 'Fun & engaging daily brain workout',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF7C3AED),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isSinhala
                                        ? 'විනෝදජනක මතක ක්‍රීඩා මගින් ඔබේ මතකය, අවධානය සහ සිතීමේ හැකියාව වර්ධනය කරගත හැක. අපි දැන්ම මතක ක්‍රීඩාවක් කරමු!'
                                        : 'Exercising memory, focus, and recall through enjoyable brain games helps boost mental agility and keep your thoughts refreshed. Let\'s play a fun game right now!',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF581C87),
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context, rootNavigator: true).pop();
                                        context.go('/dashboard/memory-games');
                                      },
                                      icon: const Icon(LucideIcons.gamepad2, size: 20),
                                      label: Text(
                                        isSinhala
                                            ? 'දැන්ම මතක ක්‍රීඩා කරමු! 🎮'
                                            : 'Let\'s Play Memory Games Now! 🎮',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C3AED),
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.45),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ACRF Score Card (No risk level text or tags shown to elder)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBFBFE),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE5E1F6),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.sparkles,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isElder
                                          ? (isSinhala
                                              ? 'ඔබේ මතක සුවතා ලකුණු'
                                              : 'YOUR WELLNESS SCORE')
                                          : (isSinhala
                                              ? 'ACRF ප්‍රජානන සුවතා ලකුණු'
                                              : 'ACRF COGNITIVE WELLNESS SCORE'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      result.acrfScore != null
                                          ? result.acrfScore!.toStringAsFixed(1)
                                          : 'N/A',
                                      style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.navy,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '/ 100',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isElder) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    isSinhala
                                        ? 'ACRF ස්ථාවර බර තැබීමේ ක්‍රමවේදය • සායනික ඇගයීම් පද්ධතිය'
                                        : (result.methodology ??
                                            'ACRF Fixed Base Weights • Clinical Evaluation Engine'),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category Breakdown (Caregiver/Clinical View Only)
                          if (!isElder) ...[
                            Row(
                              children: [
                                _buildCategoryCard(isSinhala ? 'මතකය' : 'Memory', result.memory ?? 0.0, 'w:25%', LucideIcons.brain),
                                const SizedBox(width: 8),
                                _buildCategoryCard(isSinhala ? 'අවධානය' : 'Attention', result.attention ?? 0.0, 'w:20%', LucideIcons.eye),
                                const SizedBox(width: 8),
                                _buildCategoryCard(isSinhala ? 'දිශානතිය' : 'Orientation', result.orientation ?? 0.0, 'w:20%', LucideIcons.compass),
                                const SizedBox(width: 8),
                                _buildCategoryCard(isSinhala ? 'සිහිකැඳවීම' : 'Recall', result.recall ?? 0.0, 'w:20%', LucideIcons.lightbulb),
                                const SizedBox(width: 8),
                                _buildCategoryCard(isSinhala ? 'තර්කනය' : 'Reasoning', result.reasoning ?? 0.0, 'w:15%', LucideIcons.puzzle),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ML / Caregiver Notice (Caregiver/Clinical View Only)
                          if (!isElder && result.mlAvailable) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(LucideIcons.sparkles, size: 14, color: Color(0xFFB45309)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isSinhala
                                          ? 'AI ආකෘති විශ්ලේෂණය: Random Forest AI මගින් සුවතා මට්ටම තක්සේරු කර ඇත.'
                                          : 'Experimental ML Model Demo: Evaluated with Random Forest inference for wellness baseline reference.',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF92400E),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Low/Moderate Risk: Choice Banner & Action Buttons (Elder chooses Dashboard or Games)
                          if (!isHighRisk) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: Row(
                                children: [
                                  const Text('✨', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isSinhala
                                          ? 'ඉතා විශිෂ්ටයි! ඔබේ මතකය තවදුරටත් ක්‍රියාශීලීව තබාගැනීමට මතක ක්‍රීඩා කරන්න, නැතහොත් ප්‍රධාන පුවරුවට පිවිසෙන්න.'
                                          : 'Great performance! Keep your brain active with optional memory games, or return to the overview.',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF5B21B6),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context, rootNavigator: true).pop();
                                      context.go('/dashboard');
                                    },
                                    icon: const Icon(LucideIcons.layoutDashboard, size: 16),
                                    label: Text(isSinhala ? 'ප්‍රධාන පුවරුවට' : 'Return to Dashboard'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.navy,
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFFE5E1F6), width: 1.3),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context, rootNavigator: true).pop();
                                      context.go('/dashboard/memory-games');
                                    },
                                    icon: const Icon(LucideIcons.gamepad2, size: 16),
                                    label: Text(isSinhala ? 'මතක ක්‍රීඩා කරන්න' : 'Play Memory Games'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 2,
                                      shadowColor: AppColors.primary.withValues(alpha: 0.35),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildElderResultDialog({
    required BuildContext context,
    required CognitiveSubmissionResult result,
    required bool isSinhala,
    required bool isHighRisk,
    required String voiceText,
  }) {
    final authState = ref.read(authProvider).state;
    final rawName =
        (result.residentName.trim().isNotEmpty && result.residentName.trim() != '-')
            ? result.residentName.trim()
            : (authState.userName?.trim().isNotEmpty == true
                ? authState.userName!.trim()
                : 'Friend');
    final displayName = isSinhala ? _toSinhalaName(rawName) : rawName;
    final double score = (result.acrfScore ?? 0.0).clamp(0.0, 100.0);
    final bool isGreat = !isHighRisk && score >= 80.0;
    final int starCount = isGreat
        ? 5
        : (!isHighRisk && score >= 65.0)
            ? 4
            : 3;

    final Color ringColor = isHighRisk
        ? const Color(0xFF8B5CF6)
        : (isGreat ? const Color(0xFF10B981) : const Color(0xFF6C3FC5));

    final String headline = isHighRisk
        ? (isSinhala
            ? 'හොඳ උත්සාහයක්, $displayName! 🎮'
            : 'Great Try, $rawName! 🎮')
        : isGreat
            ? (isSinhala
                ? 'හරිම විශිෂ්ටයි, $displayName! 🎉'
                : 'Wonderful Job, $rawName! 🎉')
            : (isSinhala
                ? 'ඉතා හොඳයි, $displayName! 🌟'
                : 'Well Done, $rawName! 🌟');

    final String statusPill = isHighRisk
        ? (isSinhala ? '💜 විනෝදජනක පුහුණුවට සූදානම්' : '💜 Fun Brain Practice Ready')
        : isGreat
            ? (isSinhala ? '✨ ඉතා හොඳ මතක ශක්තියක්' : '✨ Strong & Active Memory')
            : (isSinhala ? '💛 හොඳ මට්ටමක සිටී' : '💛 Doing Great Today');

    final String friendlyMessage = isHighRisk
        ? (isSinhala
            ? 'සැහැල්ලු මතක ක්‍රීඩා මගින් ඔබේ මතකය තවත් ප්‍රබෝධමත් වේ!'
            : 'Relaxing memory games keep your mind bright and happy!')
        : (isSinhala
            ? 'ඔබේ පිළිතුරු සුරැකුණා! කැමති නම් මතක ක්‍රීඩා කරන්න.'
            : 'Answers safely saved! Enjoy a fun memory game anytime.');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: _AnimatedElderModalEntrance(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: _SmartAiGradientBorderFrame(
            borderRadius: 28,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Smart AI Cosmic-Violet-to-Teal Animated Celebration Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isHighRisk
                              ? const [
                                  Color(0xFF1E1B4B),
                                  Color(0xFF5B21B6),
                                  Color(0xFFBE185D),
                                ]
                              : const [
                                  Color(0xFF1E1B4B),
                                  Color(0xFF4C1D95),
                                  Color(0xFF0F766E),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _floatingController,
                                builder: (context, _) => CustomPaint(
                                  painter: _DialogCelebrationSparklesPainter(
                                    progress: _floatingController.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF5EEAD4)
                                      .withValues(alpha: 0.52),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 12.5,
                                    color: Color(0xFF5EEAD4),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isSinhala
                                        ? 'මතක පරීක්ෂාව අවසන්'
                                        : 'MEMORY CHECK COMPLETE',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    _speakDialogVoiceOver(voiceText, isSinhala),
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.volume2,
                                        size: 13.5,
                                        color: Color(0xFFFDE68A),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isSinhala ? 'නැවත අසන්න' : 'Listen',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _ambientPulseAnimation,
                              builder: (context, child) {
                                final s = _ambientPulseAnimation.value;
                                return Transform.scale(
                                  scale: 0.94 + 0.08 * s,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: isHighRisk
                                        ? const [
                                            Color(0xFFFDE68A),
                                            Color(0xFFF59E0B),
                                          ]
                                        : const [
                                            Color(0xFF34D399),
                                            Color(0xFF0D9488),
                                          ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isHighRisk
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF34D399))
                                          .withValues(alpha: 0.50),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isHighRisk
                                      ? LucideIcons.gamepad2
                                      : LucideIcons.checkCheck,
                                  color: isHighRisk
                                      ? const Color(0xFF4C1D95)
                                      : Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                headline,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                        ],
                      ),
                  ),

                  // Sleek Compact Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isHighRisk) ...[
                          // Vibrant Playful Games Invitation Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF5B21B6),
                                  Color(0xFF7C3AED),
                                  Color(0xFFDB2777),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFF5EEAD4)
                                    .withValues(alpha: 0.50),
                                width: 1.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.28),
                                  blurRadius: 20,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Animated Floating Game Icon Trio
                                AnimatedBuilder(
                                  animation: _floatingController,
                                  builder: (context, _) {
                                    final dy =
                                        math.sin(_floatingController.value * math.pi) *
                                            5.0;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Transform.translate(
                                          offset: Offset(0, dy),
                                          child: _buildResultMiniGameOrb(
                                            '🧩',
                                            const Color(0xFFCCFBF1),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Transform.translate(
                                          offset: Offset(0, -4 - dy),
                                          child: _buildResultMiniGameOrb(
                                            '🌸',
                                            const Color(0xFFFEF3C7),
                                            large: true,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Transform.translate(
                                          offset: Offset(0, dy),
                                          child: _buildResultMiniGameOrb(
                                            '🧺',
                                            const Color(0xFFDBEAFE),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isSinhala
                                      ? 'අපි සතුටින් මතක ක්‍රීඩාවක් කරමු!'
                                      : 'Let\'s Enjoy a Fun Memory Game!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  friendlyMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _stopDialogVoiceOver();
                                      Navigator.of(context, rootNavigator: true)
                                          .pop();
                                      context.go('/dashboard/memory-games');
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            LucideIcons.gamepad2,
                                            size: 19,
                                            color: Color(0xFF6C3FC5),
                                          ),
                                          const SizedBox(width: 9),
                                          Text(
                                            isSinhala
                                                ? 'දැන්ම මතක ක්‍රීඩා කරමු! 🎮'
                                                : 'Play Memory Games Now! 🎮',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF4C1D95),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Compact Reassuring Score Strip
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F6FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE5DEFA),
                              ),
                            ),
                            child: Row(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0.0,
                                    end: result.acrfScore != null ? score : 0.0,
                                  ),
                                  duration: const Duration(milliseconds: 1100),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animScore, _) {
                                    return SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            height: 56,
                                            child: CircularProgressIndicator(
                                              value: result.acrfScore != null
                                                  ? (animScore / 100.0)
                                                  : 0.0,
                                              strokeWidth: 6.5,
                                              strokeCap: StrokeCap.round,
                                              backgroundColor:
                                                  const Color(0xFFEDE9FE),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                      Color>(
                                                Color(0xFF8B5CF6),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            result.acrfScore != null
                                                ? animScore.toStringAsFixed(0)
                                                : '—',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSinhala
                                            ? 'ඔබේ අද ලකුණු: ${score.toStringAsFixed(0)} / 100'
                                            : 'Today\'s Score: ${score.toStringAsFixed(0)} / 100',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isSinhala
                                            ? 'දිනපතා පුහුණුවෙන් මතකය තවත් ශක්තිමත් වේ 💛'
                                            : 'Daily practice keeps your memory bright 💛',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF5B4E7A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Horizontal Smart Score Showcase (Compact & Balanced!)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFCFAFF), Color(0xFFF5F0FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFE2D9F9),
                                width: 1.3,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Animated Counting Circular Score Ring (0 -> score)
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0.0,
                                    end: result.acrfScore != null ? score : 0.0,
                                  ),
                                  duration: const Duration(milliseconds: 1150),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animScore, _) {
                                    return SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 104,
                                            height: 104,
                                            child: CircularProgressIndicator(
                                              value: result.acrfScore != null
                                                  ? (animScore / 100.0)
                                                  : 0.0,
                                              strokeWidth: 9,
                                              strokeCap: StrokeCap.round,
                                              backgroundColor:
                                                  const Color(0xFFE9E2FA),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                ringColor,
                                              ),
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                result.acrfScore != null
                                                    ? animScore
                                                        .toStringAsFixed(0)
                                                    : '—',
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.navy,
                                                  height: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                isSinhala ? '100 න්' : '/ 100',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 18),

                                // Staggered Pop-In Stars + Status + Short Message
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: List.generate(5, (i) {
                                          final filled = i < starCount;
                                          return TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            duration: Duration(
                                              milliseconds: 460 + (i * 130),
                                            ),
                                            curve: Curves.easeOutBack,
                                            builder: (context, val, child) =>
                                                Transform.scale(
                                              scale: val.clamp(0.0, 1.2),
                                              child: Opacity(
                                                opacity: val.clamp(0.0, 1.0),
                                                child: child,
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 2,
                                              ),
                                              child: Text(
                                                filled ? '⭐' : '☆',
                                                style: TextStyle(
                                                  fontSize: filled ? 20 : 18,
                                                  color:
                                                      const Color(0xFFD1D5DB),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFF6EE7B7),
                                          ),
                                        ),
                                        child: Text(
                                          statusPill,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        friendlyMessage,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4B4266),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Side-by-side Crisp Action Buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _stopDialogVoiceOver();
                                    Navigator.of(context, rootNavigator: true)
                                        .pop();
                                    context.go('/dashboard');
                                  },
                                  icon: const Icon(LucideIcons.home, size: 16),
                                  label: Text(
                                    isSinhala ? 'මුල් පිටුව' : 'Home',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF5B21B6),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xFFDDD6FE),
                                      width: 1.4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6C3FC5),
                                        Color(0xFF8B5CF6),
                                        Color(0xFFEC4899),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6C3FC5)
                                            .withValues(alpha: 0.30),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _stopDialogVoiceOver();
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                        context.go('/dashboard/memory-games');
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                          horizontal: 14,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              LucideIcons.gamepad2,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                isSinhala
                                                    ? 'මතක ක්‍රීඩා කරන්න'
                                                    : 'Play Memory Games',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
      ),
    );
  }

  Widget _buildResultMiniGameOrb(
    String emoji,
    Color bg, {
    bool large = false,
  }) {
    final size = large ? 54.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: large ? 25 : 20)),
      ),
    );
  }

  Widget _buildCategoryCard(String title, double score, String weight, IconData icon) {
    final bool isHigh = score >= 75.0;
    final bool isModerate = score >= 50.0 && score < 75.0;
    final Color scoreColor = isHigh
        ? const Color(0xFF15803D)
        : isModerate
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    final Color scoreBg = isHigh
        ? const Color(0xFFDCFCE7)
        : isModerate
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E1F6), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scoreBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              weight,
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

}

/// Subtle, calming concentric wave ripples custom painter for elderly cognitive wellness
class _TherapeuticRipplesPainter extends CustomPainter {
  final double animationValue;

  _TherapeuticRipplesPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.024)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final paint2 = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Gentle therapeutic breathing ripple wave center 1 (top right)
    final center1 = Offset(size.width * 0.88, size.height * 0.12);
    for (int i = 1; i <= 3; i++) {
      final r = 90.0 * i + (animationValue * 30.0);
      canvas.drawCircle(center1, r, paint1);
    }

    // Gentle therapeutic breathing ripple wave center 2 (bottom left)
    final center2 = Offset(size.width * 0.08, size.height * 0.72);
    for (int i = 1; i <= 3; i++) {
      final r = 80.0 * i + ((1.0 - animationValue) * 26.0);
      canvas.drawCircle(center2, r, paint2);
    }
  }

  @override
  bool shouldRepaint(covariant _TherapeuticRipplesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Animated swaying flower garden painter for the bottom of the Elder Cognitive Assessment view
class _SwayingFloralMeadowPainter extends CustomPainter {
  final double swayValue;
  final double breezeValue;

  _SwayingFloralMeadowPainter({
    required this.swayValue,
    required this.breezeValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Soft rolling pastel garden hill at the base
    final hillPath1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * (0.50 + 0.04 * swayValue),
        size.width * 0.52,
        size.height * 0.66,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * (0.80 - 0.04 * swayValue),
        size.width,
        size.height * 0.60,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final hillPaint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFDDD6FE).withValues(alpha: 0.42),
          const Color(0xFFC4B5FD).withValues(alpha: 0.68),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(hillPath1, hillPaint1);

    final hillPath2 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * (0.64 - 0.03 * swayValue),
        size.width * 0.68,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * (0.84 + 0.03 * swayValue),
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final hillPaint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFEDE9FE).withValues(alpha: 0.55),
          const Color(0xFFD8B4FE).withValues(alpha: 0.75),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(hillPath2, hillPaint2);

    // 2. Swaying Flowers across the meadow
    final flowerSpecs = <List<double>>[
      // [xRatio, stemHeight, petalRadius, phaseOffset, colorIdx]
      [0.06, 56, 10.5, 0.0, 0],
      [0.12, 42, 8.5, 0.8, 1],
      [0.18, 64, 12.0, 1.5, 2],
      [0.25, 48, 9.5, 2.2, 3],
      [0.32, 58, 11.0, 0.4, 0],
      [0.39, 44, 8.5, 1.9, 1],
      [0.46, 62, 11.5, 2.8, 2],
      [0.54, 50, 9.5, 0.7, 3],
      [0.61, 60, 11.0, 1.3, 0],
      [0.68, 45, 8.5, 2.5, 1],
      [0.75, 65, 12.0, 0.3, 2],
      [0.82, 47, 9.0, 1.7, 3],
      [0.88, 58, 11.0, 2.1, 0],
      [0.94, 44, 8.5, 0.9, 1],
    ];

    const petalPalettes = <List<Color>>[
      [Color(0xFFA78BFA), Color(0xFF7C3AED)], // Lavender Violet
      [Color(0xFFF472B6), Color(0xFFEC4899)], // Soft Rose Pink
      [Color(0xFFC084FC), Color(0xFF9333EA)], // Orchid Purple
      [Color(0xFF818CF8), Color(0xFF6366F1)], // Periwinkle Indigo
    ];

    for (final spec in flowerSpecs) {
      final xBase = size.width * spec[0];
      final yBase = size.height;
      final stemH = spec[1];
      final petalR = spec[2];
      final phase = spec[3];
      final palette = petalPalettes[spec[4].toInt() % petalPalettes.length];

      // Smooth sinusoidal sway offset
      final wave = math.sin((swayValue * math.pi) + phase) * 11.0 +
          math.cos((breezeValue * 2 * math.pi) + phase) * 4.0;
      final xTip = xBase + wave;
      final yTip = yBase - stemH;

      // Draw curved stem
      final stemPath = Path()
        ..moveTo(xBase, yBase)
        ..quadraticBezierTo(
          xBase + wave * 0.45,
          yBase - stemH * 0.55,
          xTip,
          yTip,
        );

      final stemPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(stemPath, stemPaint);

      // Draw pair of small swaying leaves on the stem
      final leafX = xBase + wave * 0.48;
      final leafY = yBase - stemH * 0.45;
      final leafPaint = Paint()
        ..color = const Color(0xFF34D399).withValues(alpha: 0.60)
        ..style = PaintingStyle.fill;

      final leftLeaf = Path()
        ..moveTo(leafX, leafY)
        ..quadraticBezierTo(leafX - 11, leafY - 7, leafX - 14, leafY - 1)
        ..quadraticBezierTo(leafX - 7, leafY + 4, leafX, leafY);
      canvas.drawPath(leftLeaf, leafPaint);

      final rightLeaf = Path()
        ..moveTo(leafX, leafY - 5)
        ..quadraticBezierTo(leafX + 11, leafY - 12, leafX + 14, leafY - 6)
        ..quadraticBezierTo(leafX + 7, leafY - 1, leafX, leafY - 5);
      canvas.drawPath(rightLeaf, leafPaint);

      // Draw 6 blooming petals around (xTip, yTip)
      final petalPaint = Paint()
        ..color = palette[0].withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      final petalInnerPaint = Paint()
        ..color = palette[1].withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;

      final rotOffset = wave * 0.03;
      for (int p = 0; p < 6; p++) {
        final angle = (p * math.pi / 3.0) + rotOffset;
        final px = xTip + math.cos(angle) * (petalR * 0.68);
        final py = yTip + math.sin(angle) * (petalR * 0.68);
        canvas.drawCircle(Offset(px, py), petalR * 0.56, petalPaint);
        canvas.drawCircle(Offset(px, py), petalR * 0.30, petalInnerPaint);
      }

      // Warm golden flower center
      final centerGlow = Paint()
        ..color = const Color(0xFFFDE68A)
        ..style = PaintingStyle.fill;
      final centerCore = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(xTip, yTip), petalR * 0.42, centerGlow);
      canvas.drawCircle(Offset(xTip, yTip), petalR * 0.25, centerCore);
    }

    // 3. Gentle floating petals & sparkles drifting above the flowers
    for (int i = 0; i < 8; i++) {
      final px = size.width * (0.10 + i * 0.11) +
          math.sin((breezeValue * 2 * math.pi) + i) * 14.0;
      final py = size.height * 0.22 +
          math.cos((swayValue * math.pi) + i * 0.9) * 10.0;
      final dotPaint = Paint()
        ..color = (i.isEven ? const Color(0xFFF472B6) : const Color(0xFFA78BFA))
            .withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: 7, height: 4.5),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SwayingFloralMeadowPainter oldDelegate) {
    return oldDelegate.swayValue != swayValue ||
        oldDelegate.breezeValue != breezeValue;
  }
}

class _AnimatedElderModalEntrance extends StatelessWidget {
  final Widget child;

  const _AnimatedElderModalEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutBack,
      builder: (context, t, modal) {
        final opacity = t.clamp(0.0, 1.0);
        final scale = 0.88 + (0.12 * t);
        final offsetY = (1.0 - opacity) * 18.0;
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(opacity: opacity, child: modal),
          ),
        );
      },
      child: child,
    );
  }
}

class _DialogCelebrationSparklesPainter extends CustomPainter {
  final double progress;

  _DialogCelebrationSparklesPainter({required this.progress});

  static const List<List<double>> _dots = [
    [0.08, 0.25, 4.5, 0.0, 0.0],
    [0.20, 0.78, 3.8, 1.2, 1.0],
    [0.34, 0.18, 5.0, 2.1, 2.0],
    [0.52, 0.85, 3.6, 0.8, 0.0],
    [0.68, 0.22, 4.8, 2.8, 1.0],
    [0.82, 0.72, 4.2, 1.6, 2.0],
    [0.92, 0.30, 5.2, 0.4, 0.0],
    [0.14, 0.52, 3.2, 3.1, 2.0],
    [0.76, 0.48, 3.5, 2.4, 1.0],
  ];

  static const List<Color> _colors = [
    Color(0xFF5EEAD4), // Aurora Teal
    Color(0xFFFDE68A), // Celebration Gold
    Color(0xFFF9A8D4), // Soft Rose
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final angle = progress * math.pi * 2;
    for (final d in _dots) {
      final cx = d[0] * size.width + math.sin(angle + d[3]) * 8.0;
      final cy = d[1] * size.height + math.cos(angle + d[3]) * 7.0;
      final pulse = 0.55 + 0.45 * math.sin(angle * 1.5 + d[3]);
      final r = d[2] * (0.75 + 0.3 * pulse);
      final color = _colors[d[4].toInt()].withValues(alpha: 0.36 * pulse);

      final path = Path()
        ..moveTo(cx, cy - r)
        ..quadraticBezierTo(cx, cy, cx + r, cy)
        ..quadraticBezierTo(cx, cy, cx, cy + r)
        ..quadraticBezierTo(cx, cy, cx - r, cy)
        ..quadraticBezierTo(cx, cy, cx, cy - r)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _DialogCelebrationSparklesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SmartAiGradientBorderFrame extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final bool isWarmAmber;

  const _SmartAiGradientBorderFrame({
    required this.child,
    this.borderRadius = 28,
    this.isWarmAmber = false,
  });

  @override
  State<_SmartAiGradientBorderFrame> createState() =>
      _SmartAiGradientBorderFrameState();
}

class _SmartAiGradientBorderFrameState
    extends State<_SmartAiGradientBorderFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = widget.isWarmAmber
        ? const [
            Color(0xFFF59E0B),
            Color(0xFFFDE68A),
            Color(0xFFEC4899),
            Color(0xFF8B5CF6),
            Color(0xFFF97316),
            Color(0xFFF59E0B),
          ]
        : const [
            Color(0xFF7C3AED),
            Color(0xFF38BDF8),
            Color(0xFF2DD4BF),
            Color(0xFFA78BFA),
            Color(0xFFEC4899),
            Color(0xFFFDE68A),
            Color(0xFF7C3AED),
          ];

    final Color glowPrimary = widget.isWarmAmber
        ? const Color(0xFFF59E0B)
        : const Color(0xFF7C3AED);
    final Color glowSecondary = widget.isWarmAmber
        ? const Color(0xFFEC4899)
        : const Color(0xFF2DD4BF);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * math.pi * 2;
        final pulse = 0.85 + 0.15 * math.sin(angle * 2);

        return Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              colors: gradientColors,
              transform: GradientRotation(angle),
            ),
            boxShadow: [
              BoxShadow(
                color: glowPrimary.withValues(alpha: 0.34 * pulse),
                blurRadius: 34,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: glowSecondary.withValues(alpha: 0.26 * pulse),
                blurRadius: 26,
                spreadRadius: 1,
                offset: const Offset(0, -4),
              ),
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.16 * pulse),
                blurRadius: 20,
                offset: const Offset(8, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
