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

import '../../../core/responsive/responsive_builder.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_carevora_data.dart';
import '../../../data/models/carevora_models.dart';
import '../../../shared/widgets/carevora_avatar.dart';
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
  // Navigation & session index (10 questions battery)
  int _currentIndex = 0;
  final List<CognitiveQuestionItem> _questions = CognitiveScoring.questions;

  // Single Source of Truth: Question grades (id -> 1.0, 0.5, 0.0, or null if ungraded)
  final Map<int, double?> _grades = {};

  // Single Source of Truth: Per-question response text (manual keyboard or voice transcribed)
  final Map<int, String> _responses = {};
  late TextEditingController _responseController;

  // Timing: active question viewing duration
  final Map<int, double> _questionTimes = {};
  late DateTime _questionStartTime;
  int _sessionElapsedSeconds = 0;
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

  // Session lifecycle & persistence
  String? _sessionId;
  String _sessionStatus = 'IN_PROGRESS'; // 'IN_PROGRESS', 'PENDING_CAREGIVER_REVIEW', 'COMPLETED'

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

          // If this end-status belongs to a previous question session, do NOT cancel
          // the listening state or overwrite the status of the new question!
          if (_listeningQId != -1 && currentQId != -1 && _listeningQId != currentQId) {
            debugPrint(
              '[CARE-STT] Ignoring late end status "$status" from Q$_listeningQId while active on Q$currentQId',
            );
            return;
          }

          setState(() {
            _isListening = false;
            final text = _responseController.text.trim();
            debugPrint(
              '[CARE-STT] [7. Final Save Tracking] End status "$status". '
              'Buffer to save: "$text", targetQ=$currentQId',
            );
            if (currentQId != -1) {
              if (text.isNotEmpty) {
                _responses[currentQId] = text;
                _grades[currentQId] = CognitiveScoring.scoreQuestion(currentQId, text);
                _speechStatusMessage = 'Voice response captured.';
                _persistResponses();
              } else {
                if (_speechStatusMessage == 'Listening... Speak now.') {
                  _speechStatusMessage =
                      'Speech not recognized. Please tap the microphone to retry or type your answer.';
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
        setState(() {
          _isListening = false;
          final existing = _responseController.text.trim();
          if (existing.isNotEmpty && _currentIndex < _questions.length) {
            final qId = _questions[_currentIndex].id;
            _responses[qId] = existing;
            if (_grades[qId] == null) {
              _grades[qId] = CognitiveScoring.scoreQuestion(qId, existing);
            }
            _speechStatusMessage = 'Voice response captured.';
            _persistResponses();
          } else {
            if (errorMsg.contains('aborted')) {
              return;
            }
            if (errorMsg.contains('no-speech') || errorMsg.contains('error_no_match')) {
              _speechStatusMessage =
                  'Speech not recognized. Please tap the microphone to retry or type your answer.';
            } else if (errorMsg.contains('not-allowed') || errorMsg.contains('permission')) {
              _speechStatusMessage =
                  'Microphone permission denied. Please allow microphone access in Chrome or type your answer.';
            } else if (errorMsg.contains('network')) {
              _speechStatusMessage =
                  'Speech service network issue. Please check connection or type your answer.';
            } else if (errorMsg.contains('already started') || errorMsg.contains('invalidstateerror')) {
              _speechStatusMessage =
                  'Please tap the microphone again to speak.';
            } else {
              _speechStatusMessage =
                  'Audio note: $errorMsg. Please retry or type your answer.';
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
        setState(() => _sessionElapsedSeconds++);
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
      _responses.clear();
      _grades.clear();
      _questionTimes.clear();
      _currentIndex = 0;
      _responseController.clear();
      _isListening = false;
      _isSpeaking = false;
      _speechStatusMessage = null;
      _sessionId = null;
      _sessionStatus = 'IN_PROGRESS';
    });
    _loadSavedResidentResponses(residentId);
  }

  Future<void> _startNewAssessmentSession() async {
    final residentId = _resident?.id ?? ref.read(authProvider).state.residentId;
    if (residentId == null) return;
    final token = ref.read(authProvider).state.token;

    _saveCurrentQuestionState();
    setState(() {
      _grades.clear();
      _responses.clear();
      _questionTimes.clear();
      _currentIndex = 0;
      _responseController.clear();
      _sessionElapsedSeconds = 0;
      _sessionId = null;
      _sessionStatus = 'IN_PROGRESS';
    });

    try {
      final session = await CognitiveAssessmentService.startSession(
        residentId: residentId,
        token: token,
      );
      if (mounted) {
        setState(() {
          _sessionId = session.sessionId;
          _sessionStatus = 'IN_PROGRESS';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSavedResidentResponses(int residentId) async {
    final token = ref.read(authProvider).state.token;

    // 1. First retrieve active/pending session from the existing backend
    try {
      final pendingSession = await CognitiveAssessmentService.getPendingSession(
        residentId: residentId,
        token: token,
      );
      if (pendingSession != null && mounted) {
        setState(() {
          _sessionId = pendingSession.sessionId;
          _sessionStatus = pendingSession.status;
          if (pendingSession.responses.isNotEmpty) {
            _responses.addAll(pendingSession.responses);
          }
          if (pendingSession.grades.isNotEmpty) {
            _grades.addAll(pendingSession.grades);
          }
          if (pendingSession.questionTimes.isNotEmpty) {
            _questionTimes.addAll(pendingSession.questionTimes);
          }
          _responseController.text =
              _responses[_questions[_currentIndex].id] ?? '';
        });
        return;
      }
    } catch (_) {}

    // 2. If no pending session, start a new session on backend
    if (_sessionId == null) {
      try {
        final newSession = await CognitiveAssessmentService.startSession(
          residentId: residentId,
          token: token,
        );
        if (mounted) {
          setState(() {
            _sessionId = newSession.sessionId;
            _sessionStatus = 'IN_PROGRESS';
          });
        }
      } catch (_) {}
    }

    // 3. SharedPreferences offline fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('cognitive_responses_$residentId');
      if (savedJson != null && savedJson.isNotEmpty) {
        final decoded = json.decode(savedJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            decoded.forEach((key, val) {
              final qId = int.tryParse(key);
              if (qId != null && val is String && val.trim().isNotEmpty) {
                _responses[qId] ??= val;
              }
            });
            _responseController.text =
                _responses[_questions[_currentIndex].id] ?? '';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _persistResponses() async {
    final rId = _resident?.id ?? ref.read(authProvider).state.residentId;
    if (rId == null) return;

    final token = ref.read(authProvider).state.token;

    // Save to existing backend H2 database
    if (_sessionId != null) {
      try {
        await CognitiveAssessmentService.saveResponses(
          sessionId: _sessionId!,
          responses: _responses,
          questionTimes: _questionTimes,
          token: token,
        );
      } catch (_) {}
    }

    // Local SharedPreferences fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        for (final e in _responses.entries) e.key.toString(): e.value,
      };
      await prefs.setString('cognitive_responses_$rId', json.encode(map));
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
    if (_isSpeaking) _flutterTts.stop();
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
    if (_grades[qId] == null && text.trim().isNotEmpty) {
      _grades[qId] = CognitiveScoring.scoreQuestion(qId, text);
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
        setState(() {
          _isListening = false;
          final text = _responseController.text.trim();
          if (text.isNotEmpty && _currentIndex < _questions.length) {
            final qId = _questions[_currentIndex].id;
            _responses[qId] = text;
            _grades[qId] = CognitiveScoring.scoreQuestion(qId, text);
            _speechStatusMessage = 'Voice response captured.';
            _persistResponses();
            _triggerSaveAnimation();
          }
        });
      }
    }
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isSpeakingPrompt = false;
        });
      }
    } else {
      _isSpeakingPrompt = true;
      if (mounted) setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
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

      // On Web (especially Chrome), calling stop() and then immediately speak()
      // causes Chrome to cancel the new utterance because the cancellation event
      // is still asynchronously processing in the browser event loop.
      // Allowing a 250ms settle delay ensures flutter_tts_web transitions back to
      // stopped state so 'Next question' is voiced reliably on every question transition.
      await _flutterTts.stop();
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.50);
      await _flutterTts.speak('Next question');
    } catch (e) {
      debugPrint('[CARE-TTS] Failed to speak next question: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (_isTogglingMic) return;
    _isTogglingMic = true;

    try {
      final qId = _currentIndex < _questions.length ? _questions[_currentIndex].id : -1;
      debugPrint(
        '[CARE-STT] [1. Mic Pressed] qId=$qId, isListening=$_isListening, '
        'speechListening=${_speech.isListening}, isSpeaking=$_isSpeaking, '
        'speechAvailable=$_speechAvailable, speechInitialized=$_speechInitialized, '
        'currentBuffer="${_responseController.text}"',
      );

      // 1. Promptly stop any active TTS output so audio playback does not conflict with microphone capture
      if (_isSpeaking) {
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
              _speechStatusMessage = 'Voice response captured.';
              _persistResponses();
              _triggerSaveAnimation();
            } else {
              _speechStatusMessage =
                  'Speech not recognized. Please tap the microphone to retry or type your answer.';
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
          _speechStatusMessage =
              'Microphone not available. Please enter the answer manually below or apply caregiver clinical scoring.';
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
      setState(() {
        _isListening = true;
        _speechStatusMessage = 'Listening... Speak now.';
      });

      final currentSessionId = ++_activeListeningSessionId;
      final targetQId = qId;

      try {
        debugPrint(
          '[CARE-STT] [3. Listen Start Attempt] Calling _speech.listen for qId=$targetQId (session $currentSessionId), '
          'currentText="${_responseController.text}"',
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
                _currentIndex >= _questions.length ||
                _questions[_currentIndex].id != targetQId) {
              debugPrint(
                '[CARE-STT] Late callback saved for targetQ=$targetQId while current=${_currentIndex < _questions.length ? _questions[_currentIndex].id : -1}',
              );
              if (incomingTrimmed.isNotEmpty) {
                _responses[targetQId] = incoming;
                if (_grades[targetQId] == null) {
                  _grades[targetQId] =
                      CognitiveScoring.scoreQuestion(targetQId, incoming);
                }
                _persistResponses();
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
                  _responses[targetQId] = incoming;
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
            localeId: 'en_US',
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
                _currentIndex < _questions.length &&
                _questions[_currentIndex].id == targetQId) {
              _listeningQId = targetQId;
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
                      _currentIndex >= _questions.length ||
                      _questions[_currentIndex].id != targetQId) {
                    if (incomingTrimmed.isNotEmpty) {
                      _responses[targetQId] = incoming;
                      if (_grades[targetQId] == null) {
                        _grades[targetQId] =
                            CognitiveScoring.scoreQuestion(targetQId, incoming);
                      }
                      _persistResponses();
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
                        _responses[targetQId] = incoming;
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
                  localeId: 'en_US',
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
              _speechStatusMessage =
                  'Microphone permission denied. Please allow microphone access in Chrome or type your answer.';
            } else {
              _speechStatusMessage = 'Please tap the microphone again to speak.';
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

    // Auto-grade all answered questions using question-specific deterministic rubric
    final autoGrades = CognitiveScoring.autoScoreBattery(_responses);
    for (final e in autoGrades.entries) {
      if (_grades[e.key] == null && e.value != null) {
        _grades[e.key] = e.value;
      }
    }

    final unanswered = CognitiveScoring.getUnansweredQuestionIds(_responses);
    if (unanswered.isNotEmpty) {
      setState(() {
        _isSubmitting = false;
        _submitError =
            'Cannot submit: Question(s) ${unanswered.join(', ')} are unanswered. All 10 questions must have responses before automatic evaluation.';
      });
      return;
    }

    final authState = ref.read(authProvider).state;
    final token = authState.token;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final accuracies = CognitiveScoring.calculateDomainAccuracies(_grades);
      final taskScores = CognitiveScoring.calculateDomainScores(accuracies);
      final responseTimes = CognitiveScoring.aggregateDomainResponseTimes(
        _questionTimes,
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

      if (_sessionId == null) {
        final session = await CognitiveAssessmentService.startSession(
          residentId: residentId,
          token: token,
        );
        _sessionId = session.sessionId;
      }

      if (_sessionId != null) {
        try {
          await CognitiveAssessmentService.saveResponses(
            sessionId: _sessionId!,
            responses: _responses,
            questionTimes: _questionTimes,
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
        sessionId: _sessionId,
        responses: _responses,
        grades: {
          for (final e in _grades.entries)
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
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _sessionStatus = result.status;
          _sessionId = null;
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final bool isElder = authState.isElder;

    final currentQ = _questions[_currentIndex];
    final currentGrade = _grades[currentQ.id];
    final progressPct = _getProgressPct(isElder);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      body: Stack(
        children: [
          // Subtle, calm therapeutic animated background suitable for elderly users
          Positioned.fill(
            child: _buildSubtleTherapeuticBackground(),
          ),

          // Main scrollable workspace
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Bar & Timer (Responsive Wrap)
                _buildTopNavBar(),
                const SizedBox(height: 16),

                if (!isElder && _isLoadingResidents) ...[
                  _buildLoadingResidentsState(),
                ] else if (!isElder && _residentLoadError != null) ...[
                  _buildResidentErrorState(_residentLoadError!),
                ] else if (!isElder && _availableResidents.isEmpty) ...[
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
                      Color(0xFFFAF9FF),
                      Color(0xFFF5F1FD),
                      Color(0xFFF7F4FE),
                      Color(0xFFFBF9FE),
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
                  width: 460,
                  height: 460,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withValues(alpha: 0.08),
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
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.065),
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
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0D9488).withValues(alpha: 0.038),
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

  Widget _buildTopNavBar() {
    Color statusBg;
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (_sessionStatus == 'COMPLETED') {
      statusBg = const Color(0xFFDCFCE7);
      statusColor = const Color(0xFF15803D);
      statusLabel = 'Completed';
      statusIcon = LucideIcons.circleCheckBig;
    } else if (_sessionStatus == 'PENDING_CAREGIVER_REVIEW') {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFB45309);
      statusLabel = 'Pending Caregiver Review';
      statusIcon = LucideIcons.alertCircle;
    } else {
      statusBg = const Color(0xFFEEF2FF);
      statusColor = const Color(0xFF4F46E5);
      statusLabel = 'In Progress';
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
                    children: const [
                      Icon(LucideIcons.arrowLeft, size: 15, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Resident Directory',
                        style: TextStyle(
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
                    children: const [
                      Icon(LucideIcons.plus, size: 14, color: AppColors.primary),
                      SizedBox(width: 5),
                      Text(
                        'New Assessment',
                        style: TextStyle(
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
                  const Text(
                    'Session Elapsed: ',
                    style: TextStyle(
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
    final res = _resident;
    final initials = res != null ? _getInitials(res.name) : (isElder ? 'JP' : 'R');
    final displayName = (res != null && res.name.trim().isNotEmpty && res.name.trim() != '-')
        ? res.name.trim()
        : (isElder ? 'James Perera' : 'Resident #${res?.id ?? 5}');
    const facilityName = 'Serenity Elder Home';
    final ageDisplay = res?.age != null ? '${res!.age} yrs' : '75 yrs';
    final roomDisplay = (res?.roomNumber != null && res!.roomNumber.isNotEmpty)
        ? 'Room ${res.roomNumber}'
        : 'Room 101';
    final educationDisplay = res?.educationYears != null
        ? '${res!.educationYears} yrs'
        : '12 yrs';

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
                              isElder ? 'ELDER / RESIDENT' : 'ID: ${res?.id ?? 5}',
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
                        label: 'Age: $ageDisplay',
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
                        label: 'Education: $educationDisplay',
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
                            ? 'Self-Response Session ($_totalCount Items)'
                            : 'Standard Cognitive Battery ($_totalCount Items)',
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
                'Question ${_currentIndex + 1} of $_totalCount',
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
                    ? 'Questions Answered: $_answeredCount/$_totalCount ($progressPct%) • Self-Paced Wellness'
                    : 'Completed: $_fullyCompletedCount/$_totalCount ($progressPct%) • Answered: $_answeredCount • Graded: $_gradedCount',
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
          label: '$progressPct% completed',
          icon: LucideIcons.listChecks,
          background: const Color(0xFFF5F3FF),
          color: AppColors.primary,
          borderColor: const Color(0xFFDDD6FE),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(bool isElder) {
    return Row(
      children: List.generate(_questions.length, (i) {
        final q = _questions[i];
        final bool isCurrent = i == _currentIndex;
        final bool isDone = isElder ? _isAnswered(q.id) : _isFullyCompleted(q.id);

        return Expanded(
          flex: isCurrent ? 3 : 2,
          child: Tooltip(
            message: 'Question ${i + 1}: ${q.category}${isDone ? ' (Completed)' : ''}',
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
                              label: currentQ.category,
                              icon: LucideIcons.brain,
                              background: const Color(0xFFF5F3FF),
                              color: AppColors.primary,
                              borderColor: const Color(0xFFDDD6FE),
                            ),
                          ),
                          _buildInfoChip(
                            label: 'Domain: ${currentQ.domain}',
                            icon: LucideIcons.compass,
                            color: const Color(0xFF475569),
                            background: const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFFE2E8F0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildListenButton(currentQ.prompt),
                  ],
                ),
                const SizedBox(height: 20),

                // Question Prompt (high-contrast, large, accessible for elderly)
                Text(
                  currentQ.prompt,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    letterSpacing: -0.3,
                  ),
                ),

                // Sinhala Bilingual Prompt Card
                if (currentQ.promptSinhala.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFAF8FF), Color(0xFFF3EDFD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDDD6FE), width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C3FC5).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C3FC5).withValues(alpha: 0.28),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'සිංහල',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            currentQ.promptSinhala,
                            style: const TextStyle(
                              fontSize: 21,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B2F7E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                                ? 'Helpful Tip: Take your time. Speak clearly into the microphone or type your answer.'
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
    final bool isPlaying = _isSpeaking;
    return Tooltip(
      message: isPlaying ? 'Stop reading' : 'Read question aloud',
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
                  const Text(
                    'Stop Audio',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ] else ...[
                  const Icon(LucideIcons.volume2, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Read Aloud',
                    style: TextStyle(
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
                        const Text(
                          'Answer Saved',
                          style: TextStyle(
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
                      answered ? 'Answer Saved' : 'Self-Paced Response',
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
                        child: const Text(
                          '✅ Auto-Saved',
                          style: TextStyle(
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
                      ? 'Your answer is securely recorded. The clinical engine evaluates and scores it upon submission.'
                      : 'Type or speak your answer above. The system will safely evaluate your response.',
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
    final bool hasStatus = _speechStatusMessage != null;
    final bool statusOk = hasStatus && _speechStatusMessage!.contains('captured');
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
                    ? 'Listening to speech...'
                    : (isElder ? 'Your Answer' : 'Response Capture'),
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
                        isElder ? 'Voice or Keyboard' : 'Voice & Clinical Grading',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      _buildPrimaryActionButton(
                        label: isLastQuestion
                            ? (isElder ? 'Finish & Submit' : 'Finish Assessment')
                            : 'Next Question →',
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
                            ? 'Listening… tap the mic to stop'
                            : 'Tap the microphone to speak',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isListening
                            ? 'Speak clearly — your words will appear in the box below.'
                            : (isElder
                                ? 'Or simply type your answer in the box below.'
                                : 'Or type the resident\'s answer in the box below.'),
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
            onChanged: (val) {
              final qId = currentQ.id;
              setState(() {
                _responses[qId] = val;
                _grades[qId] = CognitiveScoring.scoreQuestion(qId, val);
              });
              _saveDebounceTimer?.cancel();
              _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                _persistResponses();
              });
            },
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: isElder
                  ? 'Type your answer here, or tap the microphone to speak...'
                  : 'Type resident answer here, or tap the microphone to dictate...',
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
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.keyboard, size: 13, color: AppColors.muted),
                  SizedBox(width: 6),
                  Text(
                    'You can also type your answer.',
                    style: TextStyle(
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
                    children: const [
                      Text('✨', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 4),
                      Text(
                        'Saved to profile',
                        style: TextStyle(
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

          // Role-Specific Section:
          // - CAREGIVER sees automatic scoring indicator and optional override buttons
          // - ELDER sees confirmation that answers are auto-evaluated upon submission
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
                    children: const [
                      Text(
                        'Automatic Scoring (Deterministic Rubric):',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'System auto-grades answers • Optional override',
                        style: TextStyle(
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
                          label: 'Correct (1.0)',
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
                          label: 'Partial (0.5)',
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
                          label: 'Incorrect (0.0)',
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
              onPressed: () => _toggleTts(currentQ.prompt),
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
              label: const Text(
                'Repeat Question',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            _buildInfoChip(
              label: isElder
                  ? 'Self-Paced • Take Your Time'
                  : 'Time: ${(_questionTimes[currentQ.id] ?? 0.0).toStringAsFixed(0)}s',
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
                label: const Text(
                  '← Prev',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
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
                              ? 'Submit for Caregiver Review'
                              : 'End & Save Session')
                          : 'End Assessment',
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
            isElder ? 'Your Answer Progress' : 'Assessment Progress',
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
                        isElder ? 'Answered' : 'Completed',
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
                'Answered',
                '$_answeredCount/$_totalCount',
                AppColors.primary,
                LucideIcons.checkCircle2,
                const Color(0xFFEDE9FE),
              ),
              _buildStatItem(
                'Remaining',
                '$_remainingToAnswerCount',
                const Color(0xFFD97706),
                LucideIcons.clock,
                const Color(0xFFFEF3C7),
              ),
              _buildStatItem(
                'Status',
                _answeredCount == _totalCount ? 'Ready' : 'In Progress',
                _answeredCount == _totalCount
                    ? const Color(0xFF15803D)
                    : const Color(0xFF4F46E5),
                LucideIcons.activity,
                _answeredCount == _totalCount
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFEEF2FF),
              ),
              _buildStatItem(
                'Reviewer',
                'Care Specialist',
                AppColors.navy,
                LucideIcons.userCheck,
                const Color(0xFFF1F5F9),
              ),
            ]),
            const SizedBox(height: 14),
            if (_remainingToAnswerCount > 0)
              _buildNoticeBanner(
                text: '$_remainingToAnswerCount question(s) pending your answer',
                icon: LucideIcons.clock,
                color: const Color(0xFF92400E),
                background: const Color(0xFFFEF3C7),
                borderColor: const Color(0xFFF59E0B),
              )
            else
              _buildNoticeBanner(
                text: 'All 10 questions answered — Ready for review!',
                icon: LucideIcons.circleCheckBig,
                color: const Color(0xFF15803D),
                background: const Color(0xFFDCFCE7),
                borderColor: const Color(0xFF86EFAC),
              ),
          ] else ...[
            _buildStatGrid([
              _buildStatItem(
                'Completed',
                '$_fullyCompletedCount/$_totalCount',
                AppColors.primary,
                LucideIcons.checkCircle2,
                const Color(0xFFEDE9FE),
              ),
              _buildStatItem(
                'Answered',
                '$_answeredCount/$_totalCount',
                const Color(0xFFB45309),
                LucideIcons.messageSquare,
                const Color(0xFFFEF3C7),
              ),
              _buildStatItem(
                'Graded',
                '$_gradedCount/$_totalCount',
                AppColors.riskLow,
                LucideIcons.sparkles,
                const Color(0xFFDCFCE7),
              ),
              _buildStatItem(
                'Remaining',
                '$_remainingToCompleteCount',
                AppColors.muted,
                LucideIcons.clock,
                const Color(0xFFF1F5F9),
              ),
            ]),
            if (_remainingToCompleteCount > 0) ...[
              const SizedBox(height: 14),
              _buildNoticeBanner(
                text: '$_remainingToCompleteCount item(s) pending response or score',
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
            'Questions Overview',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Text(
                isElder
                    ? '$_answeredCount / $_totalCount Answered'
                    : '$_fullyCompletedCount / $_totalCount Completed',
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
                                q.category,
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
                                  child: const Text(
                                    'Answer Saved',
                                    style: TextStyle(
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
                                const Text(
                                  'Missing answer',
                                  style: TextStyle(
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
                                const Text(
                                  'Awaiting score',
                                  style: TextStyle(
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
            isElder ? 'Elder Assessment Guidance' : 'Clinical Evaluation Tips',
          ),
          const SizedBox(height: 12),
          Text(
            isElder
                ? 'Take as much time as you need for each question. You can answer using the microphone or keyboard. Your care team will review your responses.'
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
          // Header with floating sparkles icon & live pulse indicator
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
              const Expanded(
                child: Text(
                  'Cognitive Vitality Focus',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Live pulsating dot
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
                      const Text(
                        'LIVE',
                        style: TextStyle(
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

          // Active domain highlight box with gentle breathing waveform
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
                      'Target Domain: ${currentQ.category}',
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
                  _getDomainEncouragement(currentQ.domain),
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

          // Gentle ambient breathing rhythm indicators (4 animated bars)
          Row(
            children: [
              const Text(
                'Assessment Rhythm',
                style: TextStyle(
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

          // Floating mini pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniWellnessPill('Dual-Language Sync', LucideIcons.languages),
              _buildMiniWellnessPill('Conversational AI', LucideIcons.heart),
              _buildMiniWellnessPill('Empathetic Care', LucideIcons.sparkles),
            ],
          ),
        ],
      ),
    );
  }

  String _getDomainEncouragement(String domain) {
    final d = domain.toLowerCase();
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

  void _showFinishConfirmationDialog(bool isElder) {
    _saveCurrentQuestionState();
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
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(
                      isAllAnswered
                          ? LucideIcons.checkCircle2
                          : LucideIcons.alertTriangle,
                      color: isAllAnswered
                          ? AppColors.riskLow
                          : const Color(0xFFB45309),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAllAnswered
                          ? 'Submit & Auto-Score Assessment'
                          : 'Questions Pending Answer',
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
                      if (!isAllAnswered) ...[
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
                                    '${unansweredIds.length} Question(s) Require Your Response',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '• Unanswered: Question(s) ${unansweredIds.join(', ')}.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please answer all 10 questions before submitting. Missing answers remain incomplete.',
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
                                children: unansweredIds.map((id) {
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(
                                    LucideIcons.checkCircle2,
                                    size: 16,
                                    color: AppColors.riskLow,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'All 10 questions have saved responses.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.riskLow,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Your responses will be evaluated deterministically using question-specific scoring rules, ACRF cognitive domain scores calculated, and AI risk prediction generated.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.navy,
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
                      isAllAnswered ? 'Review Answers' : 'Return to Assessment',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (isAllAnswered && !_isSubmitting)
                        ? () async {
                            setDialogState(() => _isSubmitting = true);
                            await _submitElderResponses();
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
                            isAllAnswered
                                ? 'Submit & Calculate Score'
                                : 'Answer All 10 Questions to Submit',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
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
    final bool isHighRisk =
        (result.riskLevel?.toLowerCase().contains('high') ?? false) ||
        (result.mlPrediction?.toLowerCase().contains('high') ?? false) ||
        (result.alertTriggered == true) ||
        (result.acrfScore != null && result.acrfScore! < 50.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                                ? 'Let\'s Play Some Games! 🧠🎮'
                                : 'Cognitive Assessment Saved! 🎉',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${result.residentName} • Evaluated by ${result.assessedBy ?? 'Care Specialist'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
                                          children: const [
                                            Text(
                                              'Let\'s play some memory games! 🧠🎮',
                                              style: TextStyle(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF4C1D95),
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Fun & engaging daily brain workout',
                                              style: TextStyle(
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
                                  const Text(
                                    'Exercising memory, focus, and recall through enjoyable brain games helps boost mental agility and keep your thoughts refreshed. Let\'s play a fun game right now!',
                                    style: TextStyle(
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
                                      label: const Text(
                                        'Let\'s Play Memory Games Now! 🎮',
                                        style: TextStyle(
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
                                  children: const [
                                    Icon(
                                      LucideIcons.sparkles,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'ACRF COGNITIVE WELLNESS SCORE',
                                      style: TextStyle(
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
                                const SizedBox(height: 8),
                                Text(
                                  result.methodology ??
                                      'ACRF Fixed Base Weights • Clinical Evaluation Engine',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category Breakdown
                          Row(
                            children: [
                              _buildCategoryCard('Memory', result.memory ?? 0.0, 'w:25%', LucideIcons.brain),
                              const SizedBox(width: 8),
                              _buildCategoryCard('Attention', result.attention ?? 0.0, 'w:20%', LucideIcons.eye),
                              const SizedBox(width: 8),
                              _buildCategoryCard('Orientation', result.orientation ?? 0.0, 'w:20%', LucideIcons.compass),
                              const SizedBox(width: 8),
                              _buildCategoryCard('Recall', result.recall ?? 0.0, 'w:20%', LucideIcons.lightbulb),
                              const SizedBox(width: 8),
                              _buildCategoryCard('Reasoning', result.reasoning ?? 0.0, 'w:15%', LucideIcons.puzzle),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ML / Caregiver Notice
                          if (result.mlAvailable) ...[
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
                                children: const [
                                  Icon(LucideIcons.sparkles, size: 14, color: Color(0xFFB45309)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Experimental ML Model Demo: Evaluated with Random Forest inference for wellness baseline reference.',
                                      style: TextStyle(
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
                                children: const [
                                  Text('✨', style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Great performance! Keep your brain active with optional memory games, or return to the overview.',
                                      style: TextStyle(
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
                                    label: const Text('Return to Dashboard'),
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
                                    label: const Text('Play Memory Games'),
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
