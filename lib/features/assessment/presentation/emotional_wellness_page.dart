import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/responsive/responsive_builder.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/mock/mock_carevora_data.dart';
import '../../../data/models/carevora_models.dart';
import '../application/facial_emotion_ai_service.dart';
import '../../auth/application/auth_controller.dart';

class EmotionalWellnessPage extends ConsumerStatefulWidget {
  const EmotionalWellnessPage({super.key});

  @override
  ConsumerState<EmotionalWellnessPage> createState() => _EmotionalWellnessPageState();
}

class _EmotionalWellnessPageState extends ConsumerState<EmotionalWellnessPage>
    with TickerProviderStateMixin {
  // Default to question 5 (index 4) to strictly mirror Proposal Figure 11-4 on load!
  int _currentIndex = 4;
  final List<AssessmentQuestion> _questions = MockCarevoraData.emotionalQuestions;

  // Real-time analysis metrics
  String _selectedEmotion = 'Happy';
  double _facialConfidence = 0.85;
  String _voiceEmotion = 'Neutral';
  double _voiceConfidence = 0.72;

  // Scores
  int _lonelinessScore = 67;
  int _isolationScore = 58;

  // Social behavior indicators
  String _commLevel = 'Moderate';
  String _engagementLevel = 'High';
  String _responseTime = 'Normal';

  // Voice recording & timers
  bool _isRecording = true;
  int _recordSeconds = 12;
  Timer? _recordTimer;
  String _spokenText =
      'Sometimes in the evenings, even when people are around, I feel alone in my thoughts.';

  // Speech and Voice engines
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;

  // Camera & Image state
  String _currentFaceAsset = 'assets/images/landing/senior_happy_face.jpg';
  Uint8List? _capturedImageBytes;
  final ImagePicker _picker = ImagePicker();

  // Animations
  late AnimationController _waveController;
  late AnimationController _scannerController;

  // Sub-navigation: 0: Assessment Session, 1: RALPA Trajectory, 2: Care Interventions & Reassessment, 3: Assessment History
  int _selectedSubTab = 0;
  late Resident _currentResident;

  final List<Resident> _availableResidents = [
    MockCarevoraData.defaultResident,
    const Resident(
      id: '9002',
      name: 'Mrs. Sarah Jenkins',
      age: 78,
      gender: 'Female',
      roomNo: '101',
      lastAssessmentDate: '11 May 2025, 02:30 PM',
      cognitiveScore: 0.68,
      cognitiveTrend: 0.04,
      emotionalScore: 0.74,
      emotionalTrend: 0.08,
      metabolicScore: 0.80,
      metabolicTrend: 0.02,
      overallIndex: 0.74,
      overallTrend: 0.05,
    ),
    const Resident(
      id: '9003',
      name: 'Mr. Arthur Pendelton',
      age: 82,
      gender: 'Male',
      roomNo: '102',
      lastAssessmentDate: '09 May 2025, 11:15 AM',
      cognitiveScore: 0.54,
      cognitiveTrend: -0.05,
      emotionalScore: 0.62,
      emotionalTrend: -0.04,
      metabolicScore: 0.70,
      metabolicTrend: 0.01,
      overallIndex: 0.62,
      overallTrend: -0.03,
    ),
    const Resident(
      id: '9004',
      name: 'Mrs. Margaret Chen',
      age: 79,
      gender: 'Female',
      roomNo: '103',
      lastAssessmentDate: '08 May 2025, 04:00 PM',
      cognitiveScore: 0.72,
      cognitiveTrend: 0.06,
      emotionalScore: 0.82,
      emotionalTrend: 0.10,
      metabolicScore: 0.65,
      metabolicTrend: 0.03,
      overallIndex: 0.73,
      overallTrend: 0.06,
    ),
  ];

  late List<PersonalizedActivityItem> _activities;
  late List<EmotionalAssessmentHistoryLog> _historyLogs;
  late Map<String, ResidentProfileDataset> _residentDatasets;

  @override
  void initState() {
    super.initState();
    _currentResident = _availableResidents.first;
    _initActivitiesAndHistory();
    _loadResidentData(_currentResident.id);
    _initAnimations();
    _initVoiceEngines();
    _startRecordingTimer();
  }

  void _initActivitiesAndHistory() {
    _residentDatasets = {
      // 1. Mr. James Perera (ID: 9001) - 5 Sessions across 4 weeks, High Risk Drift
      '9001': ResidentProfileDataset(
        baselineLoneliness: 54.0,
        baselineIsolation: 46.0,
        baselineEstablishedDate: '14 Apr 2025',
        trendSlope: 2.2,
        activities: [
          PersonalizedActivityItem(
            id: 'ACT-1-9001',
            title: 'Soothing Classical & Traditional Chants Playlist',
            category: 'Music Therapy',
            description: 'Listening to familiar acoustic rhythms reduces agitation, stabilizes vocal prosody, and elevates positive valence.',
            icon: LucideIcons.music,
            priority: 'High Priority',
            priorityColor: AppColors.primary,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-2-9001',
            title: 'Historical Folklore & Illustrated Biography Reading',
            category: 'Reading & Literature',
            description: 'Engaging narrative material prompts conversational recall and provides comfortable individual engagement in personal quarters.',
            icon: LucideIcons.bookOpen,
            priority: 'Recommended',
            priorityColor: Colors.blueAccent,
            isCompleted: true,
            completionNotes: 'Resident completed chapter 3 with caregiver assistance.',
            residentFeedback: 'Felt calm and reminisced about childhood stories.',
          ),
          PersonalizedActivityItem(
            id: 'ACT-3-9001',
            title: 'Morning Spiritual Chanting & Mindful Reflection',
            category: 'Religious / Cultural',
            description: 'Grounded in Sri Lankan care home findings (Wijesiri et al.) as a primary emotional coping mechanism for elderly residents.',
            icon: LucideIcons.sparkles,
            priority: 'Essential',
            priorityColor: AppColors.leafGreen,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-4-9001',
            title: 'Parlor Herbal Tea Connection & Peer Carrom Session',
            category: 'Social Interaction',
            description: 'Facilitated buddy pairing at 3:30 PM tea time to counter prolonged seclusion and rebuild voluntary interaction frequency.',
            icon: LucideIcons.users,
            priority: 'High Priority',
            priorityColor: AppColors.riskModerate,
            isCompleted: false,
          ),
        ],
        logs: const [
          EmotionalAssessmentHistoryLog(
            id: 'EAL-001',
            date: '12 May 2025, 10:30 AM',
            primaryEmotion: 'Sad / Affect Flattening',
            lonelinessScore: 78,
            isolationScore: 72,
            deviation: 24.0,
            trajectory: 'Increasing Risk',
            interventionStatus: 'Garden Stroll Assigned',
            assessedBy: 'Seetha N. (RN)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-002',
            date: '05 May 2025, 10:10 AM',
            primaryEmotion: 'Calm / Neutral',
            lonelinessScore: 66,
            isolationScore: 60,
            deviation: 12.0,
            trajectory: 'Stable Baseline',
            interventionStatus: 'Reading Session Completed',
            assessedBy: 'Seetha N. (RN)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-003',
            date: '28 Apr 2025, 09:45 AM',
            primaryEmotion: 'Happy / Cheerful',
            lonelinessScore: 52,
            isolationScore: 48,
            deviation: -2.0,
            trajectory: 'Improving',
            interventionStatus: 'Tea Connection Completed',
            assessedBy: 'K. Bandara (Caregiver)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-004',
            date: '21 Apr 2025, 02:15 PM',
            primaryEmotion: 'Calm / Neutral',
            lonelinessScore: 56,
            isolationScore: 50,
            deviation: 2.0,
            trajectory: 'Stable',
            interventionStatus: 'Chanting Reflection Completed',
            assessedBy: 'Seetha N. (RN)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-005',
            date: '14 Apr 2025, 10:00 AM',
            primaryEmotion: 'Neutral Baseline',
            lonelinessScore: 54,
            isolationScore: 46,
            deviation: 0.0,
            trajectory: 'Initial Baseline Established',
            interventionStatus: 'Baseline Logged',
            assessedBy: 'Dr. Wickramasinghe',
          ),
        ],
      ),

      // 2. Mrs. Sarah Jenkins (ID: 9002) - 4 Sessions, Stable Baseline
      '9002': ResidentProfileDataset(
        baselineLoneliness: 48.0,
        baselineIsolation: 42.0,
        baselineEstablishedDate: '18 Apr 2025',
        trendSlope: 0.2,
        activities: [
          PersonalizedActivityItem(
            id: 'ACT-1-9002',
            title: 'Symphonic Chamber Music & Nature Sounds',
            category: 'Music Therapy',
            description: 'Gentle classical strings playlist during morning relaxation.',
            icon: LucideIcons.music,
            priority: 'Recommended',
            priorityColor: Colors.blueAccent,
            isCompleted: true,
            completionNotes: 'Enjoyed listening while reading.',
            residentFeedback: 'Very peaceful start to the morning.',
          ),
          PersonalizedActivityItem(
            id: 'ACT-2-9002',
            title: 'Botanical Garden Memoir & Poetry',
            category: 'Reading & Literature',
            description: 'Short nature poems supporting cognitive recall and personal peace.',
            icon: LucideIcons.bookOpen,
            priority: 'Recommended',
            priorityColor: AppColors.leafGreen,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-3-9002',
            title: 'Morning Chapel Hymns & Contemplation',
            category: 'Religious / Cultural',
            description: 'Weekly choir hymn recitation with fellowship group.',
            icon: LucideIcons.sparkles,
            priority: 'Standard',
            priorityColor: AppColors.primary,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-4-9002',
            title: 'Community Knitting & Herbal Tea Table',
            category: 'Social Interaction',
            description: 'Participates in 3-person crafts circle in the east lounge.',
            icon: LucideIcons.users,
            priority: 'High Priority',
            priorityColor: AppColors.riskModerate,
            isCompleted: true,
            completionNotes: 'Participated for 45 minutes.',
            residentFeedback: 'Loved catching up with friends.',
          ),
        ],
        logs: const [
          EmotionalAssessmentHistoryLog(
            id: 'EAL-011',
            date: '11 May 2025, 02:30 PM',
            primaryEmotion: 'Calm / Neutral',
            lonelinessScore: 49,
            isolationScore: 43,
            deviation: 1.0,
            trajectory: 'Stable Baseline',
            interventionStatus: 'Knitting Circle Completed',
            assessedBy: 'Seetha N. (RN)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-012',
            date: '04 May 2025, 03:00 PM',
            primaryEmotion: 'Happy / Cheerful',
            lonelinessScore: 47,
            isolationScore: 41,
            deviation: -1.0,
            trajectory: 'Improving',
            interventionStatus: 'Music Session Completed',
            assessedBy: 'Seetha N. (RN)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-013',
            date: '27 Apr 2025, 11:15 AM',
            primaryEmotion: 'Calm / Neutral',
            lonelinessScore: 50,
            isolationScore: 44,
            deviation: 2.0,
            trajectory: 'Stable',
            interventionStatus: 'Tea Table Completed',
            assessedBy: 'K. Bandara (Caregiver)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-014',
            date: '18 Apr 2025, 10:00 AM',
            primaryEmotion: 'Neutral Baseline',
            lonelinessScore: 48,
            isolationScore: 42,
            deviation: 0.0,
            trajectory: 'Baseline Established',
            interventionStatus: 'Initial Baseline Logged',
            assessedBy: 'Dr. Wickramasinghe',
          ),
        ],
      ),

      // 3. Mr. Arthur Pendelton (ID: 9003) - 3 Sessions, Acute Deterioration & Counsellor Alert
      '9003': ResidentProfileDataset(
        baselineLoneliness: 65.0,
        baselineIsolation: 68.0,
        baselineEstablishedDate: '25 Apr 2025',
        trendSlope: 3.1,
        activities: [
          PersonalizedActivityItem(
            id: 'ACT-1-9003',
            title: 'Acoustic Calming Audio & Binaural Tones',
            category: 'Music Therapy',
            description: 'Designed to soothe evening agitation and promote restful sleep.',
            icon: LucideIcons.music,
            priority: 'High Priority',
            priorityColor: AppColors.riskHigh,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-2-9003',
            title: 'Steam Locomotive Archive & Picture Albums',
            category: 'Reading & Literature',
            description: 'High-interest historical machinery album to spark conversational enthusiasm.',
            icon: LucideIcons.bookOpen,
            priority: 'Recommended',
            priorityColor: Colors.blueAccent,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-3-9003',
            title: 'Quiet Sunset Meditation & Scripture',
            category: 'Religious / Cultural',
            description: 'Individual reflection session with spiritual care coordinator.',
            icon: LucideIcons.sparkles,
            priority: 'Essential',
            priorityColor: AppColors.leafGreen,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-4-9003',
            title: 'One-on-One Courtyard Stroll with Care Attendant',
            category: 'Social Interaction',
            description: 'Direct individual companion walk to bridge social withdrawal gently.',
            icon: LucideIcons.users,
            priority: 'Urgent Action',
            priorityColor: AppColors.riskHigh,
            isCompleted: false,
          ),
        ],
        logs: const [
          EmotionalAssessmentHistoryLog(
            id: 'EAL-021',
            date: '09 May 2025, 11:15 AM',
            primaryEmotion: 'Agitated / Withdrawal',
            lonelinessScore: 82,
            isolationScore: 78,
            deviation: 17.0,
            trajectory: 'Rapid Deterioration',
            interventionStatus: 'Counsellor Alert Dispatched',
            assessedBy: 'Dr. Wickramasinghe',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-022',
            date: '02 May 2025, 02:45 PM',
            primaryEmotion: 'Sad / Low Affect',
            lonelinessScore: 74,
            isolationScore: 73,
            deviation: 9.0,
            trajectory: 'Increasing Risk',
            interventionStatus: 'Courtyard Stroll Assigned',
            assessedBy: 'Seetha N. (RN)',
          ),
          EmotionalAssessmentHistoryLog(
            id: 'EAL-023',
            date: '25 Apr 2025, 09:30 AM',
            primaryEmotion: 'Neutral Baseline',
            lonelinessScore: 65,
            isolationScore: 68,
            deviation: 0.0,
            trajectory: 'Baseline Established',
            interventionStatus: 'Initial Intake Logged',
            assessedBy: 'Dr. Wickramasinghe',
          ),
        ],
      ),

      // 4. Mrs. Margaret Chen (ID: 9004) - Only 1 Session, Insufficient Historical Data (Tests RALPA Safe Fallback!)
      '9004': ResidentProfileDataset(
        baselineLoneliness: 45.0,
        baselineIsolation: 40.0,
        baselineEstablishedDate: '08 May 2025',
        trendSlope: 0.0,
        activities: [
          PersonalizedActivityItem(
            id: 'ACT-1-9004',
            title: 'Traditional Folk Melodies & Guzheng Instrumental',
            category: 'Music Therapy',
            description: 'Culturally familiar acoustic rhythms to support smooth initial care home transition.',
            icon: LucideIcons.music,
            priority: 'Recommended',
            priorityColor: AppColors.primary,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-2-9004',
            title: 'Illustrated Travelogues & Art Journals',
            category: 'Reading & Literature',
            description: 'Visual cultural narratives for leisurely room reading.',
            icon: LucideIcons.bookOpen,
            priority: 'Recommended',
            priorityColor: Colors.blueAccent,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-3-9004',
            title: 'Midday Mindful Breathing & Tea Ceremony',
            category: 'Religious / Cultural',
            description: 'Quiet tea mindfulness reflecting personal daily routine.',
            icon: LucideIcons.sparkles,
            priority: 'Standard',
            priorityColor: AppColors.leafGreen,
            isCompleted: false,
          ),
          PersonalizedActivityItem(
            id: 'ACT-4-9004',
            title: 'Dining Hall Buddy Introduction',
            category: 'Social Interaction',
            description: 'Paired with Mrs. Jenkins during lunch to establish first care home friendship.',
            icon: LucideIcons.users,
            priority: 'High Priority',
            priorityColor: AppColors.riskModerate,
            isCompleted: false,
          ),
        ],
        logs: const [
          EmotionalAssessmentHistoryLog(
            id: 'EAL-031',
            date: '08 May 2025, 04:00 PM',
            primaryEmotion: 'Calm / Neutral',
            lonelinessScore: 45,
            isolationScore: 40,
            deviation: 0.0,
            trajectory: 'Baseline Establishing (1 Session)',
            interventionStatus: 'Intake Assessment Logged',
            assessedBy: 'Seetha N. (RN)',
          ),
        ],
      ),
    };
  }

  void _loadResidentData(String id) {
    final dataset = _residentDatasets[id] ?? _residentDatasets['9001']!;
    _historyLogs = List.from(dataset.logs);
    _activities = List.from(dataset.activities);
    _capturedImageBytes = null;
    if (_historyLogs.isNotEmpty) {
      final latest = _historyLogs.first;
      _lonelinessScore = latest.lonelinessScore;
      _isolationScore = latest.isolationScore;

      final pEmotion = latest.primaryEmotion.toLowerCase();
      if (pEmotion.contains('sad')) {
        _selectedEmotion = 'Sad';
        _currentFaceAsset = 'assets/images/landing/senior_sad_face.jpg';
        _facialConfidence = 0.82;
        _voiceEmotion = 'Melancholic / Low Pitch';
        _voiceConfidence = 0.82;
        _commLevel = 'Low';
        _engagementLevel = 'Low';
        _responseTime = 'Delayed';
      } else if (pEmotion.contains('agitated') || pEmotion.contains('angry')) {
        _selectedEmotion = 'Angry';
        _currentFaceAsset = 'assets/images/landing/senior_sad_face.jpg';
        _facialConfidence = 0.74;
        _voiceEmotion = 'Agitated / Elevated Pitch';
        _voiceConfidence = 0.76;
        _commLevel = 'Defensive';
        _engagementLevel = 'Medium';
        _responseTime = 'Fast';
      } else if (pEmotion.contains('happy') || pEmotion.contains('cheerful')) {
        _selectedEmotion = 'Happy';
        _currentFaceAsset = 'assets/images/landing/senior_happy_face.jpg';
        _facialConfidence = 0.85;
        _voiceEmotion = 'Neutral / Calm';
        _voiceConfidence = 0.72;
        _commLevel = 'Moderate';
        _engagementLevel = 'High';
        _responseTime = 'Normal';
      } else {
        _selectedEmotion = 'Happy';
        _currentFaceAsset = 'assets/images/landing/senior_neutral_calm_face.jpg';
        _facialConfidence = 0.80;
        _voiceEmotion = 'Calm / Steady Prosody';
        _voiceConfidence = 0.75;
        _commLevel = 'Moderate';
        _engagementLevel = 'Moderate';
        _responseTime = 'Normal';
      }
    }
  }

  void _initAnimations() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _initVoiceEngines() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);

    _speech = stt.SpeechToText();
    try {
      _speechEnabled = await _speech.initialize(
        onError: (err) => debugPrint('STT Error: $err'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording) {
              // keep state synced
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Speech init fallback: $e');
    }
  }

  void _startRecordingTimer() {
    _recordTimer?.cancel();
    if (_isRecording) {
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordSeconds++;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _waveController.dispose();
    _scannerController.dispose();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _readQuestionAloud() async {
    final currentQ = _questions[_currentIndex];
    await _flutterTts.speak(currentQ.audioPrompt);
  }

  void _toggleRecording() async {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      _startRecordingTimer();
      if (_speechEnabled) {
        _speech.listen(onResult: (result) {
          if (mounted) {
            setState(() {
              _spokenText = result.recognizedWords;
            });
          }
        });
      }
    } else {
      _recordTimer?.cancel();
      if (_speechEnabled) {
        await _speech.stop();
      }
    }
  }

  Future<void> _takeLiveCameraPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
        });

        final result = await FacialEmotionAiService.analyzeImage(imageBytes: bytes);
        if (mounted) {
          _updateEmotionFromResult(result);
        }
      }
    } catch (e) {
      debugPrint('Camera capture error: $e');
    }
  }

  Future<void> _pickImageFromGalleryOrFile() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
        });

        final result = await FacialEmotionAiService.analyzeImage(imageBytes: bytes);
        if (mounted) {
          _updateEmotionFromResult(result);
        }
      }
    } catch (e) {
      debugPrint('Photo upload error: $e');
    }
  }

  void _selectSampleEmotion(String emotion, String assetPath, double conf, int lScore, int iScore) {
    setState(() {
      _selectedEmotion = emotion;
      _currentFaceAsset = assetPath;
      _capturedImageBytes = null;
      _facialConfidence = conf;
      _lonelinessScore = lScore;
      _isolationScore = iScore;

      if (emotion == 'Happy') {
        _voiceEmotion = 'Neutral / Calm';
        _voiceConfidence = 0.72;
        _commLevel = 'Moderate';
        _engagementLevel = 'High';
        _responseTime = 'Normal';
      } else if (emotion == 'Sad') {
        _voiceEmotion = 'Melancholic / Low Pitch';
        _voiceConfidence = 0.82;
        _commLevel = 'Low';
        _engagementLevel = 'Low';
        _responseTime = 'Delayed';
        _lonelinessScore = 78;
        _isolationScore = 72;
      } else if (emotion == 'Angry') {
        _voiceEmotion = 'Agitated / Elevated Pitch';
        _voiceConfidence = 0.76;
        _commLevel = 'Defensive';
        _engagementLevel = 'Medium';
        _responseTime = 'Fast';
        _lonelinessScore = 62;
        _isolationScore = 65;
      } else {
        _voiceEmotion = 'Anxious / Tremor';
        _voiceConfidence = 0.79;
        _commLevel = 'Hesitant';
        _engagementLevel = 'Low';
        _responseTime = 'Variable';
        _lonelinessScore = 74;
        _isolationScore = 69;
      }
    });
  }

  void _updateEmotionFromResult(FacialEmotionResult result) {
    setState(() {
      _facialConfidence = result.confidence;
      if (result.confidence <= 0.0) {
        _selectedEmotion = 'Neutral';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facial emotion model retired from active pipeline. Assessment relies on structured questionnaire and vocal metrics.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      if (result.primaryEmotion == EmotionCategory.happy) {
        _selectedEmotion = 'Happy';
        _lonelinessScore = 52;
        _isolationScore = 48;
      } else if (result.primaryEmotion == EmotionCategory.sadDepressed) {
        _selectedEmotion = 'Sad';
        _lonelinessScore = 79;
        _isolationScore = 75;
      } else if (result.primaryEmotion == EmotionCategory.confusedAgitated) {
        _selectedEmotion = 'Angry';
        _lonelinessScore = 65;
        _isolationScore = 62;
      } else {
        _selectedEmotion = 'Fear';
        _lonelinessScore = 70;
        _isolationScore = 68;
      }
    });
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _updateQuestionContext();
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _updateQuestionContext();
      });
    } else {
      _showEndAssessmentDialog();
    }
  }

  void _skipQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _updateQuestionContext();
      });
    }
  }

  void _updateQuestionContext() {
    final q = _questions[_currentIndex];
    // Dynamic simulated sample response per question
    if (q.id == 5) {
      _spokenText =
          'Sometimes in the evenings, even when people are around, I feel alone in my thoughts.';
    } else if (q.id == 6) {
      _spokenText =
          'I do feel left out occasionally when groups are laughing together in the lounge.';
    } else if (q.id == 7) {
      _spokenText =
          'I attend morning tea, but I prefer sitting at the side quiet corner.';
    } else {
      _spokenText = 'Resident verbal response captured and transcribed via RALPA audio feature pipeline.';
    }
  }

  void _showTipsDialog() {
    final currentQ = _questions[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(LucideIcons.sparkles, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('AI Protocol Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lavenderBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lilac),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.heartHandshake, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Question ${_currentIndex + 1} Focus: ${currentQ.category}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(currentQ.tip, style: AppTextStyles.body),
            const SizedBox(height: 12),
            const Text(
              '• Allow the senior at least 10–15 seconds to finish their thoughts without interruption.\n• The AI speech model analyzes vocal latency, fundamental frequency (F0), and emotional prosody.',
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showEndAssessmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(LucideIcons.alertTriangle, color: AppColors.riskModerate, size: 22),
            SizedBox(width: 10),
            Text('End Loneliness & Social Assessment?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The current session data will be processed through the RALPA (Resident-Adaptive Longitudinal Prediction Algorithm) pipeline to update Mr. James Perera\'s baseline and risk trajectory.',
              style: TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Loneliness Index:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('$_lonelinessScore (Moderate Risk)',
                          style: const TextStyle(
                              color: AppColors.riskModerate, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Social Isolation Index:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('$_isolationScore (High Risk)',
                          style: const TextStyle(
                              color: AppColors.riskHigh, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Predicted Trajectory:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Slow Deterioration (Action Req.)',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Session'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save & Finish Assessment'),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentQ = _questions[_currentIndex];
    final completedCount = _currentIndex;
    final remainingCount = _questions.length - (_currentIndex + 1);

    // Section 6.6 User Privacy & Distress Prevention:
    // When logged in as an Elder resident, do NOT expose distressing clinical risk scores,
    // loneliness numerical scales, or deterioration trajectories. Provide an accessible,
    // comforting conversation check-in and personal activity checklist.
    if (authState.state.isElder) {
      return _buildElderResidentView(currentQ);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Bar: Back to Residents & Date Badge
          _buildTopHeaderBar(),
          const SizedBox(height: 16),

          // 2. Resident Profile Card (Dynamic Resident Selector)
          _buildResidentHeaderCard(),
          const SizedBox(height: 20),

          // 3. Navigation Sub-Tabs (Session, RALPA Trajectory, Interventions, History)
          _buildNavigationSubTabs(),
          const SizedBox(height: 20),

          // 4. View Switching based on _selectedSubTab
          if (_selectedSubTab == 0) ...[
            // Active Loneliness & Social Assessment Session (Proposal Figure 11-4)
            ResponsiveBuilder(
              mobile: (context) => Column(
                children: [
                  _buildMainAssessmentCard(currentQ),
                  const SizedBox(height: 24),
                  _buildRightSidePanel(completedCount, remainingCount),
                ],
              ),
              desktop: (context) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 68, child: _buildMainAssessmentCard(currentQ)),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 32,
                    child: _buildRightSidePanel(completedCount, remainingCount),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // RALPA Research Methodology Intelligence Dashboard (Chapter 3: Sec 3.1 - 3.5)
            _buildRalpaMethodologyAnalyticsPanel(),
          ] else if (_selectedSubTab == 1) ...[
            // In-Depth RALPA Longitudinal Trajectory & Baseline Drift Analytics
            _buildRalpaMethodologyAnalyticsPanel(),
          ] else if (_selectedSubTab == 2) ...[
            // Personalized Interventions & Reassessment Tracking (FR11, FR14)
            _buildPersonalizedInterventionsTab(),
          ] else ...[
            // Historical Assessment Records & Audit Logs (FR4, FR13)
            _buildAssessmentHistoryTab(),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationSubTabs() {
    final tabs = [
      {'title': 'Active Assessment', 'icon': LucideIcons.messageSquare, 'desc': 'Fig 11-4 Structured Session'},
      {'title': 'RALPA Trajectory', 'icon': LucideIcons.trendingUp, 'desc': 'Sec 3.1-3.4 Longitudinal AI'},
      {'title': 'Care Interventions', 'icon': LucideIcons.sparkles, 'desc': 'FR11 / FR14 Reassessments'},
      {'title': 'Assessment History', 'icon': LucideIcons.history, 'desc': 'FR4 Longitudinal Records'},
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isSelected = _selectedSubTab == index;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedSubTab = index;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.navy,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tab['desc'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // --- TOP HEADER BAR ---
  Widget _buildTopHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => context.go('/dashboard/residents'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: const [
                Icon(LucideIcons.arrowLeft, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Back to Residents',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(LucideIcons.bell, size: 16, color: AppColors.navy),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.riskHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.calendar, size: 14, color: AppColors.muted),
                  SizedBox(width: 8),
                  Text(
                    '12 May 2025',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Monday, 10:30 AM',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- RESIDENT HEADER CARD ---
  Widget _buildResidentHeaderCard() {
    final initials = _currentResident.name
        .split(' ')
        .where((w) => !w.startsWith('Mr.') && !w.startsWith('Mrs.') && !w.startsWith('Dr.'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.isNotEmpty ? initials : 'R',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_currentResident.name} (ID: R00${_currentResident.id.length > 2 ? _currentResident.id.substring(_currentResident.id.length - 2) : _currentResident.id})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dropdown to switch residents seamlessly
                      DropdownButtonHideUnderline(
                        child: DropdownButton<Resident>(
                          value: _currentResident,
                          icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
                          dropdownColor: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          onChanged: (Resident? newRes) {
                            if (newRes != null) {
                              setState(() {
                                _currentResident = newRes;
                                _loadResidentData(newRes.id);
                              });
                            }
                          },
                          items: _availableResidents.map((Resident r) {
                            return DropdownMenuItem<Resident>(
                              value: r,
                              child: Text(
                                r.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Age ${_currentResident.age} / ${_currentResident.gender} / Room No: ${_currentResident.roomNo}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ASSESSMENT TYPE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.heartPulse, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Loneliness & Social-Isolation Assessment',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SESSION STARTED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.clock, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        '10:30:15 AM',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MAIN ASSESSMENT CARD ---
  Widget _buildMainAssessmentCard(AssessmentQuestion currentQ) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Session Title and Question Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'AI-Assisted Loneliness & Social-Isolation Assessment Session',
                  style: AppTextStyles.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Question ${_currentIndex + 1} of ${_questions.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Question Prompt Lavender Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.lavenderBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lilac),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.sparkles, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentQ.prompt,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _readQuestionAloud,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(LucideIcons.volume2, size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Tap to replay',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
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
          ),
          const SizedBox(height: 20),

          // 3. Side-by-side: Camera & Voice Recording
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                return Column(
                  children: [
                    _buildCameraCard(),
                    const SizedBox(height: 16),
                    _buildVoiceRecordingCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCameraCard()),
                  const SizedBox(width: 18),
                  Expanded(child: _buildVoiceRecordingCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // 4. Voice Prompt Guidance Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: const [
                Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please respond using your voice. Take your time. There are no right or wrong answers.',
                    style: TextStyle(fontSize: 13, color: AppColors.body, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Button Navigation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _currentIndex > 0 ? _previousQuestion : null,
                icon: const Icon(LucideIcons.arrowLeft, size: 15),
                label: const Text('Previous Question'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: const Icon(LucideIcons.arrowRight, size: 15),
                    label: Text(_currentIndex < _questions.length - 1 ? 'Next Question' : 'Complete Assessment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _skipQuestion,
                    icon: const Icon(LucideIcons.chevronsRight, size: 15, color: AppColors.muted),
                    label: const Text('Skip Question', style: TextStyle(color: AppColors.muted)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 20),

          // 6. Assessment Focus Panel
          _buildAssessmentFocusPanel(),
        ],
      ),
    );
  }

  // --- CAMERA BOX (FACIAL EXPRESSION) ---
  Widget _buildCameraCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Camera (Facial Expression)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.riskLowBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.fiber_manual_record, size: 8, color: AppColors.riskLow),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.riskLow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Face Stream Video Container with Bounding Box Reticle
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.35,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _capturedImageBytes != null
                      ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                      : Image.asset(_currentFaceAsset, fit: BoxFit.cover),

                  // Overlay Face Tracking Box with green/purple corners
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedEmotion == 'Happy'
                              ? AppColors.riskLow.withValues(alpha: 0.85)
                              : AppColors.primary.withValues(alpha: 0.85),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Face Target: ${(_facialConfidence * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white, fontSize: 9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Subtle animated scanning laser line
                  AnimatedBuilder(
                    animation: _scannerController,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + (_scannerController.value * 120),
                        left: 40,
                        right: 40,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Action buttons: Upload Image & Capture Camera
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Upload senior photo for AI Inference',
                          child: InkWell(
                            onTap: _pickImageFromGalleryOrFile,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.uploadCloud, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Capture live camera photo',
                          child: InkWell(
                            onTap: _takeLiveCameraPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
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
          const SizedBox(height: 12),

          // Detected Emotion Label and Selection Pills
          const Text(
            'Detected Emotion:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildEmotionTag(
                'Happy',
                'assets/images/landing/senior_happy_face.jpg',
                '😊 Happy',
                0.85,
                67,
                58,
                isActive: _selectedEmotion == 'Happy',
                activeColor: AppColors.riskLow,
                activeBg: AppColors.riskLowBg,
              ),
              _buildEmotionTag(
                'Sad',
                'assets/images/landing/senior_sad_face.jpg',
                '😢 Sad',
                0.82,
                78,
                72,
                isActive: _selectedEmotion == 'Sad',
                activeColor: AppColors.riskHigh,
                activeBg: AppColors.riskHighBg,
              ),
              _buildEmotionTag(
                'Angry',
                'assets/images/landing/senior_sad_face.jpg',
                '😠 Angry',
                0.74,
                64,
                65,
                isActive: _selectedEmotion == 'Angry',
                activeColor: AppColors.riskModerate,
                activeBg: AppColors.riskModerateBg,
              ),
              _buildEmotionTag(
                'Fear',
                'assets/images/landing/senior_sad_face.jpg',
                '😨 Fear',
                0.78,
                74,
                69,
                isActive: _selectedEmotion == 'Fear',
                activeColor: AppColors.primary,
                activeBg: AppColors.primarySoft,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionTag(
    String key,
    String asset,
    String label,
    double conf,
    int lScore,
    int iScore, {
    required bool isActive,
    required Color activeColor,
    required Color activeBg,
  }) {
    return InkWell(
      onTap: () => _selectSampleEmotion(key, asset, conf, lScore, iScore),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : AppColors.navy,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Text(
                '${(conf * 100).toInt()}%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: activeColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- VOICE RECORDING BOX ---
  Widget _buildVoiceRecordingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with recording blinker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Voice Recording',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isRecording ? AppColors.riskHighBg : AppColors.border,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 8,
                          color: _isRecording ? AppColors.riskHigh : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isRecording ? 'Recording...' : 'Paused',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isRecording ? AppColors.riskHigh : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimer(_recordSeconds),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic Animated Audio Waveform Box
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(24, (i) {
                    final factor = (1 + 0.8 * ((i % 4 == 0) ? 1.0 : 0.4));
                    final waveValue = (_waveController.value * 6.28 + (i * 0.3)).abs();
                    final dynamicHeight = _isRecording
                        ? (12.0 + (35.0 * (0.3 + 0.7 * (1.0 - (waveValue % 1.0)))) * factor)
                            .clamp(8.0, 75.0)
                        : 6.0;

                    return Container(
                      width: 4,
                      height: dynamicHeight,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                        gradient: _isRecording
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.5),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Central Microphone Action Button
          Center(
            child: Column(
              children: [
                InkWell(
                  onTap: _toggleRecording,
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isRecording ? AppColors.riskHigh : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? AppColors.riskHigh : AppColors.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? LucideIcons.square : LucideIcons.mic,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRecording ? 'Tap microphone to stop' : 'Tap microphone to record',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Spoken Transcript Preview
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.messageSquare, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _spokenText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.navy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ASSESSMENT FOCUS PANEL ---
  Widget _buildAssessmentFocusPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assessment Focus',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
        ),
        const SizedBox(height: 4),
        const Text(
          'This assessment helps us understand your emotional well-being and social connection',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _buildFocusBadge(LucideIcons.heart, 'Emotional Well-being', isCurrent: _questions[_currentIndex].category == 'Emotional Well-being'),
            _buildFocusBadge(LucideIcons.users, 'Social Interaction', isCurrent: _questions[_currentIndex].category == 'Social Interaction'),
            _buildFocusBadge(LucideIcons.messageSquare, 'Communication Patterns', isCurrent: _questions[_currentIndex].category == 'Communication Patterns'),
            _buildFocusBadge(LucideIcons.shieldAlert, 'Loneliness Indicators', isCurrent: _questions[_currentIndex].category == 'Loneliness Indicators'),
            _buildFocusBadge(LucideIcons.share2, 'Social-isolation Indicators', isCurrent: _questions[_currentIndex].category == 'Social-isolation Indicators'),
          ],
        ),
      ],
    );
  }

  Widget _buildFocusBadge(IconData icon, String title, {required bool isCurrent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isCurrent ? AppColors.primary : AppColors.muted),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? AppColors.primary : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  // --- RIGHT SIDEBAR PANEL ---
  Widget _buildRightSidePanel(int completed, int remaining) {
    return Column(
      children: [
        // 1. Real-time Analysis Card
        _buildRealtimeAnalysisCard(),
        const SizedBox(height: 18),

        // 2. Loneliness & Social-Isolation Indicators Card
        _buildLonelinessIsolationCard(),
        const SizedBox(height: 18),

        // 3. Session Progress Card
        _buildSessionProgressCard(completed, remaining),
        const SizedBox(height: 18),

        // 4. AI Assistant Tips Card
        _buildAiAssistantCard(),
        const SizedBox(height: 18),

        // 5. End Assessment Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showEndAssessmentDialog,
            icon: const Icon(LucideIcons.xCircle, size: 16, color: AppColors.riskHigh),
            label: const Text(
              'End Assessment',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.riskHigh,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.riskHigh, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // 1. Real-time Analysis Card
  Widget _buildRealtimeAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Real-time Analysis',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 16),

          // Facial Emotion
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Facial Emotion', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text(
                '$_selectedEmotion  ${(_facialConfidence * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.riskLow),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _facialConfidence,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.riskLow,
            ),
          ),
          const SizedBox(height: 14),

          // Voice Emotion
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Voice Emotion', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text(
                '$_voiceEmotion  ${(_voiceConfidence * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _voiceConfidence,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Social Behavior Indicators
          const Text(
            'Social Behavior Indicators',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 10),
          _buildBehaviorRow('• Communication Level', _commLevel, AppColors.riskModerateBg, AppColors.riskModerate),
          const SizedBox(height: 8),
          _buildBehaviorRow('• Engagement Level', _engagementLevel, AppColors.riskLowBg, AppColors.riskLow),
          const SizedBox(height: 8),
          _buildBehaviorRow('• Response Time', _responseTime, const Color(0xFFE0F2FE), Colors.blue),
        ],
      ),
    );
  }

  Widget _buildBehaviorRow(String label, String value, Color bg, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.body)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
      ],
    );
  }

  // 2. Loneliness & Social-Isolation Indicators Card
  Widget _buildLonelinessIsolationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loneliness & Social-Isolation Indicators',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 16),

          // Section A: Loneliness Indicators
          const Text(
            'Loneliness Indicators',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _IndicatorSubRow(label: 'Emotional Disconnection', level: 'Medium'),
                    SizedBox(height: 4),
                    _IndicatorSubRow(label: 'Perceived Loneliness', level: 'High'),
                    SizedBox(height: 4),
                    _IndicatorSubRow(label: 'Social Support', level: 'Low'),
                  ],
                ),
              ),
              _buildCircularScoreGauge(
                score: _lonelinessScore,
                riskLabel: 'Moderate Risk',
                riskColor: AppColors.riskModerate,
                bgRingColor: AppColors.riskModerateBg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Section B: Social-Isolation Indicators
          const Text(
            'Social-Isolation Indicators',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.riskHigh),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _IndicatorSubRow(label: 'Social Interaction Frequency', level: 'Medium'),
                    SizedBox(height: 4),
                    _IndicatorSubRow(label: 'Participation in Activities', level: 'Low'),
                    SizedBox(height: 4),
                    _IndicatorSubRow(label: 'Network Size', level: 'Low'),
                  ],
                ),
              ),
              _buildCircularScoreGauge(
                score: _isolationScore,
                riskLabel: 'High Risk',
                riskColor: AppColors.riskHigh,
                bgRingColor: AppColors.riskHighBg,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularScoreGauge({
    required int score,
    required String riskLabel,
    required Color riskColor,
    required Color bgRingColor,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: score / 100.0,
                strokeWidth: 5,
                backgroundColor: bgRingColor,
                valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              ),
            ),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: riskColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          riskLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: riskColor,
          ),
        ),
      ],
    );
  }

  // 3. Session Progress Card
  Widget _buildSessionProgressCard(int completed, int remaining) {
    final currentNum = _currentIndex + 1;
    final total = _questions.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Progress',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      value: currentNum / total.toDouble(),
                      strokeWidth: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  Text(
                    '$currentNum',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressLegendDot(Colors.blue, 'Completed', '$completed'),
                  const SizedBox(height: 6),
                  _buildProgressLegendDot(AppColors.primary, 'Current', '1'),
                  const SizedBox(height: 6),
                  _buildProgressLegendDot(AppColors.muted, 'Remaining', '$remaining'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLegendDot(Color color, String label, String count) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '• $label',
          style: const TextStyle(fontSize: 12, color: AppColors.body),
        ),
        const SizedBox(width: 6),
        Text(
          count,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
      ],
    );
  }

  // 4. AI Assistant Tips Card
  Widget _buildAiAssistantCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lilac),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.bot, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'AI ASSISTANT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '"I am here to listen and understand how you feel."',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.navy,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showTipsDialog,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(LucideIcons.lightbulb, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Show Tips',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // --- RALPA RESEARCH METHODOLOGY ANALYTICS PANEL (CHAPTER 3: SEC 3.1 - 3.5) ---
  // =========================================================================
  Widget _buildRalpaMethodologyAnalyticsPanel() {
    final dataset = _residentDatasets[_currentResident.id] ?? _residentDatasets['9001']!;
    final bool hasSufficientHistory = _historyLogs.length >= 2;
    final double baselineLoneliness = dataset.baselineLoneliness;
    final double baselineIsolation = dataset.baselineIsolation;
    final double currentLoneliness = _lonelinessScore.toDouble();
    final double currentIsolation = _isolationScore.toDouble();
    final double deltaLoneliness = currentLoneliness - baselineLoneliness;
    final double deltaIsolation = currentIsolation - baselineIsolation;

    final bool isHighRisk = currentLoneliness >= 70 || _selectedEmotion == 'Sad' || _selectedEmotion == 'Angry';
    final String trajectoryStatus = !hasSufficientHistory
        ? 'BASELINE ESTABLISHING (INSUFFICIENT DATA)'
        : (dataset.trendSlope > 1.0 || deltaLoneliness > 10.0
            ? 'DETERIORATING / INCREASING RISK'
            : (dataset.trendSlope < -1.0 ? 'IMPROVING TRAJECTORY' : 'STABLE BASELINE'));
    final Color trajectoryColor = !hasSufficientHistory
        ? AppColors.primary
        : (dataset.trendSlope > 1.0 || deltaLoneliness > 10.0
            ? AppColors.riskHigh
            : (_selectedEmotion == 'Happy' ? AppColors.riskLow : Colors.blueAccent));

    final List<double> forecastValues = hasSufficientHistory
        ? List.generate(14, (i) => (currentLoneliness + (i * dataset.trendSlope * 0.8)).clamp(10.0, 95.0))
        : [];

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Methodology Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.lilac),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(LucideIcons.graduationCap, size: 13, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'RESEARCH METHODOLOGY (SEC 3.1 - 3.5)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RALPA Longitudinal Predictive Intelligence Engine',
                      style: AppTextStyles.h2.copyWith(fontSize: 20, color: AppColors.navy),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Resident-Adaptive Baseline Modelling • Multimodal Deviation Detection • Longitudinal Trajectory Forecasting • Multimodal Attribution',
                      style: TextStyle(fontSize: 12, color: AppColors.body),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: const [
                    Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.riskLow),
                    SizedBox(width: 8),
                    Text(
                      'Models: Carevora Colab Ensembles (High-Risk & Trajectory) + RALPA Engine',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 24),

          // ROW 1: Baseline vs Deviation Card & Benchmark Comparison
          ResponsiveBuilder(
            mobile: (context) => Column(
              children: [
                _buildBaselineDeviationCard(
                  hasSufficientHistory: hasSufficientHistory,
                  baselineLoneliness: baselineLoneliness,
                  currentLoneliness: currentLoneliness,
                  deltaLoneliness: deltaLoneliness,
                  baselineIsolation: baselineIsolation,
                  currentIsolation: currentIsolation,
                  deltaIsolation: deltaIsolation,
                ),
                const SizedBox(height: 20),
                _buildComparativeBenchmarkCard(),
              ],
            ),
            desktop: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBaselineDeviationCard(
                    hasSufficientHistory: hasSufficientHistory,
                    baselineLoneliness: baselineLoneliness,
                    currentLoneliness: currentLoneliness,
                    deltaLoneliness: deltaLoneliness,
                    baselineIsolation: baselineIsolation,
                    currentIsolation: currentIsolation,
                    deltaIsolation: deltaIsolation,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: _buildComparativeBenchmarkCard()),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ROW 2: Trajectory Forecast Chart & SHAP Feature Importance
          ResponsiveBuilder(
            mobile: (context) => Column(
              children: [
                _buildTrajectoryForecastCard(
                  isHighRisk: isHighRisk,
                  status: trajectoryStatus,
                  statusColor: trajectoryColor,
                  forecast: forecastValues,
                ),
                const SizedBox(height: 20),
                _buildShapFeatureImportanceCard(),
              ],
            ),
            desktop: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTrajectoryForecastCard(
                    isHighRisk: isHighRisk,
                    status: trajectoryStatus,
                    statusColor: trajectoryColor,
                    forecast: forecastValues,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: _buildShapFeatureImportanceCard()),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ROW 3: Personalized Interventions & Reassessment Tracking (Sec 3.5)
          _buildPersonalizedInterventionsCard(isHighRisk),
        ],
      ),
    );
  }

  // --- 1. RESIDENT BASELINE & DEVIATION DETECTION CARD (SEC 3.1 & 3.3) ---
  Widget _buildBaselineDeviationCard({
    required bool hasSufficientHistory,
    required double baselineLoneliness,
    required double currentLoneliness,
    required double deltaLoneliness,
    required double baselineIsolation,
    required double currentIsolation,
    required double deltaIsolation,
  }) {
    final bool hasHighDrift = hasSufficientHistory && (deltaLoneliness > 10.0 || deltaIsolation > 10.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.userCheck, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Resident-Specific Baseline & Deviation',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: !hasSufficientHistory
                      ? AppColors.primarySoft
                      : (hasHighDrift ? AppColors.riskHighBg : AppColors.riskLowBg),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  !hasSufficientHistory
                      ? 'Baseline Establishing (N < 2)'
                      : (hasHighDrift ? 'Significant Deviation Δ' : 'Baseline Aligned'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: !hasSufficientHistory
                        ? AppColors.primary
                        : (hasHighDrift ? AppColors.riskHigh : AppColors.riskLow),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !hasSufficientHistory
                ? 'Methodology Sec 3.1 & 3.5: Resident requires at least 2 longitudinal assessments across distinct care periods to establish individual normal baseline.'
                : 'Methodology Sec 3.1 & 3.3: Historical modeled baseline compared against current multimodal observation to identify resident-specific drift.',
            style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3),
          ),
          const SizedBox(height: 16),

          // Loneliness Metric Comparison
          _buildDeviationMetricRow(
            label: 'Loneliness Index',
            hasSufficientHistory: hasSufficientHistory,
            baseline: baselineLoneliness,
            current: currentLoneliness,
            delta: deltaLoneliness,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Social Isolation Metric Comparison
          _buildDeviationMetricRow(
            label: 'Social-Isolation Index',
            hasSufficientHistory: hasSufficientHistory,
            baseline: baselineIsolation,
            current: currentIsolation,
            delta: deltaIsolation,
          ),
          const SizedBox(height: 14),

          // Clinical Interpretation Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  !hasSufficientHistory
                      ? LucideIcons.info
                      : (hasHighDrift ? LucideIcons.alertTriangle : LucideIcons.shieldCheck),
                  size: 16,
                  color: !hasSufficientHistory
                      ? AppColors.primary
                      : (hasHighDrift ? AppColors.riskModerate : AppColors.riskLow),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    !hasSufficientHistory
                        ? 'Initial intake session recorded. Baseline distribution requires subsequent observation sessions to model variance and separate fluctuations from sustained drift.'
                        : (hasHighDrift
                            ? 'Resident shows +${deltaLoneliness.toStringAsFixed(1)}Δ deviation from personal baseline. Indicates acute loneliness spike requiring proactive caregiver intervention.'
                            : 'Resident scores align within expected historical stability zone (±3.0Δ deviation). No anomalous behavioral departure detected.'),
                    style: const TextStyle(fontSize: 11, color: AppColors.body, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviationMetricRow({
    required String label,
    required double baseline,
    required double current,
    required double delta,
    bool hasSufficientHistory = true,
  }) {
    final bool isPositive = delta > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 2),
            Text(
              hasSufficientHistory
                  ? 'Historical Baseline: ${baseline.toInt()}/100'
                  : 'Historical Baseline: Pending (Intake Session)',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${current.toInt()} / 100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isPositive ? AppColors.riskHigh : AppColors.riskLow,
                  ),
                ),
                Text(
                  hasSufficientHistory
                      ? '${isPositive ? "+" : ""}${delta.toStringAsFixed(1)} Δ drift'
                      : 'Establishing',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasSufficientHistory
                        ? (isPositive ? AppColors.riskHigh : AppColors.riskLow)
                        : AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // --- 2. COMPARATIVE BENCHMARK CARD (SEC 3.3) ---
  Widget _buildComparativeBenchmarkCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.barChart3, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Experimental Comparative Targets',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Sec 3.3 Comparative Design',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Proposal Sec 3.3 Comparative Design: Target experimental evaluation criteria formulated to validate RALPA advantage against non-adaptive baselines in future clinical trials.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 14),

          // Benchmark Table / Rows
          _buildBenchmarkComparisonRow(
            modelName: '1. Non-Personalized ML',
            description: 'Static multimodal features without baseline',
            mae: '8.6',
            accuracy: '76.2%',
            isProposed: false,
          ),
          const SizedBox(height: 8),
          _buildBenchmarkComparisonRow(
            modelName: '2. Population-Level Model',
            description: 'Trained on cohort averages across homes',
            mae: '7.8',
            accuracy: '79.4%',
            isProposed: false,
          ),
          const SizedBox(height: 8),
          _buildBenchmarkComparisonRow(
            modelName: '3. Current-State Model',
            description: 'Single latest observation without temporal trend',
            mae: '6.9',
            accuracy: '82.1%',
            isProposed: false,
          ),
          const SizedBox(height: 8),
          _buildBenchmarkComparisonRow(
            modelName: 'Proposed: RALPA Architecture',
            description: 'Resident Baseline + Deviation + Trajectory (Validation Target)',
            mae: '< 4.0 (Target)',
            accuracy: '> 90.0% (Target)',
            isProposed: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkComparisonRow({
    required String modelName,
    required String description,
    required String mae,
    required String accuracy,
    required bool isProposed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isProposed ? AppColors.primarySoft.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isProposed ? AppColors.primary : AppColors.border,
          width: isProposed ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      modelName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isProposed ? AppColors.primary : AppColors.navy,
                      ),
                    ),
                    if (isProposed) ...[
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.sparkles, size: 12, color: AppColors.primary),
                    ],
                  ],
                ),
                Text(description, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Acc: $accuracy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isProposed ? AppColors.primary : AppColors.navy)),
                  Text('MAE: $mae', style: const TextStyle(fontSize: 9, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. LONGITUDINAL 7-DAY TRAJECTORY FORECAST CARD (SEC 3.1 & 3.4) ---
  Widget _buildTrajectoryForecastCard({
    required bool isHighRisk,
    required String status,
    required Color statusColor,
    required List<double> forecast,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.trendingUp, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Longitudinal 14-Day Trajectory Forecast',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Methodology Sec 3.1 & 3.4: Temporal trend modeling predicting continuous risk trajectory across 14 future care periods (Day +1 to Day +14).',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 16),

          if (forecast.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lilac),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Insufficient Historical Data for Trajectory Forecasting',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Per RALPA specification (Sec 3.1 & 3.5), at least 2 longitudinal assessments across distinct timepoints are required to compute personal baseline deviation and model trajectory slope.',
                          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Visual 14-Day Projection Bar/Step Indicator
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Forecasted Loneliness Risk (Day +1 to Day +14)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'RALPA Linear Regression Projection',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(forecast.length, (index) {
                        final val = forecast[index];
                        final dayLabel = index == 0 ? 'Today' : 'D+$index';
                        final barHeight = (val / 100.0 * 55.0).clamp(12.0, 55.0);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${val.toInt()}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isHighRisk ? AppColors.riskHigh : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 22,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isHighRisk
                                      ? AppColors.riskHigh.withValues(alpha: 0.2 + ((index % 7) * 0.11))
                                      : AppColors.primary.withValues(alpha: 0.8 - ((index % 7) * 0.08)),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isHighRisk ? AppColors.riskHigh : AppColors.primary,
                                    width: index == 0 ? 1.5 : 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dayLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Proposal Table 3:1 Evaluation Target Protocol Strip
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Proposal Table 3:1 Benchmark Protocol Targets (Validation in Progress):',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildMetricChip('Target Accuracy', '> 85.0%'),
                  _buildMetricChip('Target Macro F1', '> 0.80'),
                  _buildMetricChip('Target MAE Error', '< 5.0 pts'),
                  _buildMetricChip('Target ROC-AUC', '> 0.85'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navy)),
        ],
      ),
    );
  }

  // --- 4. MULTIMODAL FEATURE ATTRIBUTION CARD (SEC 3.4 TABLE 3:1) ---
  Widget _buildShapFeatureImportanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.layers, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Multimodal Modality Attribution',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Table 3:1 Protocol Weights',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Methodology Table 3:1: Predefined linear modality attribution weights (Questionnaire 40%, Social Attendance 25%, Facial Affect 20%, Voice Acoustics 15%) providing transparent clinical interpretability prior to post-hoc SHAP kernel training.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 14),

          // Modality 1: Questionnaire
          _buildShapBarRow(
            modality: 'Questionnaire Self-Report (40% Weight)',
            contribution: 40.0,
            color: AppColors.primary,
            clinicalNote: 'UCLA Loneliness scale items measuring subjective feelings of isolation.',
          ),
          const SizedBox(height: 10),

          // Modality 2: Social-Behavioral
          _buildShapBarRow(
            modality: 'Social-Behavioral Attendance (25% Weight)',
            contribution: 25.0,
            color: Colors.blueAccent,
            clinicalNote: 'Group activity participation frequency and recorded room seclusion intervals.',
          ),
          const SizedBox(height: 10),

          // Modality 3: Facial Expression
          _buildShapBarRow(
            modality: 'Facial Affect Recognition (20% Weight)',
            contribution: 20.0,
            color: AppColors.riskModerate,
            clinicalNote: 'PyTorch FER-2013 affect classification (flat affect vs positive valence).',
          ),
          const SizedBox(height: 10),

          // Modality 4: Vocal Acoustics
          _buildShapBarRow(
            modality: 'Vocal Acoustic Prosody (15% Weight)',
            contribution: 15.0,
            color: AppColors.leafGreen,
            clinicalNote: 'Rule-based acoustic metrics (RMS energy, pitch cadence, speech latency).',
          ),
        ],
      ),
    );
  }

  Widget _buildShapBarRow({
    required String modality,
    required double contribution,
    required Color color,
    required String clinicalNote,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(modality, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
            Text('${contribution.toInt()}% Impact', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: contribution / 100.0,
            minHeight: 5,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(clinicalNote, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontStyle: FontStyle.italic)),
      ],
    );
  }

  // --- 5. PERSONALIZED CARE INTERVENTIONS & REASSESSMENT CARD (SEC 3.5) ---
  Widget _buildPersonalizedInterventionsCard(bool isHighRisk) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lilac),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.heartPulse, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Personalized Intervention Protocols & Reassessment (Sec 3.5)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.lilac),
                ),
                child: const Text(
                  'Closed-Loop Reassessment Active',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Methodology Sec 3.5: Following personalized recommendations, post-intervention observations are monitored to verify whether predicted trajectory stabilizes or improves.',
            style: TextStyle(fontSize: 11, color: AppColors.body),
          ),
          const SizedBox(height: 14),

          // Interventions Grid
          ResponsiveBuilder(
            mobile: (context) => Column(
              children: [
                _buildInterventionCardItem(
                  icon: LucideIcons.sun,
                  title: 'Afternoon Garden & Daylight Stroll',
                  description: 'Exposure to natural sunlight and walking garden path supports circadian wellness and offsets evening loneliness surge.',
                  priority: isHighRisk ? 'High Priority' : 'Standard',
                  priorityColor: isHighRisk ? AppColors.riskHigh : AppColors.riskLow,
                ),
                const SizedBox(height: 10),
                _buildInterventionCardItem(
                  icon: LucideIcons.coffee,
                  title: 'Parlor Herbal Tea Connection (3:30 PM)',
                  description: 'Facilitated small-group peer table matching with active conversational partner to rebuild regular social interaction frequency.',
                  priority: 'Recommended',
                  priorityColor: AppColors.primary,
                ),
              ],
            ),
            desktop: (context) => Row(
              children: [
                Expanded(
                  child: _buildInterventionCardItem(
                    icon: LucideIcons.sun,
                    title: 'Afternoon Garden & Daylight Stroll',
                    description: 'Exposure to natural sunlight and walking garden path supports circadian wellness and offsets evening loneliness surge.',
                    priority: isHighRisk ? 'High Priority' : 'Standard',
                    priorityColor: isHighRisk ? AppColors.riskHigh : AppColors.riskLow,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildInterventionCardItem(
                    icon: LucideIcons.coffee,
                    title: 'Parlor Herbal Tea Connection (3:30 PM)',
                    description: 'Facilitated small-group peer table matching with active conversational partner to rebuild regular social interaction frequency.',
                    priority: 'Recommended',
                    priorityColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionCardItem({
    required IconData icon,
    required String title,
    required String description,
    required String priority,
    required Color priorityColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: priorityColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB-VIEW: PERSONALIZED INTERVENTIONS & REASSESSMENT (FR11, FR14) ---
  Widget _buildPersonalizedInterventionsTab() {
    final completedCount = _activities.where((a) => a.isCompleted).length;
    final pendingCount = _activities.length - completedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Protocol Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Personalized Care Interventions & Response Reassessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Grounding in Proposal Sec 1.1, FR11 & FR14: Interventions are tailored across 4 research modalities (Music, Reading, Religious/Cultural, Social) and tracked post-activity to measure longitudinal response.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricMiniItem('Active Resident', _currentResident.name, LucideIcons.user),
                    _buildMetricMiniItem('Completed Activities', '$completedCount / ${_activities.length}', LucideIcons.checkCircle2),
                    _buildMetricMiniItem('Pending Action', '$pendingCount Recommended', LucideIcons.clock),
                    _buildMetricMiniItem('RALPA Trajectory', 'Deterioration Warning', LucideIcons.alertTriangle),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Activities List
        const Text(
          'Targeted Activity Interventions for Loneliness & Isolation Mitigation',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        const SizedBox(height: 12),
        ..._activities.map((activity) => _buildActivityDetailCard(activity)),

        const SizedBox(height: 20),
        // Escalation Protocol Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.lavenderBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lilac),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.shieldAlert, color: AppColors.primary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Proposal Section 1.1 Protocol: Counsellor Escalation & Professional Follow-Up',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'If post-intervention reassessment shows continued high loneliness (Score > 75) or persistent isolation over 2 consecutive cycles, care attendants are prompted to schedule a registered gerontological counsellor or psychologist consultation.',
                      style: TextStyle(fontSize: 12, color: AppColors.body, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricMiniItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityDetailCard(PersonalizedActivityItem activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activity.isCompleted ? AppColors.leafGreen.withValues(alpha: 0.5) : AppColors.border,
          width: activity.isCompleted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: activity.priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(activity.icon, size: 22, color: activity.priorityColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: activity.isCompleted
                                ? AppColors.leafGreen.withValues(alpha: 0.15)
                                : activity.priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            activity.isCompleted ? 'COMPLETED & REASSESSED' : activity.priority,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: activity.isCompleted ? AppColors.leafGreen : activity.priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${activity.category}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activity.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.body, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (activity.isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.checkCircle2, size: 14, color: AppColors.leafGreen),
                      SizedBox(width: 6),
                      Text(
                        'Post-Intervention Reassessment Record:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (activity.completionNotes != null)
                    Text('• Caregiver Notes: ${activity.completionNotes}',
                        style: const TextStyle(fontSize: 11, color: AppColors.body)),
                  if (activity.residentFeedback != null)
                    Text('• Resident Response: "${activity.residentFeedback}"',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.primary)),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showCounsellorEscalationModal(activity),
                  icon: const Icon(LucideIcons.shieldAlert, size: 14, color: AppColors.riskModerate),
                  label: const Text('Escalate to Counsellor', style: TextStyle(fontSize: 12, color: AppColors.riskModerate)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.riskModerate),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showActivityCompletionModal(activity),
                  icon: const Icon(LucideIcons.check, size: 14, color: Colors.white),
                  label: const Text('Mark Completed & Reassess', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- SUB-VIEW: ASSESSMENT HISTORY & AUDIT LOGS (FR4, FR13) ---
  Widget _buildAssessmentHistoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Longitudinal Assessment History & Records',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Historical multimodal records for ${_currentResident.name} used by RALPA to track deviations and forecast risk trajectories.',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.database, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${_historyLogs.length} Sessions Logged',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Records Table Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceSecondary),
              columns: const [
                DataColumn(label: Text('Record ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Facial / Vocal Affect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Loneliness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Social Isolation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Baseline Dev.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Trajectory Forecast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Intervention Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Assessor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: _historyLogs.map((log) {
                final isElevated = log.lonelinessScore > 70;
                return DataRow(
                  cells: [
                    DataCell(Text(log.id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataCell(Text(log.date, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(log.primaryEmotion, style: const TextStyle(fontSize: 11))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isElevated ? AppColors.riskHigh.withValues(alpha: 0.12) : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${log.lonelinessScore} / 100',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isElevated ? AppColors.riskHigh : AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text('${log.isolationScore} / 100', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    DataCell(
                      Text(
                        '${log.deviation > 0 ? "+" : ""}${log.deviation.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: log.deviation > 15 ? AppColors.riskHigh : AppColors.leafGreen,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: log.trajectory.contains('Increasing')
                              ? AppColors.riskHigh.withValues(alpha: 0.1)
                              : AppColors.leafGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.trajectory,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: log.trajectory.contains('Increasing') ? AppColors.riskHigh : AppColors.leafGreen,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(log.interventionStatus, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(log.assessedBy, style: const TextStyle(fontSize: 11, color: AppColors.muted))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // --- ELDER RESIDENT ACCESSIBLE VIEW (SECTION 6.6 PRIVACY & DISTRESS SHIELD) ---
  Widget _buildElderResidentView(AssessmentQuestion currentQ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Friendly Header (No clinical scores)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.smile, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome, ${_currentResident.name}!',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Let\'s take a gentle moment together today. How are you feeling?',
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Conversation Question Card (Big font & large tactile buttons)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentIndex + 1} of ${_questions.length}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.volume2, color: AppColors.primary, size: 28),
                          tooltip: 'Listen to Question',
                          onPressed: _readQuestionAloud,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentQ.prompt,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Microphone interaction button
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: _isRecording ? AppColors.riskHigh : AppColors.primary,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? AppColors.riskHigh : AppColors.primary).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isRecording ? LucideIcons.square : LucideIcons.mic, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              _isRecording ? 'Listening... Tap to Stop' : 'Tap to Speak Your Answer',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Your Words: "$_spokenText"',
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppColors.navy, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentIndex > 0)
                          ElevatedButton.icon(
                            onPressed: _previousQuestion,
                            icon: const Icon(LucideIcons.chevronLeft, size: 20),
                            label: const Text('Previous', style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceSecondary,
                              foregroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          )
                        else
                          const SizedBox(),
                        ElevatedButton.icon(
                          onPressed: _nextQuestion,
                          icon: const Icon(LucideIcons.chevronRight, size: 20),
                          label: Text(
                            _currentIndex < _questions.length - 1 ? 'Next Question' : 'Complete Check-In',
                            style: const TextStyle(fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Senior Friendly Activities List
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Enjoyable Activities for Today',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose activities you love. You can let us know when you finish them!',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    ..._activities.map((act) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: act.isCompleted ? AppColors.leafGreen.withValues(alpha: 0.08) : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: act.isCompleted ? AppColors.leafGreen : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(act.icon, color: act.isCompleted ? AppColors.leafGreen : AppColors.primary, size: 24),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      act.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: act.isCompleted ? AppColors.leafGreen : AppColors.navy,
                                        decoration: act.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(act.category, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              if (act.isCompleted)
                                const Icon(LucideIcons.checkCircle2, color: AppColors.leafGreen, size: 24)
                              else
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      act.isCompleted = true;
                                      act.residentFeedback = 'Completed happily during morning routine.';
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Great job completing "${act.title}"!'),
                                        backgroundColor: AppColors.leafGreen,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('I did this!'),
                                ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODALS FOR INTERVENTIONS & REASSESSMENT ---
  void _showActivityCompletionModal(PersonalizedActivityItem activity) {
    final notesController = TextEditingController(text: 'Resident engaged positively and showed interest.');
    final feedbackController = TextEditingController(text: 'Reported feeling uplifted and more sociable afterwards.');
    String reassessmentOutcome = 'Positive Improvement';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(LucideIcons.checkCircle2, color: AppColors.leafGreen, size: 22),
              SizedBox(width: 10),
              Text('Log Activity & Post Reassessment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity: ${activity.title}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 12),
                const Text('Caregiver Observation Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Enter observation during activity...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Resident Verbal Feedback:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: feedbackController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Resident feedback quote...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Post-Intervention Reassessment Mood:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: reassessmentOutcome,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Positive Improvement', child: Text('Positive Improvement (Valence Elevated)')),
                    DropdownMenuItem(value: 'Stable / Mild Relief', child: Text('Stable / Mild Relief')),
                    DropdownMenuItem(value: 'No Significant Change', child: Text('No Significant Change (Follow-up Needed)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => reassessmentOutcome = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  activity.isCompleted = true;
                  activity.completionNotes = notesController.text;
                  activity.residentFeedback = feedbackController.text;
                  // If outcome improved, simulate slight reduction in loneliness
                  if (reassessmentOutcome == 'Positive Improvement' && _lonelinessScore > 55) {
                    _lonelinessScore -= 5;
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Activity logged & Post-Intervention Reassessment updated!'),
                    backgroundColor: AppColors.leafGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save & Update Reassessment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCounsellorEscalationModal(PersonalizedActivityItem activity) {
    final reasonController = TextEditingController(
      text: 'Resident exhibits persistent affect flattening and withdrawal despite scheduled activities. RALPA longitudinal trend indicates increasing risk.',
    );
    String urgency = 'High Priority (Within 24 Hours)';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(LucideIcons.shieldAlert, color: AppColors.riskModerate, size: 22),
              SizedBox(width: 10),
              Text('Escalate to Care Home Counsellor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proposal Section 1.1: When loneliness and social isolation indicators remain elevated, escalate to clinical care staff or psychological counsellor for direct intervention.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3),
                ),
                const SizedBox(height: 14),
                const Text('Urgency Level:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: urgency,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Immediate (Within 4 Hours)', child: Text('Immediate (Within 4 Hours)')),
                    DropdownMenuItem(value: 'High Priority (Within 24 Hours)', child: Text('High Priority (Within 24 Hours)')),
                    DropdownMenuItem(value: 'Routine Review (Weekly)', child: Text('Routine Review (Weekly)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => urgency = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Clinical Escalation Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter clinical concerns and observed patterns...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Escalation alert sent to Care Home Counsellor ($urgency).'),
                    backgroundColor: AppColors.riskModerate,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.riskModerate,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit Escalation Notice'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorSubRow extends StatelessWidget {
  final String label;
  final String level;

  const _IndicatorSubRow({required this.label, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
        Text(
          level,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}

class PersonalizedActivityItem {
  final String id;
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final String priority;
  final Color priorityColor;
  bool isCompleted;
  String? completionNotes;
  String? residentFeedback;

  PersonalizedActivityItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.priority,
    required this.priorityColor,
    this.isCompleted = false,
    this.completionNotes,
    this.residentFeedback,
  });
}

class EmotionalAssessmentHistoryLog {
  final String id;
  final String date;
  final String primaryEmotion;
  final int lonelinessScore;
  final int isolationScore;
  final double deviation;
  final String trajectory;
  final String interventionStatus;
  final String assessedBy;

  const EmotionalAssessmentHistoryLog({
    required this.id,
    required this.date,
    required this.primaryEmotion,
    required this.lonelinessScore,
    required this.isolationScore,
    required this.deviation,
    required this.trajectory,
    required this.interventionStatus,
    required this.assessedBy,
  });
}

class ResidentProfileDataset {
  final double baselineLoneliness;
  final double baselineIsolation;
  final String baselineEstablishedDate;
  final List<EmotionalAssessmentHistoryLog> logs;
  final List<PersonalizedActivityItem> activities;
  final double trendSlope;

  const ResidentProfileDataset({
    required this.baselineLoneliness,
    required this.baselineIsolation,
    required this.baselineEstablishedDate,
    required this.logs,
    required this.activities,
    required this.trendSlope,
  });
}
