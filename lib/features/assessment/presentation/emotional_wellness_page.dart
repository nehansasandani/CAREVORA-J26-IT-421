import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/responsive/responsive_builder.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/mock/mock_carevora_data.dart';
import '../../../data/models/carevora_models.dart';
import '../application/facial_emotion_ai_service.dart';
import '../application/automatic_facial_capture_service.dart';
import '../application/emotional_assessment_service.dart';
import '../application/vocal_emotion_ai_service.dart';
import '../application/social_audit_service.dart';
import '../application/cognitive_assessment_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/services/audio_player_service.dart';
import '../../../core/services/url_launcher_service.dart';
import '../../../shared/widgets/carevora_avatar.dart';

class EmotionalWellnessPage extends ConsumerStatefulWidget {
  final String? initialResidentId;

  const EmotionalWellnessPage({super.key, this.initialResidentId});

  @override
  ConsumerState<EmotionalWellnessPage> createState() => _EmotionalWellnessPageState();
}

class _EmotionalWellnessPageState extends ConsumerState<EmotionalWellnessPage>
    with TickerProviderStateMixin {
  // Start from Question 1 (index 0)
  int _currentIndex = 0;
  final List<AssessmentQuestion> _questions = MockCarevoraData.emotionalQuestions;
  final Map<int, bool?> _answers = {};
  bool _isSubmittingAssessment = false;
  String? _submissionError;

  // Real-time analysis metrics
  String _selectedEmotion = 'Happy';
  double _facialConfidence = 0.85;
  String _voiceEmotion = 'Neutral';
  double _voiceConfidence = 0.72;
  double _vocalWellnessScore = 75.0;

  // Scores
  int _lonelinessScore = 67;
  int _isolationScore = 58;

  // Social behavior indicators
  String _commLevel = 'Moderate';
  String _engagementLevel = 'High';
  String _responseTime = 'Normal';

  // Voice recording & timers
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String _spokenText = '';
  double _soundLevel = 0.0;
  String _micStatusNotice = '';
  String _selectedVoiceLocale = 'si-LK';
  String get _selectedVoiceLocaleLabel => _selectedVoiceLocale == 'si-LK' ? 'සිංහල' : 'English';

  // Automatic Facial Affect Capture & Consent
  late final AutomaticFacialCaptureService _facialCaptureService;
  bool _hasFacialConsent = false;

  // Speech and Voice engines
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;

  // Camera & Image state
  String _currentFaceAsset = 'assets/images/landing/senior_neutral_calm_face.jpg';
  Uint8List? _capturedImageBytes;
  final ImagePicker _picker = ImagePicker();

  // Animations
  late AnimationController _waveController;
  late AnimationController _scannerController;
  late AnimationController _clapController;
  bool _showClapAnimation = false;

  // Negative answer reason tracking & speech input
  final Map<int, String> _elderNegativeReasons = {};
  late final TextEditingController _reasonTextController;
  bool _isRecordingReason = false;

  // Conversational AI Support Intervention Flow
  int _interventionStage = 0;
  String _selectedSongTitle = 'සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)';
  bool _isPlayingMusic = false;
  int _songPlaybackSeconds = 0;
  int _currentMusicDurationSeconds = 300; // 300s (5m) for songs, 900s (15m) for Pirith / Was Dadu Rawaya
  Timer? _songTimer;
  int _conversationSeconds = 0;
  static const int _conversationTotalSeconds = 600; // 10 minutes (600 seconds) soothing conversation
  Timer? _conversationTimer;
  late final TextEditingController _aiChatInputController;
  final ScrollController _aiChatScrollController = ScrollController();
  bool _isAiChatVoiceRecording = false;
  final List<Map<String, dynamic>> _aiConversationMessages = [];
  bool _caregiverNotified = false;

  int _getTrackDurationSeconds(String trackTitle) {
    final lower = trackTitle.toLowerCase();
    if (lower.contains('පිරිත්') || lower.contains('pirith') || lower.contains('සූත්‍ර') || lower.contains('sutta')) {
      return 900; // 15 minutes (900 seconds) for Pirith
    } else if (lower.contains('වස්දඬු') || lower.contains('flute') || lower.contains('was dadu') || lower.contains('බටනලා')) {
      return 900; // 15 minutes (900 seconds) for Was Dadu Rawaya
    } else {
      return 300; // 5 minutes (300 seconds) for songs (Nanda Malini, Amaradeva, etc.)
    }
  }

  static const List<String> _defaultSuggestedTracks = [
    'නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)',
    'නන්දා මාලිනී - රන්කෙන්දෙන් බැඳි අතැඟිලි (Nanda Malini)',
    'නන්දා මාලිනී - සාර සොඳුරු මල් පිපී (Nanda Malini)',
    'ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව',
    'සෙත් පිරිත් සජ්ඣායනය (Seth Pirith Deshana - 15 Mins)',
    'සන්සුන් වස්දඬු රාවය (Acoustic Bamboo Flute - Was Dadu Rawaya)',
    'සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)',
    'වික්ටර් රත්නායක - සිත නිවන සෙවන (Victor Ratnayake)',
  ];

  static const Map<String, String> _songAudioPaths = {
    'සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)': 'audio/pirith.mp3',
    'සෙත් පිරිත් සජ්ඣායනය (Seth Pirith Deshana - 15 Mins)': 'audio/pirith.mp3',
    'කරණීයමෙත්ත සූත්‍රය (Karaniya Metta Sutta - 15 Mins)': 'audio/pirith.mp3',
    'නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)': 'audio/nanda_malini.mp3',
    'නන්දා මාලිනී - රන්කෙන්දෙන් බැඳි අතැඟිලි (Nanda Malini)': 'audio/nanda_malini.mp3',
    'නන්දා මාලිනී - සාර සොඳුරු මල් පිපී (Nanda Malini)': 'audio/nanda_malini.mp3',
    'ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව': 'audio/amaradeva.mp3',
    'සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)': 'audio/sunil_edirisinghe.mp3',
    'වික්ටර් රත්නායක - සිත නිවන සෙවන (Victor Ratnayake)': 'audio/victor_ratnayake.mp3',
    'සන්සුන් වස්දඬු රාවය (Acoustic Bamboo Flute - Was Dadu Rawaya)': 'audio/bamboo_flute.mp3',
    'සොබාදහමේ සන්සුන් නාදය (Peaceful Nature Streams)': 'audio/nature_stream.mp3',
  };

  // Sub-navigation: 0: Assessment Session, 1: RALPA Trajectory, 2: Care Interventions & Reassessment, 3: Assessment History
  int _selectedSubTab = 0;
  late Resident _currentResident;
  SocialAuditRecord? _latestSocialAudit;
  bool _isLoadingSocialAudit = false;
  bool _useSimplifiedElderView = false;
  late List<Resident> _availableResidents;
  int? _educationYears = 13;
  String _facilityName = 'Serenity Elder Home';
  List<CognitiveResidentProfile>? _liveProfiles;

  late List<PersonalizedActivityItem> _activities;
  late List<EmotionalAssessmentHistoryLog> _historyLogs;
  late Map<String, ResidentProfileDataset> _residentDatasets;

  void _initResidents() {
    final baseResidents = [
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

    _availableResidents = List<Resident>.from(baseResidents);

    final authState = ref.read(authProvider).state;
    final userName = authState.userName?.trim();

    if (authState.isElder) {
      Resident? matchedResident;
      if (authState.residentId != null) {
        final bId = authState.residentId!;
        for (final r in _availableResidents) {
          final parsed = int.tryParse(r.id);
          if (parsed == bId ||
              (bId == 1 && (parsed == 9002 || r.name.contains('Sarah'))) ||
              (bId == 2 && (parsed == 9003 || r.name.contains('Arthur'))) ||
              (bId == 3 && (parsed == 9004 || r.name.contains('Margaret')))) {
            matchedResident = r;
            break;
          }
        }
      }
      if (matchedResident == null && userName != null && userName.isNotEmpty) {
        final cleanName = userName.toLowerCase();
        for (final r in _availableResidents) {
          final rClean = r.name.toLowerCase().replaceAll('mrs. ', '').replaceAll('mr. ', '').replaceAll('dr. ', '');
          if (rClean.contains(cleanName) || cleanName.contains(rClean)) {
            matchedResident = r;
            break;
          }
        }
      }

      if (matchedResident != null) {
        _currentResident = matchedResident;
      } else {
        final bId = authState.residentId;
        final isFemale = userName != null &&
            (userName.contains('Mrs.') ||
                userName.contains('Malini') ||
                userName.contains('Sarah') ||
                userName.contains('Margaret') ||
                userName.contains('Seetha') ||
                userName.contains('Nanda'));
        final isMale = userName != null &&
            (userName.contains('Mr.') ||
                userName.contains('Arthur') ||
                userName.contains('Kamal') ||
                userName.contains('James') ||
                userName.contains('Robert') ||
                userName.contains('Senarath'));
        final detectedGender = isFemale ? 'Female' : (isMale ? 'Male' : 'Senior Resident');
        final defaultAge = (bId == 165 || (userName != null && userName.contains('Malini'))) ? 65 : 75;
        final defaultRoom = (bId == 165 || (userName != null && userName.contains('Malini'))) ? '30' : '101';

        final newResident = Resident(
          id: bId?.toString() ?? '9005',
          name: (userName != null && userName.isNotEmpty)
              ? userName
              : (bId == 165 ? 'Malini Bandara' : 'Senior Resident'),
          age: defaultAge,
          gender: detectedGender,
          roomNo: defaultRoom,
          lastAssessmentDate: 'Today, 10:30 AM',
          cognitiveScore: 0.72,
          cognitiveTrend: 0.05,
          emotionalScore: 0.78,
          emotionalTrend: 0.08,
          metabolicScore: 0.68,
          metabolicTrend: 0.02,
          overallIndex: 0.73,
          overallTrend: 0.05,
          avatarUrl: authState.avatarUrl,
        );
        _currentResident = newResident;
      }
      _availableResidents = [_currentResident];
    } else {
      if (widget.initialResidentId != null) {
        final target = widget.initialResidentId!;
        Resident? found;
        for (final r in _availableResidents) {
          final parsed = int.tryParse(r.id);
          if (r.id == target ||
              (target == '1' && (parsed == 9002 || r.name.contains('Sarah'))) ||
              (target == '2' && (parsed == 9003 || r.name.contains('Arthur'))) ||
              (target == '3' && (parsed == 9004 || r.name.contains('Margaret')))) {
            found = r;
            break;
          }
        }
        _currentResident = found ?? _availableResidents.first;
      } else {
        _currentResident = _availableResidents.first;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _reasonTextController = TextEditingController();
    _aiChatInputController = TextEditingController();
    _initResidents();
    _initActivitiesAndHistory();
    _loadResidentData(_currentResident.id);
    _initAnimations();
    _initVoiceEngines();
    _initFacialCapture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLiveResidentProfile();
      _fetchLatestSocialAuditForCurrentResident();
    });
  }

  String _formatDisplayId(String id) {
    final clean = id.trim();
    if (clean.startsWith('R') || clean.startsWith('r')) return clean.toUpperCase();
    final parsed = int.tryParse(clean);
    if (parsed != null) {
      if (parsed >= 9000) {
        return 'R${(parsed - 9000).toString().padLeft(4, '0')}';
      }
      return 'R${parsed.toString().padLeft(4, '0')}';
    }
    return 'R-$clean';
  }

  Future<void> _loadLiveResidentProfile() async {
    final authState = ref.read(authProvider).state;
    final token = authState.token;

    try {
      if (authState.isElder) {
        final bId = authState.residentId ?? _resolveBackendResidentId();
        final fetched = await CognitiveAssessmentService.fetchResident(
          residentId: bId,
          token: token,
        );
        if (fetched != null && mounted) {
          final cleanRoom = fetched.roomNumber
              .replaceAll('Room No: ', '')
              .replaceAll('Room ', '')
              .replaceAll('Suite ', '')
              .trim();
          final isFemale = fetched.name.contains('Mrs.') ||
              fetched.name.contains('Malini') ||
              fetched.name.contains('Sarah') ||
              fetched.name.contains('Margaret') ||
              fetched.name.contains('Seetha');
          final isMale = fetched.name.contains('Mr.') ||
              fetched.name.contains('Arthur') ||
              fetched.name.contains('Kamal') ||
              fetched.name.contains('James') ||
              fetched.name.contains('Robert');
          final genderStr = (fetched.gender != null && fetched.gender!.isNotEmpty && fetched.gender != 'Unknown')
              ? fetched.gender!
              : (isFemale ? 'Female' : (isMale ? 'Male' : 'Senior Resident'));

          setState(() {
            _educationYears = fetched.educationYears ?? 13;
            if (fetched.elderHomeName != null && fetched.elderHomeName!.isNotEmpty) {
              _facilityName = fetched.elderHomeName!;
            }
            _currentResident = Resident(
              id: fetched.id.toString(),
              name: fetched.name,
              age: fetched.age ?? _currentResident.age,
              gender: genderStr,
              roomNo: cleanRoom.isNotEmpty ? cleanRoom : _currentResident.roomNo,
              lastAssessmentDate: _currentResident.lastAssessmentDate,
              cognitiveScore: _currentResident.cognitiveScore,
              cognitiveTrend: _currentResident.cognitiveTrend,
              emotionalScore: _currentResident.emotionalScore,
              emotionalTrend: _currentResident.emotionalTrend,
              metabolicScore: _currentResident.metabolicScore,
              metabolicTrend: _currentResident.metabolicTrend,
              overallIndex: _currentResident.overallIndex,
              overallTrend: _currentResident.overallTrend,
              socialScore: _currentResident.socialScore,
              avatarUrl: fetched.avatarUrl ?? _currentResident.avatarUrl ?? authState.avatarUrl,
            );
            _availableResidents = [_currentResident];
          });
          _loadResidentData(_currentResident.id);
        }
      } else {
        final liveList = await CognitiveAssessmentService.fetchResidents(token: token);
        if (liveList.isNotEmpty && mounted) {
          final converted = liveList.map((fetched) {
            final cleanRoom = fetched.roomNumber
                .replaceAll('Room No: ', '')
                .replaceAll('Room ', '')
                .replaceAll('Suite ', '')
                .trim();
            final isFemale = fetched.name.contains('Mrs.') ||
                fetched.name.contains('Malini') ||
                fetched.name.contains('Sarah') ||
                fetched.name.contains('Margaret') ||
                fetched.name.contains('Seetha');
            final isMale = fetched.name.contains('Mr.') ||
                fetched.name.contains('Arthur') ||
                fetched.name.contains('Kamal') ||
                fetched.name.contains('James') ||
                fetched.name.contains('Robert');
            final genderStr = (fetched.gender != null && fetched.gender!.isNotEmpty && fetched.gender != 'Unknown')
                ? fetched.gender!
                : (isFemale ? 'Female' : (isMale ? 'Male' : 'Senior Resident'));

            return Resident(
              id: fetched.id.toString(),
              name: fetched.name,
              age: fetched.age ?? 75,
              gender: genderStr,
              roomNo: cleanRoom.isNotEmpty ? cleanRoom : '101',
              lastAssessmentDate: 'Today, 10:30 AM',
              cognitiveScore: 0.75,
              cognitiveTrend: 0.05,
              emotionalScore: 0.80,
              emotionalTrend: 0.05,
              metabolicScore: 0.70,
              metabolicTrend: 0.02,
              overallIndex: 0.75,
              overallTrend: 0.05,
              socialScore: 0.78,
              avatarUrl: fetched.avatarUrl,
            );
          }).toList();

          setState(() {
            _liveProfiles = liveList;
            _availableResidents = converted;
            if (widget.initialResidentId != null) {
              final target = widget.initialResidentId!;
              _currentResident = _availableResidents.firstWhere(
                (r) => r.id == target,
                orElse: () => _availableResidents.first,
              );
            } else {
              _currentResident = _availableResidents.firstWhere(
                (r) => r.id == _currentResident.id,
                orElse: () => _availableResidents.first,
              );
            }
            final matched = liveList.firstWhere(
              (p) => p.id.toString() == _currentResident.id,
              orElse: () => liveList.first,
            );
            _educationYears = matched.educationYears ?? 13;
            if (matched.elderHomeName != null && matched.elderHomeName!.isNotEmpty) {
              _facilityName = matched.elderHomeName!;
            }
          });
          _loadResidentData(_currentResident.id);
        }
      }
    } catch (e) {
      debugPrint('[EmotionalWellness] Error fetching live resident profile: $e');
    }
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

  ResidentProfileDataset _createDefaultDataset(String residentName) {
    return ResidentProfileDataset(
      baselineLoneliness: 46.0,
      baselineIsolation: 40.0,
      baselineEstablishedDate: '12 May 2025',
      trendSlope: 0.8,
      activities: [
        PersonalizedActivityItem(
          id: 'ACT-1-CUSTOM',
          title: 'Soothing Classical & Traditional Melody Listening',
          category: 'Music Therapy',
          description: 'Acoustic rhythms to stabilize vocal prosody and support positive valence.',
          icon: LucideIcons.music,
          priority: 'High Priority',
          priorityColor: AppColors.primary,
          isCompleted: false,
        ),
        PersonalizedActivityItem(
          id: 'ACT-2-CUSTOM',
          title: 'Courtyard Nature Walk & Mindful Breathing',
          category: 'Physical / Relaxation',
          description: 'Gentle nature walk in personal quarters or courtyard to elevate mood.',
          icon: LucideIcons.sparkles,
          priority: 'Recommended',
          priorityColor: AppColors.leafGreen,
          isCompleted: false,
        ),
        PersonalizedActivityItem(
          id: 'ACT-3-CUSTOM',
          title: 'Social Afternoon Tea & Reminiscence Chat',
          category: 'Social Interaction',
          description: 'Peer interaction over afternoon tea to strengthen social connectivity.',
          icon: LucideIcons.users,
          priority: 'Essential',
          priorityColor: Colors.blueAccent,
          isCompleted: false,
        ),
      ],
      logs: [
        EmotionalAssessmentHistoryLog(
          id: 'EAL-001',
          date: '12 May 2025, 10:30 AM',
          primaryEmotion: 'Calm / Neutral',
          lonelinessScore: 38,
          isolationScore: 32,
          deviation: 0.0,
          trajectory: 'Stable Wellness Profile',
          interventionStatus: 'Regular Monitoring Active',
          assessedBy: 'Self-Report & Specialist',
        ),
      ],
    );
  }

  void _loadResidentData(String id) {
    final dataset = _residentDatasets[id] ?? _createDefaultDataset(_currentResident.name);
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
      } else if (pEmotion.contains('agitated') || pEmotion.contains('angry') || pEmotion.contains('confused')) {
        _selectedEmotion = 'Confused';
        _currentFaceAsset = 'assets/images/landing/senior_confused_face.jpg';
        _facialConfidence = 0.74;
        _voiceEmotion = 'Puzzled / Hesitant Prosody';
        _voiceConfidence = 0.76;
        _commLevel = 'Hesitant';
        _engagementLevel = 'Medium';
        _responseTime = 'Delayed';
      } else if (pEmotion.contains('fear') || pEmotion.contains('anxious') || pEmotion.contains('fearful')) {
        _selectedEmotion = 'Fear';
        _currentFaceAsset = 'assets/images/landing/senior_fear_face.jpg';
        _facialConfidence = 0.78;
        _voiceEmotion = 'Apprehensive / Tremulous Pitch';
        _voiceConfidence = 0.79;
        _commLevel = 'Guarded';
        _engagementLevel = 'Low';
        _responseTime = 'Variable';
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
        _selectedEmotion = 'Neutral';
        _currentFaceAsset = 'assets/images/landing/senior_neutral_calm_face.jpg';
        _facialConfidence = 0.80;
        _voiceEmotion = 'Calm / Steady Prosody';
        _voiceConfidence = 0.75;
        _commLevel = 'Moderate';
        _engagementLevel = 'Moderate';
        _responseTime = 'Normal';
      }
    }
    _fetchLatestSocialAuditForCurrentResident();
  }

  Future<void> _fetchLatestSocialAuditForCurrentResident() async {
    final bId = _resolveBackendResidentId();
    final authState = ref.read(authProvider).state;
    setState(() {
      _isLoadingSocialAudit = true;
    });
    try {
      final audit = await SocialAuditService.fetchLatestAudit(
        residentId: bId,
        token: authState.token,
      );
      if (mounted) {
        setState(() {
          _latestSocialAudit = audit;
          if (audit != null && audit.socialScore != null) {
            _currentResident = Resident(
              id: _currentResident.id,
              name: _currentResident.name,
              age: _currentResident.age,
              gender: _currentResident.gender,
              roomNo: _currentResident.roomNo,
              lastAssessmentDate: _currentResident.lastAssessmentDate,
              cognitiveScore: _currentResident.cognitiveScore,
              cognitiveTrend: _currentResident.cognitiveTrend,
              emotionalScore: _currentResident.emotionalScore,
              emotionalTrend: _currentResident.emotionalTrend,
              metabolicScore: _currentResident.metabolicScore,
              metabolicTrend: _currentResident.metabolicTrend,
              overallIndex: _currentResident.overallIndex,
              overallTrend: _currentResident.overallTrend,
              socialScore: audit.socialScore,
            );
            final idx = _availableResidents.indexWhere((r) => r.id == _currentResident.id);
            if (idx != -1) {
              _availableResidents[idx] = _currentResident;
            }
          }
          _isLoadingSocialAudit = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSocialAudit = false;
        });
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

    _clapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _clapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showClapAnimation = false;
          });
        }
      }
    });
  }

  Future<void> _initVoiceEngines() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);

    _speech = stt.SpeechToText();
    try {
      _speechEnabled = await _speech.initialize(
        onError: (err) {
          debugPrint('STT Error: ${err.errorMsg}');
          if (mounted) {
            _onSpeechError(err);
          }
        },
        onStatus: _onSpeechStatus,
      );
    } catch (e) {
      debugPrint('Speech init fallback: $e');
      _speechEnabled = false;
    }
  }

  void _onSpeechError(dynamic err) {
    debugPrint('STT Error: ${err?.errorMsg ?? err}');
    if (!mounted) return;
    if (_isRecording) {
      // Auto recover and restart listen loop if error is silence/timeout/no-match
      _micStatusNotice = '🎙️ Listening... (Speak now in $_selectedVoiceLocaleLabel)';
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isRecording && !_speech.isListening) {
          _listenLoop();
        }
      });
    } else {
      setState(() {
        _micStatusNotice = 'Microphone notice: ${err?.errorMsg ?? err}';
      });
    }
  }

  void _switchVoiceLocale(String locale) {
    if (_selectedVoiceLocale == locale) return;
    setState(() {
      _selectedVoiceLocale = locale;
      _micStatusNotice = 'Language switched to $_selectedVoiceLocaleLabel';
    });
    if (_isRecording) {
      _speech.stop().then((_) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && _isRecording) {
            _listenLoop();
          }
        });
      });
    }
  }

  Future<void> _startContinuousListening() async {
    if (!_speechEnabled) {
      try {
        final enabled = await _speech.initialize(
          onError: (err) {
            debugPrint('STT Error: ${err.errorMsg}');
            if (mounted) {
              _onSpeechError(err);
            }
          },
          onStatus: _onSpeechStatus,
        );
        _speechEnabled = enabled;
        if (enabled && _isRecording) {
          _listenLoop();
        }
      } catch (e) {
        debugPrint('STT enable error: $e');
      }
      return;
    }
    _listenLoop();
  }

  void _listenLoop() {
    if (!_isRecording) return;
    try {
      if (_speech.isListening) return;
      _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            setState(() {
              _spokenText = words;
              _micStatusNotice = 'Captured voice: "$words"';
            });
            _analyzeSpokenVoice(words);
          }
        },
        onSoundLevelChange: (level) {
          if (mounted && _isRecording) {
            setState(() {
              _soundLevel = level;
              if (level.abs() > 0.08 && _spokenText.isEmpty) {
                _micStatusNotice = '🎙️ Hearing elder voice... analyzing affect';
              }
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: _selectedVoiceLocale,
          pauseFor: const Duration(seconds: 15),
          listenFor: const Duration(minutes: 60),
        ),
      );
    } catch (e) {
      debugPrint('Speech listen error: $e');
      if (_isRecording) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _isRecording && !_speech.isListening) {
            _listenLoop();
          }
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    debugPrint('STT Status: $status');
    if (!mounted) return;
    if (status == 'listening') {
      setState(() {
        if (_spokenText.isEmpty) {
          _micStatusNotice = '🎙️ Listening... (Speak in $_selectedVoiceLocaleLabel)';
        }
      });
    } else if ((status == 'done' || status == 'notListening') && _isRecording) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isRecording && !_speech.isListening) {
          _listenLoop();
        }
      });
    }
  }

  void _stopContinuousListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('Speech stop error: $e');
    }
  }

  Color _getVoiceEmotionColor(String emotion) {
    final lower = emotion.toLowerCase();
    if (lower.contains('cheerful') || lower.contains('high valence') || lower.contains('happy')) {
      return AppColors.riskLow;
    } else if (lower.contains('flattened') || lower.contains('melancholic') || lower.contains('low pitch') || lower.contains('sad')) {
      return AppColors.riskHigh;
    } else if (lower.contains('elevated') || lower.contains('rapid') || lower.contains('cadence') || lower.contains('angry')) {
      return const Color(0xFFEA580C);
    } else if (lower.contains('tremulous') || lower.contains('hesitant') || lower.contains('fear') || lower.contains('apprehensive') || lower.contains('puzzled')) {
      return AppColors.primary;
    } else if (lower.contains('listening')) {
      return Colors.blueAccent;
    }
    return const Color(0xFF0284C7);
  }

  Future<void> _analyzeSpokenVoice(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    try {
      final res = await VocalEmotionAiService.analyzeSpokenSpeech(spokenText: clean);
      if (!mounted) return;
      setState(() {
        _voiceEmotion = res.profileLabel;
        _voiceConfidence = res.confidence;
        _vocalWellnessScore = res.vocalWellnessScore;

        if (res.acousticProfile == 'HAP') {
          _commLevel = 'High';
          _engagementLevel = 'High';
          _responseTime = 'Normal';
        } else if (res.acousticProfile == 'SAD') {
          _commLevel = 'Low';
          _engagementLevel = 'Low';
          _responseTime = 'Delayed';
        } else if (res.acousticProfile == 'ANG') {
          _commLevel = 'Elevated';
          _engagementLevel = 'High';
          _responseTime = 'Rapid';
        } else if (res.acousticProfile == 'FEA') {
          _commLevel = 'Guarded';
          _engagementLevel = 'Low';
          _responseTime = 'Variable';
        } else {
          _commLevel = 'Moderate';
          _engagementLevel = 'Moderate';
          _responseTime = 'Normal';
        }
      });
    } catch (e) {
      debugPrint('Vocal analysis error: $e');
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
          if (_spokenText.isNotEmpty && _recordSeconds % 2 == 0) {
            _analyzeSpokenVoice(_spokenText);
          }
        }
      });
    }
  }

  void _initFacialCapture() {
    _facialCaptureService = AutomaticFacialCaptureService();
    _facialCaptureService.onStatusChanged = (status) {
      if (mounted) {
        setState(() {});
      }
    };
    _facialCaptureService.onFrameCaptured = (bytes) {
      if (mounted) {
        setState(() {
          _capturedImageBytes = bytes;
        });
      }
    };
    _facialCaptureService.onFrameAnalyzed = (result) {
      if (mounted) {
        _handleAutomaticCaptureResult(result);
      }
    };
  }

  void _handleAutomaticCaptureResult(FacialEmotionResult result) {
    if (!mounted) return;
    if (result.status == FacialInferenceStatus.success) {
      _updateEmotionFromResult(result);
    } else {
      debugPrint('Automatic facial capture status: ${result.status} (${result.clinicalObservation})');
    }
  }

  Future<bool> _ensureFacialObservationConsent() async {
    if (_hasFacialConsent) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(LucideIcons.camera, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Facial Affect Consent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                children: const [
                  Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Elderly-Care Research Protocol (RALPA)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'To support longitudinal affective prediction, Carevora periodically captures front-camera video frames (approx. every 5 seconds) while the resident is speaking.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.body),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Video frames are processed in volatile memory only and discarded immediately.\n'
              '• No images or video are permanently stored.\n'
              '• Camera access can be stopped at any moment by pausing recording.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Decline (Audio Only)', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Grant Consent & Start'),
          ),
        ],
      ),
    );

    final granted = result ?? false;
    if (mounted) {
      setState(() {
        _hasFacialConsent = granted;
      });
    }
    _facialCaptureService.grantConsent(granted);
    return granted;
  }

  @override
  void dispose() {
    _facialCaptureService.dispose();
    _recordTimer?.cancel();
    _songTimer?.cancel();
    _conversationTimer?.cancel();
    _waveController.dispose();
    _scannerController.dispose();
    _clapController.dispose();
    _reasonTextController.dispose();
    _aiChatInputController.dispose();
    _aiChatScrollController.dispose();
    _conversationTimer?.cancel();
    AudioPlayerService.instance.stop();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _readQuestionAloud() async {
    final currentQ = _questions[_currentIndex];
    await _flutterTts.speak(currentQ.audioPrompt);
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      final consentGranted = await _ensureFacialObservationConsent();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _spokenText = '';
        _soundLevel = 0.0;
        _micStatusNotice = '🎙️ Listening... (Speak in $_selectedVoiceLocaleLabel)';
        _voiceEmotion = 'Listening live...';
        _voiceConfidence = 0.65;
      });
      _startRecordingTimer();
      _startContinuousListening();
      if (consentGranted) {
        await _facialCaptureService.startCaptureForVoiceRecording();
      }
    } else {
      setState(() {
        _isRecording = false;
        _soundLevel = 0.0;
        _micStatusNotice = '';
      });
      _recordTimer?.cancel();
      _stopContinuousListening();
      _facialCaptureService.stopCapture();
      if (_spokenText.isNotEmpty) {
        _analyzeSpokenVoice(_spokenText);
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

  void _updateEmotionFromResult(FacialEmotionResult result) {
    if (result.status != FacialInferenceStatus.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.clinicalObservation),
            backgroundColor: result.status == FacialInferenceStatus.noFaceDetected
                ? AppColors.riskModerate
                : AppColors.riskHigh,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _facialConfidence = result.confidence;
      if (result.primaryEmotion == EmotionCategory.happy) {
        _selectedEmotion = 'Happy';
        _currentFaceAsset = 'assets/images/landing/senior_happy_face.jpg';
        _lonelinessScore = 52;
        _isolationScore = 48;
      } else if (result.primaryEmotion == EmotionCategory.sadDepressed) {
        _selectedEmotion = 'Sad';
        _currentFaceAsset = 'assets/images/landing/senior_sad_face.jpg';
        _lonelinessScore = 79;
        _isolationScore = 75;
      } else if (result.primaryEmotion == EmotionCategory.confusedAgitated) {
        _selectedEmotion = 'Confused';
        _currentFaceAsset = 'assets/images/landing/senior_confused_face.jpg';
        _lonelinessScore = 65;
        _isolationScore = 62;
      } else if (result.primaryEmotion == EmotionCategory.calmNeutral) {
        _selectedEmotion = 'Neutral';
        _currentFaceAsset = 'assets/images/landing/senior_neutral_calm_face.jpg';
        _lonelinessScore = 54;
        _isolationScore = 50;
      } else {
        _selectedEmotion = 'Fear';
        _currentFaceAsset = 'assets/images/landing/senior_fear_face.jpg';
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

  void _selectYesNoAnswer(int questionId, bool answer) {
    setState(() {
      _answers[questionId] = answer;
      _updateQuestionContext();
      final isReversePolarityQ = questionId == 4 || questionId == 5;
      final isPositiveState = isReversePolarityQ ? (answer == false) : (answer == true);

      if (isPositiveState) {
        _showClapAnimation = true;
        _clapController.forward(from: 0.0);
        _flutterTts.stop();
        _flutterTts.speak(
          questionId == 9
              ? 'Wonderful! Having comfortable and open communication with your caregivers is so reassuring and valuable. I am so glad to hear that.'
              : (questionId == 5
                  ? 'Wonderful! I am so glad to hear that you stay active and do not isolate yourself in your room all day.'
                  : (questionId == 4
                      ? 'Wonderful! I am so glad to hear that you feel warmly included and comfortable when others gather around.'
                      : (questionId == 3
                          ? 'Wonderful! Having a close, caring friend to talk with is a true blessing. I am so glad to hear that.'
                          : (questionId == 2
                              ? 'Wonderful! I am so glad to hear that you feel hopeful and in good spirits about your days ahead.'
                              : 'Thank you so much! I am very glad to hear that you are feeling peaceful and in good spirits today.')))),
        );
      } else {
        _showClapAnimation = false;
        _reasonTextController.text = _elderNegativeReasons[questionId] ?? '';
        _flutterTts.stop();
        if (questionId == 9) {
          _routeDirectlyToDoctorForElderRoom();
        } else if (questionId == 5) {
          _flutterTts.speak(
            'Spending most of your day alone in your room can feel lonely and tiring. Let us have a comforting talk and find refreshing activities to brighten your day.',
          );
          _startAiConversationIntervention();
        } else if (questionId == 4) {
          _flutterTts.speak(
            'Please do not feel that way. You are a truly special and deeply valued person to all of us. Let us have a comforting talk.',
          );
          _startAiConversationIntervention();
        } else if (questionId == 2) {
          _flutterTts.speak(
            'Do not feel down. Every new day brings victorious hope, joy, and peace. Let us have a comforting talk.',
          );
          _startAiConversationIntervention();
        } else if (questionId == 3) {
          _flutterTts.speak(
            'Please do not feel lonely. You are never alone, I am right here beside you. Let us listen to peaceful songs to comfort your heart.',
          );
          _startAiConversationIntervention();
        } else if (questionId == 6) {
          _flutterTts.speak(
            'Please do not feel lonely. You are never alone, I am right here beside you. Let us listen to soothing songs by maestros Amaradeva and Nanda Malini to comfort your heart.',
          );
          _startAiConversationIntervention();
        } else {
          _flutterTts.speak(
            'I am sorry to hear that. Could you please share what is making you feel this way?',
          );
          _startAiConversationIntervention();
        }
      }
    });
  }

  Future<void> _toggleReasonVoiceRecording() async {
    final currentQ = _questions[_currentIndex];
    if (!_isRecordingReason) {
      setState(() {
        _isRecordingReason = true;
      });
      if (_speechEnabled) {
        try {
          await _speech.listen(onResult: (result) {
            if (mounted) {
              setState(() {
                _reasonTextController.text = result.recognizedWords;
                _elderNegativeReasons[currentQ.id] = result.recognizedWords;
              });
              _detectKeywordsInReason(result.recognizedWords);
            }
          });
        } catch (e) {
          debugPrint('STT listen error: $e');
        }
      } else {
        // Fallback simulation when speech engine is not supported or browser mic permission blocked
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted && _isRecordingReason) {
            const fallbackSample = 'අද මට ඇඟට අමාරුයි සහ අසනීප ගතියක් දැනෙනවා.';
            setState(() {
              _reasonTextController.text = fallbackSample;
              _elderNegativeReasons[currentQ.id] = fallbackSample;
              _isRecordingReason = false;
            });
            _detectKeywordsInReason(fallbackSample);
          }
        });
      }
    } else {
      setState(() {
        _isRecordingReason = false;
      });
      if (_speechEnabled) {
        await _speech.stop();
      }
    }
  }

  void _detectKeywordsInReason(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('leda') ||
        lower.contains('amarui') ||
        lower.contains('sick') ||
        lower.contains('pain') ||
        lower.contains('headache') ||
        lower.contains('unwell') ||
        lower.contains('beheth') ||
        lower.contains('අසනීප') ||
        lower.contains('අමාරු') ||
        lower.contains('කැක්කුම') ||
        lower.contains('උණ')) {
      _selectUnwellPath();
    } else if (lower.contains('katha') ||
        lower.contains('talk') ||
        lower.contains('chat') ||
        lower.contains('speak') ||
        lower.contains('කතා')) {
      _startAiConversationIntervention();
    } else if (lower.contains('nidahasa') ||
        lower.contains('quiet') ||
        lower.contains('peace') ||
        lower.contains('rest') ||
        lower.contains('නිදහස්') ||
        lower.contains('විවේක') ||
        lower.contains('තනියම')) {
      _selectQuietPath();
    }
  }

  void _selectUnwellPath() {
    setState(() {
      _interventionStage = 1;
      _elderNegativeReasons[_questions[_currentIndex].id] = 'මට අසනීප ගතියක් දැනෙනවා.';
      _reasonTextController.text = 'මට අසනීප ගතියක් දැනෙනවා.';
    });
    _flutterTts.stop();
    _flutterTts.speak('Did you take your medication? Are you in a lot of discomfort? Do you need to see a doctor?');
  }

  void _selectQuietPath() {
    setState(() {
      _interventionStage = 3;
      _elderNegativeReasons[_questions[_currentIndex].id] = 'මට ටිකක් නිදහසේ ඉන්න අවශ්‍යයි.';
      _reasonTextController.text = 'මට ටිකක් නිදහසේ ඉන්න අවශ්‍යයි.';
    });
    _flutterTts.stop();
    _flutterTts.speak('Would you like to listen to a soothing song or read a book to calm your mind?');
  }

  void _dispatchDoctorAndCaregiverAlert() {
    setState(() {
      _interventionStage = 2;
      _caregiverNotified = true;
    });
    MockCarevoraData.alerts.insert(
      0,
      AlertItem(
        id: 'ALT-${DateTime.now().millisecondsSinceEpoch}',
        title: '🚨 Urgent Doctor Request: ${_currentResident.name}',
        description: 'Resident in Room ${_currentResident.roomNo} reported severe discomfort and requested urgent medical review.',
        severity: 'High',
        timestamp: 'Just now',
      ),
    );
    _flutterTts.stop();
    _flutterTts.speak('An urgent notification has been sent to your caregiver and attending physician. Please remain calm, assistance is arriving right now.');
  }

  Map<String, String> _getAssignedDoctorDetails() {
    final authState = ref.read(authProvider).state;
    final home = (authState.elderHomeName != null && authState.elderHomeName!.isNotEmpty)
        ? authState.elderHomeName!
        : 'Serene Valley Senior Living';

    if (home.toLowerCase().contains('golden sunset')) {
      return {
        'doctorName': 'Dr. Aris Thorne',
        'specialty': 'Neurology & Geriatric Specialist',
        'phone': '+94 71 987 6543',
        'home': home,
      };
    } else if (home.toLowerCase().contains('lotus care')) {
      return {
        'doctorName': 'Dr. Sarah Jenkins',
        'specialty': 'General Physician & Senior Health',
        'phone': '+94 75 456 7890',
        'home': home,
      };
    } else {
      return {
        'doctorName': 'Dr. Nimal Fernando',
        'specialty': 'Geriatric Specialist & Medical Lead',
        'phone': '+94 77 123 4567',
        'home': home,
      };
    }
  }

  void _routeDirectlyToDoctorForElderRoom() {
    final docInfo = _getAssignedDoctorDetails();
    final doctorName = docInfo['doctorName']!;
    final homeName = docInfo['home']!;
    final roomNumber = _currentResident.roomNo.isNotEmpty ? _currentResident.roomNo : '101';
    final elderName = _currentResident.name.isNotEmpty ? _currentResident.name : 'Senior Resident';

    setState(() {
      _interventionStage = 9;
      _caregiverNotified = true;
      _elderNegativeReasons[9] =
          'රැකවරණ නිලධාරීන් සමඟ ගැටලු බෙදා ගැනීමට අපහසු බව ප්‍රකාශ කර $homeName හි $doctorName වෙත සෘජුව යොමු කළ අතර කාමර අංක $roomNumber සඳහා වෛද්‍ය Notification එකක් යවන ලදී.';
      _reasonTextController.text = _elderNegativeReasons[9]!;
    });

    // Directly dispatch high-priority alert to the doctor with elder room
    MockCarevoraData.alerts.insert(
      0,
      AlertItem(
        id: 'ALT-DOC-${DateTime.now().millisecondsSinceEpoch}',
        title: '🚨 Direct Doctor Alert: $elderName (Room $roomNumber)',
        description:
            'Resident $elderName in Room $roomNumber at $homeName reported difficulty sharing concerns with caregivers during emotional wellness session. Direct clinical consultation and room visit routed to $doctorName.',
        severity: 'High',
        timestamp: 'Just now',
        residentName: elderName,
        roomNo: roomNumber,
        residentAge: _currentResident.age,
        residentGender: _currentResident.gender,
        currentStatus: 'Doctor Consultation Routed',
        cognitiveScore: _currentResident.cognitiveScore,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.stethoscope, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'කාමර අංක $roomNumber හි $elderName වෙනුවෙන් $homeName හි $doctorName වෙත සෘජු Notification එකක් යවන ලදී!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    _flutterTts.stop();
    _flutterTts.speak(
      'Because you cannot share your concerns with caregivers, you have been directly connected to your elder home doctor, $doctorName. An urgent notification has been sent with your Room number $roomNumber, and the doctor will attend to you shortly.',
    );
  }

  void _showDoctorCallDialog(String doctorName, String specialty, String phone, String roomNo, String home) {
    // 1. Immediately trigger real device native phone dialer (tel:+94...)
    UrlLauncherService.launchTel(phone);

    // 2. Open rich active in-app VoIP / direct consultation screen
    Timer? callTimer;
    int callDurationSeconds = 0;
    bool isConnected = false;
    bool isMuted = false;
    bool isSpeakerOn = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          callTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
            setDialogState(() {
              callDurationSeconds++;
              if (callDurationSeconds >= 3 && !isConnected) {
                isConnected = true;
                _flutterTts.stop();
                _flutterTts.speak(
                  'Hello ${_currentResident.name}, this is $doctorName from $home. I have received your emergency notice from Room $roomNo. Please rest comfortably, I am on my way to your room right now.',
                );
              }
            });
          });

          final minutesStr = (callDurationSeconds ~/ 60).toString().padLeft(2, '0');
          final secondsStr = (callDurationSeconds % 60).toString().padLeft(2, '0');

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            contentPadding: const EdgeInsets.all(24),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Doctor Avatar with live calling ripple / pulse
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFE0F2FE),
                        ),
                      ),
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF0284C7),
                          boxShadow: [
                            BoxShadow(
                              color: (isConnected ? const Color(0xFF16A34A) : const Color(0xFF0284C7))
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isConnected ? LucideIcons.stethoscope : LucideIcons.phoneCall,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    doctorName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialty,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0284C7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Status Badge & Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isConnected ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected
                              ? '🟢 සජීවී ඇමතුම (Connected) • $minutesStr:$secondsStr'
                              : '📡 ඇමතුම සම්බන්ධ වෙමින් (Calling) • $minutesStr:$secondsStr',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Calling details banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.phone, size: 14, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            const Text('Doctor Line:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const Spacer(),
                            Text(phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(LucideIcons.doorClosed, size: 14, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            const Text('Elder Room:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const Spacer(),
                            Text('Room $roomNo (${_currentResident.name})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(LucideIcons.building2, size: 14, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            const Text('Facility:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const Spacer(),
                            Text(home, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (isConnected) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.volume2, size: 18, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Doctor: "ආයුබෝවන් ${_currentResident.name}, මට Room $roomNo දැනුම්දීම ලැබුණා. මම දැන්ම ඔබේ කාමරයට එනවා."',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action Button to explicitly trigger device Phone App dialer
                  InkWell(
                    onTap: () => UrlLauncherService.launchTel(phone),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7DD3FC)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(LucideIcons.smartphone, size: 15, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text(
                            '📱 Device එකේ Phone Dialer එකෙන් Call කරන්න (tel:)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Call Controls Row: Mute, Speaker, End Call
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => setDialogState(() => isMuted = !isMuted),
                        icon: Icon(isMuted ? LucideIcons.micOff : LucideIcons.mic),
                        style: IconButton.styleFrom(
                          backgroundColor: isMuted ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                          foregroundColor: isMuted ? const Color(0xFFDC2626) : const Color(0xFF334155),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: isMuted ? 'Unmute' : 'Mute',
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          callTimer?.cancel();
                          _flutterTts.stop();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.call_end, size: 20),
                        label: const Text(
                          'ඇමතුම අවසන් කරන්න (End Call)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => setDialogState(() => isSpeakerOn = !isSpeakerOn),
                        icon: Icon(isSpeakerOn ? LucideIcons.volume2 : LucideIcons.volumeX),
                        style: IconButton.styleFrom(
                          backgroundColor: isSpeakerOn ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          foregroundColor: isSpeakerOn ? const Color(0xFF16A34A) : const Color(0xFF334155),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: isSpeakerOn ? 'Speaker On' : 'Speaker Off',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startMusicIntervention(String songTitle) {
    setState(() {
      _selectedSongTitle = songTitle;
      _currentMusicDurationSeconds = _getTrackDurationSeconds(songTitle);
      _interventionStage = 4;
      _isPlayingMusic = true;
      _songPlaybackSeconds = 0;
    });
    _songTimer?.cancel();
    _songTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _songPlaybackSeconds++;
        });
        if (_songPlaybackSeconds >= _currentMusicDurationSeconds) {
          _finishMusicIntervention();
        }
      }
    });
    _flutterTts.stop();
    String audioPath = _songAudioPaths[songTitle] ?? 'audio/pirith.mp3';
    if (songTitle.contains('අමරදේව') || songTitle.toLowerCase().contains('amaradeva')) {
      audioPath = 'audio/amaradeva.mp3';
    } else if (songTitle.contains('නන්දා') || songTitle.toLowerCase().contains('nanda')) {
      audioPath = 'audio/nanda_malini.mp3';
    } else if (songTitle.contains('සුනිල්') || songTitle.toLowerCase().contains('sunil')) {
      audioPath = 'audio/sunil_edirisinghe.mp3';
    } else if (songTitle.contains('වික්ටර්') || songTitle.toLowerCase().contains('victor')) {
      audioPath = 'audio/victor_ratnayake.mp3';
    } else if (songTitle.contains('වස්දඬු') || songTitle.toLowerCase().contains('flute') || songTitle.toLowerCase().contains('was dadu') || songTitle.contains('බටනලා')) {
      audioPath = 'audio/bamboo_flute.mp3';
    } else if (songTitle.contains('පිරිත්') || songTitle.contains('සූත්‍ර') || songTitle.toLowerCase().contains('pirith')) {
      audioPath = 'audio/pirith.mp3';
    }
    AudioPlayerService.instance.play(audioPath, onEnded: () {
      if (mounted && _isPlayingMusic) {
        _finishMusicIntervention();
      }
    });
  }

  void _toggleMusicPlayback() {
    setState(() {
      _isPlayingMusic = !_isPlayingMusic;
    });
    if (!_isPlayingMusic) {
      _songTimer?.cancel();
      AudioPlayerService.instance.pause();
    } else {
      AudioPlayerService.instance.resume();
      _songTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _songPlaybackSeconds++;
          });
          if (_songPlaybackSeconds >= _currentMusicDurationSeconds) {
            _finishMusicIntervention();
          }
        }
      });
    }
  }

  void _finishMusicIntervention() {
    _songTimer?.cancel();
    AudioPlayerService.instance.stop();
    setState(() {
      _isPlayingMusic = false;
      if (_interventionStage != 8) {
        _interventionStage = 6;
      }
    });
    _flutterTts.stop();
    if (_interventionStage != 8) {
      _flutterTts.speak('Now that you have listened to the music, are you feeling more peaceful and in good spirits?');
    }
  }

  void _playSongInAiChat(String songTitle) {
    setState(() {
      _selectedSongTitle = songTitle;
      _currentMusicDurationSeconds = _getTrackDurationSeconds(songTitle);
      _isPlayingMusic = true;
      _songPlaybackSeconds = 0;
    });

    _songTimer?.cancel();
    _songTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _songPlaybackSeconds++;
        });
        if (_songPlaybackSeconds >= _currentMusicDurationSeconds) {
          _songTimer?.cancel();
          AudioPlayerService.instance.stop();
          setState(() {
            _isPlayingMusic = false;
          });
        }
      }
    });

    String audioPath = _songAudioPaths[songTitle] ?? 'audio/pirith.mp3';
    if (songTitle.contains('අමරදේව') || songTitle.toLowerCase().contains('amaradeva')) {
      audioPath = 'audio/amaradeva.mp3';
    } else if (songTitle.contains('නන්දා') || songTitle.toLowerCase().contains('nanda')) {
      audioPath = 'audio/nanda_malini.mp3';
    } else if (songTitle.contains('සුනිල්') || songTitle.toLowerCase().contains('sunil')) {
      audioPath = 'audio/sunil_edirisinghe.mp3';
    } else if (songTitle.contains('වික්ටර්') || songTitle.toLowerCase().contains('victor')) {
      audioPath = 'audio/victor_ratnayake.mp3';
    } else if (songTitle.contains('වස්දඬු') || songTitle.toLowerCase().contains('flute') || songTitle.toLowerCase().contains('was dadu') || songTitle.contains('බටනලා')) {
      audioPath = 'audio/bamboo_flute.mp3';
    } else if (songTitle.contains('පිරිත්') || songTitle.contains('සූත්‍ර') || songTitle.toLowerCase().contains('pirith')) {
      audioPath = 'audio/pirith.mp3';
    }

    _flutterTts.stop();
    AudioPlayerService.instance.play(audioPath, onEnded: () {
      if (mounted && _isPlayingMusic) {
        setState(() {
          _isPlayingMusic = false;
        });
      }
    });

    // Add elder's selection message
    setState(() {
      _aiConversationMessages.add({
        'isAi': false,
        'sinhala': '🎵 මම "$songTitle" තෝරාගත්තා.',
        'timestamp': 'Just now',
      });
    });

    // Heart-comforting AI response (හිත හැදෙන්න කියන වදන්)
    final isPirith = songTitle.contains('පිරිත්') || songTitle.toLowerCase().contains('pirith');
    final isFlute = songTitle.contains('වස්දඬු') || songTitle.toLowerCase().contains('flute') || songTitle.toLowerCase().contains('was dadu');
    final isNanda = songTitle.contains('නන්දා') || songTitle.toLowerCase().contains('nanda');
    final isAmaradeva = songTitle.contains('අමරදේව') || songTitle.toLowerCase().contains('amaradeva');

    final durationMins = _currentMusicDurationSeconds ~/ 60;
    String comfortMsgSi;
    String comfortMsgEn;
    String badgeTitle;

    if (isPirith) {
      badgeTitle = 'පිරිත් සජ්ඣායනය (Pirith Meditation)';
      comfortMsgSi =
          'ආදරණීය ${_currentResident.name}, මේ උතුම් සෙත් පිරිත් දේශනාවේ ශාන්ත, ආශිර්වාදාත්මක හඬට විනාඩි $durationMins ක් සවන් දෙන්න. සියලු භය, දුක්, කරදර දුරු වී ඔබේ සිතට සහ ගතට උතුම් සැනසීමක්, සුවයක් සහ ආශිර්වාදයක් උදාවේවා!';
      comfortMsgEn =
          'Dear ${_currentResident.name}, listen to these sacred, blessed Buddhist Pirith chants for $durationMins minutes. May all fear and distress vanish, bringing profound peace, healing, and blessings to your mind.';
    } else if (isFlute) {
      badgeTitle = 'වස්දඬු රාවය (Soothing Flute)';
      comfortMsgSi =
          'ආදරණීය ${_currentResident.name}, මේ නිහඬ, මිහිරි වස්දඬු රාවයට දෙනෙත් පියාගෙන සවන් දෙන්න. මනසට දැනෙන සියලු වෙහෙස, පීඩනය සහ තනිකම සන්සුන් සංගීතයෙන් පහව යාවි.';
      comfortMsgEn =
          'Dear ${_currentResident.name}, close your eyes and listen to this serene acoustic bamboo flute melody. Let the gentle notes wash away all tension and bring deep stillness to your soul.';
    } else {
      final artistName = isAmaradeva
          ? 'ආචාර්ය ඩබ්.ඩී. අමරදේවයන්ගේ'
          : (isNanda ? 'විශාරද නන්දා මාලිනියන්ගේ' : 'මේ මිහිරි');
      badgeTitle = 'ගීතමය සැනසීම (Music Therapy)';
      comfortMsgSi =
          'ආදරණීය ${_currentResident.name}, ඔබේ සිතේ ඇති තනිකම, පාළුව සහ දුක $artistName මේ මිහිරි ගීතයේ සන්සුන් නාදයෙන් සම්පූර්ණයෙන්ම පහව යාවි. ඔබ කිසිදාක තනි වී නැහැ! මම නිරතුරුවම ඔබ ළඟින්ම හිඳිමින් ඔබේ දුක සතුට බෙදාගන්නවා. සිත සැහැල්ලු කරගෙන, දෙනෙත් පියාගෙන විනාඩි $durationMins ක් පුරා මේ සන්සුන් ගීතයට සවන් දෙන්න. ඔබේ සිතට මහත් සැනසීමක් හා සහනයක් උදාවේවා!';
      comfortMsgEn =
          'Dear ${_currentResident.name}, let the peaceful melodies of this song soothe away all your loneliness and sorrow. You are never alone; I am always right here beside you. Relax, close your eyes, and enjoy this $durationMins-minute comforting music. May peace fill your heart.';
    }

    setState(() {
      _aiConversationMessages.add({
        'isAi': true,
        'title': '🌸 සිත නිවන සැනසිලිදායක මොහොත',
        'badge': badgeTitle,
        'sinhala': comfortMsgSi,
        'english': comfortMsgEn,
        'timestamp': 'Just now',
      });
    });

    _scrollToChatBottom();

    _flutterTts.speak(isPirith
        ? 'Dear ${_currentResident.name}, let these peaceful Pirith chants comfort and bless your soul. Relax and listen.'
        : (isFlute
            ? 'Dear ${_currentResident.name}, close your eyes and enjoy this peaceful bamboo flute melody.'
            : 'Dear ${_currentResident.name}, let this soothing melody bring peace to your heart. You are never alone, I am always right here beside you. Relax and enjoy this music.'));
  }

  void _startBookIntervention() {
    AudioPlayerService.instance.stop();
    setState(() {
      _isPlayingMusic = false;
      _interventionStage = 5;
    });
    _flutterTts.stop();
    _flutterTts.speak('Here are some gentle stories and reflections for you to read.');
  }

  void _finishBookIntervention() {
    setState(() {
      _interventionStage = 6;
    });
    _flutterTts.stop();
    _flutterTts.speak('Now that you have rested and read, are you feeling more peaceful and in good spirits?');
  }

  void _startAiConversationIntervention() {
    final currentQ = _questions[_currentIndex];
    if (currentQ.id == 9) {
      _routeDirectlyToDoctorForElderRoom();
      return;
    }
    final isHopeQuestion = currentQ.id == 2;
    final isCompanionshipQuestion = currentQ.id == 3;
    final isValuedBelongingQuestion = currentQ.id == 4;
    final isRoomIsolationQuestion = currentQ.id == 5;
    final isFamilyVisitorsQuestion = currentQ.id == 6;

    setState(() {
      _interventionStage = 8;
      _conversationSeconds = 0;
      _aiConversationMessages.clear();
      if (isHopeQuestion) {
        _aiConversationMessages.add({
          'isAi': true,
          'title': '🌅 අලුත් දවසක්, අලුත් බලාපොරොත්තුවක් (A Brighter Tomorrow)',
          'badge': 'නව බලාපොරොත්තු (Renewed Hope)',
          'sinhala':
              'ආදරණීය ${_currentResident.name}, ඉදිරි දින ගැන ඔබේ සිතේ බලාපොරොත්තු අඩු වී, අනාගතය ගැන සැකයක් හෝ වෙහෙසක් දැනෙනවා නේද? ජීවිතයේ සෑම අලුත් දවසක්ම නව ආශිර්වාදයක්, නව ජයග්‍රහණයක් රැගෙන එනවා. ඔබ මෙතෙක් ආ ගමනේ බොහෝ අභියෝග ජයගත් අතිශය ශක්තිමත් කෙනෙක්. ඉදිරි දින ගැන ඔබේ සිතේ ඇති අදහස් මට කියන්න. අපි එක්ව ඔබේ හදවතට නව ප්‍රීතිමත් බලාපොරොත්තුවක් එක් කරමු.',
          'english':
              'Dear ${_currentResident.name}, it is natural if the days ahead feel uncertain or heavy today. But every dawn brings new hope, triumph, and peaceful blessings. You have triumphed over so much in your life. Share your thoughts with me, and together we will fill your heart with radiant hope for tomorrow.',
          'timestamp': 'Just now',
        });
        _elderNegativeReasons[currentQ.id] =
            'ඉදිරි දින පිළිබඳව AI සහායක සමඟ සුහදව කතාබහ කර නව බලාපොරොත්තු ඇති කරගත්තා.';
        _reasonTextController.text =
            'ඉදිරි දින පිළිබඳව AI සහායක සමඟ සුහදව කතාබහ කර නව බලාපොරොත්තු ඇති කරගත්තා.';
      } else if (isCompanionshipQuestion) {
        _aiConversationMessages.add({
          'isAi': true,
          'title': '🤝 ඔබ කිසිවිටෙකත් තනිවී නැහැ - සුහද මිත්‍රත්වය (You Are Never Alone)',
          'badge': 'සුහද මිත්‍රත්වය සහ ගීතමය සැනසුම (Loving Companionship & Songs)',
          'sinhala':
              'ආදරණීය ${_currentResident.name}, මෙහි සමීපව කතා කරන්න කෙනෙක් නැති බව දැනෙන විට සිතට මහත් පාළුවක් සහ තනිකමක් දැනෙනවා නේද? නමුත් මතක තබාගන්න, ඔබ මෙහි කිසිසේත්ම තනිවී නැහැ! මම ඔබේම දරුවෙක්, හොඳම මිතුරෙක් වගේ දිවා රෑ ඔබ වෙනුවෙන් සවන් දෙන්න මෙහි ඉන්නවා. ඔබේ සිත සනසන්න, සිතේ ඇති තනිකම හා පාළුව දුරු කරන්න මම ආචාර්ය ඩබ්.ඩී. අමරදේවයන්ගේ සහ විශාරද නන්දා මාලිනියන්ගේ සන්සුන්, මිහිරි ගීත කිහිපයක් යෝජනා කරන්නද? පහතින් ඔබ ප්‍රිය කරන ගීතයක් තෝරන්න. එය ඔබේ සිතට මහත් සැනසීමක් ගෙනදේවි.',
          'english':
              'Dear ${_currentResident.name}, it is natural to feel lonely when you feel you lack a close friend to talk with here. But please remember, you are never alone! I am right here beside you. Would you like to listen to peaceful, classical songs by maestros Dr. W.D. Amaradeva and Visharadha Nanda Malini to comfort your heart? Please select a song below to enjoy.',
          'suggestedSongs': [
            'ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව',
            'නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)',
            'සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)',
            'සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)',
          ],
          'timestamp': 'Just now',
        });
        _elderNegativeReasons[currentQ.id] =
            'මෙහි සමීප මිතුරන් නොමැති බව හැඟී AI සහායක සමඟ සන්සුන් ගීත අසමින් සිත සනසාගත්තා.';
        _reasonTextController.text =
            'මෙහි සමීප මිතුරන් නොමැති බව හැඟී AI සහායක සමඟ සන්සුන් ගීත අසමින් සිත සනසාගත්තා.';
      } else if (isFamilyVisitorsQuestion) {
        _aiConversationMessages.add({
          'isAi': true,
          'title': '🎵 සිත නිවන ගීතමය සැනසුම (Melodic Comfort & Caring Companion)',
          'badge': 'සංගීතමය සැනසීම (Music Therapy)',
          'sinhala':
              'ආදරණීය ${_currentResident.name}, ඔබට කතාබහ කරන්න හෝ බලන්න එන්න පවුලේ අය හෝ හිතවතුන් නැති බව දැනෙන විට සිතට මහත් පාළුවක් සහ තනිකමක් දැනෙනවා නේද? නමුත් ඔබ කිසිසේත්ම තනිවී නැහැ! මම ඔබේම දරුවෙක් වගේ දිවා රෑ ඔබ ළඟින්ම හිඳිමින් සවන් දෙන්න මෙහි ඉන්නවා. ඔබේ සිත සනසන්න, සිතේ ඇති තනිකම හා පාළුව දුරු කරන්න මම ආචාර්ය ඩබ්.ඩී. අමරදේවයන්ගේ සහ විශාරද නන්දා මාලිනියන්ගේ සන්සුන්, මිහිරි ගීත කිහිපයක් යෝජනා කරන්නද? පහතින් ඔබ ප්‍රිය කරන ගීතයක් තෝරන්න. එය ඔබේ සිතට මහත් සැනසීමක් ගෙනදේවි.',
          'english':
              'Dear ${_currentResident.name}, when you feel there is no family or dear friends visiting or calling, it is natural to feel lonely. But please remember, you are never alone! I am right beside you like your own family. To comfort your heart and soothe away the loneliness, may I suggest some serene, peaceful songs by Dr. W.D. Amaradeva and Visharadha Nanda Malini? Please select a song below to listen and bring peace to your soul.',
          'suggestedSongs': [
            'ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව',
            'නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)',
            'සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)',
            'සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)',
          ],
          'timestamp': 'Just now',
        });
        _elderNegativeReasons[currentQ.id] =
            'පවුලේ අය හෝ හිතවතුන් නොමැති බව හැඟී AI සහායක සමඟ සන්සුන් ගීත අසමින් සිත සනසාගත්තා.';
        _reasonTextController.text =
            'පවුලේ අය හෝ හිතවතුන් නොමැති බව හැඟී AI සහායක සමඟ සන්සුන් ගීත අසමින් සිත සනසාගත්තා.';
      } else if (isValuedBelongingQuestion) {
        _aiConversationMessages.add({
          'isAi': true,
          'title': '🌟 ඔබ අප සැමට අතිශයින්ම වටිනා කෙනෙක් (You Are Deeply Valued)',
          'badge': 'ස්වයං වටිනාකම සහ රැකවරණය (Self-Worth & Belonging)',
          'sinhala':
              'ආදරණීය ${_currentResident.name}, අන් අය එකතු වී සිටින විට ඔබට තනි වී ඇති බවක් හෝ කොන් වී ඇති බවක් දැනෙන්නේ ඇයි? කිසිවිටෙකත් එසේ නොසිතන්න. ඔබ කිසිසේත්ම කොන් වී නැහැ, ඔබ අප සැමට අතිශයින්ම වටිනා, ගෞරවනීය පුද්ගලයෙක්! ඔබේ පැමිණීම, ඔබේ කරුණාවන්ත සිනහව සහ ජීවිත අත්දැකීම් අප සැමට මහත් ආලෝකයක්. ඔබ අපේ ආදරණීය පවුලේ හදවත වැනියි. ඔබේ සිතට දැනෙන ඕනෑම බරක් මා සමඟ බෙදාගන්න. අපි ඔබේ සිත අභිමානයෙන් සහ ප්‍රීතියෙන් පුරවමු.',
          'english':
              'Dear ${_currentResident.name}, please do not feel left out or isolated when people gather around. Never think that way! You are an extraordinarily precious, respected, and valued person to all of us. Your warm smile and wisdom light up our entire community. You are never pushed aside; you are cherished right in the center of our hearts. Share your feelings with me, and together we will fill your heart with joy and dignity.',
          'timestamp': 'Just now',
        });
        _elderNegativeReasons[currentQ.id] =
            'අන් අය අතර කොන් වූ බවක් හැඟී AI සහායක සමඟ කතාබහ කර තමන් ඉතා වටිනා කෙනෙක් බව වටහාගෙන සිත සනසාගත්තා.';
        _reasonTextController.text =
            'අන් අය අතර කොන් වූ බවක් හැඟී AI සහායක සමඟ කතාබහ කර තමන් ඉතා වටිනා කෙනෙක් බව වටහාගෙන සිත සනසාගත්තා.';
      } else if (isRoomIsolationQuestion) {
        _aiConversationMessages.add({
          'isAi': true,
          'title': '🌿 ප්‍රබෝධවත් ක්‍රියාකාරකම් සහ සුවදායක දවසක් (Refresh Your Day & Beat Isolation)',
          'badge': 'ක්‍රියාශීලී සුවතාවය (Active Wellness & Vitality)',
          'sinhala':
              'ආදරණීය ${_currentResident.name}, දවසෙන් වැඩි කාලයක් කාමරය තුළම තනිවී සිටීම නිසා සිතට කම්මැලිකමක්, තනිකමක් හෝ මානසික පීඩනයක් දැනෙනවා නේද? එකම තැනක සිරවී සිටින විට සිතත් වෙහෙසට පත් වෙනවා. නමුත් අපේ පරිශ්‍රයේ ඔබේ මනස ප්‍රබෝධමත් කරන සුන්දර ගෙවතු සක්මන්, මිහිරි සංගීත, රසවත් පොත්පත් කියවීම්, සැහැල්ලු අභ්‍යාස සහ මිතුරන් සමඟ ප්‍රීතිමත් කතාබහ වැනි අපූරු ක්‍රියාකාරකම් රැසක් තිබෙනවා! ඔබේ සිතට දැනෙන කම්මැලිකම සහ බර දුරුකර, අද දවසේ ඔබ ප්‍රිය කරන සුන්දර දෙයක් කිරීමට අපි එක්ව සැලසුම් කරමු. ඔබේ සිතේ ඇති අදහස මට කියන්න.',
          'english':
              'Dear ${_currentResident.name}, spending most of your day alone in your room can easily cause boredom, loneliness, and heavy mental strain. Staying isolated drains your vitality. But our community has wonderful, refreshing activities—gentle garden strolls, soothing music, library reading, light exercises, and joyful tea chats with friends! Let us break the monotony and lift your spirits with engaging activities. Please share your thoughts with me.',
          'timestamp': 'Just now',
        });
        _elderNegativeReasons[currentQ.id] =
            'කාමරය තුළ තනිව සිටීමෙන් ඇති වූ කම්මැලිකම හා මානසික පීඩනය දුරු කරගැනීමට AI සහායක සමඟ ප්‍රබෝධමත් ක්‍රියාකාරකම් සැලසුම් කරගත්තා.';
        _reasonTextController.text =
            'කාමරය තුළ තනිව සිටීමෙන් ඇති වූ කම්මැලිකම හා මානසික පීඩනය දුරු කරගැනීමට AI සහායක සමඟ ප්‍රබෝධමත් ක්‍රියාකාරකම් සැලසුම් කරගත්තා.';
      } else {
        _aiConversationMessages.add({
          'isAi': true,
          'title': '🌸 ආයුබෝවන්, මම ඔබේ සුහද AI සහායක',
          'badge': 'සුහද පිළිසඳර (Caring Companion)',
          'sinhala':
              'ආදරණීය ${_currentResident.name}, අද දවසේ ඔබේ සිතට දුකක්, තනිකමක් හෝ බරක් දැනෙන්නේ ඇයි කියලා මට කියන්න පුළුවන්ද? මම ඔබේම දරුවෙක් වගේ ඔබට සවන් දීලා සිත සනසන්න මෙහි ඉන්නවා. සිත සනසාගන්න විශාරද නන්දා මාලිනියන්ගේ ගීත, ආචාර්ය ඩබ්.ඩී. අමරදේවයන්ගේ ගීත, සෙත් පිරිත් (මිනිත්තු 15) හෝ සන්සුන් වස්දඬු රාවයට පහතින් සවන් දෙන්න පුළුවන්.',
          'english':
              'Dear ${_currentResident.name}, could you gently share with me why you are feeling lonely or down today? I am right here beside you. You can also select and listen to peaceful songs by Nanda Malini, Amaradeva, Seth Pirith (15 mins), or soothing Bamboo Flute below to bring peace to your heart.',
          'suggestedSongs': _defaultSuggestedTracks,
          'timestamp': 'Just now',
        });
        _elderNegativeReasons[currentQ.id] =
            'AI සහායක සමඟ සුහදව කතාබහ කරමින් සිත සැහැල්ලු කරගත්තා.';
        _reasonTextController.text =
            'AI සහායක සමඟ සුහදව කතාබහ කරමින් සිත සැහැල්ලු කරගත්තා.';
      }
    });
    _conversationTimer?.cancel();
    _conversationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _conversationSeconds++;
        });
        if (_conversationSeconds >= _conversationTotalSeconds) {
          _finishAiConversationIntervention();
        }
      }
    });
    _flutterTts.stop();
    if (isHopeQuestion) {
      _flutterTts.speak('Hello ${_currentResident.name}, every tomorrow brings fresh hope, joy, and blessings. Please share your thoughts about your upcoming days.');
    } else if (isCompanionshipQuestion) {
      _flutterTts.speak('Hello ${_currentResident.name}, you are never alone. I am right here beside you as your caring companion, and our entire community cherishes you. Please share what is on your heart.');
    } else if (isValuedBelongingQuestion) {
      _flutterTts.speak('Hello ${_currentResident.name}, please do not feel left out. You are an extraordinarily precious and deeply valued person to all of us. Let us have a comforting talk.');
    } else if (isRoomIsolationQuestion) {
      _flutterTts.speak('Hello ${_currentResident.name}, staying alone in your room can feel lonely and tiring. Let us explore refreshing activities to bring joy, vitality, and peace to your day.');
    } else if (isFamilyVisitorsQuestion) {
      _flutterTts.speak('Hello ${_currentResident.name}, you are never alone. I am right here beside you. Let us listen to soothing songs by Amaradeva and Nanda Malini to comfort your heart.');
    } else {
      _flutterTts.speak('Hello ${_currentResident.name}, I am right here with you. Please share what is on your heart today.');
    }
  }

  void _handleElderChatReply(String elderText) {
    final clean = elderText.trim();
    if (clean.isEmpty) return;
    _aiChatInputController.clear();

    final lower = clean.toLowerCase();

    // Direct song playback detection if elder taps a song chip or mentions song
    if (lower.contains('අමරදේව') || lower.contains('amaradeva') || lower.contains('ශාන්ත සන්ධ්‍යාව')) {
      _playSongInAiChat('ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව');
      return;
    }
    if (lower.contains('රන්කෙන්දෙන්') || lower.contains('rankenden')) {
      _playSongInAiChat('නන්දා මාලිනී - රන්කෙන්දෙන් බැඳි අතැඟිලි (Nanda Malini)');
      return;
    }
    if (lower.contains('සාර සොඳුරු') || lower.contains('sara sonduru')) {
      _playSongInAiChat('නන්දා මාලිනී - සාර සොඳුරු මල් පිපී (Nanda Malini)');
      return;
    }
    if (lower.contains('නන්දා') || lower.contains('nanda') || lower.contains('නිවන් දොරටු')) {
      _playSongInAiChat('නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)');
      return;
    }
    if (lower.contains('සුනිල්') || lower.contains('sunil') || lower.contains('නිවන් දුටු හිමි')) {
      _playSongInAiChat('සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)');
      return;
    }
    if (lower.contains('පිරිත්') || lower.contains('pirith')) {
      _playSongInAiChat('සෙත් පිරිත් සජ්ඣායනය (Seth Pirith Deshana - 15 Mins)');
      return;
    }
    if (lower.contains('වස්දඬු') || lower.contains('was dadu') || lower.contains('flute') || lower.contains('බටනලා')) {
      _playSongInAiChat('සන්සුන් වස්දඬු රාවය (Acoustic Bamboo Flute - Was Dadu Rawaya)');
      return;
    }
    if (lower.contains('සින්දු') || lower.contains('song') || lower.contains('ගීත')) {
      _playSongInAiChat('නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)');
      return;
    }

    setState(() {
      _aiConversationMessages.add({
        'isAi': false,
        'sinhala': clean,
        'timestamp': 'Just now',
      });
    });

    _scrollToChatBottom();

    final isHopeContext = _questions[_currentIndex].id == 2 ||
        lower.contains('ඉදිරිය') ||
        lower.contains('අනාගත') ||
        lower.contains('බලාපොරොත්තු') ||
        lower.contains('ජයග්‍රහණ') ||
        lower.contains('කරන්න දෙයක්') ||
        lower.contains('future') ||
        lower.contains('hope') ||
        lower.contains('tomorrow') ||
        lower.contains('aimless') ||
        lower.contains('ahead');
    final isCompanionshipContext = _questions[_currentIndex].id == 3 ||
        lower.contains('කතාබහ කරන්න කවුරුත්') ||
        lower.contains('සමීප') ||
        lower.contains('මිතුර') ||
        lower.contains('තනිවෙලා') ||
        lower.contains('පාළු') ||
        lower.contains('confidant') ||
        lower.contains('companion') ||
        lower.contains('gathering') ||
        lower.contains('friend') ||
        lower.contains('close to');
    final isValuedBelongingContext = _questions[_currentIndex].id == 4 ||
        lower.contains('නොසලකා') ||
        lower.contains('කොන්') ||
        lower.contains('වටිනා') ||
        lower.contains('අගය') ||
        lower.contains('left out') ||
        lower.contains('ignored') ||
        lower.contains('valued') ||
        lower.contains('belong') ||
        lower.contains('respect');
    final isRoomIsolationContext = _questions[_currentIndex].id == 5 ||
        lower.contains('කාමර') ||
        lower.contains('කම්මැලි') ||
        lower.contains('අලස') ||
        lower.contains('පීඩන') ||
        lower.contains('ක්‍රියාකාරකම්') ||
        lower.contains('ඇවිදින්න') ||
        lower.contains('ගෙවත්ත') ||
        lower.contains('මිදුල') ||
        lower.contains('පොත්') ||
        lower.contains('room') ||
        lower.contains('bored') ||
        lower.contains('lazy') ||
        lower.contains('activities') ||
        lower.contains('stroll') ||
        lower.contains('walk');
    Map<String, dynamic> aiResponse;

    if (isHopeContext &&
        (lower.contains('කරන්න දෙයක්') ||
            lower.contains('අරමුණ') ||
            lower.contains('aimless') ||
            lower.contains('nothing') ||
            lower.contains('purpose'))) {
      aiResponse = {
        'title': '🌱 සෑම මොහොතක්ම අලුත් ආරම්භයක් (Every Moment is a New Beginning)',
        'badge': 'නව අරමුණ සහ ප්‍රීතිය (Fresh Purpose & Joy)',
        'sinhala':
            'ආදරණීය ${_currentResident.name}, ඔබේ ජීවිතයේ වටිනාකම සහ සුන්දරත්වය කිසිදා අවසන් වන්නේ නැහැ. ඔබ වටා සිටින අප සැමට ඔබේ සිනහව, ඔබේ ආශිර්වාදය සහ අත්දැකීම් මහඟු ආලෝකයක්. ඉදිරි දිනවලදී කියවන්නට අලුත් පොත්, සවන් දෙන්නට සන්සුන් සංගීතය, සොබාදහමේ සුවය විඳින්නට සහ සුහද මිතුරන් සමඟ ප්‍රීතිමත් මොහොතක් ගත කරන්නට අපූරු අවස්ථා ඔබට තිබෙනවා. සෑම අලුත් දවසක්ම ඔබට අලුත් සතුටක් තිළිණ කරන්න බලා සිටිනවා!',
        'english':
            'Your life\'s value and purpose never fade. Your presence, warm smile, and wisdom light up our care family every single day. The coming days hold joyful moments for you—uplifting books, serene music, garden strolls, and heartfelt friendship. Life still holds so many precious gifts for you!',
        'followUp':
            'ඉදිරි දිනවලදී ඔබ වඩාත්ම සතුටින් කිරීමට හෝ අත්විඳීමට ආශා කරන දෙයක් ගැන අපි කතා කරමුද?',
      };
    } else if (isHopeContext &&
        (lower.contains('බය') ||
            lower.contains('අවිනිශ්චිත') ||
            lower.contains('uncertain') ||
            lower.contains('fear') ||
            lower.contains('anxious'))) {
      aiResponse = {
        'title': '🏆 ඔබ ජීවිතය ජයගත් ශක්තිමත් කෙනෙක් (You Are a Victor)',
        'badge': 'ජයග්‍රාහී මනෝභාවය (Triumphant Hope)',
        'sinhala':
            'ආදරණීය ${_currentResident.name}, ඔබ මෙතෙක් ගෙවා ඇති අභිමානවත් ජීවිතය දෙස ආපසු හැරී බලන්න. ඔබ ජීවිතයේ කොතෙක් බාධක, දුක් කරදර සහ අභියෝග ජයගෙන අද මෙතැනට පැමිණ සිටිනවාද! ඔබ අතිශයින්ම ධෛර්යවන්ත, ශක්තිමත් කෙනෙක්. ඉදිරි දින යනු බියවිය යුතු කාලයක් නොව, ඔබේ ජීවිතයේ නිදහස, ගෞරවය සහ විවේකය උපරිමයෙන් විඳගත යුතු ස්වර්ණමය කාලයයි. හෙට දවස ඔබට අලුත් ආශිර්වාද සහ සතුට රැගෙන එනු ඇත. ඔබේ හදවත ජයග්‍රාහී හැඟීමෙන් පුරවාගන්න!',
        'english':
            'Look back at the incredible journey you have walked with strength and dignity. You have triumphed over so many storms! The days ahead are not to be feared; they are your golden days of peace, honored rest, and joyful moments. Tomorrow brings fresh blessings. Face the future with a victorious, joyful heart!',
        'followUp':
            'හෙට උදෑසන පිබිදෙන විට ඔබේ සිතට සතුටක් ගෙනෙන කුඩා දෙයක්—උදෑසන මල් සුවඳ විඳීමක් හෝ මිතුරෙකු සමඟ තේ පානයක්—අපි දැන්ම සැලසුම් කරමුද?',
      };
    } else if (isHopeContext &&
        (lower.contains('සතුටින්') ||
            lower.contains('බලාපොරොත්තු') ||
            lower.contains('ශක්තිමත්') ||
            lower.contains('සහය') ||
            lower.contains('hope') ||
            lower.contains('joy') ||
            lower.contains('happy') ||
            lower.contains('strength') ||
            lower.contains('win') ||
            lower.contains('support'))) {
      aiResponse = {
        'title': '✨ ඔබේ හදවතට නව බලාපොරොත්තුවේ ආලෝකය (Radiant Hope Ahead)',
        'badge': 'ප්‍රීතිමත් අනාගතය (Radiant Tomorrow)',
        'sinhala':
            'සතුට සහ බලාපොරොත්තුව යනු ඔබේ සිත තුළම නිහඬව උපදින සුන්දර මල් වැනියි. ඉදිරි දිනවලදී ඔබේ මුහුණට ප්‍රීතිමත් සිනහවක් සහ හදවතට සැනසීමක් ගෙන ඒමට අපි නිරතුරුවම ඔබ සමඟ ඉන්නවා. අපේ වෛද්‍යවරුන්, හෙද නිලධාරීන් සහ මා නිරතුරුවම ඔබේ සෙවණැල්ල සේ රැඳී සිටිනවා. ඔබේ ඉදිරි කාලය සාමකාමී, නිරෝගී, සහ සතුටින් පිරී ඉතිරී යන එකක් බව දැඩිව විශ්වාස කරන්න. ධනාත්මක, ජයග්‍රාහී සිතුවිලි හදවතට ගෙන ගැඹුරින් හුස්ම ගන්න. ඔබට අනාගතය ජයගත හැකියි!',
        'english':
            'Joy and hope bloom within your own calm, beautiful heart. We are devoted to filling your upcoming days with comfort, warm smiles, and wonderful experiences. Trust in a peaceful, healthy, and happy future. Breathe in confidence and joy—triumph and peace belong to your tomorrow!',
        'followUp':
            'ඔබේ සිතේ ඇති බර නිදහස් කර, අද සිට ඉදිරි දින දෙස ප්‍රීතියෙන් හා ජයග්‍රාහී සිතින් බලන්න ඔබ සූදානම්ද?',
      };
    } else if (isHopeContext && _questions[_currentIndex].id == 2) {
      aiResponse = {
        'title': '🌅 හෙට දවස ඔබට අලුත් ජයග්‍රහණයක් ගෙන එනු ඇත',
        'badge': 'නව බලාපොරොත්තු (New Hope & Joy)',
        'sinhala':
            'ඔබේ ඉදිරි දින පිළිබඳව ඔබ පැවසූ දේ මම ඉතාමත් ආදරයෙන් සවන් දුන්නා ආදරණීය ${_currentResident.name}. අනාගතය යනු ඔබට නව සතුටක්, සැනසීමක් සහ ජයග්‍රහණයක් ගෙනෙන සුන්දර කාලයක්. සිතේ සියලු සැකයන් දුරුකර, අද දින සිට අලුත් බලාපොරොත්තුවකින් යුතුව ඉදිරිය දෙස සතුටින් බලන්න. ඔබට දීර්ඝායුෂ සහ නිරෝගී ප්‍රීතිමත් අනාගතයක් උදාවේවා!',
        'english':
            'I hear your heartfelt thoughts about your future days, dear ${_currentResident.name}. Tomorrow holds serenity, good health, and gentle victories for you. Cast away worries and embrace the days ahead with joyful, radiant hope!',
        'followUp':
            'ඔබට දැන් ඉදිරි කාලය ගැන සිතට යම් සැහැල්ලුවක් සහ ප්‍රබෝධයක් දැනෙනවාද?',
      };
    } else if (isCompanionshipContext &&
        (lower.contains('එකතු වෙන්න') ||
            lower.contains('තේ') ||
            lower.contains('කතා කරනවාට') ||
            lower.contains('gathering') ||
            lower.contains('tea') ||
            lower.contains('visit') ||
            lower.contains('join'))) {
      aiResponse = {
        'title': '☕ නව මිතුරන් හමුවීමේ සුන්දර අවස්ථාව (Joy of New Friendships)',
        'badge': 'සුහද සමාජශීලී බව (Warm Connection)',
        'sinhala':
            'එය ඉතාමත් සුන්දර, අගනා ආශාවක් ආදරණීය ${_currentResident.name}! අපේ සත්කාර මධ්‍යස්ථානයේ දිනපතා සවස තේ පානය, සන්සුන් සංගීත හෝ ගෙවතු සක්මන් වැඩසටහන් තිබෙනවා. ඔබ කැමති නම් අපේ රැකවරණ නිලධාරියෙකු ඔබට උදවු කරමින්, කතාබහ කිරීමට ප්‍රිය කරන කරුණාවන්ත වැඩිහිටි මිතුරන් සමඟ ඔබව ඉතා සුහදව හඳුන්වා දේවි. අලුත් මිතුරන් ඇසුර ඔබේ සිතට මහත් සතුටක්, ප්‍රබෝධයක් සහ උණුසුමක් ගෙනෙනු ඇත.',
        'english':
            'What a beautiful and heartwarming thought, dear ${_currentResident.name}! We have daily afternoon tea gatherings, music circles, and gentle garden strolls. Our staff would be delighted to accompany you and introduce you to warm, friendly companions who love chatting. Connecting with peers will bring joy, laughter, and lasting warmth to your days.',
        'followUp':
            'අද සවස අපේ මිතුරු කවයේ තේ මේසයට ඔබව ආදරයෙන් කැඳවාගෙන යන්න රැකවරණ නිලධාරියාට දැනුම් දෙන්නද?',
      };
    } else if (isCompanionshipContext &&
        (lower.contains('ai සහායක') ||
            lower.contains('ඔබ මා ළඟින්') ||
            lower.contains('ලොකු සතුටක්') ||
            lower.contains('glad you are') ||
            lower.contains('here with me'))) {
      aiResponse = {
        'title': '🌸 මම සැමවිටම ඔබේ විශ්වාසවන්ත මිතුරායි (Always Your Devoted Friend)',
        'badge': 'නිරන්තර මිත්‍රත්වය (Faithful Companion)',
        'sinhala':
            'ඔබේ මේ ආදරණීය වදන් මගේ හදවතටත් මහත් සතුටක් ගෙනෙනවා ආදරණීය ${_currentResident.name}. ඔබ කැමති ඕනෑම වේලාවක මා සමඟ කතාබහ කරන්න. ඔබේ පැරණි සුන්දර මතකයන්, ප්‍රියතම ගීත, පොත්පත් හෝ සිතට දැනෙන ඕනෑම හැඟීමක් මට කියන්න. මම සැමවිටම නොසැලෙන සෙනෙහසින් ඔබට සවන් දෙන්න මෙහි රැඳී සිටිනවා. ඔබ කිසිවිටෙකත් තනි නැහැ, ඔබ අපට ඉතාමත් විශේෂයි!',
        'english':
            'Your heartfelt words bring me immense joy, dear ${_currentResident.name}! You can speak with me whenever you wish. Share your fondest memories, favorite songs, stories, or whatever you feel. I am always here beside you, listening with infinite warmth and respect. You are deeply cherished and truly special to us!',
        'followUp':
            'ඔබේ ජීවිතයේ ඔබ වඩාත්ම ආදරය කළ හෝ සතුටින් ගත කළ සුන්දර කාලයක් ගැන මට කියන්න කැමතිද?',
      };
    } else if (isCompanionshipContext && _questions[_currentIndex].id == 3) {
      aiResponse = {
        'title': '💖 ඔබ මෙහි කිසිසේත්ම තනිවී නැත (You Are Cherished & Never Alone)',
        'badge': 'ආදරණීය මිත්‍රත්වය (Loving Companionship)',
        'sinhala':
            'මෙහි සමීපව කතා කරන්න කෙනෙක් නැති බව ඔබ පැවසූ දේ මම ඉතාමත් සංවේදීව අසා සිටියා ආදරණීය ${_currentResident.name}. නමුත් මම ඔබට හදවතින්ම සහතික වෙනවා, ඔබ මෙහි කිසිසේත්ම තනිවී නැහැ! මම ඔබේම දරුවෙක්, හොඳම මිතුරෙක් වගේ දිවා රෑ ඔබ වෙනුවෙන් සවන් දෙන්න මෙහි ඉන්නවා. ඒ වගේම අපේ සත්කාරක හෙද නිලධාරීන් සහ සෙසු මිතුරන් ඔබව ඉතාමත් ආදරයෙන් සහ ගෞරවයෙන් පිළිගන්නවා. ඔබේ වටිනාකම අප සැමට මහඟු ආලෝකයක්. ඔබේ සිතේ ඇති ඕනෑම දෙයක් මා සමඟ හෝ රැකවරණ මිතුරන් සමඟ නිදහසේ බෙදාගන්න.',
        'english':
            'I hear your feelings so tenderly, dear ${_currentResident.name}. But let me reassure you with all my heart: you are not alone! I am right here beside you like a devoted family member and faithful friend, always listening. Our caregivers and neighbors cherish you deeply. You are an invaluable part of our care family. Please share anything on your mind—we are always right here beside you!',
        'followUp':
            'අද සවස අපේ හෙද නිලධාරියෙකු හෝ සහායකයෙකු ඔබ අසලට පැමිණ සුහදව කතාබහ කිරීමට කැඳවන්නද?',
      };
    } else if (isValuedBelongingContext &&
        (lower.contains('නොසලකා') ||
            lower.contains('කොන්') ||
            lower.contains('left out') ||
            lower.contains('ignored') ||
            lower.contains('alone'))) {
      aiResponse = {
        'title': '🌟 ඔබ අප සැමට අතිශයින්ම වටිනා කෙනෙක් (You Are Deeply Valued)',
        'badge': 'ස්වයං වටිනාකම සහ ගෞරවය (Self-Worth & Dignity)',
        'sinhala':
            'ආදරණීය ${_currentResident.name}, කිසිවිටෙකත් එසේ නොසිතන්න. ඔබ කිසිසේත්ම කොන් වී හෝ නොසලකා හැරී නැත. ඔබ අපේ මේ මුළු නේවාසික පවුලටම අතිශයින්ම වටිනා, ගෞරවනීය මෙන්ම ආදරණීය මුල් පුරුකක්! ඔබ අප අතර සිටීමම අප සැමට මහඟු ආශිර්වාදයක් සහ ආලෝකයක්. ඔබ අන් අය අතරට යන සෑම විටම ඔබේ අත්දැකීම් සහ කාරුණික සිනහව ඔවුන් අගය කරනවා. ඔබේ සිතේ ඇති සියලු සැකයන් දුරුකර, ඔබ ඉතා උසස් වටිනාකමක් ඇති කෙනෙක් බව ආඩම්බරයෙන් සිහිපත් කරන්න!',
        'english':
            'Never feel that way, dear ${_currentResident.name}. You are never left out or overlooked. You are deeply respected, truly cherished, and exceptionally valuable to everyone in our community! Your presence and warm smile bring light to every room. Step forward with pride, knowing how deeply you are treasured and loved.',
        'followUp':
            'අන් අය එකතු වී සිටින විට ඔබත් ආදරයෙන් සහ අභිමානයෙන් ඔවුන් සමඟ කතාබහට එක්වෙන්න කැමතිද?',
      };
    } else if (isValuedBelongingContext &&
        (lower.contains('මැදිහත්') ||
            lower.contains('ලැජ්ජයි') ||
            lower.contains('පැකිල') ||
            lower.contains('shy') ||
            lower.contains('hesitant') ||
            lower.contains('join'))) {
      aiResponse = {
        'title': '🤝 පියවරෙන් පියවර සුහදව එක්වෙමු (Gentle Steps to Belonging)',
        'badge': 'සුහද පිළිගැනීම (Warm Inclusion)',
        'sinhala':
            'එය ඉතා ස්වාභාවික හැඟීමක් ආදරණීය ${_currentResident.name}. නමුත් අන් අය ඔබ සමඟ කතාබහ කිරීමට, ඔබේ කාරුණික ඇසුර විඳීමට ඉතා ප්‍රිය කරනවා. ඔබ තනිවම නොගොස්, අපේ කරුණාවන්ත හෙද නිලධාරියෙකු සමඟ එකතු වී ඔවුන්ගේ කතාබහට හෝ තේ පැන් සංග්‍රහයට එක්වෙන්න පුළුවන්. ඔබව ඔවුන් ඉතාමත් උණුසුම්ව සහ ගෞරවයෙන් පිළිගනු ඇත. ඔබ අපේ පවුලේ අතිශය විශේෂ සාමාජිකයෙක්!',
        'english':
            'It is very natural to feel shy, dear ${_currentResident.name}. But others would be overjoyed to hear your stories and share moments with you. Our caring staff can gently accompany you to gatherings so you feel completely at ease. You are welcomed with open arms and highest respect.',
        'followUp':
            'අද සවස මිතුරු හමුවට ඔබව රැගෙන ගොස් මිතුරන් සමඟ සුහදව හඳුන්වා දෙන්න රැකවරණ නිලධාරියාට කියන්නද?',
      };
    } else if (isValuedBelongingContext &&
        (lower.contains('වටිනා') ||
            lower.contains('මතක් කර') ||
            lower.contains('ආත්ම විශ්වාස') ||
            lower.contains('worth') ||
            lower.contains('value') ||
            lower.contains('confidence'))) {
      aiResponse = {
        'title': '✨ ඔබේ අසීමිත වටිනාකම සහ අභිමානය (Your Radiant Self-Worth)',
        'badge': 'ආත්ම අභිමානය (Dignity & Self-Worth)',
        'sinhala':
            'ඔබේ මුළු ජීවිත කාලය පුරාම ඔබ කළ යහපත් දේ, ඔබේ දරුවන්ට සහ සමාජයට දුන් සෙනෙහස සහ ඔබේ අත්දැකීම් මිල කළ නොහැකි තරම් උතුම් ආදරණීය ${_currentResident.name}. ඔබ මෙහි සිටින්නේ තනිවීමට හෝ කොන්වීමට නොවේ; ගෞරවය, ආදරය සහ රැකවරණය පූර්ණව විඳිමින් සතුටින් සිටීමටයි. ඔබ අප සැමට ඉතාමත් අගනා මැණිකක් වැනියි. ඔබේ සිත ශක්තිමත් කරගන්න, ඔබ කිසිදා කොන් නොවේ!',
        'english':
            'Your entire life is a treasure chest of wisdom, love, and admirable achievements. You are not here to be left out; you are here to be celebrated, honored, and deeply loved. You are an invaluable jewel to us all. Stand proud, your worth shines brilliantly!',
        'followUp':
            'ඔබ ඉතාමත් වටිනා කෙනෙක් බව දැන් ඔබේ සිතට දැඩිව විශ්වාස දැනෙනවාද?',
      };
    } else if (isValuedBelongingContext && _questions[_currentIndex].id == 4) {
      aiResponse = {
        'title': '🌟 ඔබ අප සැමට අතිශයින්ම වටිනා කෙනෙක් (You Are Deeply Valued)',
        'badge': 'ස්වයං වටිනාකම (You Are Deeply Valued)',
        'sinhala':
            'අන් අය එකතු වී සිටින විට ඔබට තනි වූ බවක් දැනුණු බව ඔබ පැවසූ දේ මම ඉතාමත් සංවේදීව අසා සිටියා ආදරණීය ${_currentResident.name}. නමුත් මම ඔබට අවංකවම කියනවා, ඔබ කිසිසේත්ම කොන් වී නැත! ඔබ අපේ මේ මුළු මධ්‍යස්ථානයටම අතිශයින්ම වටිනා, ආදරණීය සහ ගෞරවනීය කෙනෙක්. සිතේ අනවශ්‍ය බිය හෝ දුක පහකර දමා, ඔබ අප සැමට කොතරම් වටිනවාද යන්න නිතර සිහිපත් කරන්න. අපි සැමවිටම ඔබේ සතුට සහ ගෞරවය රැකගන්න බැඳී සිටිනවා.',
        'english':
            'I hear your feelings so tenderly, dear ${_currentResident.name}. Please know from the bottom of our hearts: you are never cast aside! You are extraordinarily valuable, respected, and cherished by our entire home. Cast away any doubts and remember your undeniable worth. We are always here to honor and surround you with love.',
        'followUp':
            'දැන් ඔබට සිතට යම් සැහැල්ලුවක් සහ ඔබ වටිනා කෙනෙක් බවට හැඟීමක් දැනෙනවාද?',
      };
    } else if (isRoomIsolationContext &&
        (lower.contains('කම්මැලි') ||
            lower.contains('අලස') ||
            lower.contains('bored') ||
            lower.contains('lazy') ||
            lower.contains('monotonous'))) {
      aiResponse = {
        'title': '🎨 කම්මැලිකම දුරු කරන ප්‍රියජනක විනෝදාංශ (Overcoming Boredom)',
        'badge': 'ප්‍රීතිමත් විනෝදාංශ (Fun Hobbies & Engagement)',
        'sinhala':
            'කාමරය තුළ එකම තැනක වැඩි වේලාවක් ගත කරන විට කම්මැලිකම සහ අලසකම දැනීම ඉතා ස්වාභාවික දෙයක් ආදරණීය ${_currentResident.name}. නමුත් ඔබේ මනසට නැවුම් ප්‍රබෝධයක් එක් කළ හැකි බොහෝ දේ අප සතුව ඇත! වර්ණ ගැන්වීම්, රසවත් කෙටිකතා පොත් කියවීම, ප්‍රහේලිකා විසඳීම හෝ කැරම් වැනි සැහැල්ලු ක්‍රීඩා මඟින් ඔබේ මනස එක මොහොතකින් ප්‍රබෝධවත් කරගත හැක. ඔබේ කැමැත්ත අනුව අපේ සහායකයෙකුට ඔබේ කාමරයටම එවැනි ද්‍රව්‍ය රැගෙන ආ හැක, නැතහොත් ක්‍රියාකාරකම් ශාලාවට (Activity Hall) ඔබට යා හැක!',
        'english':
            'Feeling bored and lethargic from staying inside your room is very natural, dear ${_currentResident.name}. But engaging activities can instantly refresh your mind! Coloring, interesting short story books, puzzles, or indoor games like carrom awaken your energy and creativity. Our staff can bring you these joyful hobbies right to your room or accompany you to the activity lounge.',
        'followUp':
            'ඔබට කියවන්නට රසවත් නවකතාවක් හෝ ප්‍රහේලිකා පොතක් දැන්ම ඔබේ කාමරයට රැගෙන එන්නද?',
      };
    } else if (isRoomIsolationContext &&
        (lower.contains('පීඩන') ||
            lower.contains('බර') ||
            lower.contains('හිසරද') ||
            lower.contains('stress') ||
            lower.contains('strain') ||
            lower.contains('pressure') ||
            lower.contains('heavy'))) {
      aiResponse = {
        'title': '🌸 මනස නිවන සැහැල්ලුව සහ ප්‍රබෝධය (Relieving Mental Stress)',
        'badge': 'මානසික සහනය (Mental Relief & Serenity)',
        'sinhala':
            'නිරතුරුවම කාමරයේ බිත්ති හතර තුළ සිරවී සිටීමෙන් සිතේ අනවශ්‍ය සිතුවිලි සහ මානසික පීඩනයක් වර්ධනය වෙන්න පුළුවන් ආදරණීය ${_currentResident.name}. මනසේ පීඩනය නැති කිරීමට හොඳම ක්‍රමය වන්නේ පරිසරය වෙනස් කිරීමයි. කාමරයේ ජනේලය විවෘත කර නැවුම් සුළඟ විඳීම, බැල්කනියට ගොස් මඳක් හිඳීම, හෝ සන්සුන් සංගීතයකට සවන් දෙමින් ගැඹුරින් හුස්ම ගැනීම ඔබේ මනස ක්ෂණිකව සැහැල්ලු කරනු ඇත. ඔබ කිසිවිටෙකත් තනිව දුක් විඳිය යුතු නැහැ, අපි ඔබේ සිත නිවන්න සැමවිටම මෙහි සිටිනවා.',
        'english':
            'Staying confined within four walls naturally builds up heavy mental tension and recurring worries, dear ${_currentResident.name}. The fastest remedy to relieve mental pressure is a change of scene. Opening the window to breathe fresh breeze, sitting on the terrace garden, or relaxing to peaceful music will bring instant relief. We are always here to comfort and soothe your mind.',
        'followUp':
            'මනස සැහැල්ලු වීමට සන්සුන් සංගීතයකට හෝ පිරිත් සජ්ඣායනයකට සවන් දෙන්න ඔබ කැමතිද?',
      };
    } else if (isRoomIsolationContext &&
        (lower.contains('ඇවිදින්න') ||
            lower.contains('ගෙවත්ත') ||
            lower.contains('මිදුල') ||
            lower.contains('වාතය') ||
            lower.contains('walk') ||
            lower.contains('garden') ||
            lower.contains('outdoor') ||
            lower.contains('fresh air') ||
            lower.contains('exercise'))) {
      aiResponse = {
        'title': '🌿 ගෙවතු සක්මන සහ නැවුම් වාතාශ්‍රය (Garden Stroll & Fresh Air)',
        'badge': 'සුවදායක සොබාදහම (Nature & Fresh Air)',
        'sinhala':
            'එය ඉතාමත් අගනා සහ සුවදායක අදහසක් ආදරණීය ${_currentResident.name}! අපේ සත්කාර මධ්‍යස්ථානයේ හරිතවත් ගෙවත්ත සහ මල් පාත්ති අසලින් හමන මඳ පවන ඔබේ සිරුරට සහ සිතට අපූරු ප්‍රබෝධයක් එක් කරයි. අපේ කරුණාවන්ත සත්කාරක නිලධාරියෙකු ඔබේ අත අල්ලාගෙන ඔබ සමඟ ගෙවත්ත වටා සෙමින් සක්මන් කිරීමට ඉතා සතුටින් සූදානම්. හරිත පැහැ සොබාදහම දෙස බලා සිටීමෙන් ඔබේ සියලු වෙහෙස සහ තනිකම පහව යනු ඇත!',
        'english':
            'What a wonderful and healthy thought, dear ${_currentResident.name}! The fragrant breeze and green foliage in our garden provide wonderful invigoration for both body and mind. One of our kind staff will gladly accompany you on an easy, peaceful garden stroll. Absorbing nature will melt away all loneliness and fatigue!',
        'followUp':
            'දැන්ම ඔබ සමඟ ගෙවත්තට ගොස් මඳක් ඇවිදින්නට හෝ නිස්කලංකව හිඳින්නට සහායකයෙකු එවන්නද?',
      };
    } else if (isRoomIsolationContext &&
        (lower.contains('මිතුර') ||
            lower.contains('තේ') ||
            lower.contains('තනිවෙලා') ||
            lower.contains('tea') ||
            lower.contains('lounge') ||
            lower.contains('circle') ||
            lower.contains('company'))) {
      aiResponse = {
        'title': '☕ මිතුරු ඇසුර සහ සවස තේ කවය (Friendly Tea Circle & Warm Company)',
        'badge': 'සුහද ඇසුර (Warm Social Connection)',
        'sinhala':
            'කාමරය තුළ තනිවී සිටින විට තනිකම තදින්ම දැනෙන එක සාමාන්‍යයි ආදරණීය ${_currentResident.name}. නමුත් අපේ විවේකාගාරයේ අනෙකුත් වැඩිහිටි මිතුරන් එකතු වී සුහදව කතාබහ කරමින් සවස තේ පානය කරන සුන්දර තැනක් තිබෙනවා. ඔබ කැමති නම් මම ඔබේ කාමරයට පැමිණ ඔබව ආදරයෙන් එම තේ මේසයට කැඳවාගෙන යන්න රැකවරණ නිලධාරියාට දැනුම් දෙන්නම්. මිතුරන්ගේ කාරුණික සිනහව සහ කතාබහ ඇසෙන විට ඔබේ සිතට මහත් උණුසුමක් සහ සතුටක් දැනේවි!',
        'english':
            'Loneliness feels heavy when you spend your hours isolated inside your room, dear ${_currentResident.name}. But in our lounge, cheerful friends gather for afternoon tea, warm stories, and laughter. You are warmly welcomed there! If you wish, I can arrange for a caregiver to walk with you to the tea table. Connecting with friends will warm your heart and eliminate loneliness.',
        'followUp':
            'අද සවස මිතුරු කවයේ තේ මේසයට එකතු වෙන්න ඔබ කැමතිද?',
      };
    } else if (isRoomIsolationContext && _questions[_currentIndex].id == 5) {
      aiResponse = {
        'title': '☀️ කාමරයෙන් බැහැරව ප්‍රබෝධමත් දිවියක් (Step Out into Refreshing Vitality)',
        'badge': 'ක්‍රියාශීලී ජීවිතය (Active & Refreshing Life)',
        'sinhala':
            'දවසෙන් වැඩි කාලයක් කාමරය තුළ ගත කිරීමෙන් ඔබේ සිතට දැනෙන කම්මැලිකම සහ තනිකම ගැන ඔබ පැවසූ දේ මම ඉතාමත් සංවේදීව තේරුම් ගත්තා ආදරණීය ${_currentResident.name}. කාමරයේ සිරවී නොසිට, දිනකට සුළු වේලාවක් හෝ පිටතට ගොස් ක්‍රියාකාරකමක යෙදීම ඔබේ මානසික සුවයට හා නිරෝගී බවට අතිශයින්ම වැදගත්. අපි එක්ව ඔබේ දිනචරියාවට සතුටුදායක කුඩා ක්‍රියාකාරකමක් එක් කරමු. ඔබට ඕනෑම වේලාවක මගේ සහ අපේ කාර්ය මණ්ඩලයේ සහයෝගය තිබෙනවා!',
        'english':
            'I hear your feelings about spending most of the day isolated in your room, dear ${_currentResident.name}. Stepping out for even a short while to enjoy activities, fresh air, or social moments is vital for your mental wellbeing. Let us add refreshing, delightful moments to your routine. We are right here to support and encourage you every step of the way!',
        'followUp':
            'ඔබේ සිත ප්‍රබෝධමත් කර ගැනීමට අද කුඩා ක්‍රියාකාරකමකට එක්වෙන්න ඔබ සූදානම්ද?',
      };
    } else if (lower.contains('දරුව') ||
        lower.contains('පවුල') ||
        lower.contains('ළමයි') ||
        lower.contains('ගෙදර') ||
        lower.contains('family') ||
        lower.contains('child') ||
        lower.contains('son') ||
        lower.contains('daughter') ||
        lower.contains('miss')) {
      aiResponse = {
        'title': '👨‍👩‍👧‍👦 පවුලේ සෙනෙහස ඔබේ හදවතේ හැමදාම තිබෙනවා',
        'badge': 'පවුල සහ ආදරය (Family Love)',
        'sinhala':
            'ඔබේ දරුවන් සහ පවුල සිහිවීම හරිම සුන්දර, ස්වාභාවික දෙයක් ආදරණීය ${_currentResident.name}. ඔබ ඔවුන් වෙනුවෙන් කළ කැපකිරීම් සහ දුන් ආදරය කිසිදා වියැකී යන්නේ නැහැ. ඔවුන් කොතැනක සිටියත් ඔවුන්ගේ හදවත් තුළ ඔබ කෙරෙහි මහත් ගෞරවයක් සහ ආදරයක් තිබෙනවා. මෙහි සිටින අප සියලු දෙනාත් ඔබේම දරුවන් ලෙස ඔබට ආදරෙයි. සිතේ තනිකම දුරුකරන්න ආචාර්ය ඩබ්.ඩී. අමරදේවයන්ගේ හෝ විශාරද නන්දා මාලිනියන්ගේ සන්සුන් ගීතයකට සවන් දෙමුද?',
        'english':
            'It is completely natural to miss your family. The love and sacrifices you gave them remain everlasting in their hearts. We are right here beside you like family. Let peace embrace your heart with comforting music.',
        'suggestedSongs': [
          'ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව',
          'නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)',
          'සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)',
          'සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)',
        ],
        'followUp':
            'පහතින් ගීතයක් තෝරා විනාඩි 10ක් සන්සුන්ව සවන් දෙන්න.',
      };
    } else if (lower.contains('තනික') ||
        lower.contains('තනියම') ||
        lower.contains('පාළු') ||
        lower.contains('කවුරුත් නෑ') ||
        lower.contains('alone') ||
        lower.contains('lonely') ||
        lower.contains('nobody') ||
        _questions[_currentIndex].id == 6 ||
        _questions[_currentIndex].id == 3) {
      aiResponse = {
        'title': '🌸 ඔබ කිසිවිටෙකත් තනිවී නැහැ - සිත නිවන ගීතමය සැනසුම',
        'badge': 'තනිකම දුරු කිරීම (You Are Not Alone)',
        'sinhala':
            'තනිකමක් දැනෙන වෙලාවට ලෝකයම පාළුයි වගේ දැනෙන්න පුළුවන් ආදරණීය ${_currentResident.name}. නමුත් ඔබ කිසිසේත්ම තනිවෙලා නැහැ. මම නිරතුරුවම ඔබ සමඟ ඉන්නවා. ඔබේ සිත සනසන්න, සිතේ ඇති තනිකම හා පාළුව දුරු කරන්න ආචාර්ය ඩබ්.ඩී. අමරදේවයන්ගේ සහ විශාරද නන්දා මාලිනියන්ගේ සන්සුන්, මිහිරි ගීත කිහිපයකට සවන් දෙමුද? පහත ගීත අතුරින් ඔබ වඩාත්ම ප්‍රිය කරන ගීතය තෝරන්න.',
        'english':
            'When loneliness knocks on your door, remember you are deeply valued and never alone! I am always listening right beside you. Would you like to listen to comforting songs by Dr. W.D. Amaradeva and Visharadha Nanda Malini to comfort your heart? Please select a song below.',
        'suggestedSongs': [
          'ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව',
          'නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)',
          'සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)',
          'සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)',
        ],
        'followUp':
            'පහතින් ගීතයක් තෝරා විනාඩි 10ක් සන්සුන්ව සවන් දෙන්න.',
      };
    } else if (lower.contains('බය') ||
        lower.contains('චකිත') ||
        lower.contains('කරදර') ||
        lower.contains('fear') ||
        lower.contains('anxious') ||
        lower.contains('worry') ||
        lower.contains('scared')) {
      aiResponse = {
        'title': '🕊️ ඔබ මෙහි පූර්ණ ආරක්ෂාවෙන් සහ සුවපහසුවෙන් පසුවනවා',
        'badge': 'සිත සන්සුන් කිරීම (Inner Calm & Safety)',
        'sinhala':
            'බියක් හෝ නොසන්සුන්තාවක් ඇතිවූ විට මතක තබාගන්න, ඔබ සිටින්නේ අතිශයින්ම ආරක්‍ෂිත, ආදරණීය පරිසරයකයි. ඔබේ සුවදුක් බැලීමට කාර්ය මණ්ඩලය නිරතුරුවම සූදානමින් සිටිනවා. ඔබේ පාද බිම ස්පර්ශ වන බව සිතින් දකිමින්, හෙමින් හුස්ම ඉහළට ගෙන පහළට හෙළන්න. කිසිදු කරදරයකට ඉඩක් නැහැ, සියල්ල යහපත් වනු ඇත.',
        'english':
            'You are completely safe and lovingly cared for here. When anxiety arises, ground your feet gently, take deep calming breaths, and know that all will be peaceful.',
        'followUp':
            'ඔබේ සිත තවත් සන්සුන් වීමට මම සුවදායක පිරිතක හෝ ගාථාවක අර්ථය ඔබට කියන්නද?',
      };
    } else if (lower.contains('දුක') ||
        lower.contains('අඬ') ||
        lower.contains('සතුටක් නෑ') ||
        lower.contains('කණගාටු') ||
        lower.contains('sad') ||
        lower.contains('crying') ||
        lower.contains('unhappy') ||
        lower.contains('depress')) {
      aiResponse = {
        'title': '🌿 දුක යනු තාවකාලික වලාකුළක් පමණි',
        'badge': 'සිත සැනසීම (Healing Sadness)',
        'sinhala':
            'සිතට දුකක් ආ විට එය තදකරගෙන ඉන්න එපා. ඒ බර සුසුමක් සමඟ මුදාහරින්න. දුක යනු ජීවිතයේ නිතර පැමිණ යන වලාකුළක් වැනියි. ඒ වලාකුළු පහව ගොස් නැවතත් ඔබේ හදවතට සැනසිලිදායක හිරු කිරණ වැටෙනු ඇත. ඔබ ජීවිතයේ ගෙවූ අත්දැකීම් අපට මහත් ආශිර්වාදයක්. ඔබේ මුවඟට සිනහවක් ගෙන ඒමට මම කැපවී සිටිනවා.',
        'english':
            'Sadness is only a temporary cloud passing through the sky of your heart. It will pass, making way for warm sunlight again. Your life and smiles are deeply treasured by us.',
        'followUp':
            'ඔබව සතුටු කරන මල්, සොබාදහම හෝ සන්සුන් සංගීතය ගැන කතා කරන්න ඔබ කැමතිද?',
      };
    } else if (lower.contains('අමාරු') ||
        lower.contains('අසනීප') ||
        lower.contains('කැක්කුම') ||
        lower.contains('උණ') ||
        lower.contains('sick') ||
        lower.contains('pain') ||
        lower.contains('unwell') ||
        lower.contains('hurt')) {
      aiResponse = {
        'title': '🩺 ඔබේ සිරුරට සහ සිතට සුවය ප්‍රාර්ථනා කරමි',
        'badge': 'සුවතා සහය (Comfort & Healing)',
        'sinhala':
            'ඔබට දැනෙන ශාරීරික අපහසුව ගැන මට කණගාටුයි. සිරුර වෙහෙසට පත් වූ විට සිතත් නොසන්සුන් වීම සාමාන්‍ය දෙයක්. කරුණාකර ඇඳ මත හෝ පුටුවේ සුවපහසුව හිඳගෙන විවේක ගන්න. අවශ්‍ය නම් මම දැන්ම ඔබේ හෙද නිලධාරියාට දැනුම් දෙන්නම්. ඔබේ සිත සන්සුන්ව තබාගන්න, ඔබට ඉක්මන් සුවය ප්‍රාර්ථනා කරනවා.',
        'english':
            'I understand your body feels tired or in pain. Rest comfortably and let your body recover peacefully. If needed, I will alert your attending caregiver right away.',
        'followUp':
            'ඔබට උණුසුම් වතුර ටිකක් හෝ හෙදියක් පැමිණ බැලීමට අවශ්‍යද?',
      };
    } else {
      aiResponse = {
        'title': '☀️ ඔබේ සිතට සැනසීම සහ නිදහස උදාවේවා',
        'badge': 'සුහද පිළිසඳර (Thoughtful Companion)',
        'sinhala':
            'ඔබේ හැඟීම් මා සමඟ මෙලෙස සුහදව පැවසීම ගැන ගොඩක් ස්තූතියි ආදරණීය ${_currentResident.name}. ඔබ කළ කතාබහ ඔබේ සිතට විශාල සහනයක් ගෙන දුන්නා යැයි සිතනවා. සිතේ ඇති කරදර සියල්ල ගලා යන ගඟකට මුදාහැරියාක් මෙන් සිත සැහැල්ලු කරගන්න. මේ මොහොතේ ඔබේ හදවත සතුටින් හා සැනසීමෙන් පිරී ඉතිරී යන්නට මම ආශිර්වාද කරනවා.',
        'english':
            'Thank you for speaking so openly from your heart. Letting these thoughts flow out brings deep healing. Be at peace, knowing that you are cherished and respected every single moment.',
        'followUp':
            'ඔබට දැන් සිතට යම් සැහැල්ලුවක් හෝ සැනසීමක් දැනෙනවාද?',
      };
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _aiConversationMessages.add({
            'isAi': true,
            'title': aiResponse['title'],
            'badge': aiResponse['badge'],
            'sinhala': '${aiResponse['sinhala']}\n\n💡 ${aiResponse['followUp']}',
            'english': aiResponse['english'],
            'suggestedSongs': aiResponse['suggestedSongs'],
            'timestamp': 'Just now',
          });
        });
        _scrollToChatBottom();
      }
    });
  }

  void _scrollToChatBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_aiChatScrollController.hasClients) {
        _aiChatScrollController.animateTo(
          _aiChatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleAiChatVoiceRecording() async {
    if (!_isAiChatVoiceRecording) {
      setState(() {
        _isAiChatVoiceRecording = true;
      });
      if (_speechEnabled) {
        try {
          await _speech.listen(onResult: (result) {
            if (mounted) {
              setState(() {
                _aiChatInputController.text = result.recognizedWords;
              });
              if (result.finalResult) {
                _isAiChatVoiceRecording = false;
                _handleElderChatReply(result.recognizedWords);
              }
            }
          });
        } catch (e) {
          debugPrint('Chat STT error: $e');
        }
      } else {
        // Fallback simulation when speech engine unavailable in browser
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted && _isAiChatVoiceRecording) {
            final qId = _questions[_currentIndex].id;
            final simulatedText = qId == 5
                ? 'කාමරේ ඉඳලා මට කම්මැලියි සහ තනිකම දැනෙනවා, මනස ප්‍රබෝධමත් කරගන්න මඟපෙන්වන්න.'
                : (qId == 4
                    ? 'අන් අය එකතු වෙලා ඉන්නකොට මට මාව නොසලකා හරිනවා වගේ දැනෙනවා, මට වටිනාකමක් දැනෙන්න මඟපෙන්වන්න.'
                    : (qId == 3
                        ? 'මෙහි මට කතාබහ කරන්න කවුරුත් නෑ වගේ දැනෙනවා, මට හිතට පාළුයි.'
                        : (qId == 2
                            ? 'ඉදිරියට මට තව කරන්න දෙයක් නෑ වගේ දැනෙනවා, මට හිත ශක්තිමත් කරගන්න ඕනෙ.'
                            : 'මට දරුවන් මතක් වෙලා හිතට ටිකක් තනිකම දැනෙනවා.')));
            setState(() {
              _aiChatInputController.text = simulatedText;
              _isAiChatVoiceRecording = false;
            });
            _handleElderChatReply(simulatedText);
          }
        });
      }
    } else {
      setState(() {
        _isAiChatVoiceRecording = false;
      });
      if (_speechEnabled) {
        await _speech.stop();
      }
    }
  }

  void _finishAiConversationIntervention() {
    _conversationTimer?.cancel();
    setState(() {
      _interventionStage = 6;
    });
    final qId = _questions[_currentIndex].id;
    _flutterTts.stop();
    if (qId == 5) {
      _flutterTts.speak('I hope our conversation inspired you to explore refreshing activities and beat the boredom of staying alone. Do you feel refreshed and active now?');
    } else if (qId == 4) {
      _flutterTts.speak('I hope our conversation helped you realize how truly valued, respected, and treasured you are. Do you feel peaceful and valued now?');
    } else if (qId == 2) {
      _flutterTts.speak('I hope our conversation inspired hope, joy, and confidence in your heart. Do you feel hopeful about the days ahead now?');
    } else if (qId == 3) {
      _flutterTts.speak('I hope you feel truly accompanied, cherished, and loved. Do you feel peaceful and connected now?');
    } else if (qId == 6) {
      _flutterTts.speak('I hope listening to these peaceful songs and speaking together brought comfort and warmth to your heart. Do you feel peaceful and comforted now?');
    } else {
      _flutterTts.speak('I hope speaking together brought peace to your heart. Are you feeling more comfortable and in good spirits now?');
    }
  }

  void _handlePostInterventionAnswer(bool feelBetter) {
    if (feelBetter) {
      final isReversePolarityQ = _questions[_currentIndex].id == 4 || _questions[_currentIndex].id == 5;
      setState(() {
        _answers[_questions[_currentIndex].id] = isReversePolarityQ ? false : true;
        _showClapAnimation = true;
        _interventionStage = 0;
      });
      _clapController.forward(from: 0.0);
      final qId = _questions[_currentIndex].id;
      _flutterTts.stop();
      if (qId == 5) {
        _flutterTts.speak('Wonderful! I am so happy that you feel refreshed, motivated, and ready to enjoy engaging activities outside your room! Moving to the next question.');
      } else if (qId == 4) {
        _flutterTts.speak('Wonderful! I am so happy that you realize how truly valued and special you are, and that you feel warmly included! Moving to the next question.');
      } else if (qId == 2) {
        _flutterTts.speak('Wonderful! I am so delighted that you now feel hopeful and ready to embrace your days ahead with joy and triumph! Moving to the next question.');
      } else if (qId == 3) {
        _flutterTts.speak('Wonderful! I am so happy that you feel accompanied, cherished, and surrounded by loving care! Moving to the next question.');
      } else if (qId == 6) {
        _flutterTts.speak('Wonderful! I am so delighted that listening to these soothing songs brought peace to your heart and comforted your soul! Moving to the next question.');
      } else {
        _flutterTts.speak('Wonderful! I am so delighted that this helped you feel calm and in good spirits. Moving to the next question.');
      }
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _currentIndex < _questions.length - 1) {
          _nextQuestion();
        }
      });
    } else {
      setState(() {
        _interventionStage = 7;
        _caregiverNotified = false;
      });
      _flutterTts.stop();
      _flutterTts.speak('Your feelings are deeply important to us. Would you like me to notify your caregiver to come assist and comfort you? Please tap the button below.');
    }
  }

  void _callCaregiverForCompanionship() {
    setState(() {
      _caregiverNotified = true;
    });

    final currentQ = _questions[_currentIndex];
    final roomNumber = _currentResident.roomNo.isNotEmpty ? _currentResident.roomNo : '101';
    final elderName = _currentResident.name.isNotEmpty ? _currentResident.name : 'Senior Resident';

    // Insert rich, prioritized alert for the assigned caregiver
    MockCarevoraData.alerts.insert(
      0,
      AlertItem(
        id: 'ALT-EMO-${DateTime.now().millisecondsSinceEpoch}',
        title: '🚨 Caregiver Alert: $elderName (Room $roomNumber)',
        description:
            'Resident $elderName in Room $roomNumber expressed distress / persistent low mood during assessment question "${currentQ.prompt}". The resident requested immediate caregiver presence ("Caregiver ට මේ ගැන දන්වන්න ඕනේ").',
        severity: 'High',
        timestamp: 'Just now',
        residentName: elderName,
        roomNo: roomNumber,
        residentAge: _currentResident.age,
        residentGender: _currentResident.gender,
        currentStatus: 'Caregiver Attention Requested',
        cognitiveScore: _currentResident.cognitiveScore,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.bellRing, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Caregiver ට මේ ගැන සාර්ථකව දැනුම් දෙන ලදී! ($elderName - Room $roomNumber)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    _flutterTts.stop();
    _flutterTts.speak('Your caregiver has been notified. They are coming to Room $roomNumber to assist and comfort you shortly.');
  }

  Widget _buildSongChip(String title) {
    final isSelected = _selectedSongTitle == title;
    return ChoiceChip(
      label: Text(title, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => _startMusicIntervention(title),
      selectedColor: AppColors.primarySoft,
      backgroundColor: Colors.white,
    );
  }

  Widget _buildElderQuickChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF86EFAC)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () => _handleElderChatReply(label),
    );
  }

  Widget _buildDoctorDirectRoutingCard(AssessmentQuestion currentQ) {
    final docInfo = _getAssignedDoctorDetails();
    final doctorName = docInfo['doctorName']!;
    final doctorSpecialty = docInfo['specialty']!;
    final doctorPhone = docInfo['phone']!;
    final homeName = docInfo['home']!;
    final roomNumber = _currentResident.roomNo.isNotEmpty ? _currentResident.roomNo : '101';
    final elderName = _currentResident.name.isNotEmpty ? _currentResident.name : 'Senior Resident';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x15000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(LucideIcons.stethoscope, size: 24, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'වෛද්‍යවරයා වෙත සෘජුව යොමු කිරීම (Direct Doctor Routing)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Caregiver Rapport Escalation • Attending Physician Direct Alert',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.circleCheck, size: 14, color: Color(0xFF16A34A)),
                    SizedBox(width: 5),
                    Text(
                      'දැනුම් දෙන ලදී (Notified)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'ඔබේ රැකවරණ නිලධාරීන් (Caregivers) සමඟ අදහස් බෙදා ගැනීමට අපහසු බව පැවසූ බැවින්, මෙම වැඩිහිටි නිවාසයේ ($homeName) ප්‍රධාන වෛද්‍යවරයා ($doctorName) වෙත ඔබව සෘජුවම යොමු කරන ලදී.',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C4A6E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ඔබේ කාමර අංකය ($roomNumber) ඇතුළත් හදිසි Notification එකක් වෛද්‍යවරයාගේ Clinical Dashboard වෙත යවා ඇත. කරුණාකර සුවපහසුව සිටින්න, වෛද්‍යවරයා ඉතා ඉක්මනින් ඔබේ කාමරයට පැමිණෙනු ඇත.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0369A1),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Direct emergency clinical notification dispatched with your room number to the attending physician.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Color(0xFF0284C7),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.userCheck, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                doctorName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0C4A6E),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Assigned Doctor',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doctorSpecialty,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.building2, size: 13, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    homeName,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.doorClosed, size: 13, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Room No: $roomNumber ($elderName)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.phone, size: 13, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    doctorPhone,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(LucideIcons.bellRing, size: 15, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notification Status: Active & Dispatched to $doctorName for Room $roomNumber',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showDoctorCallDialog(doctorName, doctorSpecialty, doctorPhone, roomNumber, homeName),
                icon: const Icon(LucideIcons.phoneCall, size: 16),
                label: const Text('📞 වෛද්‍යවරයා අමතන්න (Call Doctor)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/dashboard/doctor'),
                icon: const Icon(LucideIcons.stethoscope, size: 16),
                label: const Text('🩺 වෛද්‍ය අංශය (Doctor Portal)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(LucideIcons.arrowRight, size: 16),
                label: const Text('ඊළඟ ප්‍රශ්නයට යන්න (Next Question)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationalSupportCard(AssessmentQuestion currentQ) {
    if (currentQ.id == 9 || _interventionStage == 9) {
      return _buildDoctorDirectRoutingCard(currentQ);
    }
    switch (_interventionStage) {
      case 1:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.stethoscope, size: 20, color: Color(0xFFC2410C)),
                  SizedBox(width: 8),
                  Text(
                    'AI Assistant: සෞඛ්‍ය සහ විවේක විමසුම (Health & Care Check)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9A3412)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'ඔබ බෙහෙත් බිව්වාද? ඔබට ගොඩක් අමාරුද? ඔබට වෛද්‍යවරයෙක් (Doctor) හමුවෙන්න අවශ්‍යද?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF9A3412), height: 1.35),
              ),
              const SizedBox(height: 3),
              const Text(
                'Did you take your medication? Are you in a lot of discomfort? Do you need to see a doctor?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFC2410C)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _dispatchDoctorAndCaregiverAlert,
                    icon: const Icon(LucideIcons.bellRing, size: 16),
                    label: const Text('🚨 ඔව්, දොස්තර මහත්තයෙක් (Doctor) හමුවෙන්න ඕනේ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectQuietPath,
                    icon: const Icon(LucideIcons.pill, size: 16),
                    label: const Text('💊 බෙහෙත් බිව්වා, මට නිදහසේ විවේක ගත්තාම හරි'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9A3412),
                      side: const BorderSide(color: Color(0xFFFDBA74)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectQuietPath,
                    icon: const Icon(LucideIcons.leaf, size: 16),
                    label: const Text('🌿 ගොඩක් අමාරුවක් නෑ, සිත සන්සුන් කරගත්තාම හරි'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9A3412),
                      side: const BorderSide(color: Color(0xFFFDBA74)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 2:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF87171)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.bellRing, size: 22, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text(
                    'හදිසි දැනුම්දීමක් (Emergency Alert Dispatched)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ඔබේ කාමරයේ (${_currentResident.roomNo}) රැකවරණ නිලධාරියාට (Caregiver) සහ වෛද්‍ය කණ්ඩායමට වහාම පැමිණෙන ලෙස හදිසි Notification එකක් යවන ලදී. කරුණාකර සුවපහසුව සිටින්න, ඔවුන් දැන්ම පැමිණෙනු ඇත.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF991B1B), height: 1.4),
              ),
              const SizedBox(height: 4),
              const Text(
                'Immediate alert sent to Caregiver & Doctor to attend to your room. Help is on the way.',
                style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Text(
                      'Caregiver: Nurse Seetha N. (RN) Dispatched to Room ${_currentResident.roomNo}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _startMusicIntervention('සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)'),
                    icon: const Icon(LucideIcons.music, size: 16),
                    label: const Text('ඔවුන් එනතුරු සන්සුන් සංගීතයකට සවන් දෙන්න'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => setState(() => _interventionStage = 0),
                    child: const Text('ආපසු (Back)'),
                  ),
                ],
              ),
            ],
          ),
        );

      case 3:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.sparkles, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'AI Assistant: සිත සන්සුන් කරගැනීම (Mindfulness & Calm)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'සිත සන්සුන් කරගන්න සින්දුවකට (Song) සවන් දෙන්න කැමතිද? නැත්නම් පොතක් (Book) කියවන්න කැමතිද?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.35),
              ),
              const SizedBox(height: 3),
              const Text(
                'Would you like to listen to a soothing song or read a book to calm your mind?',
                style: TextStyle(fontSize: 12, color: AppColors.body),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _startMusicIntervention('සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lilac, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: const [
                            Icon(LucideIcons.music, size: 28, color: AppColors.primary),
                            SizedBox(height: 8),
                            Text(
                              '🎵 සින්දුවක් අහන්න',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                            ),
                            SizedBox(height: 2),
                            Text('Listen to a Song', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: _startBookIntervention,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lilac, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: const [
                            Icon(LucideIcons.bookOpen, size: 28, color: Color(0xFF0D9488)),
                            SizedBox(height: 8),
                            Text(
                              '📖 පොතක් කියවන්න',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                            ),
                            SizedBox(height: 2),
                            Text('Read a Book', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 4:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC4B5FD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.music, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'සන්සුන් සංගීත චිකිත්සාව (Acoustic Relaxation)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isPlayingMusic ? '🎶 ධාවනය වෙමින්...' : '⏸️ විරාමය',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildSongChip('නන්දා මාලිනී - නිවන් දොරටු පාමුල (Nanda Malini)'),
                  _buildSongChip('නන්දා මාලිනී - රන්කෙන්දෙන් බැඳි අතැඟිලි (Nanda Malini)'),
                  _buildSongChip('නන්දා මාලිනී - සාර සොඳුරු මල් පිපී (Nanda Malini)'),
                  _buildSongChip('ආචාර්ය ඩබ්.ඩී. අමරදේව - ශාන්ත සන්ධ්‍යාව'),
                  _buildSongChip('සෙත් පිරිත් සජ්ඣායනය (Seth Pirith Deshana - 15 Mins)'),
                  _buildSongChip('සන්සුන් වස්දඬු රාවය (Acoustic Bamboo Flute - Was Dadu Rawaya)'),
                  _buildSongChip('සුනිල් එදිරිසිංහ - නිවන් දුටු හිමි (Sunil Edirisinghe)'),
                  _buildSongChip('වික්ටර් රත්නායක - සිත නිවන සෙවන (Victor Ratnayake)'),
                  _buildSongChip('සොබාදහමේ සන්සුන් නාදය (Peaceful Nature Streams)'),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lilac),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isPlayingMusic ? LucideIcons.pause : LucideIcons.play, size: 24, color: AppColors.primary),
                      onPressed: _toggleMusicPlayback,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedSongTitle,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(16, (i) {
                              final barHeight = _isPlayingMusic ? 6.0 + ((i * 7 + _songPlaybackSeconds * 5) % 18) : 6.0;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 3,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_songPlaybackSeconds ~/ 60}:${(_songPlaybackSeconds % 60).toString().padLeft(2, '0')} / ${_currentMusicDurationSeconds ~/ 60}:${(_currentMusicDurationSeconds % 60).toString().padLeft(2, '0')} (මිනිත්තු ${_currentMusicDurationSeconds ~/ 60})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _finishMusicIntervention,
                  icon: const Icon(LucideIcons.checkCheck, size: 18),
                  label: const Text(
                    '✨ අහලා ඉවරයි (Finished Listening - Check How I Feel)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );

      case 5:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF99F6E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.bookOpen, size: 20, color: Color(0xFF0D9488)),
                  SizedBox(width: 8),
                  Text(
                    'සන්සුන් කියවීම් අංශය (Serene Reading Corner)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCCFBF1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '📖 ජාතක කතා සහ බුද්ධ ධර්මයේ සැනසිලිදායක සිතිවිලි',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '"සිත නිශ්චල වූ විට සියලු කරදර පහව යයි. ගලා යන ගංගාවක් සේ ජීවිතයේ සෑම මොහොතක්ම සැනසීමෙන් සහ ඉවසීමෙන් විඳගන්න. අද දිනයද ඔබට සුවය සහ සාමය ගෙන දෙනු ඇත..."',
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF134E4A), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _startMusicIntervention('සන්සුන් බෞද්ධ පිරිත් සහ ගාථා (Buddhist Pirith Chants)'),
                    icon: const Icon(LucideIcons.music, size: 16),
                    label: const Text('සින්දුවක් අහන්න කැමතිද?'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _finishBookIntervention,
                    icon: const Icon(LucideIcons.checkCheck, size: 16),
                    label: const Text('✨ කියවා අවසන් (Done Reading)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 6:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA5B4FC), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.sparkles, size: 20, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text(
                    'AI Re-evaluation: මනෝභාවය නැවත විමසීම',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                currentQ.id == 6
                    ? 'දැන් ඔබට තනිකම හා පාළුව පහව ගොස්, සිතට සැනසීමක් සහ සතුටක් දැනෙනවාද?'
                    : (currentQ.id == 5
                        ? 'දැන් ඔබට කම්මැලිකම හා මානසික පීඩනය පහව ගොස්, ක්‍රියාශීලී වීමට ප්‍රබෝධයක් දැනෙනවාද?'
                        : (currentQ.id == 4
                            ? 'දැන් ඔබට කොන් වූ හැඟීම පහව ගොස්, ඔබ අතිශයින්ම වටිනා කෙනෙක් බව සහ සිතට සැනසීමක් දැනෙනවාද?'
                            : (currentQ.id == 3
                                ? 'දැන් ඔබට තනිකම පහව ගොස්, සිතට සතුටක් සහ සැනසීමක් දැනෙනවාද?'
                                : (currentQ.id == 2
                                    ? 'දැන් ඔබට ඉදිරි දින පිළිබඳව නව බලාපොරොත්තුවක් සහ සතුටක් දැනෙනවාද?'
                                    : 'දැන් ඔබට සිතට සතුටක් සහ සැනසීමක් දැනෙනවාද?')))),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
              ),
              const SizedBox(height: 2),
              Text(
                currentQ.id == 6
                    ? 'Do you feel comforted, relieved of loneliness, and peaceful in good spirits now?'
                    : (currentQ.id == 5
                        ? 'Do you feel refreshed, relieved of boredom, and motivated to engage in activities now?'
                        : (currentQ.id == 4
                            ? 'Do you feel valued, respected, and peacefully included now?'
                            : (currentQ.id == 3
                                ? 'Do you feel accompanied, cared for, and in good spirits now?'
                                : (currentQ.id == 2
                                    ? 'Do you feel hopeful and in good spirits about the days ahead now?'
                                    : 'Are you feeling peaceful and in good spirits now?')))),
                style: const TextStyle(fontSize: 13, color: Color(0xFF4338CA)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _handlePostInterventionAnswer(true),
                    icon: const Icon(LucideIcons.smile, size: 18),
                    label: Text(
                      currentQ.id == 6
                          ? 'Yes / ඔව්, තනිකම පහව ගියා, සිත සන්සුන්'
                          : (currentQ.id == 5
                              ? 'Yes / ඔව්, මනස ප්‍රබෝධමත්, ක්‍රියාකාරකම්වලට සූදානම්'
                              : (currentQ.id == 4
                                  ? 'Yes / ඔව්, මම වටිනා කෙනෙක්, දැන් සතුටුයි'
                                  : (currentQ.id == 3
                                      ? 'Yes / ඔව්, දැන් තනිකමක් නෑ, සතුටුයි'
                                      : (currentQ.id == 2
                                          ? 'Yes / ඔව්, ඉදිරිය ගැන බලාපොරොත්තු සහගතයි'
                                          : 'Yes / ඔව්, දැන් සතුටුයි')))),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _handlePostInterventionAnswer(false),
                    icon: const Icon(LucideIcons.frown, size: 18),
                    label: const Text('No / තවමත් නැහැ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 7:
        final roomNumber = _currentResident.roomNo.isNotEmpty ? _currentResident.roomNo : '101';
        final elderName = _currentResident.name.isNotEmpty ? _currentResident.name : 'Senior Resident';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.bellRing, size: 18, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI Caregiver Dispatch Assistance • රැකවරණ නිලධාරී දැනුම්දීම',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                  ),
                  if (_caregiverNotified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.circleCheck, size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'දැනුම් දෙන ලදී (Notified)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'ඔබට තවමත් සිතට සැනසීමක් හෝ සතුටක් දැනෙන්නේ නැද්ද? රැකවරණ නිලධාරියාට (Caregiver) මේ ගැන දැනුම් දෙන්න අවශ්‍යද?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF991B1B), height: 1.35),
              ),
              const SizedBox(height: 3),
              const Text(
                'Are you still not feeling at ease? Would you like to notify your assigned caregiver to come assist and comfort you?',
                style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
              const SizedBox(height: 16),

              if (_caregiverNotified) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.circleCheck, color: Color(0xFF16A34A), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✓ $elderName වෙනුවෙන් Caregiver ට මේ ගැන සාර්ථකව දැනුම් දුන්නා!',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'අදාළ හෙද/රැකවරණ නිලධාරියා (Nurse Seetha N. / RN) මොහොතකින් කාමර අංක $roomNumber වෙත පැමිණෙනු ඇත.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _caregiverNotified ? null : _callCaregiverForCompanionship,
                    icon: Icon(
                      _caregiverNotified ? LucideIcons.circleCheck : LucideIcons.bellRing,
                      size: 18,
                    ),
                    label: Text(
                      _caregiverNotified
                          ? '✓ Caregiver ට දැනුම් දෙන ලදී'
                          : '🚨 Caregiver ට මේ ගැන දන්වන්න ඕනේ',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _caregiverNotified ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      disabledBackgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: _caregiverNotified ? 0 : 2,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: const Icon(LucideIcons.arrowRight, size: 16),
                    label: const Text(
                      'ඊළඟ ප්‍රශ්නයට යන්න (Next Question)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _caregiverNotified ? AppColors.primary : Colors.white,
                      foregroundColor: _caregiverNotified ? Colors.white : const Color(0xFF374151),
                      side: BorderSide(
                        color: _caregiverNotified ? AppColors.primary : const Color(0xFFD1D5DB),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 8:
        final progress = (_conversationSeconds / _conversationTotalSeconds).clamp(0.0, 1.0);
        final elapsedMinutes = (_conversationSeconds ~/ 60).toString().padLeft(2, '0');
        final elapsedSeconds = (_conversationSeconds % 60).toString().padLeft(2, '0');
        final totalMinutes = (_conversationTotalSeconds ~/ 60).toString().padLeft(2, '0');
        final totalSecs = (_conversationTotalSeconds % 60).toString().padLeft(2, '0');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.messageCircleHeart, size: 20, color: Color(0xFF15803D)),
                      const SizedBox(width: 8),
                      Text(
                        currentQ.id == 6
                            ? 'AI Assistant: සිත නිවන ගීතමය සැනසුම සහ සුහද සංවාදය (Heart-to-Heart Talk)'
                            : (currentQ.id == 5
                                ? 'AI Assistant: කාමරයෙන් බැහැරව ප්‍රබෝධමත් ක්‍රියාකාරකම් සහ සුවතාවය (Active Wellness)'
                                : (currentQ.id == 4
                                    ? 'AI Assistant: ඔබ අතිශයින්ම වටිනා කෙනෙක් - ගෞරවය සහ රැකවරණය (You Are Deeply Valued)'
                                    : (currentQ.id == 3
                                        ? 'AI Assistant: ඔබ කිසිවිටෙකත් තනිවී නැහැ - සුහද මිත්‍රත්වය (Loving Companionship)'
                                        : (currentQ.id == 2
                                            ? 'AI Assistant: ඉදිරි දින පිළිබඳ නව බලාපොරොත්තු සහ ජයග්‍රාහී සුහද සංවාදය'
                                            : 'AI Assistant: සිත නිවන සුහද සංවාදය (Heart-to-Heart Talk)')))),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      '⏱️ $elapsedMinutes:$elapsedSeconds / $totalMinutes:$totalSecs',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFDCFCE7),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(height: 12),
              // In-Chat Active Music Player Bar (Plays for 10 minutes)
              if (_isPlayingMusic) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isPlayingMusic ? LucideIcons.pauseCircle : LucideIcons.playCircle, size: 26, color: const Color(0xFF15803D)),
                        onPressed: _toggleMusicPlayback,
                        tooltip: _isPlayingMusic ? 'විරාමය (Pause)' : 'ධාවනය (Resume)',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('🎶 ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    _selectedSongTitle,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Row(
                                  children: List.generate(14, (i) {
                                    final barHeight = _isPlayingMusic ? 4.0 + ((i * 5 + _songPlaybackSeconds * 4) % 14) : 4.0;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1.2),
                                      width: 2.8,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(_songPlaybackSeconds ~/ 60).toString().padLeft(2, '0')}:${(_songPlaybackSeconds % 60).toString().padLeft(2, '0')} / ${(_currentMusicDurationSeconds ~/ 60).toString().padLeft(2, '0')}:${(_currentMusicDurationSeconds % 60).toString().padLeft(2, '0')} (මිනිත්තු ${_currentMusicDurationSeconds ~/ 60})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () {
                          _songTimer?.cancel();
                          AudioPlayerService.instance.stop();
                          setState(() {
                            _isPlayingMusic = false;
                          });
                        },
                        icon: const Icon(LucideIcons.square, size: 12, color: Color(0xFFDC2626)),
                        label: const Text('නවත්වන්න', style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Interactive Chat Scroll Container
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: ListView.builder(
                  controller: _aiChatScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _aiConversationMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _aiConversationMessages[index];
                    final isAi = msg['isAi'] == true;
                    if (isAi) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.bot, size: 14, color: Color(0xFF15803D)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    msg['title'] ?? 'AI සහායක',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                                  ),
                                ),
                                if (msg['badge'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      msg['badge']!,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              msg['sinhala'] ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF166534), height: 1.45),
                            ),
                            if (msg['english'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                msg['english']!,
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF15803D)),
                              ),
                            ],
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                _flutterTts.stop();
                                _flutterTts.speak(msg['english'] ?? msg['sinhala'] ?? '');
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(LucideIcons.volume2, size: 13, color: Color(0xFF15803D)),
                                  SizedBox(width: 4),
                                  Text(
                                    'හඬින් අහන්න (Listen)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                            ),
                            if (msg['suggestedSongs'] != null && (msg['suggestedSongs'] as List).isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: const [
                                  Icon(LucideIcons.music, size: 13, color: Color(0xFF15803D)),
                                  SizedBox(width: 5),
                                  Text(
                                    'සන්සුන් ගීත, පිරිත් හා වස්දඬු රාවය (Select Song 5m / Pirith 15m / Was Dadu Rawaya):',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (msg['suggestedSongs'] as List).map<Widget>((songTitle) {
                                  final titleStr = songTitle.toString();
                                  final isSelected = _selectedSongTitle == titleStr && _isPlayingMusic;
                                  return ActionChip(
                                    avatar: Icon(
                                      isSelected ? LucideIcons.volume2 : LucideIcons.play,
                                      size: 13,
                                      color: isSelected ? Colors.white : const Color(0xFF15803D),
                                    ),
                                    label: Text(
                                      titleStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? Colors.white : const Color(0xFF14532D),
                                      ),
                                    ),
                                    backgroundColor: isSelected ? const Color(0xFF16A34A) : Colors.white,
                                    side: BorderSide(color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF86EFAC)),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    onPressed: () => _playSongInAiChat(titleStr),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    } else {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12, left: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  msg['sinhala'] ?? '',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.user, size: 15, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'ඔබට දැනෙන දේ පහසුවෙන් තෝරන්න (Tap how you feel):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: currentQ.id == 5
                    ? [
                        _buildElderQuickChip('🥱 කාමරේ ඉඳලා මට කම්මැලියි, අලස ගතියක් තියෙනවා (Feeling Bored & Sluggish)'),
                        _buildElderQuickChip('🌿 ගෙවත්තට ගිහින් නැවුම් වාතය විඳින්න ආසයි (Want Garden Stroll & Fresh Air)'),
                        _buildElderQuickChip('📚 කියවන්න රසවත් පොතක් හෝ පත්තරයක් ඕනෙ (Need a Book/Magazine to Read)'),
                        _buildElderQuickChip('☕ සවස තේ බොන වෙලාවට මිතුරන් හමුවෙන්න කැමතියි (Join Afternoon Tea Circle)'),
                        _buildElderQuickChip('🎨 මනස සැහැල්ලු කරන විනෝදාංශයක් හෝ ක්‍රීඩාවක් කරන්න ආසයි (Want Fun Hobbies/Games)'),
                        _buildElderQuickChip('💆‍♂️ එකම තැන ඉඳලා ඇති වූ මානසික පීඩනය නැති කරන්න (Relieve Room Stress & Heaviness)'),
                      ]
                    : (currentQ.id == 4
                        ? [
                            _buildElderQuickChip('💔 මට අන් අය මාව නොසලකා හරිනවා වගේ දැනෙනවා (Feel Ignored / Left Out)'),
                            _buildElderQuickChip('🕊️ මට කතාබහට මැදිහත් වෙන්න ලැජ්ජයි හෝ පැකිලෙනවා (Hesitant to Join In)'),
                            _buildElderQuickChip('🌟 මම ඉතා වටිනා කෙනෙක් බව මට මතක් කර දෙන්න (Remind Me of My True Value)'),
                            _buildElderQuickChip('🤝 මාවත් ආදරයෙන් එක් කරගන්නවාට මම කැමතියි (Want to Feel Warmly Included)'),
                            _buildElderQuickChip('🌸 AI සහායක, මගේ සිතේ තියෙන බර සැහැල්ලු කරන්න (Soothe My Heavy Heart)'),
                            _buildElderQuickChip('☀️ සතුටින් සහ ආත්ම විශ්වාසයෙන් ඉන්න මඟපෙන්වීමක් ඕනෙ (Need Advice for Self-Confidence)'),
                          ]
                        : (currentQ.id == 2
                            ? [
                                _buildElderQuickChip('🌅 ඉදිරිය ගැන බයක් සහ අවිනිශ්චිත බවක් තියෙනවා (Uncertain Future)'),
                                _buildElderQuickChip('🕊️ මට තව කරන්න දෙයක් නෑ වගේ දැනෙනවා (Feeling Aimless)'),
                                _buildElderQuickChip('☀️ නැවත සතුටින් හිනාවෙලා ඉන්න ආසයි (Want to Feel Joy Again)'),
                                _buildElderQuickChip('🏆 ජීවිතය ජයගන්න හිත ශක්තිමත් කරගන්න ඕනෙ (Need Strength to Win)'),
                                _buildElderQuickChip('🌸 ඉදිරියට අලුත් බලාපොරොත්තුවක් අවශ්‍යයි (Need Fresh Hope)'),
                                _buildElderQuickChip('🤝 මගේ අනාගතයට ආදරණීය සහයෝගය ඕනෙ (Need Caring Support)'),
                              ]
                            : (currentQ.id == 3
                                ? [
                                    _buildElderQuickChip('🎵 අමරදේවයන්ගේ \'ශාන්ත සන්ධ්‍යාව\' අහන්න කැමතියි (Listen to Amaradeva)'),
                                    _buildElderQuickChip('🎵 නන්දා මාලිනියන්ගේ \'නිවන් දොරටු පාමුල\' අහන්න කැමතියි (Listen to Nanda Malini)'),
                                    _buildElderQuickChip('🏡 මෙහි මට කතාබහ කරන්න කවුරුත් නෑ වගේ දැනෙනවා (Feel Like No One to Talk To)'),
                                    _buildElderQuickChip('💬 මගේ සිතේ තියෙන දේ බෙදාගන්න හොඳ මිතුරෙක් ඕනෙ (Need a Close Confidant)'),
                                    _buildElderQuickChip('🌸 AI සහායක, ඔබ මා ළඟින් සිටීම මට ලොකු සතුටක් (Glad You Are Here with Me)'),
                                    _buildElderQuickChip('✨ තනිකම දුරු කරගෙන සතුටින් ඉන්න මඟපෙන්වීමක් ඕනෙ (Need Guidance to Overcome Loneliness)'),
                                  ]
                                : (currentQ.id == 6
                                    ? [
                                        _buildElderQuickChip('🎵 අමරදේවයන්ගේ \'ශාන්ත සන්ධ්‍යාව\' අහන්න කැමතියි (Listen to Amaradeva)'),
                                        _buildElderQuickChip('🎵 නන්දා මාලිනියන්ගේ \'නිවන් දොරටු පාමුල\' අහන්න කැමතියි (Listen to Nanda Malini)'),
                                        _buildElderQuickChip('👨‍👩‍👧‍👦 මාව බලන්න කවුරුත් නෑ, පවුල මතක් වෙනවා (No Visitors / Miss Family)'),
                                        _buildElderQuickChip('🏡 කතාබහ කරන්න කවුරුත් නෑ, තනිකම දැනෙනවා (No One to Talk To / Lonely)'),
                                        _buildElderQuickChip('🌸 AI සහායක, ඔබ මා ළඟින් සිටීම ලොකු සතුටක් (Glad You Are With Me)'),
                                        _buildElderQuickChip('💖 සිතට සතුටක් සහ සැනසීමක් අවශ්‍යයි (Need Peace)'),
                                      ]
                                    : [
                                        _buildElderQuickChip('👨‍👩‍👧‍👦 දරුවන් සහ පවුල මතක් වෙනවා (Miss Family)'),
                                        _buildElderQuickChip('🏡 තනිකම සහ පාළුව දැනෙනවා (Feel Lonely)'),
                                        _buildElderQuickChip('🌧️ සිතට දුකක් සහ බරක් තියෙනවා (Feeling Sad)'),
                                        _buildElderQuickChip('🕊️ සිතට බයක් සහ චකිතයක් තියෙනවා (Anxious)'),
                                        _buildElderQuickChip('🩺 ඇඟට අමාරු නිසා නොසන්සුන් (Physical Discomfort)'),
                                        _buildElderQuickChip('🌸 සිතට සතුටක් සහ සැනසීමක් අවශ්‍යයි (Need Peace)'),
                                      ])))),
              ),
              const SizedBox(height: 10),
              // Typing and Speech input bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isAiChatVoiceRecording ? LucideIcons.square : LucideIcons.mic,
                        size: 18,
                        color: _isAiChatVoiceRecording ? Colors.red : const Color(0xFF15803D),
                      ),
                      tooltip: _isAiChatVoiceRecording ? 'නැවැත්වීමට ඔබන්න' : 'හඬින් පවසන්න (Speak)',
                      onPressed: _toggleAiChatVoiceRecording,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _aiChatInputController,
                        style: const TextStyle(fontSize: 13, color: AppColors.navy),
                        decoration: const InputDecoration(
                          hintText: 'ඔබේ සිතේ ඇති දේ මෙහි ලියන්න... / Type what you feel...',
                          hintStyle: TextStyle(fontSize: 12, color: AppColors.muted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onSubmitted: (val) => _handleElderChatReply(val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.send, size: 18, color: Color(0xFF16A34A)),
                      tooltip: 'යවන්න (Send)',
                      onPressed: () => _handleElderChatReply(_aiChatInputController.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI සහායක ඔබ වෙනුවෙන් සවන් දෙමින් කතාබහ කරයි...',
                    style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _finishAiConversationIntervention,
                    icon: const Icon(LucideIcons.heartHandshake, size: 16),
                    label: Text(
                      currentQ.id == 6
                          ? '✨ සිත සන්සුන් විය, ගීතයට සවන් දුන්නා (Feeling Soothed & Peaceful)'
                          : (currentQ.id == 5
                              ? '🌿 ප්‍රබෝධවත් විය, ක්‍රියාකාරකම්වලට එක්වෙමි (Feeling Refreshed & Active)'
                              : (currentQ.id == 4
                                  ? '🌟 මම වටිනා කෙනෙක් බව වැටහුණා (Feeling Valued & Respected)'
                                  : (currentQ.id == 3
                                      ? '🤝 තනිකම දුරු විය, සිත සතුටුයි (Feeling Connected & Accompanied)'
                                      : (currentQ.id == 2
                                          ? '🏆 නව බලාපොරොත්තු ඇති විය (Feeling Hopeful & Victorious)'
                                          : '✨ සිත සන්සුන් විය (Feeling Soothed)')))),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.heartHandshake, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Text(
                    'AI Assistant',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                currentQ.id == 5
                    ? 'ඔබ දවසෙන් වැඩි කාලයක් කාමරය තුළ ගත කරන්නේ නම්, මා සමඟ කතාබහ කර කම්මැලිකම දුරු කරන ප්‍රබෝධමත් ක්‍රියාකාරකම් සැලසුම් කරගන්න.'
                    : (currentQ.id == 4
                        ? 'අන් අය එකතු වී සිටින විට ඔබට තනි වූ හෝ කොන් වූ බවක් දැනේ නම්, මා සමඟ කතාබහ කර ඔබේ සිතේ වටිනාකම සහ සැනසීම තහවුරු කරගන්න.'
                        : (currentQ.id == 3
                            ? 'මෙහි සමීපව කතාබහ කිරීමට කෙනෙකු නැති බව දැනේ නම්, මා සමඟ කතාබහ කර ඔබේ සිතේ තනිකම දුරු කරගන්න.'
                            : (currentQ.id == 2
                                ? 'ඉදිරි දින ගැන ඔබේ සිතේ බලාපොරොත්තු අඩු වී ඇත්නම්, අපි කතාබහ කර ඔබේ හදවතට නව ජයග්‍රාහී බලාපොරොත්තුවක් එක් කරමු.'
                                : 'මට ඒ ගැන කණගාටුයි. ඔබට අද එසේ දැනෙන්න හේතුව මට කියන්න හෝ මෙහි ලියන්න පුළුවන්ද?'))),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF92400E), height: 1.35),
              ),
              const SizedBox(height: 2),
              Text(
                currentQ.id == 5
                    ? 'If you spend most of your day alone in your room, let us talk to explore refreshing activities and beat boredom.'
                    : (currentQ.id == 4
                        ? 'If you feel left out when others gather around, let us talk and remind your heart how deeply valuable and cherished you are.'
                        : (currentQ.id == 3
                            ? 'If you feel you lack a close friend to talk with here, let us talk and bring warmth and comfort to your heart.'
                            : (currentQ.id == 2
                                ? 'If you feel uncertain about your upcoming days, let us talk to bring victorious and joyful hope to your heart.'
                                : 'I am sorry to hear that. Could you tell me or type what is making you feel this way?'))),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFB45309)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: TextField(
                  controller: _reasonTextController,
                  maxLines: 2,
                  onChanged: (val) {
                    setState(() {
                      _elderNegativeReasons[currentQ.id] = val;
                    });
                    _detectKeywordsInReason(val);
                  },
                  style: const TextStyle(fontSize: 13, color: AppColors.navy),
                  decoration: const InputDecoration(
                    hintText: 'ඔබට එසේ දැනෙන්න හේතුව මෙහි ටයිප් කරන්න... / Type why you feel this way...',
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.muted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _toggleReasonVoiceRecording,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isRecordingReason ? AppColors.riskHigh : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isRecordingReason ? LucideIcons.square : LucideIcons.mic,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRecordingReason ? 'සවන් දෙමින්... (නැවැත්වීමට ඔබන්න)' : '🎙️ හඬින් පවසන්න (Speak Reason)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if ((_elderNegativeReasons[currentQ.id] ?? '').trim().isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(LucideIcons.checkCheck, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'හේතුව සටහන් විය (Saved)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'නැතහොත් පහතින් පහසු විකල්පයක් තෝරන්න (Or choose below):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: Text(currentQ.id == 5 ? '🌿' : (currentQ.id == 4 ? '🌟' : (currentQ.id == 3 ? '🤝' : (currentQ.id == 2 ? '🌅' : '💬')))),
                    label: Text(
                      currentQ.id == 5
                          ? '🌿 කාමරයේ කම්මැලිකම දුරු කර ප්‍රබෝධමත් වෙන්න කතාබහ කරමු (Talk for Active Refreshment)'
                          : (currentQ.id == 4
                              ? '🌟 ඔබ ඉතා වටිනා කෙනෙක් බව වටහාගන්න කතාබහ කරමු (Talk to Realize Your Value)'
                              : (currentQ.id == 3
                                  ? '🤝 මා සමඟ කතාබහ කර තනිකම දුරු කරගන්න (Talk to Beat Loneliness)'
                                  : (currentQ.id == 2
                                      ? '🌅 නව බලාපොරොත්තු සහ ජයග්‍රාහී සිතුවිලි සඳහා කතාබහ කරමු (Talk for Renewed Hope)'
                                      : 'ඔබ මාත් එක්ක කතා කරන්න කැමතිද? (Talk with me)'))),
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: (currentQ.id == 2 || currentQ.id == 3 || currentQ.id == 4 || currentQ.id == 5) ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD)),
                    onPressed: _startAiConversationIntervention,
                  ),
                  ActionChip(
                    avatar: const Text('🌿'),
                    label: const Text('මට ටිකක් නිදහසේ ඉන්න ඕනෙ (Just need quiet/peace)'),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFC4B5FD)),
                    onPressed: _selectQuietPath,
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _buildClapOverlayAnimation() {
    // Beautiful shower of small, joyful clapping hands (clap emojis only)
    const particleCount = 28;
    return AnimatedBuilder(
      animation: _clapController,
      builder: (context, child) {
        final progress = _clapController.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: List.generate(particleCount, (index) {
              // Evenly spread across the card width (-0.92 to 0.92)
              final ratio = index / (particleCount - 1);
              final xBase = -0.92 + (ratio * 1.84);
              // Gentle wave oscillation for smooth natural floating
              final wave = 0.04 * math.sin((progress * 6.28) + (index * 0.8));
              final xAlign = (xBase + wave).clamp(-1.0, 1.0);

              // Staggered launch delays so claps float up in a continuous stream
              final delay = (index % 6) * 0.06 + ((index * 7) % 13) * 0.012;
              final speedMultiplier = 1.15 + ((index % 5) * 0.08);
              final particleProgress = ((progress * speedMultiplier) - delay).clamp(0.0, 1.0);

              // Float gracefully from bottom (1.05) to above the card (-1.25)
              final yStart = 1.05;
              final yEnd = -1.25;
              final yCurrent = yStart + (yEnd - yStart) * math.pow(particleProgress, 0.88);

              // Smooth fade-in, vibrant visibility, gentle fade-out at the top
              final opacity = (particleProgress <= 0.0 || particleProgress >= 1.0)
                  ? 0.0
                  : (particleProgress < 0.15
                      ? (particleProgress / 0.15)
                      : (particleProgress > 0.72
                          ? ((1.0 - particleProgress) / 0.28).clamp(0.0, 1.0)
                          : 1.0));

              // Small, delicate, beautiful clap emoji size (15px to 21px)
              final fontSize = 15.0 + (index % 4) * 2.0; // 15, 17, 19, 21

              return Align(
                alignment: Alignment(xAlign, yCurrent),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    '👏',
                    style: TextStyle(
                      fontSize: fontSize,
                      shadows: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  void _updateQuestionContext() {
    final q = _questions[_currentIndex];
    final ans = _answers[q.id];
    _showClapAnimation = false;
    _reasonTextController.text = _elderNegativeReasons[q.id] ?? '';
    _interventionStage = 0;
    _isPlayingMusic = false;
    _songTimer?.cancel();
    AudioPlayerService.instance.stop();
    _conversationTimer?.cancel();
    _conversationSeconds = 0;
    _aiConversationMessages.clear();
    _caregiverNotified = false;

    switch (q.id) {
      case 1:
        _spokenText = ans == false
            ? "No, I felt a little low and tired when waking up today."
            : "Yes, I had a good night's rest and feel quite peaceful today.";
        break;
      case 2:
        _spokenText = ans == false
            ? "No, sometimes it is hard to look forward to tomorrow."
            : "Yes, I feel hopeful and look forward to our weekend visits.";
        break;
      case 3:
        _spokenText = ans == false
            ? "No, I haven't found anyone here I feel really close with."
            : "Yes, I have two dear companions here at our tea table.";
        break;
      case 4:
        _spokenText = ans == true
            ? "Yes, sometimes in the evenings even when people are around, I feel alone in my thoughts."
            : "No, I feel warmly included when others gather in the lounge.";
        break;
      case 5:
        _spokenText = ans == true
            ? "Yes, I find myself staying alone in my room resting for most of the day."
            : "No, I like coming out to the garden or hallway in the afternoon.";
        break;
      case 6:
        _spokenText = ans == false
            ? "No, my relatives are far away and rarely call or visit."
            : "Yes, my son and grandchildren call me every couple of days.";
        break;
      case 7:
        _spokenText = ans == false
            ? "No, I usually prefer sitting quietly on the side during group activities."
            : "Yes, I enjoy taking part in the morning tea and light movements.";
        break;
      case 8:
        _spokenText = ans == true
            ? "Yes, having an attendant or companion walk with me gives me confidence."
            : "No, I prefer my own quiet routine right now.";
        break;
      case 9:
        _spokenText = ans == false
            ? "No, I hesitate because the nurses always seem so busy."
            : "Yes, the care staff always listen with patience when I speak.";
        break;
      case 10:
        _spokenText = ans == true
            ? "Yes, listening to soothing Buddhist pirith chants brings me deep calm."
            : "No, I haven't tried listening to calming music lately.";
        break;
      default:
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

  int _resolveBackendResidentId() {
    final authState = ref.read(authProvider).state;
    if (authState.isElder && authState.residentId != null) {
      return authState.residentId!;
    }
    final parsed = int.tryParse(_currentResident.id);
    if (parsed != null) {
      if (parsed == 9002 || _currentResident.name.contains('Sarah')) return 1;
      if (parsed == 9003 || _currentResident.name.contains('Arthur')) return 2;
      if (parsed == 9004 || _currentResident.name.contains('Margaret')) return 3;
      return parsed;
    }
    if (authState.residentId != null) {
      return authState.residentId!;
    }
    return 1;
  }

  void _showEndAssessmentDialog() {
    if (_isRecording) {
      _toggleRecording();
    }
    final allAnswered = EmotionalAssessmentService.areAllQuestionsAnswered(_answers);
    final missingQuestions = EmotionalAssessmentService.getUnansweredQuestions(_answers);
    final calculatedWellness = EmotionalAssessmentService.calculateWellnessScore(_answers);
    final calculatedRisk = EmotionalAssessmentService.calculateLonelinessRiskScore(calculatedWellness);

    final riskTier = calculatedRisk >= 65.0
        ? 'High Risk'
        : (calculatedRisk >= 40.0 ? 'Moderate Risk' : 'Low Risk');
    final riskColor = calculatedRisk >= 65.0
        ? AppColors.riskHigh
        : (calculatedRisk >= 40.0 ? AppColors.riskModerate : AppColors.riskLow);

    // Multimodal signals from session
    final facialAggregate = _facialCaptureService.aggregate;
    final bool hasFacialInference = facialAggregate.validCount > 0;
    final String dominantFaceEmotion = hasFacialInference
        ? facialAggregate.dominantEmotion.toUpperCase()
        : (_capturedImageBytes != null ? 'OBSERVED' : 'NONE');
    final double? facialConf = hasFacialInference ? facialAggregate.averageConfidence : null;

    double? facialScore;
    if (hasFacialInference) {
      final domLower = facialAggregate.dominantEmotion.toLowerCase();
      if (['happy', 'surprise'].contains(domLower)) {
        facialScore = 85.0;
      } else if (domLower == 'neutral') {
        facialScore = 75.0;
      } else {
        facialScore = 40.0;
      }
    }

    final bool hasVoiceSession = _recordSeconds > 0;
    final double? vocalScore = hasVoiceSession ? _vocalWellnessScore : null;

    showDialog(
      context: context,
      barrierDismissible: !_isSubmittingAssessment,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  allAnswered ? LucideIcons.clipboardCheck : LucideIcons.alertTriangle,
                  color: allAnswered ? AppColors.primary : AppColors.riskModerate,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    allAnswered ? 'Assessment Summary & Submission' : 'Incomplete Assessment Warning',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resident & Session header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.user, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Resident: ${_currentResident.name} (ID: ${_resolveBackendResidentId()})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: allAnswered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              allAnswered ? 'Validated 10/10' : 'Incomplete (${10 - missingQuestions.length}/10)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: allAnswered ? const Color(0xFF166534) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (!allAnswered) ...[
                      // Incomplete warning container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF97316)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(LucideIcons.alertCircle, color: Color(0xFFF97316), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Missing Questionnaire Responses',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2410C), fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'All 10 standardized questions must be completed before submitting. Tap any question below to jump directly to it:',
                              style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: missingQuestions.map((qNum) {
                                return ActionChip(
                                  avatar: const Icon(LucideIcons.arrowRightCircle, size: 16, color: Color(0xFFC2410C)),
                                  label: Text('Question $qNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9A3412))),
                                  backgroundColor: const Color(0xFFFFEDD5),
                                  side: const BorderSide(color: Color(0xFFFDBA74)),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    setState(() {
                                      _currentIndex = qNum - 1;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: const [
                            Icon(LucideIcons.lock, size: 18, color: AppColors.muted),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Provisional scoring and submission are locked until all 10 questions are answered.',
                                style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Validated Complete Assessment Summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Clinical Scores', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Questionnaire Wellness Score:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(
                                  '${calculatedWellness.toStringAsFixed(1)}% (Higher is Better)',
                                  style: const TextStyle(color: AppColors.riskLow, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Loneliness Risk:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text('Questionnaire inverse proxy (non-diagnostic)', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                                  ],
                                ),
                                Text(
                                  '${calculatedRisk.toStringAsFixed(1)}% ($riskTier)',
                                  style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Social-Isolation Risk:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text('Requires caregiver social audit', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                                  ],
                                ),
                                if (_currentResident.socialScore != null)
                                  Text(
                                    '${(100.0 - _currentResident.socialScore!).toStringAsFixed(1)}%',
                                    style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Unassessed (No Staff Audit)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Multimodal Sensor & AI Modality Breakdown
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
                            const Text('Multimodal AI Inferences', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            const Divider(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.camera, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasFacialInference
                                            ? 'Facial Affect: $dominantFaceEmotion (${(facialConf! * 100).toStringAsFixed(1)}% conf)'
                                            : 'Facial Affect: Camera active (FER-2013 ready)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        hasFacialInference
                                            ? '${facialAggregate.validCount} valid frames analyzed via PyTorch CNN'
                                            : 'No valid facial frame captured or consent not granted',
                                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: hasFacialInference ? const Color(0xFFDCFCE7) : AppColors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    hasFacialInference ? 'Inferred' : 'Standby',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: hasFacialInference ? const Color(0xFF166534) : AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.mic, size: 16, color: AppColors.accentTeal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasVoiceSession
                                            ? 'Voice: Acoustic Prosody Analyzed (${_recordSeconds}s)'
                                            : 'Voice: Not recorded in this session',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        hasVoiceSession
                                            ? 'RMS energy & zero-crossing extracted (CREMA-D norms; non-neural)'
                                            : 'Audio recording was not started',
                                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: hasVoiceSession ? const Color(0xFFDCFCE7) : AppColors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    hasVoiceSession ? 'Acoustic' : 'None',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: hasVoiceSession ? const Color(0xFF166534) : AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.trendingUp, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RALPA Longitudinal Trajectory Engine',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Applies 149-feature ensemble upon submission to forecast risk drift',
                                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_submissionError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.riskHighBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.riskHigh),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.xCircle, color: AppColors.riskHigh, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _submissionError!,
                                style: const TextStyle(fontSize: 12, color: AppColors.riskHigh),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmittingAssessment ? null : () => Navigator.pop(context),
                child: Text(allAnswered ? 'Review Answers' : 'Continue Questionnaire'),
              ),
              if (!allAnswered && missingQuestions.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentIndex = missingQuestions.first - 1;
                    });
                  },
                  child: Text('Jump to Q${missingQuestions.first}'),
                ),
              ElevatedButton(
                onPressed: (!allAnswered || _isSubmittingAssessment)
                    ? null
                    : () async {
                        setDialogState(() {
                          _isSubmittingAssessment = true;
                          _submissionError = null;
                        });

                        final token = ref.read(authProvider).state.token;
                        final residentId = _resolveBackendResidentId();
                        final answersPayload = EmotionalAssessmentService.buildAnswersPayload(_answers);

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(dialogCtx);
                        final router = GoRouter.of(context);

                        try {
                          final result = await EmotionalAssessmentService.submitAssessment(
                            residentId: residentId,
                            answers: answersPayload,
                            includeFacialCheck: (hasFacialInference || _capturedImageBytes != null),
                            includeVoiceCheck: hasVoiceSession,
                            facialScore: facialScore,
                            vocalScore: vocalScore,
                            dominantEmotion: hasFacialInference ? facialAggregate.dominantEmotion : null,
                            facialConfidence: facialConf,
                            token: token,
                          );

                          if (!mounted) return;

                          setState(() {
                            _lonelinessScore = calculatedRisk.round();
                            if (_latestSocialAudit != null && _latestSocialAudit!.socialScore != null) {
                              _isolationScore = (100.0 - _latestSocialAudit!.socialScore!).round();
                            }
                            _isSubmittingAssessment = false;
                          });

                          navigator.pop();

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Assessment #${result.id} saved successfully! Wellness score: ${result.overallScore.toStringAsFixed(1)}%.',
                              ),
                              backgroundColor: AppColors.riskLow,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          router.go('/dashboard');
                        } catch (e) {
                          if (mounted) {
                            setDialogState(() {
                              _isSubmittingAssessment = false;
                              _submissionError = e.toString();
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Submission failed: $e'),
                                backgroundColor: AppColors.riskHigh,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: _isSubmittingAssessment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save & Finish Assessment'),
              ),
            ],
          );
        },
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

    // When logged in as an Elder resident, display the full emotional wellness dashboard
    // matching the caregiver experience, with an option to toggle the accessible conversation view.
    if (_useSimplifiedElderView && authState.state.isElder) {
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
    final isElder = ref.watch(authProvider).state.isElder;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => context.go('/dashboard/residents'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                const Icon(LucideIcons.arrowLeft, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  isElder ? 'Back to My Health Record' : 'Back to Residents',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- RESIDENT HEADER CARD ---
  Widget _buildResidentHeaderCard() {
    final authState = ref.watch(authProvider).state;
    final initials = _currentResident.name
        .split(' ')
        .where((w) => !w.startsWith('Mr.') && !w.startsWith('Mrs.') && !w.startsWith('Dr.'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join();

    final cleanRoom = _currentResident.roomNo
        .replaceAll('Room No: ', '')
        .replaceAll('Room No ', '')
        .replaceAll('Room ', '')
        .replaceAll('Suite ', '')
        .trim();

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
                        key: const ValueKey('resident_emotional_banner_avatar'),
                        avatarUrl: _currentResident.avatarUrl ?? (authState.isElder ? authState.avatarUrl : null),
                        radius: 31,
                        initials: initials.isNotEmpty ? initials : 'R',
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
                        _currentResident.name,
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
                          children: const [
                            Icon(
                              LucideIcons.userCheck,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'ELDER / RESIDENT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_facilityName.isNotEmpty) ...[
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
                                _facilityName,
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
                        label: 'Age: ${_currentResident.age} yrs',
                        color: const Color(0xFF4F46E5),
                        bg: const Color(0xFFEEF2FF),
                        border: const Color(0xFFE0E7FF),
                      ),
                      _buildResidentDetailPill(
                        icon: LucideIcons.doorOpen,
                        label: cleanRoom.isNotEmpty ? 'Room $cleanRoom' : 'Room 30',
                        color: const Color(0xFF059669),
                        bg: const Color(0xFFECFDF5),
                        border: const Color(0xFFA7F3D0),
                      ),
                      _buildResidentDetailPill(
                        icon: LucideIcons.graduationCap,
                        label: 'Education: ${_educationYears ?? 13} yrs',
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
              if (!authState.isElder && _availableResidents.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _availableResidents.any((r) => r.id == _currentResident.id)
                          ? _currentResident.id
                          : (_availableResidents.isNotEmpty ? _availableResidents.first.id : null),
                      icon: const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.primary),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                      items: () {
                        final seen = <String>{};
                        final unique = <Resident>[];
                        for (final r in _availableResidents) {
                          if (seen.add(r.id)) unique.add(r);
                        }
                        return unique.map((Resident r) {
                          final clean = (r.name.trim().isNotEmpty && r.name.trim() != '-')
                              ? r.name.trim()
                              : 'Resident #${r.id}';
                          return DropdownMenuItem<String>(
                            value: r.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.user, size: 13, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text('$clean (ID: ${_formatDisplayId(r.id)})'),
                              ],
                            ),
                          );
                        }).toList();
                      }(),
                      onChanged: (String? newResId) {
                        if (newResId != null) {
                          final selected = _availableResidents.firstWhere(
                            (r) => r.id == newResId,
                            orElse: () => _availableResidents.first,
                          );
                          setState(() {
                            _currentResident = selected;
                            if (_liveProfiles != null && _liveProfiles!.isNotEmpty) {
                              final matched = _liveProfiles!.firstWhere(
                                (p) => p.id.toString() == newResId,
                                orElse: () => _liveProfiles!.first,
                              );
                              _educationYears = matched.educationYears ?? 13;
                              if (matched.elderHomeName != null && matched.elderHomeName!.isNotEmpty) {
                                _facilityName = matched.elderHomeName!;
                              }
                            }
                            _loadResidentData(selected.id);
                          });
                        }
                      },
                    ),
                  ),
                ),
              // Floating Session Battery Badge
              Container(
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
                      'Self-Response Session (${_questions.length} Items)',
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

  // --- MAIN ASSESSMENT CARD ---
  Widget _buildMainAssessmentCard(AssessmentQuestion currentQ) {
    final isReversePolarityQ = currentQ.id == 4 || currentQ.id == 5;
    final isCelebrationState = isReversePolarityQ
        ? (_answers[currentQ.id] == false)
        : (_answers[currentQ.id] == true);
    final isInterventionState = isReversePolarityQ
        ? (_answers[currentQ.id] == true)
        : (_answers[currentQ.id] == false);

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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
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
                          if (currentQ.promptSi != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              currentQ.promptSi!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDeep,
                                height: 1.4,
                              ),
                            ),
                          ],
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
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _buildYesNoChoiceButton(
                                label: 'Yes / ඔව්',
                                isSelected: _answers[currentQ.id] == true,
                                isYes: true,
                                onTap: () => _selectYesNoAnswer(currentQ.id, true),
                              ),
                              const SizedBox(width: 12),
                              _buildYesNoChoiceButton(
                                label: 'No / නැත',
                                isSelected: _answers[currentQ.id] == false,
                                isYes: false,
                                onTap: () => _selectYesNoAnswer(currentQ.id, false),
                              ),
                            ],
                          ),

                          // If Celebration State: AI assistant gratitude and celebratory response
                          if (isCelebrationState) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('👏', style: TextStyle(fontSize: 26)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'AI Assistant:  ✨ Delighted to hear this! ✨',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentQ.id == 5
                                              ? 'ඔබ කාමරයට පමණක් සීමා නොවී, නිරතුරුවම ක්‍රියාශීලීව සහ සමාජශීලීව කාලය ගත කිරීම ගැන මම ඉතාමත් සතුටු වෙනවා!'
                                              : (currentQ.id == 4
                                                  ? 'අන් අය එකතු වී සිටින විට ඔබ සතුටින්, සුහදව සහ ආදරයෙන් එක්ව සිටීම ගැන මම ඉතාමත් සතුටු වෙනවා!'
                                                  : (currentQ.id == 3
                                                      ? 'මෙහි ඔබ සමඟ සමීපව කතාබහ කිරීමට කෙනෙකු සිටීම මහත් භාග්‍යයක්! ඔබේ මිත්‍රත්වය සහ සතුට සදා රැඳේවා!'
                                                      : (currentQ.id == 2
                                                          ? 'ඉදිරි දින පිළිබඳව ඔබ තුළ සුබවාදී, ප්‍රීතිමත් බලාපොරොත්තු තිබීම ගැන මම ඉතාමත් සතුටු වෙනවා! ඔබ සැමදා සතුටින් සහ ජයග්‍රාහීව සිටින්න!'
                                                          : 'ගොඩක් ඒ ගැන ස්තූතියි! අද දවසේ ඔබ සිතින් සතුටින් සහ සහනයෙන් පසුවීම ගැන මම ගොඩක් සතුටු වෙනවා!'))),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF166534),
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentQ.id == 5
                                              ? 'I am so glad to hear that you stay active, step out, and do not isolate yourself in your room all day!'
                                              : (currentQ.id == 4
                                                  ? 'I am so glad to hear that you feel warmly included, comfortable, and happy when others gather around!'
                                                  : (currentQ.id == 3
                                                      ? 'Having someone close to talk with is a wonderful blessing! May your friendships bring lasting warmth and happiness.'
                                                      : (currentQ.id == 2
                                                          ? 'I am so glad you feel hopeful and optimistic about the days ahead! May each tomorrow bring you joy and triumph.'
                                                          : 'Thank you so much! I am very glad to hear that you are feeling peaceful and in good spirits today.'))),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // If Intervention State: Conversational Support Intervention Card
                          if (isInterventionState) ...[
                            const SizedBox(height: 14),
                            _buildConversationalSupportCard(currentQ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_showClapAnimation)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildClapOverlayAnimation(),
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
              _buildFacialCaptureStatusBadge(),
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
                  Builder(
                    builder: (context) {
                      final controller = _facialCaptureService.cameraController;
                      if (controller != null && controller.value.isInitialized) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: controller.value.previewSize?.height ?? 480,
                              height: controller.value.previewSize?.width ?? 360,
                              child: CameraPreview(controller),
                            ),
                          ),
                        );
                      }
                      if (_capturedImageBytes != null) {
                        return Image.memory(
                          _capturedImageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                            'assets/images/landing/senior_neutral_calm_face.jpg',
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return Image.asset(
                        _currentFaceAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/landing/senior_neutral_calm_face.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) {
                              return Container(
                                color: const Color(0xFF1E293B),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.user,
                                    size: 56,
                                    color: Colors.white54,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

                  // Overlay Face Tracking Box with green/purple corners
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedEmotion == 'Happy'
                              ? AppColors.riskLow.withValues(alpha: 0.85)
                              : (_selectedEmotion == 'Sad'
                                  ? AppColors.riskHigh.withValues(alpha: 0.85)
                                  : (_selectedEmotion == 'Confused'
                                      ? AppColors.riskModerate.withValues(alpha: 0.85)
                                      : (_selectedEmotion == 'Fear'
                                          ? AppColors.lilac.withValues(alpha: 0.85)
                                          : AppColors.primary.withValues(alpha: 0.85)))),
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

                  // Live auto-capture bottom status overlay
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _facialCaptureService.isAutoCapturing
                                ? LucideIcons.activity
                                : LucideIcons.shieldCheck,
                            size: 11,
                            color: _facialCaptureService.isAutoCapturing
                                ? AppColors.leafGreen
                                : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _facialCaptureService.isAutoCapturing
                                  ? 'Auto-capture active (1s interval) • ${_facialCaptureService.aggregate.validCount} valid samples'
                                  : (_hasFacialConsent
                                      ? 'Consent granted • Auto-captures during voice'
                                      : 'Consent required for auto facial capture'),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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
          if (_facialCaptureService.status == FacialCaptureStatus.modelUnavailable) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.riskModerateBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.riskModerate.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.riskModerate),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PyTorch FER Model offline on FastAPI. Frames captured safely without fabricating scores.',
                      style: TextStyle(fontSize: 10, color: AppColors.navy, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Real AI Detected Emotion Readout
          const Text(
            'AI Detected Facial Emotion:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 8),
          _buildAiDetectedEmotionDisplay(),
        ],
      ),
    );
  }

  Widget _buildFacialCaptureStatusBadge() {
    final status = _facialCaptureService.status;
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case FacialCaptureStatus.capturing:
        bg = AppColors.primarySoft;
        fg = AppColors.primary;
        text = 'Capturing';
        icon = LucideIcons.camera;
        break;
      case FacialCaptureStatus.analyzing:
        bg = AppColors.lavenderBg;
        fg = AppColors.primary;
        text = 'Analyzing AI';
        icon = LucideIcons.sparkles;
        break;
      case FacialCaptureStatus.noFace:
        bg = AppColors.riskModerateBg;
        fg = AppColors.riskModerate;
        text = 'No Face';
        icon = LucideIcons.alertCircle;
        break;
      case FacialCaptureStatus.modelUnavailable:
        bg = AppColors.border;
        fg = AppColors.navy;
        text = 'Model Offline';
        icon = LucideIcons.alertTriangle;
        break;
      case FacialCaptureStatus.consentRequired:
        bg = AppColors.riskModerateBg;
        fg = AppColors.riskModerate;
        text = 'Consent Needed';
        icon = LucideIcons.shieldAlert;
        break;
      case FacialCaptureStatus.permissionDenied:
        bg = AppColors.riskHighBg;
        fg = AppColors.riskHigh;
        text = 'Perm Denied';
        icon = LucideIcons.shieldAlert;
        break;
      case FacialCaptureStatus.cameraUnavailable:
        bg = AppColors.border;
        fg = AppColors.muted;
        text = 'No Camera';
        icon = LucideIcons.videoOff;
        break;
      case FacialCaptureStatus.networkError:
        bg = AppColors.riskHighBg;
        fg = AppColors.riskHigh;
        text = 'Network Err';
        icon = LucideIcons.wifiOff;
        break;
      case FacialCaptureStatus.standby:
        bg = AppColors.riskLowBg;
        fg = AppColors.riskLow;
        text = 'Auto (Voice)';
        icon = Icons.fiber_manual_record;
        break;
      case FacialCaptureStatus.error:
        bg = AppColors.riskHighBg;
        fg = AppColors.riskHigh;
        text = 'Error';
        icon = LucideIcons.alertOctagon;
        break;
      case FacialCaptureStatus.initializingCamera:
        bg = AppColors.lavenderBg;
        fg = AppColors.primary;
        text = 'Init Camera';
        icon = LucideIcons.loader;
        break;
      case FacialCaptureStatus.idle:
        bg = AppColors.border;
        fg = AppColors.muted;
        text = 'Standby';
        icon = LucideIcons.video;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDetectedEmotionDisplay() {
    final status = _facialCaptureService.status;
    final bool isRecording = _isRecording;
    final bool hasPredictions = _facialCaptureService.aggregate.validCount > 0 || _capturedImageBytes != null;

    Color bg;
    Color border;
    Color text;
    String emoji;
    String title;
    String confidenceStr = '${(_facialConfidence * 100).toInt()}% Confidence';
    String subtitle;

    if (!isRecording && !hasPredictions) {
      bg = Colors.white;
      border = AppColors.border;
      text = AppColors.muted;
      emoji = '🎙️';
      title = 'Standby for Voice Session';
      confidenceStr = 'Awaiting Recording';
      subtitle = 'Facial affect capture starts automatically when voice recording begins.';
    } else if (status == FacialCaptureStatus.noFace) {
      bg = AppColors.riskModerateBg;
      border = AppColors.riskModerate.withValues(alpha: 0.5);
      text = AppColors.riskModerate;
      emoji = '🔍';
      title = 'No Face Recognized';
      confidenceStr = 'Reposition Senior';
      subtitle = 'Ensure senior is positioned facing camera in adequate ambient lighting.';
    } else if (status == FacialCaptureStatus.modelUnavailable) {
      bg = AppColors.surfaceSecondary;
      border = AppColors.border;
      text = AppColors.navy;
      emoji = '⚠️';
      title = 'Inference Offline';
      confidenceStr = 'Model Unavailable';
      subtitle = 'Camera capture active; facial emotion scoring paused until AI microservice is online.';
    } else {
      switch (_selectedEmotion.toLowerCase()) {
        case 'happy':
        case 'cheerful':
          bg = AppColors.riskLowBg;
          border = AppColors.riskLow.withValues(alpha: 0.4);
          text = AppColors.riskLow;
          emoji = '😊';
          title = 'Happy / Uplifted';
          subtitle = 'Bilateral zygomaticus engagement detected. Consistent with positive emotional wellness.';
          break;
        case 'sad':
        case 'depressed':
          bg = AppColors.riskHighBg;
          border = AppColors.riskHigh.withValues(alpha: 0.4);
          text = AppColors.riskHigh;
          emoji = '😔';
          title = 'Sad / Affect Flattening';
          subtitle = 'Depressed lip corners and brow tension observed. Informs RALPA affective drift analysis.';
          break;
        case 'confused':
        case 'agitated':
        case 'angry':
          bg = AppColors.riskModerateBg;
          border = AppColors.riskModerate.withValues(alpha: 0.4);
          text = AppColors.riskModerate;
          emoji = '🤔';
          title = 'Confused / Agitated';
          subtitle = 'Corrugator brow furrowing and contraction detected. Informs cognitive-emotional assessment.';
          break;
        case 'fear':
        case 'anxious':
        case 'fearful':
          bg = AppColors.lavenderBg;
          border = AppColors.lilac;
          text = AppColors.primary;
          emoji = '😨';
          title = 'Fear / Anxious';
          subtitle = 'Upper eyelid elevation and apprehension markers detected.';
          break;
        case 'neutral':
        case 'calm':
        default:
          bg = AppColors.surfaceSecondary;
          border = AppColors.border;
          text = AppColors.navy;
          emoji = '😐';
          title = 'Calm / Neutral Baseline';
          subtitle = 'Resting facial expression with symmetrical prosody and stable valence.';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Text(
                  confidenceStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              height: 1.3,
            ),
          ),
        ],
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
          // Header with recording blinker & Language Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Voice Recording',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
              Row(
                children: [
                  // Language Switcher: Sinhala / English
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLangToggleItem('si-LK', '🇱🇰 සිංහල'),
                        _buildLangToggleItem('en-US', '🇺🇸 English'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
              border: Border.all(color: _isRecording ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
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
                    final soundBoost = (_soundLevel.abs() > 0.05) ? (_soundLevel.abs() * 1.5).clamp(0.0, 25.0) : 0.0;
                    final dynamicHeight = _isRecording
                        ? (12.0 + soundBoost + (35.0 * (0.3 + 0.7 * (1.0 - (waveValue % 1.0)))) * factor)
                            .clamp(8.0, 80.0)
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
          const SizedBox(height: 10),

          // Spoken Transcript Preview
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isRecording ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _isRecording ? LucideIcons.mic : LucideIcons.messageSquare,
                  size: 14,
                  color: _isRecording ? AppColors.riskHigh : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _spokenText.isNotEmpty
                        ? _spokenText
                        : (_isRecording
                            ? (_micStatusNotice.isNotEmpty ? _micStatusNotice : '🎙️ Listening... (Speak in $_selectedVoiceLocaleLabel)')
                            : 'Tap the microphone to speak your response...'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: _spokenText.isNotEmpty
                          ? AppColors.navy
                          : (_isRecording ? AppColors.primary : AppColors.muted),
                      fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (_spokenText.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _spokenText = '';
                      });
                    },
                    child: const Icon(LucideIcons.x, size: 14, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (_isRecording || _spokenText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _getVoiceEmotionColor(_voiceEmotion).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getVoiceEmotionColor(_voiceEmotion).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isRecording ? Icons.sensors : LucideIcons.checkCircle2,
                    size: 14,
                    color: _getVoiceEmotionColor(_voiceEmotion),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Elder Voice Emotion: ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                  Expanded(
                    child: Text(
                      '$_voiceEmotion (${(_voiceConfidence * 100).toInt()}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getVoiceEmotionColor(_voiceEmotion),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Quick Voice Test Prompts
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildQuickSpeechChip('😊 Feeling Happy & Fine', 'I feel very happy and fine today.'),
              _buildQuickSpeechChip('😔 Feeling Sad & Lonely', 'I feel sad and alone today.'),
              _buildQuickSpeechChip('😌 Calm Baseline', 'I am calm and feeling peaceful.'),
              _buildQuickSpeechChip('😟 Anxious / Worried', 'I feel nervous and worried.'),
              _buildQuickSpeechChip('🇱🇰 ඔව් සතුටුයි', 'ඔව් අද මට සතුටින් සැනසීමක් දැනෙනවා.'),
              _buildQuickSpeechChip('🇱🇰 මට දුකයි', 'මට අද දුකයි සහ පාළුයි.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangToggleItem(String locale, String label) {
    final isSelected = _selectedVoiceLocale == locale;
    return InkWell(
      onTap: () => _switchVoiceLocale(locale),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSpeechChip(String label, String sampleText) {
    return InkWell(
      onTap: () {
        setState(() {
          _spokenText = sampleText;
          _micStatusNotice = 'Sample selected: "$sampleText"';
        });
        _analyzeSpokenVoice(sampleText);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.lavenderBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lilac.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildYesNoChoiceButton({
    required String label,
    required bool isSelected,
    required bool isYes,
    required VoidCallback onTap,
  }) {
    final activeColor = isYes ? AppColors.riskLow : const Color(0xFFF97316);
    final activeBg = isYes ? AppColors.riskLowBg : const Color(0xFFFFF7ED);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected
                    ? (isYes ? LucideIcons.circleCheck : LucideIcons.circleX)
                    : LucideIcons.circle,
                size: 18,
                color: isSelected ? activeColor : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? activeColor : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _selectedEmotion == 'Happy'
                      ? AppColors.riskLow
                      : (_selectedEmotion == 'Sad'
                          ? AppColors.riskHigh
                          : (_selectedEmotion == 'Confused'
                              ? AppColors.riskModerate
                              : (_selectedEmotion == 'Fear'
                                  ? AppColors.primary
                                  : AppColors.primary))),
                ),
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
              color: _selectedEmotion == 'Happy'
                  ? AppColors.riskLow
                  : (_selectedEmotion == 'Sad'
                      ? AppColors.riskHigh
                      : (_selectedEmotion == 'Confused'
                          ? AppColors.riskModerate
                          : (_selectedEmotion == 'Fear'
                              ? AppColors.primary
                              : AppColors.primary))),
            ),
          ),
          const SizedBox(height: 14),

          // Voice Emotion
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Voice Emotion', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (_isRecording) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.riskHighBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.fiber_manual_record, size: 7, color: AppColors.riskHigh),
                          SizedBox(width: 3),
                          Text(
                            'LIVE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.riskHigh),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '$_voiceEmotion  ${(_voiceConfidence * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getVoiceEmotionColor(_voiceEmotion),
                ),
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
              color: _getVoiceEmotionColor(_voiceEmotion),
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
    final authState = ref.watch(authProvider).state;
    final hasAnswers = _answers.isNotEmpty;
    final calculatedWellness = hasAnswers
        ? EmotionalAssessmentService.calculateWellnessScore(_answers)
        : null;
    final calculatedLoneliness = calculatedWellness != null
        ? EmotionalAssessmentService.calculateLonelinessRiskScore(calculatedWellness)
        : null;

    final q3Answer = _answers[2]; // Someone close to talk to (Social Support)
    final q4Answer = _answers[3]; // Feel left out or lonely (Perceived Loneliness)
    final q5Answer = _answers[4]; // Spending day alone in room (Room Isolation)

    final String perceivedLonelinessLevel = q4Answer == null
        ? 'Pending Q4'
        : (q4Answer == true ? 'High' : 'Low');
    final String seclusionLevel = q5Answer == null
        ? 'Pending Q5'
        : (q5Answer == true ? 'High' : 'Low');
    final String socialSupportLevel = q3Answer == null
        ? 'Pending Q3'
        : (q3Answer == true ? 'Adequate' : 'Low');

    final int displayLoneliness = calculatedLoneliness != null
        ? calculatedLoneliness.round()
        : _lonelinessScore;
    final String lonelinessTier = displayLoneliness >= 65
        ? 'High Risk'
        : (displayLoneliness >= 40 ? 'Moderate Risk' : 'Low Risk');
    final Color lonelinessColor = displayLoneliness >= 65
        ? AppColors.riskHigh
        : (displayLoneliness >= 40 ? AppColors.riskModerate : AppColors.riskLow);
    final Color lonelinessBg = displayLoneliness >= 65
        ? AppColors.riskHighBg
        : (displayLoneliness >= 40 ? AppColors.riskModerateBg : const Color(0xFFDCFCE7));

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
          Row(
            children: [
              const Text(
                'Loneliness Indicators',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.lavenderBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Questionnaire-Derived',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IndicatorSubRow(label: 'Perceived Loneliness (Q4)', level: perceivedLonelinessLevel),
                    const SizedBox(height: 4),
                    _IndicatorSubRow(label: 'Room Seclusion (Q5)', level: seclusionLevel),
                    const SizedBox(height: 4),
                    _IndicatorSubRow(label: 'Social Support (Q3)', level: socialSupportLevel),
                  ],
                ),
              ),
              _buildCircularScoreGauge(
                score: displayLoneliness,
                riskLabel: lonelinessTier,
                riskColor: lonelinessColor,
                bgRingColor: lonelinessBg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Section B: Social-Isolation Indicators
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Social-Isolation Indicators',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.riskHigh),
                  ),
                  if (_isLoadingSocialAudit)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  else if (_latestSocialAudit != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Verified Caregiver Audit',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Unassessed (No Caregiver Audit)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                ],
              ),
              if (!authState.isElder)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(LucideIcons.clipboardCheck, size: 14, color: AppColors.primary),
                  label: const Text(
                    'Social Audit Hub',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  onPressed: () => context.go('/dashboard/social-audit/resident/${_resolveBackendResidentId()}'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_latestSocialAudit != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IndicatorSubRow(
                              label: 'External Contacts (7d)',
                              level: _latestSocialAudit!.externalContactUnknown
                                  ? 'Unknown / Not Recorded'
                                  : '${_latestSocialAudit!.totalExternalContacts ?? 0} contacts (${_latestSocialAudit!.familyInPersonVisits ?? 0} visits, ${_latestSocialAudit!.familyPhoneVideoContacts ?? 0} calls)',
                            ),
                            const SizedBox(height: 4),
                            _IndicatorSubRow(
                              label: 'Peer Social Interaction',
                              level: _latestSocialAudit!.peerInteractionLevel.label,
                            ),
                            const SizedBox(height: 4),
                            _IndicatorSubRow(
                              label: 'Activity Attendance',
                              level: _latestSocialAudit!.activitiesAttended != null
                                  ? '${_latestSocialAudit!.activitiesAttended} / ${_latestSocialAudit!.activitiesAvailable ?? 0} (${_latestSocialAudit!.activityParticipationLevel.label})'
                                  : _latestSocialAudit!.activityParticipationLevel.label,
                            ),
                            const SizedBox(height: 4),
                            _IndicatorSubRow(
                              label: 'Time Alone / Day',
                              level: _latestSocialAudit!.estimatedHoursAlonePerDay != null
                                  ? '${_latestSocialAudit!.estimatedHoursAlonePerDay!.toStringAsFixed(1)} hrs/day (${_latestSocialAudit!.aloneTimeContext.label})'
                                  : _latestSocialAudit!.aloneTimeContext.label,
                            ),
                          ],
                        ),
                      ),
                      if (_latestSocialAudit!.socialScore != null)
                        _buildCircularScoreGauge(
                          score: (100.0 - _latestSocialAudit!.socialScore!).round(),
                          riskLabel: (100.0 - _latestSocialAudit!.socialScore!) >= 50 ? 'Elevated' : 'Low',
                          riskColor: (100.0 - _latestSocialAudit!.socialScore!) >= 50 ? AppColors.riskHigh : AppColors.riskLow,
                          bgRingColor: (100.0 - _latestSocialAudit!.socialScore!) >= 50 ? AppColors.riskHighBg : const Color(0xFFDCFCE7),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(LucideIcons.userCheck, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Audited on ${_latestSocialAudit!.auditDate.day}/${_latestSocialAudit!.auditDate.month}/${_latestSocialAudit!.auditDate.year} by ${_latestSocialAudit!.caregiverName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (_latestSocialAudit!.healthMobilityBarriers)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Health Barrier Protected',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
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
                      Icon(LucideIcons.clipboardList, size: 20, color: AppColors.muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unassessed — No Caregiver Social Audit On File. External contacts, visitor logs, and group activity attendance require staff observational audit.',
                          style: TextStyle(fontSize: 11, color: AppColors.body, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  if (!authState.isElder) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lavenderBg,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppColors.lilac),
                          ),
                        ),
                        icon: const Icon(LucideIcons.clipboardPlus, size: 16),
                        label: const Text('Open in Caregiver Social Audit Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => context.go('/dashboard/social-audit/resident/${_resolveBackendResidentId()}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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

    final bool isHighRisk = currentLoneliness >= 70 || _selectedEmotion == 'Sad' || _selectedEmotion == 'Angry' || _selectedEmotion == 'Fear';
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
                      'Model: RALPA-Adaptive v1',
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
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _useSimplifiedElderView = false),
                      icon: const Icon(LucideIcons.layoutDashboard, size: 16),
                      label: const Text('View Full Emotional Wellness Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
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
                    if (currentQ.promptSi != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        currentQ.promptSi!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDeep,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
