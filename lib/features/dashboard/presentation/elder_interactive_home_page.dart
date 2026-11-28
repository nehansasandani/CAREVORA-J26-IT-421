import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import 'elder_meal_experience_page.dart';

enum DayPeriod { morning, afternoon, evening, night }

enum DailyAssessmentSlot { morning, afternoon, night }

DailyAssessmentSlot _getCurrentAssessmentSlot(DateTime dt) {
  final hour = dt.hour;
  if (hour < 12) {
    return DailyAssessmentSlot.morning; // 12:00 AM - 11:59 AM (පෙ.ව. / උදෑසන)
  } else if (hour < 17) {
    return DailyAssessmentSlot.afternoon; // 12:00 PM - 4:59 PM (දහවල්)
  } else {
    return DailyAssessmentSlot.night; // 5:00 PM - 11:59 PM (රාත්‍රිය)
  }
}

String _getSlotNameSi(DailyAssessmentSlot slot) {
  switch (slot) {
    case DailyAssessmentSlot.morning:
      return 'උදෑසන';
    case DailyAssessmentSlot.afternoon:
      return 'දහවල';
    case DailyAssessmentSlot.night:
      return 'රාත්‍රිය';
  }
}

String _getSlotActionName(DailyAssessmentSlot slot) {
  switch (slot) {
    case DailyAssessmentSlot.morning:
      return 'උදෑසන';
    case DailyAssessmentSlot.afternoon:
      return 'දනවල්';
    case DailyAssessmentSlot.night:
      return 'රාත්‍රී';
  }
}

String _getSlotIcon(DailyAssessmentSlot slot) {
  switch (slot) {
    case DailyAssessmentSlot.morning:
      return '🌅';
    case DailyAssessmentSlot.afternoon:
      return '☀️';
    case DailyAssessmentSlot.night:
      return '🌙';
  }
}

String _getNextSlotNameSi(DailyAssessmentSlot slot) {
  switch (slot) {
    case DailyAssessmentSlot.morning:
      return 'දහවල්';
    case DailyAssessmentSlot.afternoon:
      return 'රාත්‍රී';
    case DailyAssessmentSlot.night:
      return 'උදෑසන';
  }
}

String _getNextSlotInfoSi(DailyAssessmentSlot slot) {
  switch (slot) {
    case DailyAssessmentSlot.morning:
      return 'දහවල් 12:00';
    case DailyAssessmentSlot.afternoon:
      return 'සවස 05:00';
    case DailyAssessmentSlot.night:
      return 'හෙට උදෑසන';
  }
}

class ElderInteractiveHomePage extends ConsumerStatefulWidget {
  const ElderInteractiveHomePage({super.key});

  @override
  ConsumerState<ElderInteractiveHomePage> createState() =>
      _ElderInteractiveHomePageState();
}

class _ElderInteractiveHomePageState
    extends ConsumerState<ElderInteractiveHomePage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _floatingController;
  late final AnimationController _ambientBgController;
  late final Animation<double> _ambientBgAnimation;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Routine check state
  bool _routine1AnsweredYes = true;
  bool _routine1AnsweredNo = false;
  bool _routine2AnsweredYes = true;
  bool _routine2AnsweredNo = false;
  bool _routineWaterAnsweredYes = false;
  bool _routineWaterAnsweredNo = false;
  bool _showHydrationReminder = true;
  bool _isPlayingVoice = false;
  bool _hasSpokenInitialGreeting = false;

  // 3-Sessions Per Day Tracking State
  bool _emotionalMorningDone = false;
  bool _emotionalAfternoonDone = false;
  bool _emotionalNightDone = false;
  bool _memoryMorningDone = false;
  bool _memoryAfternoonDone = false;
  bool _memoryNightDone = false;

  // Interactive Book Slot Selection State (Page Flip Effect)
  DailyAssessmentSlot? _selectedEmotionalSlot;
  DailyAssessmentSlot? _selectedMemorySlot;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _ambientBgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _ambientBgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_ambientBgController);

    _loadDailySessionStatus();

    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
        _loadDailySessionStatus();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasSpokenInitialGreeting) {
        _hasSpokenInitialGreeting = true;
        final authState = ref.read(authProvider).state;
        final isSinhala = ref.read(languageProvider).isSinhala;
        final displayName = _resolveDisplayName(authState, isSinhala);
        final period = _getCurrentDayPeriod(_now);
        _speakInitialGreeting(displayName, period);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController.dispose();
    _floatingController.dispose();
    _ambientBgController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  DayPeriod _getCurrentDayPeriod(DateTime dt) {
    final hour = dt.hour;
    if (hour < 12) {
      return DayPeriod.morning;
    } else if (hour < 16) {
      // 12:00 PM to 3:59 PM (12 to 15:59)
      return DayPeriod.afternoon;
    } else if (hour < 19) {
      // 4:00 PM to 6:59 PM (16 to 18:59) -> Evening (සවස / සන්ධ්‍යාව)
      return DayPeriod.evening;
    } else {
      // 7:00 PM to 11:59 PM -> Night (රාත්‍රිය)
      return DayPeriod.night;
    }
  }

  static String _toSinhalaResidentName(String name) {
    if (name.isEmpty) return 'නේවාසික සාමාජිකයා';
    final trimmed = name.trim();
    if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(trimmed)) {
      return trimmed;
    }

    final lower = trimmed.toLowerCase();
    if (lower == 'kumara' || lower == 'mr. kumara' || lower == 'mr kumara') return 'කුමාර මහත්මයා';
    if (lower == 'malini' || lower == 'malini bandara' || lower == 'mrs. malini bandara') return 'මාලිනී බණ්ඩාර';
    if (lower == 'arthur' || lower == 'arthur pendleton' || lower == 'mr. arthur pendleton') return 'ආතර් පෙන්ඩ්ල්ටන්';
    if (lower == 'sarah' || lower == 'sarah jenkins' || lower == 'mrs. sarah jenkins') return 'සාරා ජෙන්කින්ස්';
    if (lower == 'margaret' || lower == 'margaret chen' || lower == 'mrs. margaret chen') return 'මාග්‍රට් චෙන්';
    if (lower == 'seetha' || lower == 'seetha wickramasinghe' || lower == 'mrs. seetha wickramasinghe') return 'සීතා වික්‍රමසිංහ';
    if (lower == 'kamal' || lower == 'kamal perera' || lower == 'mr. kamal perera') return 'කමල් පෙරේරා';
    if (lower == 'sunil' || lower == 'sunil silva' || lower == 'mr. sunil silva') return 'සුනිල් සිල්වා';
    if (lower == 'nimal' || lower == 'nimal perera') return 'නිමල්';
    if (lower == 'resident' || lower == 'senior resident') return 'නේවාසික සාමාජිකයා';

    try {
      final trans = SinhalaNameTransliterator.toSinhala(trimmed);
      if (trans.isNotEmpty) return trans;
    } catch (_) {}

    return trimmed;
  }

  String _resolveDisplayName(AuthState authState, bool isSinhala) {
    String rawName = '';
    if (authState.userName != null && authState.userName!.trim().isNotEmpty) {
      rawName = authState.userName!.trim();
    } else if (authState.email != null && authState.email!.isNotEmpty) {
      final handle = authState.email!.split('@').first.replaceAll('.', ' ');
      rawName = handle.isNotEmpty ? handle[0].toUpperCase() + handle.substring(1) : 'කුමාර';
    } else {
      rawName = 'කුමාර';
    }

    return isSinhala ? _toSinhalaResidentName(rawName) : rawName;
  }

  ImageProvider _resolveAvatarImage(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        return NetworkImage(avatarUrl);
      }
      return AssetImage(avatarUrl);
    }
    return const AssetImage('assets/images/landing/testimonial_1.jpg');
  }

  void _speakInitialGreeting(String displayName, DayPeriod period) {
    String greeting;
    switch (period) {
      case DayPeriod.morning:
        greeting = 'සුබ උදෑසනක්, $displayName! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
        break;
      case DayPeriod.afternoon:
        greeting = 'සුබ දහවලක්, $displayName! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
        break;
      case DayPeriod.evening:
        greeting = 'සුබ සන්ධ්‍යාවක්, $displayName! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
        break;
      case DayPeriod.night:
        greeting = 'සුබ රාත්‍රියක්, $displayName! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
        break;
    }
    TtsService.instance.speak(greeting, isSinhala: true);
  }

  void _speak(String text) async {
    setState(() => _isPlayingVoice = true);
    await TtsService.instance.speak(text, isSinhala: true);
    if (mounted) {
      setState(() => _isPlayingVoice = false);
    }
  }

  String _formatSinhalaDate(DateTime date) {
    const months = [
      'ජනවාරි',
      'පෙබරවාරි',
      'මාර්තු',
      'අප්‍රේල්',
      'මැයි',
      'ජූනි',
      'ජූලි',
      'අගෝස්තු',
      'සැප්තැම්බර්',
      'ඔක්තෝබර්',
      'නොවැම්බර්',
      'දෙසැම්බර්'
    ];
    final monthName = months[date.month - 1];
    return 'අද, ${date.day} $monthName ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour12 = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  // =========================================================================
  // 3-SESSIONS PER DAY TRACKING & COOLDOWN LOGIC
  // =========================================================================
  Future<void> _loadDailySessionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey =
          "${_now.year.toString().padLeft(4, '0')}-${_now.month.toString().padLeft(2, '0')}-${_now.day.toString().padLeft(2, '0')}";
      if (mounted) {
        setState(() {
          _emotionalMorningDone =
              prefs.getBool('carevora_${todayKey}_emotional_morning') ?? false;
          _emotionalAfternoonDone =
              prefs.getBool('carevora_${todayKey}_emotional_afternoon') ?? false;
          _emotionalNightDone =
              prefs.getBool('carevora_${todayKey}_emotional_night') ?? false;

          _memoryMorningDone =
              prefs.getBool('carevora_${todayKey}_memory_morning') ?? false;
          _memoryAfternoonDone =
              prefs.getBool('carevora_${todayKey}_memory_afternoon') ?? false;
          _memoryNightDone =
              prefs.getBool('carevora_${todayKey}_memory_night') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _markSessionCompleted(
      String activity, DailyAssessmentSlot slot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey =
          "${_now.year.toString().padLeft(4, '0')}-${_now.month.toString().padLeft(2, '0')}-${_now.day.toString().padLeft(2, '0')}";
      await prefs.setBool('carevora_${todayKey}_${activity}_${slot.name}', true);
      await _loadDailySessionStatus();
    } catch (_) {}
  }

  bool _isSlotDone(String activity, DailyAssessmentSlot slot) {
    if (activity == 'emotional') {
      switch (slot) {
        case DailyAssessmentSlot.morning:
          return _emotionalMorningDone;
        case DailyAssessmentSlot.afternoon:
          return _emotionalAfternoonDone;
        case DailyAssessmentSlot.night:
          return _emotionalNightDone;
      }
    } else {
      switch (slot) {
        case DailyAssessmentSlot.morning:
          return _memoryMorningDone;
        case DailyAssessmentSlot.afternoon:
          return _memoryAfternoonDone;
        case DailyAssessmentSlot.night:
          return _memoryNightDone;
      }
    }
  }

  int _getDoneCount(String activity) {
    int count = 0;
    if (activity == 'emotional') {
      if (_emotionalMorningDone) count++;
      if (_emotionalAfternoonDone) count++;
      if (_emotionalNightDone) count++;
    } else {
      if (_memoryMorningDone) count++;
      if (_memoryAfternoonDone) count++;
      if (_memoryNightDone) count++;
    }
    return count;
  }

  void _showSessionAlreadyCompletedDialog({
    required BuildContext context,
    required String activityTitle,
    required String activityKey,
    required DailyAssessmentSlot slot,
    required VoidCallback onContinueAnyway,
  }) {
    final slotName = _getSlotNameSi(slot);
    final nextSlotName = _getNextSlotNameSi(slot);
    final nextSlotInfo = _getNextSlotInfoSi(slot);
    final speechText =
        'ඔබ අද $slotName $activityTitle දැනටමත් සම්පූර්ණ කර ඇත. මීළඟ සැසිය $nextSlotInfo ට $nextSlotName විවෘත වේ.';

    _speak(speechText);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 16,
          child: Container(
            padding: const EdgeInsets.all(22),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration Icon Circle
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E22CE).withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎉', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 16),

                // Dialog Title
                Text(
                  'අද $slotName සැසිය සම්පූර්ණයි! ✓',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF581C87),
                  ),
                ),
                const SizedBox(height: 10),

                // Description with elder-friendly explanation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'ඔබ අද $slotName $activityTitle ඉතා සාර්ථකව සිදු කර ඇත. එක දිගට සිදු නොකර සිත සැහැල්ලුවෙන් තබා ගැනීමට, මීළඟ සැසිය $nextSlotInfo ට ($nextSlotName) ආරම්භ කිරීමට සූදානම් කර ඇත.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Speaker Button
                InkWell(
                  onTap: () => _speak(speechText),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.volume2, size: 16, color: Color(0xFF7E22CE)),
                        SizedBox(width: 6),
                        Text(
                          'නැවත අසන්න',
                          style: TextStyle(
                            color: Color(0xFF7E22CE),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Action Buttons
                Row(
                  children: [
                    // Optional practice / visit anyway
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onContinueAnyway();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'විනෝදයට යන්න 🎮',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Done / Close
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: const Text(
                          'හරි, ස්තූතියි 😊',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailySessionTracker({
    required String activity,
    required DailyAssessmentSlot currentSlot,
    required Color activeThemeColor,
  }) {
    final morningDone = _isSlotDone(activity, DailyAssessmentSlot.morning);
    final afternoonDone = _isSlotDone(activity, DailyAssessmentSlot.afternoon);
    final nightDone = _isSlotDone(activity, DailyAssessmentSlot.night);

    return Row(
      children: [
        // 1. උදෑසන
        Expanded(
          child: _buildMockupSlotCard(
            label: 'උදෑසන',
            timeText: '(6.00 – 10.00)',
            iconWidget: const Text('🌅', style: TextStyle(fontSize: 20)),
            isDone: morningDone,
            isCurrent: currentSlot == DailyAssessmentSlot.morning,
            slotType: DailyAssessmentSlot.morning,
          ),
        ),
        const SizedBox(width: 8),

        // 2. දහවල්
        Expanded(
          child: _buildMockupSlotCard(
            label: 'දහවල්',
            timeText: '(10.00 – 4.00)',
            iconWidget: const Text('☀️', style: TextStyle(fontSize: 20)),
            isDone: afternoonDone,
            isCurrent: currentSlot == DailyAssessmentSlot.afternoon,
            slotType: DailyAssessmentSlot.afternoon,
          ),
        ),
        const SizedBox(width: 8),

        // 3. රාත්‍රී
        Expanded(
          child: _buildMockupSlotCard(
            label: 'රාත්‍රී',
            timeText: '(4.00 – 9.00)',
            iconWidget: const Text('🌙', style: TextStyle(fontSize: 20)),
            isDone: nightDone,
            isCurrent: currentSlot == DailyAssessmentSlot.night,
            slotType: DailyAssessmentSlot.night,
          ),
        ),
      ],
    );
  }

  Widget _buildMockupSlotCard({
    required String label,
    required String timeText,
    required Widget iconWidget,
    required bool isDone,
    required bool isCurrent,
    required DailyAssessmentSlot slotType,
  }) {
    Color bg;
    Color borderColor;
    double borderWidth;

    if (isDone) {
      bg = const Color(0xFFF0FDF4); // Soft therapeutic mint
      borderColor = const Color(0xFF86EFAC); // Emerald mint border
      borderWidth = 1.4;
    } else if (isCurrent) {
      bg = const Color(0xFFFAF5FF); // Light lavender
      borderColor = const Color(0xFF7C3AED); // Purple border
      borderWidth = 1.6;
    } else if (slotType == DailyAssessmentSlot.morning) {
      bg = const Color(0xFFFFFBEB); // Soft morning amber
      borderColor = const Color(0xFFFEF08A);
      borderWidth = 1.2;
    } else {
      bg = Colors.white;
      borderColor = const Color(0xFFE2E8F0);
      borderWidth = 1.2;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
        if (isDone)
          Positioned(
            top: -5,
            right: -3,
            child: Container(
              width: 19,
              height: 19,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3316A34A),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSlotStatusBadge({
    required bool isCurrentDone,
    required String currentSlotName,
    required Color activeColor,
    String? customNotDoneText,
  }) {
    if (isCurrentDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFFDDD6FE), width: 1.1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✨', style: TextStyle(fontSize: 14)),
            SizedBox(width: 5),
            Text(
              'සැසිය සම්පූර්ණයි',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6D28D9),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7), // warm soft cream (matching mockup)
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Swinging animated bell to catch elder's eye and remind them
            AnimatedBuilder(
              animation: _floatingController,
              builder: (context, _) {
                final angle = math.sin(_floatingController.value * 4 * math.pi) * 0.28;
                return Transform.rotate(
                  angle: angle,
                  alignment: Alignment.topCenter,
                  child: const Text('🔔', style: TextStyle(fontSize: 16)),
                );
              },
            ),
            const SizedBox(width: 5),
            Text(
              customNotDoneText ?? 'දැන් සිදු කරන්න',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3B0764), // deep purple text
              ),
            ),
          ],
        ),
      );
    }
  }

  // Compact Lavender Blossom Trim (Matching Carevora's Royal Purple aesthetic)
  Widget _buildLavenderBlossomTrimCompact() {
    return Container(
      height: 22,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3FF),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('🌸', style: TextStyle(fontSize: 12)),
              SizedBox(width: 3),
              Text('💜', style: TextStyle(fontSize: 11)),
              SizedBox(width: 3),
              Text('🌿', style: TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Text('🌿', style: TextStyle(fontSize: 12)),
              SizedBox(width: 3),
              Text('💜', style: TextStyle(fontSize: 11)),
              SizedBox(width: 3),
              Text('🌸', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final isSinhala = ref.watch(languageProvider).isSinhala;
    final elderDisplayName = _resolveDisplayName(authState, isSinhala);
    final dayPeriod = _getCurrentDayPeriod(_now);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7FD),
      body: Stack(
        children: [
          // 1. Scrollable main dashboard content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Hero Purple Interactive Greeting Banner
                _buildInteractiveHeroBanner(elderDisplayName, dayPeriod, authState.avatarUrl),
                const SizedBox(height: 16),

                // 2.1 Daily Routine Cards (Placed below the Welcome Banner)
                _buildDailyRoutineSection(dayPeriod),
                const SizedBox(height: 22),

                // 3. Quick Access Title & Large Action Cards
                _buildQuickAccessSection(context, isSinhala),
                const SizedBox(height: 24),

                // 4. Animated swaying floral garden at the bottom of the page content
                _buildAnimatedBottomFlowerGarden(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // 2. Overlay area (cleaned up for elder readability)
        ],
      ),
    );
  }

  // Animated swaying floral garden along the bottom of the screen
  Widget _buildAnimatedBottomFlowerGarden() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatingController, _ambientBgController]),
        builder: (context, _) {
          final sway = _floatingController.value; // 0.0 -> 1.0 -> 0.0 (3.2s cycle)
          final breeze = _ambientBgAnimation.value; // slow 14s drift

          return SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _SwayingFloralMeadowPainter(
                swayValue: sway,
                breezeValue: breeze,
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 2. HERO PURPLE INTERACTIVE GREETING BANNER
  // =========================================================================
  String _formatElderHonorific(String name) {
    if (name.contains('මහත්මිය') || name.contains('මහතා') || name.contains('මහත්මයා')) return name;
    return '$name මහත්මිය';
  }

  Widget _buildInteractiveHeroBanner(String displayName, DayPeriod period, String? avatarUrl) {
    String greetingTitle;
    const greetingSubtitle = 'අදත් ඔබගේ ක්‍රියාකාරකම් සම්පූර්ණ කරමු. ♡';
    final honorificName = _formatElderHonorific(displayName);

    switch (period) {
      case DayPeriod.morning:
        greetingTitle = 'සුබ උදෑසනක්,\n$honorificName! 👋';
        break;

      case DayPeriod.afternoon:
        greetingTitle = 'සුබ දහවලක්,\n$honorificName! 👋';
        break;

      case DayPeriod.evening:
        greetingTitle = 'සුබ සන්ධ්‍යාවක්,\n$honorificName! 👋';
        break;

      case DayPeriod.night:
        greetingTitle = 'සුබ රාත්‍රියක්,\n$honorificName! 👋';
        break;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6D28D9), // vibrant, elegant royal violet
            Color(0xFF7C3AED), // bright cheerful purple
            Color(0xFF8B5CF6), // warm radiant violet
            Color(0xFFA855F7), // soft gentle lavender purple
            Color(0xFFC084FC), // light luminous lavender glow
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: const Color(0xFFE9D5FF).withValues(alpha: 0.90),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Floral background decoration spreading from right edge
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.90,
                child: Image.asset(
                  'assets/images/banner_flowers_fade.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Animated floating sparkles
            Positioned(
              top: 14,
              left: 420,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final t = _pulseController.value;
                  return Opacity(
                    opacity: (0.3 + 0.6 * math.sin(t * math.pi)).clamp(0.0, 1.0),
                    child: const Text('✨', style: TextStyle(fontSize: 16)),
                  );
                },
              ),
            ),

            // Main Banner Content: Clean, spacious & elder-friendly
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: _buildBannerLeftGreeting(greetingTitle, greetingSubtitle, avatarUrl),
            ),
          ],
        ),
      ),
    );
  }

  // Left side of banner: Elder photo + Dynamic Greeting
  Widget _buildBannerLeftGreeting(String title, String subtitle, String? avatarUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Elder photo (circular avatar with radiant glow ring)
        Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.60),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.0),
              image: DecorationImage(
                image: _resolveAvatarImage(avatarUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Text Greeting & Audio Pill
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  height: 1.25,
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _speak('${title.replaceAll('\n', ' ')}. $subtitle ඔබ ගැන අදත් හොඳින් සලකමු!'),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.volume2, size: 14, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'සවන් දෙන්න',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
        ),
      ],
    );
  }



  // =========================================================================
  // 2.1 DAILY ROUTINE QUESTION CARDS (Placed beautifully below Welcome Banner)
  // =========================================================================
  Widget _buildDailyRoutineSection(DayPeriod period) {
    // Card 1: Meal Check
    String card1Icon = '🍲';
    String card1Question = 'දිවා ආහාරය\nගත්තාද?';
    String card1YesText = 'ගත්තා';
    String card1NoText = 'තවම නැහැ';
    String card1YesFeedback = 'ඔබ දිවා ආහාරය ගෙන තිබීම සතුටක්! නිරෝගීව හා ශක්තිමත්ව සිටින්න.';
    String card1NoFeedback = 'ඔබ තවම දිවා ආහාරය ගෙන නැත්නම්, ඔබට උදව් කිරීමට සහායකයා දැනුවත් කර ඇත.';

    // Card 2: Rest Check
    String card2Icon = '🛋️';
    String card2Question = 'කෙටි විවේකයක්\nගත්තාද?';
    String card2YesText = 'ගත්තා';
    String card2NoText = 'තවම නැහැ';
    String card2YesFeedback = 'ඉතා විශිෂ්ටයි! කෙටි විවේකයක් ගැනීමෙන් ඔබේ මනසට සහ සිරුරට නව ප්‍රබෝධයක් ලැබේ.';
    String card2NoFeedback = 'සුවදායක කෙටි විවේකයක් ලබා ගැනීමට සහායක කණ්ඩායම දැනුවත් කර ඇත.';

    switch (period) {
      case DayPeriod.morning:
        card1Icon = '🍲';
        card1Question = 'උදෑසන ආහාර\nගත්තාද?';
        card1YesFeedback = 'ඔබ උදෑසන ආහාරය ලබාගෙන තිබීම සතුටක්!';
        card1NoFeedback = 'උදෑසන ආහාරය ලබා ගැනීමට සහායකයා ඔබට උදව් කරනු ඇත.';

        card2Icon = '🛏️';
        card2Question = 'විවේක\nගත්තාද?';
        card2YesFeedback = 'ඉතා විශිෂ්ටයි! ඔබ ප්‍රබෝධමත්ව අද දවස සතුටින් ගත කිරීමට සූදානම්.';
        card2NoFeedback = 'සුවදායක කෙටි විවේකයක් ලබා ගැනීමට සහායකයා දැනුවත් කර ඇත.';
        break;

      case DayPeriod.afternoon:
        card1Icon = '🍲';
        card1Question = 'දිවා ආහාරය\nගත්තාද?';
        card1YesFeedback = 'ඔබ දිවා ආහාරය ගෙන තිබීම සතුටක්!';
        card1NoFeedback = 'ඔබ තවම දිවා ආහාරය ගෙන නැත්නම්, ඔබට උදව් කිරීමට සහායකයා දැනුවත් කර ඇත.';

        card2Icon = '🛋️';
        card2Question = 'කෙටි විවේකයක්\nගත්තාද?';
        card2YesFeedback = 'ඉතා විශිෂ්ටයි! කෙටි විවේකයක් ගැනීමෙන් නව ප්‍රබෝධයක් ලැබේ.';
        card2NoFeedback = 'සුවදායක කෙටි විවේකයක් ලබා ගැනීමට සහායකයා දැනුවත් කර ඇත.';
        break;

      case DayPeriod.evening:
        card1Icon = '☕';
        card1Question = 'සවස තේ පැන්\nපානය කළාද?';
        card1YesFeedback = 'සවස උණුසුම් තේ පැන් පානය කර තිබීම සතුටක්!';
        card1NoFeedback = 'සවස තේ පැන් ලබා ගැනීමට සහායකයා පැමිණෙනු ඇත.';

        card2Icon = '🌿';
        card2Question = 'නැවුම් සුළං\nසුවය වින්දාද?';
        card2YesFeedback = 'නැවුම් සවස සුළං සුවය විඳීම ඔබේ මනස සන්සුන් කරයි!';
        card2NoFeedback = 'සවස නැවුම් සුළං සුවය විඳීමට සහායකයා පැමිණෙනු ඇත.';
        break;

      case DayPeriod.night:
        card1Icon = '💊';
        card1Question = 'රාත්‍රී ආහාර හා\nඖෂධ ගත්තාද?';
        card1YesFeedback = 'ඉතා විශිෂ්ටයි! රාත්‍රී ආහාර සහ ඖෂධ නියමිත වේලාවට ලබා ගැනීම නීරෝගී බවට ඉතා වැදගත්.';
        card1NoFeedback = 'ඔබ තවම රාත්‍රී ආහාර හෝ ඖෂධ ගෙන නැත්නම්, සහායකයා දැනුවත් කර ඇත.';

        card2Icon = '🛏️';
        card2Question = 'සුව නින්දකට\nසූදානම්ද?';
        card2YesFeedback = 'සුවබර, සැනසිලිදායක නින්දක් ඔබට ප්‍රාර්ථනා කරනවා!';
        card2NoFeedback = 'සුව නින්දකට සූදානම් වීමට සහායකයා දැනුවත් කර ඇත.';
        break;
    }

    // Card 3: Water Check
    const card3Question = 'ප්‍රමාණවත් ජලය\nබිව්වාද?';
    const card3YesFeedback = 'ඉතා විශිෂ්ටයි! ප්‍රමාණවත් ලෙස ජලය පානය කිරීම ඔබගේ නිරෝගී සුවයට ඉතා වැදගත් වේ.';
    const card3NoFeedback = 'ජලය ප්‍රමාණවත් ලෙස පානය කිරීමට අමතක නොකරන්න. මම සහායකයාට දැන්වුවා ඔබට ජලය ගෙන එන්න.';

    final card1 = _buildMockupRoutineCard(
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE9D5FF),
      iconWidget: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA), width: 1.3),
        ),
        alignment: Alignment.center,
        child: Text(card1Icon, style: const TextStyle(fontSize: 23)),
      ),
      question: card1Question,
      isAnsweredYes: _routine1AnsweredYes,
      isAnsweredNo: _routine1AnsweredNo,
      yesButtonText: card1YesText,
      noButtonText: card1NoText,
      isWaterCard: false,
      onToggle: () {
        setState(() {
          _routine1AnsweredYes = true;
          _routine1AnsweredNo = false;
        });
        _speak('අද දින ආහාරය පිළිබඳ තොරතුරු සටහන් කරමු.');
        context.go('/dashboard/elder-meal');
      },
    );

    final card2 = _buildMockupRoutineCard(
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE9D5FF),
      iconWidget: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD), width: 1.3),
            ),
            alignment: Alignment.center,
            child: Text(card2Icon, style: const TextStyle(fontSize: 23)),
          ),
          const Positioned(
            top: -4,
            right: -4,
            child: Text('💤', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      question: card2Question,
      isAnsweredYes: _routine2AnsweredYes,
      isAnsweredNo: _routine2AnsweredNo,
      yesButtonText: card2YesText,
      noButtonText: card2NoText,
      isWaterCard: false,
      onToggle: () {
        setState(() {
          _routine2AnsweredYes = !_routine2AnsweredYes;
          _routine2AnsweredNo = !_routine2AnsweredYes;
        });
        _speak(_routine2AnsweredYes ? card2YesFeedback : card2NoFeedback);
      },
    );

    final card3 = _buildMockupRoutineCard(
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE9D5FF),
      iconWidget: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBF7D0), width: 1.3),
        ),
        alignment: Alignment.center,
        child: const Text('🥛', style: TextStyle(fontSize: 23)),
      ),
      question: card3Question,
      isAnsweredYes: _routineWaterAnsweredYes,
      isAnsweredNo: _routineWaterAnsweredNo,
      yesButtonText: 'බිව්වා',
      noButtonText: 'තවම නැහැ',
      isWaterCard: true,
      onToggle: () {
        setState(() {
          _routineWaterAnsweredYes = !_routineWaterAnsweredYes;
          _routineWaterAnsweredNo = !_routineWaterAnsweredYes;
        });
        _speak(_routineWaterAnsweredYes ? card3YesFeedback : card3NoFeedback);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;
        if (isWide) {
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 14),
              Expanded(child: card2),
              const SizedBox(width: 14),
              Expanded(child: card3),
            ],
          );
        } else {
          return Column(
            children: [
              card1,
              const SizedBox(height: 10),
              card2,
              const SizedBox(height: 10),
              card3,
            ],
          );
        }
      },
    );
  }

  Widget _buildMockupRoutineCard({
    required Widget iconWidget,
    required String question,
    required bool isAnsweredYes,
    required bool isAnsweredNo,
    required String yesButtonText,
    required String noButtonText,
    required bool isWaterCard,
    required VoidCallback onToggle,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor ??
              (isAnsweredYes
                  ? const Color(0xFFA855F7)
                  : const Color(0xFFE9D5FF)),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Squircle Icon Container
                iconWidget,
                const SizedBox(width: 12),

                // Question Text (2 lines)
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1B4B),
                      height: 1.25,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Pill Action Button
                if (isAnsweredYes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15803D), // Accessible Forest Green
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF15803D).withValues(alpha: 0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.check, size: 15, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          yesButtonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: const Color(0xFFDDD6FE), width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.clock, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 5),
                        Text(
                          noButtonText,
                          style: const TextStyle(
                            color: Color(0xFF6D28D9),
                            fontSize: 13.0,
                            fontWeight: FontWeight.w800,
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
    );
  }

  // =========================================================================
  // 3. QUICK ACCESS SECTION (EXACT REFERENCE DESIGN FOR CARDS 1 & 2)
  // =========================================================================
  Widget _buildQuickAccessSection(BuildContext context, bool isSinhala) {
    final currentSlot = _getCurrentAssessmentSlot(_now);
    final currentSlotName = _getSlotNameSi(currentSlot);
    final nextSlotTime = _getNextSlotInfoSi(currentSlot);

    final emotionalDone = _isSlotDone('emotional', currentSlot);
    final memoryDone = _isSlotDone('memory', currentSlot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title Row (Polished squircle icon + elder friendly badge)
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF3E8FF), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.calendar, size: 20, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 12),
            const Text(
              'අද දින සිදුකල යුතු ක්‍රියාකාරකම්',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E1B4B),
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                ),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.calendarDays, size: 15, color: Color(0xFF7C3AED)),
                  SizedBox(width: 6),
                  Text(
                    'දිනකට 3 වතාවක්',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final slotAction = _getSlotActionName(currentSlot);

            final assessmentCards = [
              // Card 1: මානසික ක්‍රියාකාරකම් (Interactive 3D Open Book Design with Page Flip)
              _wrapWithFloatingReminder(
                isDone: emotionalDone,
                child: _buildEmotionalOpenBookCard(
                  context: context,
                  currentSlot: currentSlot,
                  nextSlotTime: nextSlotTime,
                ),
              ),

              // Card 2: මනස පරීක්ෂණ ක්‍රියාකාරකම් (Interactive 3D Open Book Design with Page Flip)
              _wrapWithFloatingReminder(
                isDone: memoryDone,
                child: _buildMemoryOpenBookCard(
                  context: context,
                  currentSlot: currentSlot,
                  nextSlotTime: nextSlotTime,
                ),
              ),
            ];

            final leisureCards = [
              // Card 1: පොත් කියවීම (Reading Books - Exact Mockup)
              _buildMockupLeisureCard(
                leadingIcon: const Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED), size: 36),
                title: 'පොත් කියවීම',
                subtitle: 'හිත සැනසෙන කියවීමේ කාලයක්.',
                illustration: _buildStackedBooksIllustration(),
                buttonText: 'පොත් කියවන්න',
                onTap: () {
                  _showReadingLibraryModal(context);
                },
              ),

              // Card 2: නිර්මාණාත්මක ක්‍රියාකාරකම් (Creative Activities - Exact Mockup)
              _buildMockupLeisureCard(
                leadingIcon: const Text('🎨', style: TextStyle(fontSize: 34)),
                title: 'නිර්මාණාත්මක ක්‍රියාකාරකම්',
                subtitle: 'ඔබගේ නිර්මාණශීලීත්වය පුළුල් කරයි.',
                illustration: _buildEaselPaintingIllustration(),
                buttonText: 'නිර්මාණය කරන්න',
                onTap: () {
                  _showCreativeActivitiesModal(context);
                },
              ),

              // Card 3: සංගීතය සහ රසවින්දනය (Music & Enjoyment - Exact Mockup)
              _buildMockupLeisureCard(
                leadingIcon: const Icon(Icons.headphones_rounded, color: Color(0xFF7C3AED), size: 34),
                title: 'සංගීතය සහ රසවින්දනය',
                subtitle: 'සුවදායක සංගීතයෙන් සිත සනසන්න.',
                illustration: _buildMusicalNotesIllustration(),
                buttonText: 'සංගීතය අහන්න',
                onTap: () {
                  _speak('සන්සුන් සංගීතය සහ රසවින්දනය ඔබ වෙනුවෙන් වාදනය කරමු.');
                  _showMusicPlayerModal(context);
                },
              ),
            ];

            final isDesktopWide = constraints.maxWidth >= 950;
            final isTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 950;
            final rowSpacing = constraints.maxWidth >= 1000 ? 28.0 : 22.0;

            if (isDesktopWide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1 (Top Assessment Cards): Exact Mockup Side-by-Side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: assessmentCards[0]),
                      const SizedBox(width: 38),
                      Expanded(child: assessmentCards[1]),
                    ],
                  ),
                  SizedBox(height: rowSpacing + 8),

                  // Section Heading: නිදහසේ කාලය ගත කරන්න කැමතිද? [මගේ කැමැත්ත තෝරන්න]
                  _buildLeisureSectionHeader(isSinhala),
                  const SizedBox(height: 18),

                  // Leisure Row: All 3 cards side-by-side in exact reference mockup layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leisureCards[0]),
                      const SizedBox(width: 18),
                      Expanded(child: leisureCards[1]),
                      const SizedBox(width: 18),
                      Expanded(child: leisureCards[2]),
                    ],
                  ),
                ],
              );
            } else if (isTablet) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: assessmentCards[0]),
                      const SizedBox(width: 28),
                      Expanded(child: assessmentCards[1]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLeisureSectionHeader(isSinhala),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leisureCards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: leisureCards[1]),
                    ],
                  ),
                  const SizedBox(height: 18),
                  leisureCards[2],
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  assessmentCards[0],
                  const SizedBox(height: 20),
                  assessmentCards[1],
                  const SizedBox(height: 24),
                  _buildLeisureSectionHeader(isSinhala),
                  const SizedBox(height: 16),
                  ...leisureCards.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: c,
                      )),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  // =========================================================================
  // LEISURE & RELAXATION SECTION HEADER ("අද නිදහසේ කාලය ගත කරන්න කැමතිද?")
  // =========================================================================
  Widget _buildLeisureSectionHeader(bool isSinhala) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDCFCE7), Color(0xFFD1FAE5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.sparkles, size: 20, color: Color(0xFF059669)),
            ),
            Text(
              isSinhala
                  ? 'නිදහසේ කාලය ගත කරන්න කැමතිද?'
                  : 'Would you like to relax today?',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E1B4B),
                letterSpacing: -0.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                isSinhala ? 'මගේ කැමැත්ත තෝරන්න' : 'Choose Your Preference',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isSinhala
              ? 'දිනපතා විනෝදයෙන්, සතුටින් සහ නිරෝගීව සිටීමට ඔබ කැමති ක්‍රියාකාරකම් තෝරන්න.'
              : 'Choose the activities you love to stay joyful, happy, and healthy every day.',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // GENTLE UP-AND-DOWN FLOATING REMINDER FOR INCOMPLETE ASSESSMENT CARDS
  // =========================================================================
  Widget _wrapWithFloatingReminder({
    required Widget child,
    required bool isDone,
  }) {
    if (isDone) {
      // Completed cards rest calmly at normal position
      return child;
    }

    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: _floatingController,
          curve: Curves.easeInOutSine,
        ).value;
        // Smoothly floats up and down by 6.0 pixels to catch the elder's eye and remind them
        final offsetY = -6.0 * progress;
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: child,
        );
      },
    );
  }

  // =========================================================================
  // PURPLE BOTANICAL CORNER SPRIG (Matching Mockup)
  // =========================================================================
  Widget _buildPurpleCornerSprig({required bool isLeft}) {
    return CustomPaint(
      size: const Size(38, 38),
      painter: _PurpleBotanicalCornerPainter(isLeft: isLeft),
    );
  }

  // =========================================================================
  // TOP ROW: 3D INTERACTIVE OPEN BOOK ASSESSMENT CARDS (EXACT REFERENCE MOCKUP)
  // =========================================================================

  // Book 1: මානසික ක්‍රියාකාරකම් Open Book
  Widget _buildEmotionalOpenBookCard({
    required BuildContext context,
    required DailyAssessmentSlot currentSlot,
    required String nextSlotTime,
  }) {
    final activeSlot = _selectedEmotionalSlot ?? currentSlot;
    final isDone = _isSlotDone('emotional', activeSlot);

    String slotTitle;
    String timeText;
    List<String> checklist;

    switch (activeSlot) {
      case DailyAssessmentSlot.morning:
        slotTitle = 'උදෑසන ක්‍රියාකාරකම්';
        timeText = 'පෙ.ව. 6.00 – 10.00';
        checklist = [
          'හෙමින් හුස්ම ගැනීම (Breathing Exercise)',
          'සිතැඟි විඳිමු',
          'හොඳ අදහස් සටහන් කිරීම',
        ];
        break;
      case DailyAssessmentSlot.afternoon:
        slotTitle = 'දහවල් ක්‍රියාකාරකම්';
        timeText = 'ප.ව. 10.00 – 4.00';
        checklist = [
          'දිවා විවේක සුවය හා සංසුන් බව',
          'සංගීත චිකිත්සාව (Music Therapy)',
          'මනස ප්‍රබෝධමත් කරන කෙටි ක්‍රියාකාරකම්',
        ];
        break;
      case DailyAssessmentSlot.night:
        slotTitle = 'රාත්‍රී ක්‍රියාකාරකම්';
        timeText = 'ප.ව. 4.00 – 9.00';
        checklist = [
          'සුවබර නින්දට සූදානම් වීම',
          'කෘතඥතා මෙනෙහි කිරීම',
          'රාත්‍රී සන්සුන් භාවනා',
        ];
        break;
    }

    final buttonText = isDone
        ? 'සම්පූර්ණයි ($nextSlotTime ට) ⏰'
        : 'මෙම වේලාවේ ක්‍රියාකාරකම් බලන්න';

    return _buildOpenBookFrame(
      coverGradient: const [
        Color(0xFFA78BFA), // Soft luminous Lavender-Violet (elder-friendly & matches page)
        Color(0xFF8B5CF6),
        Color(0xFF7C3AED),
      ],
      bindingGradient: const [
        Color(0xFFEDE9FE), // Soft Lavender Casing
        Color(0xFFDDD6FE),
      ],
      bindingBorderColor: const Color(0xFFC4B5FD),
      buttonGradient: const [
        Color(0xFF8B5CF6),
        Color(0xFF7C3AED),
      ],
      buttonLeadingIcon: const Icon(Icons.psychology_rounded, color: Colors.white, size: 16),
      coverIcon: const Icon(Icons.psychology_rounded, size: 28, color: Colors.white),
      coverTitleLines: const ['මානසික', 'ක්‍රියාකාරකම්'],
      coverSubtitle: 'ඔබගේ මානසික\nසුවය වර්ධනය කරයි.',
      coverBottomWidget: Text(
        '♡',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
      selectedSlot: activeSlot,
      currentSlot: currentSlot,
      onSlotChanged: (newSlot) {
        setState(() {
          _selectedEmotionalSlot = newSlot;
        });
        _speak(newSlot == DailyAssessmentSlot.morning
            ? 'උදෑසන මානසික ක්‍රියාකාරකම් පිටුවට පෙරළුවා.'
            : (newSlot == DailyAssessmentSlot.afternoon
                ? 'දහවල් මානසික ක්‍රියාකාරකම් පිටුවට පෙරළුවා.'
                : 'රාත්‍රී මානසික ක්‍රියාකාරකම් පිටුවට පෙරළුවා.'));
      },
      pageKey: ValueKey('emotional_$activeSlot'),
      pageIllustration: _buildGrandmaMeditationAvatar(),
      pageSlotTitle: slotTitle,
      pageTimeText: timeText,
      pageChecklist: checklist,
      buttonText: buttonText,
      onButtonPressed: () {
        if (isDone) {
          _showSessionAlreadyCompletedDialog(
            context: context,
            activityTitle: 'මානසික ක්‍රියාකාරකම්',
            activityKey: 'emotional',
            slot: activeSlot,
            onContinueAnyway: () {
              context.go('/dashboard/emotional');
            },
          );
        } else {
          _markSessionCompleted('emotional', activeSlot);
          _speak('මානසික ක්‍රියාකාරකම් වෙත ඔබව සාදරයෙන් පිළිගන්නවා.');
          context.go('/dashboard/emotional');
        }
      },
    );
  }

  // Book 2: මනස පරීක්ෂණ ක්‍රියාකාරකම් Open Book
  Widget _buildMemoryOpenBookCard({
    required BuildContext context,
    required DailyAssessmentSlot currentSlot,
    required String nextSlotTime,
  }) {
    final activeSlot = _selectedMemorySlot ?? currentSlot;
    final isDone = _isSlotDone('memory', activeSlot);

    String slotTitle;
    String timeText;
    List<String> checklist;

    switch (activeSlot) {
      case DailyAssessmentSlot.morning:
        slotTitle = 'උදෑසන මනස ක්‍රියාකාරකම්';
        timeText = 'පෙ.ව. 6.00 – 10.00';
        checklist = [
          'පද මාලා (Word Puzzle)',
          'මතක ශක්තිය පරීක්ෂණ ක්‍රීඩා',
          'ලොජික් ප්‍රශ්න (Brain Quiz)',
        ];
        break;
      case DailyAssessmentSlot.afternoon:
        slotTitle = 'දහවල් මනස ක්‍රියාකාරකම්';
        timeText = 'ප.ව. 10.00 – 4.00';
        checklist = [
          'රූප ගැලපුම් ක්‍රීඩාව (Pattern Match)',
          'අංක සහ රටා හඳුනාගැනීම',
          'අවධානය යොමුකිරීමේ ක්‍රීඩා',
        ];
        break;
      case DailyAssessmentSlot.night:
        slotTitle = 'රාත්‍රී මනස ක්‍රියාකාරකම්';
        timeText = 'ප.ව. 4.00 – 9.00';
        checklist = [
          'දවසේ මතකය ආවර්ජනය',
          'සරල වචන ප්‍රහේලිකා',
          'සන්සුන් මනෝ ක්‍රීඩා',
        ];
        break;
    }

    final buttonText = isDone
        ? 'සම්පූර්ණයි ($nextSlotTime ට) ⏰'
        : 'මෙම වේලාවේ ක්‍රීඩා බලන්න';

    return _buildOpenBookFrame(
      coverGradient: const [
        Color(0xFF60A5FA), // Cheerful, soft Sky & Cornflower Blue (elder-friendly)
        Color(0xFF3B82F6),
        Color(0xFF2563EB),
      ],
      bindingGradient: const [
        Color(0xFFEFF6FF), // Soft Sky Casing
        Color(0xFFDBEAFE),
      ],
      bindingBorderColor: const Color(0xFFBAE6FD),
      buttonGradient: const [
        Color(0xFF3B82F6),
        Color(0xFF2563EB),
      ],
      buttonLeadingIcon: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 16),
      coverIcon: const Icon(Icons.extension_rounded, size: 26, color: Colors.white),
      coverTitleLines: const ['මනස', 'පරීක්ෂණ', 'ක්‍රියාකාරකම්'],
      coverSubtitle: 'මනස හා අවධානය\nවර්ධනය කරයි.',
      coverBottomWidget: Icon(
        Icons.sports_esports_rounded,
        size: 24,
        color: Colors.white.withValues(alpha: 0.85),
      ),
      selectedSlot: activeSlot,
      currentSlot: currentSlot,
      onSlotChanged: (newSlot) {
        setState(() {
          _selectedMemorySlot = newSlot;
        });
        _speak(newSlot == DailyAssessmentSlot.morning
            ? 'උදෑසන මනස ක්‍රීඩා පිටුවට පෙරළුවා.'
            : (newSlot == DailyAssessmentSlot.afternoon
                ? 'දහවල් මනස ක්‍රීඩා පිටුවට පෙරළුවා.'
                : 'රාත්‍රී මනස ක්‍රීඩා පිටුවට පෙරළුවා.'));
      },
      pageKey: ValueKey('memory_$activeSlot'),
      pageIllustration: _buildCrosswordLightbulbIllustrationExact(),
      pageSlotTitle: slotTitle,
      pageTimeText: timeText,
      pageChecklist: checklist,
      buttonText: buttonText,
      onButtonPressed: () {
        if (isDone) {
          _showSessionAlreadyCompletedDialog(
            context: context,
            activityTitle: 'මනස පරීක්ෂණ ක්‍රියාකාරකම්',
            activityKey: 'memory',
            slot: activeSlot,
            onContinueAnyway: () {
              context.go('/dashboard/memory-games');
            },
          );
        } else {
          _markSessionCompleted('memory', activeSlot);
          _speak('මනස පරීක්ෂණ ක්‍රියාකාරකම් පිටුවට යමු.');
          context.go('/dashboard/memory-games');
        }
      },
    );
  }

  // Master 3D Open Book Frame Widget
  Widget _buildOpenBookFrame({
    required Widget coverIcon,
    required List<String> coverTitleLines,
    required String coverSubtitle,
    required Widget coverBottomWidget,
    required DailyAssessmentSlot selectedSlot,
    required DailyAssessmentSlot currentSlot,
    required ValueChanged<DailyAssessmentSlot> onSlotChanged,
    required Key pageKey,
    required Widget pageIllustration,
    required String pageSlotTitle,
    required String pageTimeText,
    required List<String> pageChecklist,
    required String buttonText,
    required VoidCallback onButtonPressed,
    List<Color>? coverGradient,
    List<Color>? bindingGradient,
    Color? bindingBorderColor,
    List<Color>? buttonGradient,
    Widget? buttonLeadingIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hardcover Outer Binding Frame
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: bindingGradient ?? const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: bindingBorderColor ?? const Color(0xFFC4B5FD),
                  width: 2.2,
                ),
              ),
            ),
          ),

          // Layered 3D Paper Stack Edge & Spine Arch Curvature effect at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 12,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BookSpineArchPainter(
                spineRatio: 0.38,
                casingColor: bindingBorderColor ?? const Color(0xFF7C3AED),
              ),
            ),
          ),

          // Open Two-Page Spread (Left Purple Cover Page + Right Cream/White Page)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT PAGE (Cover / Theme page - 38% width)
                    Expanded(
                      flex: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: coverGradient ?? const [
                              Color(0xFF8B5CF6),
                              Color(0xFF7C3AED),
                              Color(0xFF6D28D9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Crease / gutter shadow on right edge of left page
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              width: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.06),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                            // Corner flourish
                            Positioned(
                              top: 8,
                              left: 8,
                              child: _buildBookCornerFlourish(),
                            ),
                            // Bottom-left Botanical leaves flourish (Matching Mockup)
                            const Positioned(
                              bottom: 4,
                              left: 6,
                              child: Text('🌿', style: TextStyle(fontSize: 19)),
                            ),
                            // Cover Contents
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Glowing Circular Badge
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.40),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: coverIcon,
                                  ),
                                  const SizedBox(height: 6),

                                  // Title Lines
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: coverTitleLines.map((line) {
                                      return Text(
                                        line,
                                        style: const TextStyle(
                                          fontSize: 18.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                          height: 1.15,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 6),

                                  // Subtitle
                                  Text(
                                    coverSubtitle,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.88),
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Bottom Accent
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: coverBottomWidget,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // RIGHT PAGE (Interactive Content & Flipping Page - 62% width)
                    Expanded(
                      flex: 62,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFF9F7FF),
                              Colors.white,
                              Color(0xFFFCFAFF),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Left edge crease shadow from spine
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              width: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.05),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                            // Content on Right Page
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Top Slot Pills (☀️ උදෑසන | 🌤️ දවල් | 🌙 රාත්‍රී)
                                  _buildBookSlotTabBar(
                                    selectedSlot: selectedSlot,
                                    currentSlot: currentSlot,
                                    onSlotChanged: onSlotChanged,
                                  ),
                                  const SizedBox(height: 10),

                                  // Animated 3D Page Turn Content with Dynamic Paper Lighting Shadow
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 420),
                                    transitionBuilder: (child, animation) {
                                      final flipAnimation = Tween<double>(
                                        begin: math.pi / 2.2,
                                        end: 0.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeInOutCubic,
                                        ),
                                      );
                                      return AnimatedBuilder(
                                        animation: flipAnimation,
                                        child: child,
                                        builder: (context, child) {
                                          final shadowAlpha = (flipAnimation.value / (math.pi / 2.2)) * 0.22;
                                          return Transform(
                                            transform: Matrix4.identity()
                                              ..setEntry(3, 2, 0.0014)
                                              ..rotateY(flipAnimation.value),
                                            alignment: Alignment.centerLeft,
                                            child: Stack(
                                              children: [
                                                child!,
                                                if (shadowAlpha > 0.01)
                                                  Positioned.fill(
                                                    child: IgnorePointer(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors.black.withValues(alpha: shadowAlpha),
                                                              Colors.black.withValues(alpha: shadowAlpha * 0.25),
                                                              Colors.transparent,
                                                            ],
                                                            begin: Alignment.centerLeft,
                                                            end: Alignment.centerRight,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: KeyedSubtree(
                                      key: pageKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Middle Row: Illustration + Checklist
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              pageIllustration,
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      pageSlotTitle,
                                                      style: const TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: Color(0xFF1E1B4B),
                                                        letterSpacing: -0.1,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.access_time_rounded,
                                                          size: 12,
                                                          color: Color(0xFF64748B),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          pageTimeText,
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: Color(0xFF64748B),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ...pageChecklist.map(_buildBookChecklistItem),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          // Bottom Action Pill Button
                                          Center(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: onButtonPressed,
                                                borderRadius: BorderRadius.circular(99),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: buttonGradient ?? const [Color(0xFF6D28D9), Color(0xFF7C3AED)],
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(99),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: (buttonGradient?.first ?? const Color(0xFF6D28D9)).withValues(alpha: 0.35),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      if (buttonLeadingIcon != null) ...[
                                                        buttonLeadingIcon,
                                                        const SizedBox(width: 6),
                                                      ],
                                                      Text(
                                                        buttonText,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      const Icon(
                                                        Icons.arrow_forward_rounded,
                                                        color: Colors.white,
                                                        size: 15,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
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
                  ],
                ),
              ),
            ),
          ),

          // Golden Ribbon Bookmark at top spine junction
          Positioned(
            top: -2,
            left: 0,
            right: 0,
            child: Align(
              alignment: const Alignment(-0.24, 0), // At the 38% spine fold
              child: CustomPaint(
                size: const Size(20, 30),
                painter: _RibbonBookmarkPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Top Slot Tab Bar for the Right Page of the Book
  Widget _buildBookSlotTabBar({
    required DailyAssessmentSlot selectedSlot,
    required DailyAssessmentSlot currentSlot,
    required ValueChanged<DailyAssessmentSlot> onSlotChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBookSlotTabItem(
              label: 'උදෑසන',
              icon: '☀️',
              isSelected: selectedSlot == DailyAssessmentSlot.morning,
              onTap: () => onSlotChanged(DailyAssessmentSlot.morning),
            ),
          ),
          Expanded(
            child: _buildBookSlotTabItem(
              label: 'දවල්',
              icon: '🌤️',
              isSelected: selectedSlot == DailyAssessmentSlot.afternoon,
              onTap: () => onSlotChanged(DailyAssessmentSlot.afternoon),
            ),
          ),
          Expanded(
            child: _buildBookSlotTabItem(
              label: 'රාත්‍රී',
              icon: '🌙',
              isSelected: selectedSlot == DailyAssessmentSlot.night,
              onTap: () => onSlotChanged(DailyAssessmentSlot.night),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookSlotTabItem({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Checklist Item with Green Circular Checkmark
  Widget _buildBookChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, size: 10, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                height: 1.25,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Card 1 Avatar: Cheerful Grandma in Meditation with Green Leaves (Matching Mockup)
  Widget _buildGrandmaMeditationAvatar() {
    return SizedBox(
      width: 80,
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: -4,
            bottom: 12,
            child: Text('🌿', style: TextStyle(fontSize: 20)),
          ),
          const Positioned(
            right: -4,
            bottom: 12,
            child: Text('🌿', style: TextStyle(fontSize: 20)),
          ),
          CustomPaint(
            size: const Size(62, 72),
            painter: _GrandmaAvatarPainter(),
          ),
          // Floating Pink Hearts next to Grandma (Matching Mockup)
          const Positioned(
            right: 0,
            top: 10,
            child: Text('💖', style: TextStyle(fontSize: 14)),
          ),
          const Positioned(
            right: -6,
            top: 24,
            child: Text('💕', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // Corner Flourish for Book Cover Page
  Widget _buildBookCornerFlourish() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _BookCornerFlourishPainter(),
      ),
    );
  }

  // =========================================================================
  // ILLUSTRATIONS & DECORATIONS
  // =========================================================================

  // Card 1: Smiling Grandmother with Glasses & Floating Pink Hearts (Exact Mockup Match)
  Widget _buildGrandmaIllustrationExact() {
    return SizedBox(
      width: 95,
      height: 85,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft radial purple glow
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFC084FC).withValues(alpha: 0.28),
                  const Color(0xFFFAF5FF).withValues(alpha: 0.04),
                ],
              ),
            ),
          ),
          // Custom Vector Grandmother Avatar (compact size)
          CustomPaint(
            size: const Size(68, 76),
            painter: _GrandmaAvatarPainter(),
          ),
          // Floating Pink Hearts around Grandma (matching mockup)
          const Positioned(
            top: 4,
            left: -4,
            child: Text('💖', style: TextStyle(fontSize: 14)),
          ),
          const Positioned(
            top: 26,
            left: -8,
            child: Text('💕', style: TextStyle(fontSize: 12)),
          ),
          const Positioned(
            top: 4,
            right: -4,
            child: Text('💖', style: TextStyle(fontSize: 14)),
          ),
          const Positioned(
            top: 26,
            right: -8,
            child: Text('💕', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Card 2: 3D Crossword Puzzle Board with Glowing Lightbulb & Pencil (Compact)
  Widget _buildCrosswordLightbulbIllustrationExact() {
    return SizedBox(
      width: 98,
      height: 85,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Wooden Easel Crossword Board
          Positioned(
            left: 12,
            top: 10,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                width: 62,
                height: 66,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A), // warm wood frame
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                  ),
                  child: Column(
                    children: [
                      _buildCrosswordRow([true, false, true, false]),
                      _buildCrosswordRow([false, true, false, true]),
                      _buildCrosswordRow([true, true, false, false]),
                      _buildCrosswordRow([false, false, true, true]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Glowing Lightbulb on top right of the board
          Positioned(
            right: 8,
            top: -4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.65),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                const Text('💡', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),

          // Green leaves sprouting on right
          const Positioned(
            right: 0,
            bottom: 14,
            child: Text('🌿', style: TextStyle(fontSize: 18)),
          ),

          // Pencil leaning on the crossword board on bottom right (matching mockup)
          Positioned(
            right: 10,
            bottom: 2,
            child: Transform.rotate(
              angle: 0.35,
              child: const Text('✏️', style: TextStyle(fontSize: 22)),
            ),
          ),

          // 3D Purple Puzzle Piece leaning on bottom left
          Positioned(
            left: 0,
            bottom: 2,
            child: Transform.rotate(
              angle: -0.15,
              child: const Text('🧩', style: TextStyle(fontSize: 24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrosswordRow(List<bool> isBlack) {
    return Expanded(
      child: Row(
        children: isBlack.map((black) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.all(0.8),
              decoration: BoxDecoration(
                color: black ? const Color(0xFF334155) : Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Card 1 Bottom Hibiscus Blossom Trim (matching Card 1's soft rose color scheme)
  Widget _buildCard1HibiscusBlossomTrim() {
    return Container(
      height: 42,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFAF5FF),
            Color(0xFFF3E8FF),
            Color(0xFFE9D5FF),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Soft rose wavy hill in background
          Positioned(
            left: -20,
            right: -20,
            bottom: -22,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFDA4AF).withValues(alpha: 0.18),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(120),
                  topRight: Radius.circular(140),
                ),
              ),
            ),
          ),
          // Left blossom cluster
          const Positioned(
            left: 12,
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🌿', style: TextStyle(fontSize: 14)),
                SizedBox(width: 3),
                Text('🌺', style: TextStyle(fontSize: 22)),
                SizedBox(width: 3),
                Text('🌸', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          // Right blossom cluster
          const Positioned(
            right: 12,
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🌸', style: TextStyle(fontSize: 16)),
                SizedBox(width: 3),
                Text('🌺', style: TextStyle(fontSize: 24)),
                SizedBox(width: 3),
                Text('🌿', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 2 Bottom Golden Amber Trim (matching Card 2's warm color scheme)
  Widget _buildCard2GoldenAmberTrim() {
    return Container(
      height: 42,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFBEB), // warm butter cream
            Color(0xFFFEF3C7), // soft pastel amber
            Color(0xFFFDE68A), // warm golden tone
          ],
        ),
      ),
      child: Stack(
        children: [
          // Soft golden wavy hill in background
          Positioned(
            left: -20,
            right: -20,
            bottom: -22,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(120),
                  topRight: Radius.circular(140),
                ),
              ),
            ),
          ),
          // Left golden cluster
          const Positioned(
            left: 12,
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🌿', style: TextStyle(fontSize: 14)),
                SizedBox(width: 3),
                Text('🌻', style: TextStyle(fontSize: 22)),
                SizedBox(width: 3),
                Text('🍁', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          // Right golden cluster
          const Positioned(
            right: 12,
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🍂', style: TextStyle(fontSize: 16)),
                SizedBox(width: 3),
                Text('🌻', style: TextStyle(fontSize: 23)),
                SizedBox(width: 3),
                Text('🌿', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 3: 3D Headphones with Musical Notes
  Widget _buildHeadphonesMusicIllustration() {
    return SizedBox(
      width: 90,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.30),
                  const Color(0xFFCCFBF1).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🎧', style: TextStyle(fontSize: 32)),
          ),
          const Positioned(
            top: -2,
            left: 4,
            child: Text('🎵', style: TextStyle(fontSize: 17)),
          ),
          const Positioned(
            top: 2,
            right: 0,
            child: Text('🎶', style: TextStyle(fontSize: 19)),
          ),
          const Positioned(
            bottom: 6,
            right: 2,
            child: Text('✨', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Card 4: Caregiver with Headset & Speech Bubble
  Widget _buildCaregiverWithHeadsetIllustration() {
    return SizedBox(
      width: 90,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  const Color(0xFFE0F2FE).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              color: const Color(0xFFE0F2FE),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/landing/caregivers_team.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('👩‍⚕️', style: TextStyle(fontSize: 34)),
                ),
              ),
            ),
          ),
          Positioned(
            top: -4,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Text('💬', style: TextStyle(fontSize: 13)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.headphones, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Card 3 Bottom Park Landscape
  Widget _buildParkNatureLandscape() {
    return Container(
      height: 125,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0F2FE),
            Color(0xFFBBF7D0),
            Color(0xFF4ADE80),
            Color(0xFF16A34A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 10,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDE047).withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -20,
            right: -20,
            bottom: -30,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF86EFAC).withValues(alpha: 0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(160),
                  topRight: Radius.circular(140),
                ),
              ),
            ),
          ),
          Positioned(
            left: -10,
            right: -10,
            bottom: -35,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF15803D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(130),
                  topRight: Radius.circular(160),
                ),
              ),
            ),
          ),
          const Positioned(
            right: 18,
            bottom: 12,
            child: Text('🌳', style: TextStyle(fontSize: 42)),
          ),
          Positioned(
            left: 45,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF78350F),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.armchair, size: 15, color: Color(0xFFFEF3C7)),
                  SizedBox(width: 4),
                  Text(
                    'විවේක බංකුව',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFEF3C7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 4 Bottom Cottage Meadow Landscape
  Widget _buildCottageMeadowLandscape() {
    return Container(
      height: 125,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0F2FE),
            Color(0xFFBAE6FD),
            Color(0xFF86EFAC),
            Color(0xFF15803D),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 20,
            top: 10,
            child: Text('☁️', style: TextStyle(fontSize: 20)),
          ),
          Positioned(
            left: -20,
            right: -20,
            bottom: -30,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(150),
                  topRight: Radius.circular(150),
                ),
              ),
            ),
          ),
          Positioned(
            left: -10,
            right: -10,
            bottom: -35,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(140),
                  topRight: Radius.circular(160),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 36,
            bottom: 12,
            child: Text('🏡', style: TextStyle(fontSize: 38)),
          ),
          const Positioned(
            right: 32,
            bottom: 14,
            child: Text('🌲', style: TextStyle(fontSize: 36)),
          ),
        ],
      ),
    );
  }


  // =========================================================================
  // LEISURE SECTION CARDS: EXACT REFERENCE MOCKUP DESIGN
  // =========================================================================

  // Mockup Leisure Card Widget (Exact Mockup Match)
  Widget _buildMockupLeisureCard({
    required Widget leadingIcon,
    required String title,
    required String subtitle,
    required Widget illustration,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9D5FF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Leading Icon + Title & Subtitle + Illustration
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leadingIcon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E1B4B),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              illustration,
            ],
          ),
          const SizedBox(height: 16),

          // Bottom: Centered Royal Purple Action Pill Button
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 1 Illustration: 3 Stacked Books (Coral Pink, Soft Blue, Teal Green - Exact Mockup)
  Widget _buildStackedBooksIllustration() {
    return SizedBox(
      width: 58,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottom Book (Teal Green)
          Positioned(
            bottom: 3,
            child: Container(
              width: 52,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(width: 5, color: const Color(0xFF115E59)),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      color: const Color(0xFFF0FDFA),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Middle Book (Soft Sky Blue)
          Positioned(
            bottom: 16,
            child: Container(
              width: 48,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(width: 5, color: const Color(0xFF0284C7)),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      color: const Color(0xFFF0F9FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Top Book (Coral Pink)
          Positioned(
            bottom: 29,
            child: Container(
              width: 44,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(width: 5, color: const Color(0xFFBE123C)),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      color: const Color(0xFFFFF1F2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 2 Illustration: Easel with Landscape Painting (Exact Mockup)
  Widget _buildEaselPaintingIllustration() {
    return SizedBox(
      width: 48,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tripod Legs
          Positioned(
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.22,
                  child: Container(width: 3, height: 34, color: const Color(0xFFD97706)),
                ),
                const SizedBox(width: 18),
                Transform.rotate(
                  angle: 0.22,
                  child: Container(width: 3, height: 34, color: const Color(0xFFD97706)),
                ),
              ],
            ),
          ),
          // Center Mast
          Positioned(
            top: 2,
            child: Container(width: 3.5, height: 42, color: const Color(0xFFB45309)),
          ),
          // Shelf
          Positioned(
            bottom: 12,
            child: Container(
              width: 42,
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFF92400E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Canvas Painting (Sun & Green Mountains)
          Positioned(
            top: 7,
            child: Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFBAE6FD),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.5),
                child: Stack(
                  children: [
                    // Sun
                    Positioned(
                      top: 3,
                      left: 5,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBBF24),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Green Mountain
                    Positioned(
                      bottom: -5,
                      left: -2,
                      right: -2,
                      child: Container(
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -6,
                      right: 1,
                      child: Container(
                        width: 18,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF059669),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 3 Illustration: Floating Musical Notes (Exact Mockup)
  Widget _buildMusicalNotesIllustration() {
    return const SizedBox(
      width: 44,
      height: 46,
      child: Stack(
        children: [
          Positioned(
            top: 2,
            left: 2,
            child: Text('🎵', style: TextStyle(fontSize: 20)),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Text('🎶', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }

  // Card 1 Illustration: Grandma Reading Book in Armchair with Bookshelf & Table Lamp
  Widget _buildGrandmaReadingBookIllustration() {
    return SizedBox(
      height: 105,
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: [
          // Background soft purple aura
          Positioned(
            right: 8,
            top: 10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE9D5FF).withValues(alpha: 0.40),
              ),
            ),
          ),
          // Bookshelf on far right
          Positioned(
            right: 2,
            top: 8,
            child: Container(
              width: 36,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFD4A373).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBC6C25), width: 1.2),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(width: 5, height: 22, color: const Color(0xFF2563EB)),
                      Container(width: 5, height: 20, color: const Color(0xFFDC2626)),
                      Container(width: 5, height: 23, color: const Color(0xFF16A34A)),
                      Container(width: 5, height: 19, color: const Color(0xFFEAB308)),
                    ],
                  ),
                  Container(height: 1.5, color: const Color(0xFFBC6C25)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(width: 5, height: 19, color: const Color(0xFF9333EA)),
                      Container(width: 5, height: 22, color: const Color(0xFFEA580C)),
                      Container(width: 5, height: 20, color: const Color(0xFF0284C7)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Warm Table Lamp on left
          Positioned(
            right: 76,
            top: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDE047),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFDE047),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Container(width: 2.5, height: 16, color: const Color(0xFF78350F)),
                Container(width: 14, height: 3, decoration: BoxDecoration(color: const Color(0xFF78350F), borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
          // Grandmother sitting & reading red book
          Positioned(
            right: 22,
            bottom: 2,
            child: SizedBox(
              width: 72,
              height: 86,
              child: CustomPaint(
                painter: _GrandmaReadingPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 2 Illustration: Grandma Painting Purple Flowers on Wooden Easel
  Widget _buildGrandmaPaintingArtIllustration() {
    return SizedBox(
      height: 105,
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: [
          // Background warm amber aura
          Positioned(
            right: 8,
            top: 10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.40),
              ),
            ),
          ),
          // Artist Easel with Canvas painting
          Positioned(
            right: 2,
            bottom: 2,
            child: SizedBox(
              width: 54,
              height: 86,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(left: 6, bottom: 0, top: 10, child: Container(width: 3, color: const Color(0xFF9A3412))),
                  Positioned(right: 6, bottom: 0, top: 10, child: Container(width: 3, color: const Color(0xFF9A3412))),
                  Positioned(left: 25, bottom: 0, top: 0, child: Container(width: 3.5, color: const Color(0xFF7C2D12))),
                  Positioned(
                    top: 12,
                    child: Container(
                      width: 44,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFB45309), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            bottom: 2,
                            child: Container(width: 2.5, height: 26, color: const Color(0xFF16A34A)),
                          ),
                          const Positioned(
                            top: 4,
                            child: Text('🌸', style: TextStyle(fontSize: 16)),
                          ),
                          const Positioned(
                            top: 14,
                            left: 2,
                            child: Text('🪻', style: TextStyle(fontSize: 12)),
                          ),
                          const Positioned(
                            top: 14,
                            right: 2,
                            child: Text('🪻', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 66,
                    child: Container(
                      width: 50,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF78350F),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grandmother painting with brush
          Positioned(
            right: 44,
            bottom: 2,
            child: SizedBox(
              width: 68,
              height: 86,
              child: CustomPaint(
                painter: _GrandmaPaintingPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 3 Illustration: Elder with Headphones & Floating Musical Notes
  Widget _buildElderListeningMusicIllustration() {
    return SizedBox(
      height: 105,
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: [
          // Soft puffy blue cloud in background
          Positioned(
            right: 6,
            top: 14,
            child: Container(
              width: 86,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE).withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: 4,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE0F2FE).withValues(alpha: 0.80),
              ),
            ),
          ),
          // Floating purple & magenta musical notes
          const Positioned(
            right: 76,
            top: 10,
            child: Text('🎵', style: TextStyle(fontSize: 18, color: Color(0xFF9333EA))),
          ),
          const Positioned(
            right: 84,
            top: 36,
            child: Text('🎶', style: TextStyle(fontSize: 16, color: Color(0xFFEC4899))),
          ),
          const Positioned(
            right: 12,
            top: 6,
            child: Text('🎵', style: TextStyle(fontSize: 14, color: Color(0xFF0284C7))),
          ),
          // Elder wearing modern headphones
          Positioned(
            right: 12,
            bottom: 2,
            child: SizedBox(
              width: 74,
              height: 88,
              child: CustomPaint(
                painter: _ElderListeningMusicPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 1 Floral Trim (Lavender with Hibiscus Blossoms)
  Widget _buildLavenderBlossomTrim() {
    return Container(
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
        ),
        border: Border(
          top: BorderSide(color: const Color(0xFFE9D5FF).withValues(alpha: 0.60), width: 1.0),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('🌸', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🌺', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🍃', style: TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              Text('🍃', style: TextStyle(fontSize: 11)),
              SizedBox(width: 2),
              Text('🌺', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🌸', style: TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2 Floral Trim (Golden Amber with Sunflowers)
  Widget _buildGoldenFloraTrim() {
    return Container(
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        border: Border(
          top: BorderSide(color: const Color(0xFFFDE68A).withValues(alpha: 0.60), width: 1.0),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('🌻', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🌼', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🍃', style: TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              Text('🍃', style: TextStyle(fontSize: 11)),
              SizedBox(width: 2),
              Text('🌼', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🌻', style: TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  // Card 3 Floral Trim (Sky Blue with Flowers)
  Widget _buildSkyBlueFloraTrim() {
    return Container(
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
        ),
        border: Border(
          top: BorderSide(color: const Color(0xFFBAE6FD).withValues(alpha: 0.60), width: 1.0),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('🌸', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🪻', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🍃', style: TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              Text('🍃', style: TextStyle(fontSize: 11)),
              SizedBox(width: 2),
              Text('🪻', style: TextStyle(fontSize: 14)),
              SizedBox(width: 2),
              Text('🌸', style: TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  // Creative Activities Modal Sheet
  void _showCreativeActivitiesModal(BuildContext context) {
    _speak('නිර්මාණාත්මක ක්‍රියාකාරකම් වෙත ඔබව සාදරයෙන් පිළිගන්නවා.');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('🎨', style: TextStyle(fontSize: 26)),
                SizedBox(width: 10),
                Text(
                  'නිර්මාණාත්මක ක්‍රියාකාරකම්',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'චිත්‍ර ඇඳීම, මල් වගාව හෝ අත්කම් නිර්මාණයේ නිරතව සතුටක් ලබාගන්න:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.palette_rounded, color: Color(0xFFD97706), size: 24),
              title: const Text('චිත්‍ර ඇඳීම සහ වර්ණ ගැන්වීම', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Digital Coloring & Art Therapy'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD97706), size: 18),
              onTap: () {
                Navigator.pop(ctx);
                _speak('මනස සතුටු කරන චිත්‍ර වර්ණ ගැන්වීම ආරම්භ කළා.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.yard_rounded, color: Color(0xFF16A34A), size: 24),
              title: const Text('මල් වගාව සහ ගෙවතු වගා උපදෙස්', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Flower Gardening & Nature Joy'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF16A34A), size: 18),
              onTap: () {
                Navigator.pop(ctx);
                _speak('මල් වගාව: උදෑසන මල් පැලවලට ජලය යෙදීම සහ මල් පිබිදීම නැරඹීම මනසට මහත් සතුටක් ගෙනදෙයි.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cut_rounded, color: Color(0xFF7C3AED), size: 24),
              title: const Text('සරල අත්කම් නිර්මාණ සහ විනෝදාංශ', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Simple Crafts & Creative Hobbies'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF7C3AED), size: 18),
              onTap: () {
                Navigator.pop(ctx);
                _speak('සරල අත්කම් නිර්මාණ මඟින් ඇඟිලි හා දෑත්වල ක්‍රියාකාරිත්වය ප්‍රබෝධමත් වේ.');
              },
            ),
          ],
        ),
      ),
    );
  }

  // Reading Library Modal Sheet
  void _showReadingLibraryModal(BuildContext context) {
    _speak('පොත් කියවීම: කතා, නවකතා සහ උපදේශනා පොත් කියවීම සඳහා ඔබව සාදරයෙන් පිළිගන්නවා.');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('📖', style: TextStyle(fontSize: 26)),
                SizedBox(width: 10),
                Text(
                  'පොත් කියවීම (නවකතා සහ රසකතා)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'දැනුම සහ සතුට වැඩි කරවන ආදර්ශවත් කතාන්දර සහ පොත්පත්:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.newspaper_rounded, color: Color(0xFF7C3AED), size: 24),
              title: const Text('අද දවසේ ප්‍රධාන පුවත් සහ විස්තර', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Today\'s Inspiring News & Updates'),
              trailing: const Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED), size: 26),
              onTap: () {
                Navigator.pop(ctx);
                _speak('අද දවසේ පුවත්: ලක්දිව කාලගුණය යහපත් අතර, වැඩිහිටි සුභසාධන සේවා ඉතා සාර්ථකව ක්‍රියාත්මක වේ.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED), size: 24),
              title: const Text('ආදර්ශවත් ජාතක කතා සහ කෙටිකතා', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Moral Stories & Nostalgic Tales'),
              trailing: const Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED), size: 26),
              onTap: () {
                Navigator.pop(ctx);
                _speak('වණ්ණුපථ ජාතකය: උත්සාහය හා ධෛර්යය තුළින් ඕනෑම අභියෝගයක් ජයගත හැකි අයුරු මෙම කතාවෙන් කියවේ.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF16A34A), size: 24),
              title: const Text('සුවබර දිවියකට නිරෝගී උපදෙස්', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Senior Wellness & Nutrition Tips'),
              trailing: const Icon(Icons.menu_book_rounded, color: Color(0xFF16A34A), size: 26),
              onTap: () {
                Navigator.pop(ctx);
                _speak('සුවදායී උපදෙස: දිනපතා ප්‍රමාණවත් පරිදි ජලය පානය කරන්න. උදෑසන සුළු ඇවිදීමක් ඔබේ නිරෝගීභාවයට මහඟු පිටුවහලකි.');
              },
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Row Quick Card Widget (Cards 3 & 4)
  Widget _buildQuickCard({
    required Color backgroundColor,
    required Color borderColor,
    required String badgeIcon,
    required Widget topRightIllustration,
    required String title,
    required String description,
    required String buttonText,
    required List<Color> buttonGradient,
    required VoidCallback onTap,
    Widget? bottomDecoration,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(badgeIcon, style: const TextStyle(fontSize: 24)),
                      ),
                      topRightIllustration,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Compact centered Action Button
                  Center(
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: buttonGradient),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: buttonGradient.first.withValues(alpha: 0.40),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              buttonText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (bottomDecoration != null) bottomDecoration,
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. BOTTOM DASHBOARD ROW (3 CARDS)
  // =========================================================================
  Widget _buildBottomDashboardRow(BuildContext context, bool isSinhala) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 980;

        final cardA = _buildWellnessScoreCard();
        final cardB = _buildRecentActivityCard();
        final cardC = _buildNatureQuoteCard();

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: cardA),
              const SizedBox(width: 14),
              Expanded(flex: 7, child: cardB),
              const SizedBox(width: 14),
              Expanded(flex: 6, child: cardC),
            ],
          );
        } else {
          return Column(
            children: [
              cardA,
              const SizedBox(height: 14),
              cardB,
              const SizedBox(height: 14),
              cardC,
            ],
          );
        }
      },
    );
  }

  // Card A: My Wellness Score (78%)
  Widget _buildWellnessScoreCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.heartPulse, size: 16, color: Color(0xFF9333EA)),
              ),
              const SizedBox(width: 8),
              const Text(
                'මගේ මානසික සුවතාව (My Wellness)',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              // Circular progress ring 78%
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: CircularProgressIndicator(
                        value: 0.78,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '78%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Wellness Score',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Description & Smile
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('😊', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ඔබගේ මානසික සුවතාව හොඳ මට්ටමක පවතී! 🌿',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'දිගටම ඔබේ දෛනික පුරුදු පවත්වාගෙන යන්න.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                        height: 1.3,
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

  // Card B: Recent Activity
  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.history, size: 16, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 8),
              const Text(
                'මෑත කටයුතු (Recent Activity)',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Item 1: Voice Analysis
          _buildActivityItem(
            icon: LucideIcons.mic,
            title: 'හඬ ඇගයීම (Voice Analysis)',
            date: '2025-11-20',
          ),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),

          // Item 2: Facial Emotion
          _buildActivityItem(
            icon: LucideIcons.camera,
            title: 'මුහුණු හැඟීම් ඇගයීම (Facial Emotion)',
            date: '2025-11-20',
          ),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),

          // Item 3: Questionnaire
          _buildActivityItem(
            icon: LucideIcons.clipboardList,
            title: 'ප්‍රශ්නාවලිය (Questionnaire)',
            date: '2025-11-18',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String date,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text(
            'සම්පූර්ණයි',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16A34A),
            ),
          ),
        ),
      ],
    );
  }

  // Card C: Nature Quote Card
  Widget _buildNatureQuoteCard() {
    return Container(
      height: 175,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF9C3), Color(0xFFDCFCE7), Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Meadow / Floral nature illustration at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 48,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
                gradient: LinearGradient(
                  colors: [Color(0xFF86EFAC), Color(0xFF4ADE80)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('🌸', style: TextStyle(fontSize: 16)),
                  Text('🌿', style: TextStyle(fontSize: 14)),
                  Text('☀️', style: TextStyle(fontSize: 18)),
                  Text('🌼', style: TextStyle(fontSize: 16)),
                  Text('🌾', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),

          // Central Quote
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _speak('සුබ සිතක්, සුවබර ජීවිතයකට මගක් වේ.'),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          '“සුබ සිතක්,\nසුවබර ජීවිතයකට\nමගක් වේ.”',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4C1D95),
                            height: 1.35,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(LucideIcons.volume2, size: 16, color: Color(0xFF7E22CE)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '💜',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ACTIONS: CALL CAREGIVER & MUSIC MODAL
  // =========================================================================
  void _handleEmergencyCall(BuildContext context) {
    _speak('ඔබේ ඇමතුම සහායක කණ්ඩායමට යොමු කළා. සුළු මොහොතකින් පැමිණෙනු ඇත.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(LucideIcons.phoneCall, color: Color(0xFF0284C7), size: 24),
            SizedBox(width: 10),
            Text('සත්කාරක ඇමතුම', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: const Text(
          'ඔබගේ හදිසි හෝ සාමාන්‍ය උපකාර ඉල්ලීම රැකබලා ගන්නා කණ්ඩායම වෙත සාර්ථකව යොමු කරන ලදී.\n\nසුළු මොහොතකින් සහායකයෙකු ඔබ වෙත පැමිණෙනු ඇත.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('හරි, ස්තූතියි', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showMusicPlayerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('🎧', style: TextStyle(fontSize: 24)),
                SizedBox(width: 10),
                Text(
                  'සන්සුන් සංගීතය සහ ස්වභාවික නාද',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.music, color: Color(0xFF059669)),
              title: const Text('මනස සන්සුන් කරන මිහිරි තනුව'),
              subtitle: const Text('Calming Acoustic Melody'),
              trailing: const Icon(LucideIcons.playCircle, color: Color(0xFF059669), size: 28),
              onTap: () {
                Navigator.pop(ctx);
                _speak('සන්සුන් සංගීතය වාදනය ආරම්භ කළා.');
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.waves, color: Color(0xFF0284C7)),
              title: const Text('ගලායන දිය දහරාව සහ කුරුළු නාදය'),
              subtitle: const Text('Nature Stream & Birds'),
              trailing: const Icon(LucideIcons.playCircle, color: Color(0xFF0284C7), size: 28),
              onTap: () {
                Navigator.pop(ctx);
                _speak('ස්වභාවික කුරුළු නාදය සහ දිය දහරාව වාදනය ආරම්භ කළා.');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated swaying flower garden painter for the bottom of the Elder Interactive Home view
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

/// Animated floating butterflies overlay that flutters gracefully across the Elder Home Page
class _FloatingButterfliesOverlay extends StatefulWidget {
  const _FloatingButterfliesOverlay();

  @override
  State<_FloatingButterfliesOverlay> createState() =>
      _FloatingButterfliesOverlayState();
}

class _FloatingButterfliesOverlayState
    extends State<_FloatingButterfliesOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _flightController;
  late final AnimationController _flapController;

  @override
  void initState() {
    super.initState();
    // Flight loop over 24 seconds for slow, therapeutic, gentle drifting
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    // Wing flutter cycle (380ms)
    _flapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..repeat();
  }

  @override
  void dispose() {
    _flightController.dispose();
    _flapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flightController, _flapController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ButterfliesPainter(
            flightProgress: _flightController.value,
            flapProgress: _flapController.value,
          ),
        );
      },
    );
  }
}

class _ButterflySpec {
  final List<Color> wingColors;
  final Color innerHighlight;
  final Color sparkleColor;
  final double scale;
  final double flapPhase;
  final double pathOffset;
  final int pathType; // 0, 1, 2, 3

  const _ButterflySpec({
    required this.wingColors,
    required this.innerHighlight,
    required this.sparkleColor,
    required this.scale,
    required this.flapPhase,
    required this.pathOffset,
    required this.pathType,
  });
}

class _ButterfliesPainter extends CustomPainter {
  final double flightProgress;
  final double flapProgress;

  _ButterfliesPainter({
    required this.flightProgress,
    required this.flapProgress,
  });

  static const _butterflies = [
    // 1. Golden Monarch Amber
    _ButterflySpec(
      wingColors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
      innerHighlight: Color(0xFFFEF08A),
      sparkleColor: Color(0xFFFBBF24),
      scale: 1.05,
      flapPhase: 0.0,
      pathOffset: 0.0,
      pathType: 0,
    ),
    // 2. Azure Blue Morpho
    _ButterflySpec(
      wingColors: [Color(0xFF0284C7), Color(0xFF6366F1)],
      innerHighlight: Color(0xFFBAE6FD),
      sparkleColor: Color(0xFF38BDF8),
      scale: 0.95,
      flapPhase: 0.28,
      pathOffset: 0.25,
      pathType: 1,
    ),
    // 3. Orchid Blossom Pink
    _ButterflySpec(
      wingColors: [Color(0xFFEC4899), Color(0xFFA855F7)],
      innerHighlight: Color(0xFFFBCFE8),
      sparkleColor: Color(0xFFF472B6),
      scale: 0.90,
      flapPhase: 0.55,
      pathOffset: 0.50,
      pathType: 2,
    ),
    // 4. Fresh Emerald Mint
    _ButterflySpec(
      wingColors: [Color(0xFF10B981), Color(0xFF14B8A6)],
      innerHighlight: Color(0xFFA7F3D0),
      sparkleColor: Color(0xFF34D399),
      scale: 0.85,
      flapPhase: 0.80,
      pathOffset: 0.72,
      pathType: 3,
    ),
    // 5. Coral Sunset Swallowtail
    _ButterflySpec(
      wingColors: [Color(0xFFF43F5E), Color(0xFFFB923C)],
      innerHighlight: Color(0xFFFFEDD5),
      sparkleColor: Color(0xFFFB7185),
      scale: 0.92,
      flapPhase: 0.15,
      pathOffset: 0.12,
      pathType: 4,
    ),
    // 6. Royal Amethyst Fairy
    _ButterflySpec(
      wingColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      innerHighlight: Color(0xFFDDD6FE),
      sparkleColor: Color(0xFFA78BFA),
      scale: 1.00,
      flapPhase: 0.42,
      pathOffset: 0.38,
      pathType: 5,
    ),
    // 7. Sunny Lemon Sulphur
    _ButterflySpec(
      wingColors: [Color(0xFFFACC15), Color(0xFFEAB308)],
      innerHighlight: Color(0xFFFEF9C3),
      sparkleColor: Color(0xFFFDE047),
      scale: 0.80,
      flapPhase: 0.68,
      pathOffset: 0.62,
      pathType: 6,
    ),
    // 8. Cyan Aqua Sea-Breeze
    _ButterflySpec(
      wingColors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
      innerHighlight: Color(0xFFCFFAFE),
      sparkleColor: Color(0xFF22D3EE),
      scale: 0.88,
      flapPhase: 0.90,
      pathOffset: 0.85,
      pathType: 7,
    ),
    // 9. Ruby Crimson Emperor
    _ButterflySpec(
      wingColors: [Color(0xFFE11D48), Color(0xFFBE123C)],
      innerHighlight: Color(0xFFFFE4E6),
      sparkleColor: Color(0xFFF43F5E),
      scale: 0.96,
      flapPhase: 0.10,
      pathOffset: 0.08,
      pathType: 8,
    ),
    // 10. Golden Topaz Swallowtail
    _ButterflySpec(
      wingColors: [Color(0xFFD97706), Color(0xFFCA8A04)],
      innerHighlight: Color(0xFFFEF3C7),
      sparkleColor: Color(0xFFF59E0B),
      scale: 0.86,
      flapPhase: 0.35,
      pathOffset: 0.45,
      pathType: 9,
    ),
    // 11. Lilac Dream Fairy
    _ButterflySpec(
      wingColors: [Color(0xFFA855F7), Color(0xFF818CF8)],
      innerHighlight: Color(0xFFEDE9FE),
      sparkleColor: Color(0xFFC084FC),
      scale: 0.92,
      flapPhase: 0.62,
      pathOffset: 0.68,
      pathType: 10,
    ),
    // 12. Spring Jade Meadow
    _ButterflySpec(
      wingColors: [Color(0xFF059669), Color(0xFF10B981)],
      innerHighlight: Color(0xFFD1FAE5),
      sparkleColor: Color(0xFF34D399),
      scale: 0.82,
      flapPhase: 0.82,
      pathOffset: 0.92,
      pathType: 11,
    ),
  ];

  Offset _computePos(int type, double t) {
    final twoPi = 2 * math.pi;
    switch (type) {
      case 0:
        // Gentle wide loop across top-center & right
        final x = 0.52 + 0.36 * math.cos(twoPi * t) + 0.06 * math.sin(4 * math.pi * t);
        final y = 0.26 + 0.16 * math.sin(twoPi * t) + 0.04 * math.cos(6 * math.pi * t);
        return Offset(x, y);
      case 1:
        // Graceful wave across left and center-mid
        final x = 0.30 + 0.22 * math.sin(twoPi * t + 1.4) + 0.05 * math.cos(4 * math.pi * t);
        final y = 0.50 + 0.22 * math.cos(twoPi * t + 0.8) + 0.03 * math.sin(6 * math.pi * t);
        return Offset(x, y);
      case 2:
        // Swooping figure-8 towards bottom right near nature quote & garden
        final x = 0.68 + 0.20 * math.cos(twoPi * t + 3.0) + 0.04 * math.sin(4 * math.pi * t + 1.0);
        final y = 0.62 + 0.18 * math.sin(twoPi * t + 2.2) + 0.03 * math.cos(6 * math.pi * t + 1.5);
        return Offset(x, y);
      case 3:
        // Playful fluttering dance on upper left
        final x = 0.18 + 0.14 * math.sin(4 * math.pi * t + 2.0);
        final y = 0.20 + 0.14 * math.cos(twoPi * t + 1.0);
        return Offset(x, y);
      case 4:
        // Center diagonal sweep from upper-mid to right
        final x = 0.45 + 0.30 * math.cos(twoPi * t + 0.6);
        final y = 0.40 + 0.24 * math.sin(twoPi * t + 0.6);
        return Offset(x, y);
      case 5:
        // Gliding high over banner and dipping to middle
        final x = 0.60 + 0.26 * math.sin(twoPi * t + 2.4);
        final y = 0.18 + 0.12 * math.cos(twoPi * t + 1.2);
        return Offset(x, y);
      case 6:
        // Delicate flutter over lower cards and wellness score
        final x = 0.38 + 0.18 * math.cos(twoPi * t + 4.0);
        final y = 0.70 + 0.15 * math.sin(twoPi * t + 3.2);
        return Offset(x, y);
      case 7:
        // Right side vertical loop
        final x = 0.82 + 0.12 * math.sin(twoPi * t + 1.8);
        final y = 0.45 + 0.25 * math.cos(twoPi * t + 2.5);
        return Offset(x, y);
      case 8:
        // Upper right header drift
        final x = 0.76 + 0.16 * math.sin(twoPi * t + 0.5);
        final y = 0.12 + 0.08 * math.cos(twoPi * t + 1.5);
        return Offset(x, y);
      case 9:
        // Lower left diagonal glide near bottom flowers
        final x = 0.22 + 0.16 * math.cos(twoPi * t + 2.8);
        final y = 0.78 + 0.12 * math.sin(twoPi * t + 1.1);
        return Offset(x, y);
      case 10:
        // Mid center figure-8 loop between banner and cards
        final x = 0.50 + 0.24 * math.sin(twoPi * t + 3.6);
        final y = 0.38 + 0.14 * math.sin(4 * math.pi * t + 0.8);
        return Offset(x, y);
      default:
        // Hovering near the nature quote card on the bottom right
        final x = 0.85 + 0.10 * math.cos(twoPi * t + 4.5);
        final y = 0.75 + 0.14 * math.sin(twoPi * t + 2.0);
        return Offset(x, y);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    for (final spec in _butterflies) {
      final t = (flightProgress + spec.pathOffset) % 1.0;
      final posRatio = _computePos(spec.pathType, t);

      // Compute heading angle using small forward delta
      const dt = 0.004;
      final nextPosRatio = _computePos(spec.pathType, (t + dt) % 1.0);
      final dx = (nextPosRatio.dx - posRatio.dx) * size.width;
      final dy = (nextPosRatio.dy - posRatio.dy) * size.height;
      final angle = math.atan2(dy, dx) + math.pi / 2;

      // Current screen coordinates
      final screenX = posRatio.dx * size.width;
      final screenY = posRatio.dy * size.height;

      // Wing flap factor (0.20 to 1.0)
      final flapCycle = (flapProgress + spec.flapPhase) % 1.0;
      final wingFlap = 0.20 + 0.80 * math.cos(flapCycle * 2 * math.pi).abs();
      final yBob = math.sin(flapCycle * 2 * math.pi) * 3.0;

      // 1. Draw fairy-dust sparkle trail behind the butterfly
      for (int i = 1; i <= 4; i++) {
        final trailT = (t - i * 0.012 + 1.0) % 1.0;
        final trailPos = _computePos(spec.pathType, trailT);
        final trailX = trailPos.dx * size.width;
        final trailY = trailPos.dy * size.height;
        final alpha = (0.55 - i * 0.12).clamp(0.0, 1.0);

        final sparklePaint = Paint()
          ..color = spec.sparkleColor.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(trailX, trailY), 2.8 - i * 0.5, sparklePaint);

        // Tiny cross-star shimmer on odd trail particles
        if (i.isOdd) {
          final starPaint = Paint()
            ..color = Colors.white.withValues(alpha: alpha * 0.85)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(trailX - 3.5, trailY),
            Offset(trailX + 3.5, trailY),
            starPaint,
          );
          canvas.drawLine(
            Offset(trailX, trailY - 3.5),
            Offset(trailX, trailY + 3.5),
            starPaint,
          );
        }
      }

      // 2. Draw the Butterfly
      canvas.save();
      canvas.translate(screenX, screenY + yBob);
      canvas.rotate(angle);
      canvas.scale(spec.scale, spec.scale);

      _drawSingleButterfly(canvas, spec, wingFlap);
      canvas.restore();
    }
  }

  void _drawSingleButterfly(
    Canvas canvas,
    _ButterflySpec spec,
    double wingFlap,
  ) {
    // Draw Left and Right Wings
    for (final isRight in [false, true]) {
      canvas.save();
      canvas.scale(isRight ? wingFlap : -wingFlap, 1.0);

      // Forewing (upper larger wing)
      final forewing = Path()
        ..moveTo(1.2, -1.0)
        ..cubicTo(5.0, -9.0, 14.0, -10.0, 17.0, -4.0)
        ..cubicTo(18.5, 0.0, 15.0, 5.0, 8.0, 4.0)
        ..cubicTo(4.0, 3.5, 2.0, 2.0, 1.2, 0.5)
        ..close();

      final forewingPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [spec.wingColors[0], spec.wingColors[1]],
        ).createShader(const Rect.fromLTWH(0, -10, 18, 15))
        ..style = PaintingStyle.fill;
      canvas.drawPath(forewing, forewingPaint);

      // Forewing inner translucent highlight glow
      final forewingHighlight = Path()
        ..moveTo(2.0, -0.5)
        ..cubicTo(5.0, -6.5, 11.0, -7.0, 13.0, -3.0)
        ..cubicTo(13.5, 0.0, 10.0, 2.5, 5.0, 2.0)
        ..close();
      final highlightPaint = Paint()
        ..color = spec.innerHighlight.withValues(alpha: 0.60)
        ..style = PaintingStyle.fill;
      canvas.drawPath(forewingHighlight, highlightPaint);

      // Hindwing (lower curved wing)
      final hindwing = Path()
        ..moveTo(1.2, 1.5)
        ..cubicTo(6.0, 3.0, 13.0, 5.0, 11.5, 10.5)
        ..cubicTo(10.0, 14.5, 4.0, 12.0, 1.2, 6.5)
        ..close();

      final hindwingPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            spec.wingColors[0].withValues(alpha: 0.90),
            spec.wingColors[1],
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 14, 15))
        ..style = PaintingStyle.fill;
      canvas.drawPath(hindwing, hindwingPaint);

      // Wing edge white jewel dots (Monarch style delicacy)
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(16.0, -3.5), 1.0, dotPaint);
      canvas.drawCircle(const Offset(15.0, 0.5), 0.9, dotPaint);
      canvas.drawCircle(const Offset(10.8, 10.8), 0.9, dotPaint);

      canvas.restore();
    }

    // Slender Body
    final bodyPaint = Paint()
      ..color = const Color(0xFF262626)
      ..style = PaintingStyle.fill;

    // Abdomen / thorax
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.5, -4.5, 3.0, 12.0),
        const Radius.circular(2.0),
      ),
      bodyPaint,
    );

    // Head
    canvas.drawCircle(const Offset(0, -6.5), 2.0, bodyPaint);

    // Antennae
    final antennaPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final leftAntenna = Path()
      ..moveTo(-0.8, -7.5)
      ..quadraticBezierTo(-3.5, -11.0, -5.0, -12.5);
    canvas.drawPath(leftAntenna, antennaPaint);

    final rightAntenna = Path()
      ..moveTo(0.8, -7.5)
      ..quadraticBezierTo(3.5, -11.0, 5.0, -12.5);
    canvas.drawPath(rightAntenna, antennaPaint);

    // Golden tip on antennae
    final antennaTip = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-5.0, -12.5), 0.9, antennaTip);
    canvas.drawCircle(const Offset(5.0, -12.5), 0.9, antennaTip);
  }

  @override
  bool shouldRepaint(covariant _ButterfliesPainter oldDelegate) {
    return oldDelegate.flightProgress != flightProgress ||
        oldDelegate.flapProgress != flapProgress;
  }
}

/// Vector avatar painter for Grandma with glasses, grey hair bun, and cheerful smile
class _GrandmaAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Body / Purple Blouse
    final bodyPaint = Paint()..color = const Color(0xFF7C3AED);
    final bodyPath = Path()
      ..moveTo(cx - 36, size.height)
      ..quadraticBezierTo(cx - 38, cy + 18, cx - 18, cy + 14)
      ..lineTo(cx + 18, cy + 14)
      ..quadraticBezierTo(cx + 38, cy + 18, cx + 36, size.height)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Folded hands over heart
    final skinPaint = Paint()..color = const Color(0xFFFFE0BD);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 24), width: 34, height: 16),
      skinPaint,
    );
    final handBorder = Paint()
      ..color = const Color(0xFFFDBA74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 24), width: 34, height: 16),
      handBorder,
    );

    // Neck
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + 10), width: 14, height: 12), skinPaint);

    // Head / Face
    canvas.drawCircle(Offset(cx, cy - 8), 24, skinPaint);

    // Rosy cheeks
    final blushPaint = Paint()..color = const Color(0xFFFDA4AF).withValues(alpha: 0.55);
    canvas.drawCircle(Offset(cx - 12, cy - 4), 5, blushPaint);
    canvas.drawCircle(Offset(cx + 12, cy - 4), 5, blushPaint);

    // Grey / Silver Hair
    final hairPaint = Paint()..color = const Color(0xFFD1D5DB);
    canvas.drawCircle(Offset(cx, cy - 32), 12, hairPaint);
    canvas.drawCircle(Offset(cx - 20, cy - 14), 13, hairPaint);
    canvas.drawCircle(Offset(cx + 20, cy - 14), 13, hairPaint);
    canvas.drawCircle(Offset(cx - 12, cy - 24), 16, hairPaint);
    canvas.drawCircle(Offset(cx + 12, cy - 24), 16, hairPaint);
    canvas.drawCircle(Offset(cx, cy - 22), 18, hairPaint);

    // Forehead
    final foreheadSkin = Paint()..color = const Color(0xFFFFE0BD);
    canvas.drawCircle(Offset(cx, cy - 10), 18, foreheadSkin);

    // Spectacles / Glasses (round dark frames)
    final glassesPaint = Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(cx - 9, cy - 8), 7, glassesPaint);
    canvas.drawCircle(Offset(cx + 9, cy - 8), 7, glassesPaint);
    canvas.drawLine(Offset(cx - 2, cy - 8), Offset(cx + 2, cy - 8), glassesPaint);
    canvas.drawLine(Offset(cx - 16, cy - 8), Offset(cx - 22, cy - 10), glassesPaint);
    canvas.drawLine(Offset(cx + 16, cy - 8), Offset(cx + 22, cy - 10), glassesPaint);

    // Smiling closed eyes (cheerful curved arcs inside glasses)
    final eyePaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final leftEye = Path()
      ..moveTo(cx - 12, cy - 7)
      ..quadraticBezierTo(cx - 9, cy - 10, cx - 6, cy - 7);
    final rightEye = Path()
      ..moveTo(cx + 6, cy - 7)
      ..quadraticBezierTo(cx + 9, cy - 10, cx + 12, cy - 7);
    canvas.drawPath(leftEye, eyePaint);
    canvas.drawPath(rightEye, eyePaint);

    // Cheerful smiling mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final mouth = Path()
      ..moveTo(cx - 7, cy + 3)
      ..quadraticBezierTo(cx, cy + 9, cx + 7, cy + 3);
    canvas.drawPath(mouth, mouthPaint);

    // Nose
    final nosePaint = Paint()
      ..color = const Color(0xFFFDBA74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final nose = Path()
      ..moveTo(cx - 1.5, cy - 3)
      ..quadraticBezierTo(cx + 1.5, cy - 1, cx - 1, cy + 0);
    canvas.drawPath(nose, nosePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// =========================================================================
// CUSTOM PAINTERS FOR LEISURE MOCKUP ILLUSTRATIONS
// =========================================================================

class _GrandmaReadingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.48;
    final cy = size.height * 0.45;

    // Armchair back
    final chairPaint = Paint()..color = const Color(0xFFFBBF24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 4, cy + 4), width: 44, height: 58), const Radius.circular(16)),
      chairPaint,
    );

    // Body / Purple blouse
    final bodyPaint = Paint()..color = const Color(0xFF7C3AED);
    final bodyPath = Path()
      ..moveTo(cx - 20, size.height)
      ..quadraticBezierTo(cx - 22, cy + 12, cx - 12, cy + 8)
      ..lineTo(cx + 12, cy + 8)
      ..quadraticBezierTo(cx + 22, cy + 12, cx + 20, size.height)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Head / Face
    final skinPaint = Paint()..color = const Color(0xFFFFE0BD);
    canvas.drawCircle(Offset(cx, cy - 8), 16, skinPaint);

    // Rosy cheeks
    final blushPaint = Paint()..color = const Color(0xFFFDA4AF).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(cx - 8, cy - 5), 3.5, blushPaint);
    canvas.drawCircle(Offset(cx + 8, cy - 5), 3.5, blushPaint);

    // Hair (Silver bun)
    final hairPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - 9), radius: 17), 3.14, 3.14, true, hairPaint);
    canvas.drawCircle(Offset(cx, cy - 25), 8, hairPaint);

    // Glasses
    final glassesPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(Offset(cx - 6, cy - 8), 4.5, glassesPaint);
    canvas.drawCircle(Offset(cx + 6, cy - 8), 4.5, glassesPaint);
    canvas.drawLine(Offset(cx - 1.5, cy - 8), Offset(cx + 1.5, cy - 8), glassesPaint);

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFFBE123C)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - 2), radius: 4), 0.2, 2.7, false, smilePaint);

    // Open Red Book in hands
    final bookCover = Paint()..color = const Color(0xFFDC2626);
    final bookPages = Paint()..color = Colors.white;
    // Left page
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 16, cy + 16, 15, 18), const Radius.circular(2)), bookCover);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 15, cy + 17, 13, 16), const Radius.circular(1.5)), bookPages);
    // Right page
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 1, cy + 16, 15, 18), const Radius.circular(2)), bookCover);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 2, cy + 17, 13, 16), const Radius.circular(1.5)), bookPages);

    // Hands holding book
    canvas.drawCircle(Offset(cx - 15, cy + 24), 3.5, skinPaint);
    canvas.drawCircle(Offset(cx + 15, cy + 24), 3.5, skinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GrandmaPaintingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.42;
    final cy = size.height * 0.42;

    // Body / Purple blouse
    final bodyPaint = Paint()..color = const Color(0xFF7C3AED);
    final bodyPath = Path()
      ..moveTo(cx - 18, size.height)
      ..quadraticBezierTo(cx - 20, cy + 12, cx - 10, cy + 8)
      ..lineTo(cx + 10, cy + 8)
      ..quadraticBezierTo(cx + 20, cy + 12, cx + 18, size.height)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Head / Face
    final skinPaint = Paint()..color = const Color(0xFFFFE0BD);
    canvas.drawCircle(Offset(cx, cy - 8), 16, skinPaint);

    // Rosy cheeks
    final blushPaint = Paint()..color = const Color(0xFFFDA4AF).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(cx - 8, cy - 5), 3.5, blushPaint);
    canvas.drawCircle(Offset(cx + 8, cy - 5), 3.5, blushPaint);

    // Hair (Silver bun)
    final hairPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - 9), radius: 17), 3.14, 3.14, true, hairPaint);
    canvas.drawCircle(Offset(cx, cy - 25), 8, hairPaint);

    // Glasses
    final glassesPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(Offset(cx - 6, cy - 8), 4.5, glassesPaint);
    canvas.drawCircle(Offset(cx + 6, cy - 8), 4.5, glassesPaint);
    canvas.drawLine(Offset(cx - 1.5, cy - 8), Offset(cx + 1.5, cy - 8), glassesPaint);

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFFBE123C)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - 2), radius: 4), 0.2, 2.7, false, smilePaint);

    // Right arm holding paintbrush extended towards easel
    final armPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 8, cy + 14), Offset(cx + 28, cy + 22), armPaint);

    // Hand & Paintbrush
    canvas.drawCircle(Offset(cx + 28, cy + 22), 4, skinPaint);
    final brushPaint = Paint()
      ..color = const Color(0xFFB45309)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 26, cy + 24), Offset(cx + 42, cy + 16), brushPaint);
    final brushTip = Paint()..color = const Color(0xFF9333EA);
    canvas.drawCircle(Offset(cx + 43, cy + 15), 2.5, brushTip);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ElderListeningMusicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.48;
    final cy = size.height * 0.44;

    // Body / Purple shirt
    final bodyPaint = Paint()..color = const Color(0xFF6B21A8);
    final bodyPath = Path()
      ..moveTo(cx - 20, size.height)
      ..quadraticBezierTo(cx - 22, cy + 12, cx - 12, cy + 8)
      ..lineTo(cx + 12, cy + 8)
      ..quadraticBezierTo(cx + 22, cy + 12, cx + 20, size.height)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Head / Face
    final skinPaint = Paint()..color = const Color(0xFFFFE0BD);
    canvas.drawCircle(Offset(cx, cy - 6), 17, skinPaint);

    // Rosy cheeks
    final blushPaint = Paint()..color = const Color(0xFFFDA4AF).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(cx - 9, cy - 3), 4, blushPaint);
    canvas.drawCircle(Offset(cx + 9, cy - 3), 4, blushPaint);

    // Silver hair
    final hairPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - 8), radius: 18), 3.14, 3.14, true, hairPaint);

    // Closed smiling eyes in pure musical bliss (peaceful crescents)
    final eyePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx - 6, cy - 6), radius: 4), 3.4, 2.5, false, eyePaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx + 6, cy - 6), radius: 4), 3.4, 2.5, false, eyePaint);

    // Glasses frames
    final glassesPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(Offset(cx - 6, cy - 6), 5.5, glassesPaint);
    canvas.drawCircle(Offset(cx + 6, cy - 6), 5.5, glassesPaint);
    canvas.drawLine(Offset(cx - 0.5, cy - 6), Offset(cx + 0.5, cy - 6), glassesPaint);

    // Peaceful Smile
    final smilePaint = Paint()
      ..color = const Color(0xFFBE123C)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: 5), 0.2, 2.7, false, smilePaint);

    // Big Modern Over-Ear Headphones
    final hpHeadband = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy - 7), radius: 21), 3.14, 3.14, false, hpHeadband);

    // Ear cushions
    final earCushion = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 24, cy - 13, 7, 16), const Radius.circular(3)), earCushion);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 17, cy - 13, 7, 16), const Radius.circular(3)), earCushion);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// PURPLE BOTANICAL CORNER PAINTER (Matching Mockup)
// =========================================================================
class _PurpleBotanicalCornerPainter extends CustomPainter {
  final bool isLeft;
  const _PurpleBotanicalCornerPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (!isLeft) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final stemPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.60)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafPaint1 = Paint()
      ..color = const Color(0xFFC084FC).withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;

    final leafPaint2 = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final leafPaint3 = Paint()
      ..color = const Color(0xFFA855F7).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final leafPaint4 = Paint()
      ..color = const Color(0xFFDDD6FE).withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;

    // Curved stem from corner
    final path = Path()
      ..moveTo(2, size.height - 2)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.55, size.width * 0.88, 4);
    canvas.drawPath(path, stemPaint);

    // Leaf 1 (lower left)
    canvas.save();
    canvas.translate(size.width * 0.32, size.height * 0.68);
    canvas.rotate(-0.65);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 7), leafPaint1);
    canvas.restore();

    // Leaf 2 (middle upward)
    canvas.save();
    canvas.translate(size.width * 0.58, size.height * 0.44);
    canvas.rotate(0.50);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 15, height: 7.5), leafPaint2);
    canvas.restore();

    // Leaf 3 (tip)
    canvas.save();
    canvas.translate(size.width * 0.88, 4);
    canvas.rotate(0.20);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 16, height: 8), leafPaint3);
    canvas.restore();

    // Leaf 4 (small soft accent)
    canvas.save();
    canvas.translate(size.width * 0.48, size.height * 0.60);
    canvas.rotate(-0.25);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 5), leafPaint4);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// 3D BOOKMARK RIBBON PAINTER (Golden Ribbon at top spine)
// =========================================================================
class _RibbonBookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ribbonPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFBBF24), // amber
          Color(0xFFF59E0B), // gold
          Color(0xFFD97706), // dark gold
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 7) // V-cut ribbon tail
      ..lineTo(0, size.height)
      ..close();

    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path.shift(const Offset(1, 2)), shadowPaint);

    canvas.drawPath(path, ribbonPaint);

    // Golden vertical shine highlight
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.35, 2),
      Offset(size.width * 0.35, size.height - 8),
      shinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================================
// BOOK CORNER FLOURISH PAINTER (Delicate filigree corner on cover)
// =========================================================================
class _BookCornerFlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(2, size.height)
      ..quadraticBezierTo(2, 2, size.width, 2);
    canvas.drawPath(path, paint);

    final innerPath = Path()
      ..moveTo(5, size.height * 0.75)
      ..quadraticBezierTo(5, 5, size.width * 0.75, 5);
    canvas.drawPath(innerPath, paint);

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(7, 7), 1.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// =========================================================================
// REALISTIC 3D OPEN BOOK BOTTOM ARCH & PAPER STACK PAINTER
// =========================================================================
class _BookSpineArchPainter extends CustomPainter {
  final double spineRatio;
  final Color casingColor;

  const _BookSpineArchPainter({
    this.spineRatio = 0.38,
    required this.casingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final s = w * spineRatio;

    // 1. Center spine upward arch cavity (dark shading)
    final spineCavityPaint = Paint()
      ..color = casingColor.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    final spineArchPath = Path();
    spineArchPath.moveTo(s - 14, h);
    spineArchPath.quadraticBezierTo(s, h - 8, s + 14, h);
    spineArchPath.close();
    canvas.drawPath(spineArchPath, spineCavityPaint);

    // Spine binding crease highlight
    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(s, 0), Offset(s, h - 7), creasePaint);

    // 2. Right page stacked paper layers (Multi-sheet page thickness)
    for (int i = 1; i <= 3; i++) {
      final double dy = (i * 1.8);
      final pageEdgePaint = Paint()
        ..color = (i == 1
                ? Colors.white
                : (i == 2 ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0)))
            .withValues(alpha: 0.95 - (i * 0.12))
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final paperEdgePath = Path();
      paperEdgePath.moveTo(s + 12, h - 6 + dy);
      paperEdgePath.quadraticBezierTo(
        s + (w - s) * 0.55,
        h - 1 + dy,
        w - 12,
        h - 4 + dy,
      );
      canvas.drawPath(paperEdgePath, pageEdgePaint);
    }

    // 3. Left cover bottom curved edge
    final coverEdgePaint = Paint()
      ..color = casingColor.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final coverEdgePath = Path();
    coverEdgePath.moveTo(12, h - 3);
    coverEdgePath.quadraticBezierTo(s * 0.5, h, s - 12, h - 5);
    canvas.drawPath(coverEdgePath, coverEdgePaint);
  }

  @override
  bool shouldRepaint(covariant _BookSpineArchPainter oldDelegate) =>
      oldDelegate.spineRatio != spineRatio ||
      oldDelegate.casingColor != casingColor;
}
