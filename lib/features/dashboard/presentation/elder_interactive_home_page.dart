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

enum DayPeriod { morning, afternoon, evening, night }

enum DailyAssessmentSlot { morning, afternoon, night }

DailyAssessmentSlot _getCurrentAssessmentSlot(DateTime dt) {
  final hour = dt.hour;
  if (hour >= 5 && hour < 12) {
    return DailyAssessmentSlot.morning; // 5:00 AM - 11:59 AM
  } else if (hour >= 12 && hour < 17) {
    return DailyAssessmentSlot.afternoon; // 12:00 PM - 4:59 PM
  } else {
    return DailyAssessmentSlot.night; // 5:00 PM - 4:59 AM
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
      return 'හෙට පෙ.ව. 05:00';
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
  bool _routine1AnsweredYes = false;
  bool _routine1AnsweredNo = false;
  bool _routine2AnsweredYes = false;
  bool _routine2AnsweredNo = false;
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
    if (hour >= 5 && hour < 12) {
      return DayPeriod.morning;
    } else if (hour >= 12 && hour < 16) {
      // 12:00 PM to 3:59 PM (12 to 15:59)
      return DayPeriod.afternoon;
    } else if (hour >= 16 && hour < 19) {
      // 4:00 PM to 6:59 PM (16 to 18:59) -> Evening (සවස / සන්ධ්‍යාව)
      return DayPeriod.evening;
    } else {
      // 7:00 PM onwards or before 5:00 AM -> Night (රාත්‍රිය)
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
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.22),
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
                    color: Color(0xFF15803D),
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
                          backgroundColor: const Color(0xFF16A34A),
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
    final doneCount = _getDoneCount(activity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: Slot counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'දෛනික සැසි (3/දින):',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: doneCount == 3 ? const Color(0xFFDCFCE7) : activeThemeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$doneCount / 3 සම්පූර්ණයි',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: doneCount == 3 ? const Color(0xFF15803D) : activeThemeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3 Slot Pills Row
          Row(
            children: [
              Expanded(
                child: _buildSlotPill(
                  label: 'උදෑසන',
                  icon: '🌅',
                  isDone: morningDone,
                  isCurrent: currentSlot == DailyAssessmentSlot.morning,
                  activeThemeColor: activeThemeColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSlotPill(
                  label: 'දහවල',
                  icon: '☀️',
                  isDone: afternoonDone,
                  isCurrent: currentSlot == DailyAssessmentSlot.afternoon,
                  activeThemeColor: activeThemeColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSlotPill(
                  label: 'රාත්‍රිය',
                  icon: '🌙',
                  isDone: nightDone,
                  isCurrent: currentSlot == DailyAssessmentSlot.night,
                  activeThemeColor: activeThemeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlotPill({
    required String label,
    required String icon,
    required bool isDone,
    required bool isCurrent,
    required Color activeThemeColor,
  }) {
    Color bg;
    Color borderColor;
    Color textColor;
    String statusSymbol;

    if (isDone) {
      bg = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF86EFAC);
      textColor = const Color(0xFF15803D);
      statusSymbol = '✓';
    } else if (isCurrent) {
      bg = activeThemeColor.withValues(alpha: 0.14);
      borderColor = activeThemeColor.withValues(alpha: 0.55);
      textColor = activeThemeColor;
      statusSymbol = '🔔';
    } else {
      bg = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF94A3B8);
      statusSymbol = '⏳';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isCurrent && !isDone ? 1.8 : 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$icon $statusSymbol',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotStatusBadge({
    required bool isCurrentDone,
    required String currentSlotName,
    required Color activeColor,
  }) {
    if (isCurrentDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              '$currentSlotName සැසිය සම්පූර්ණයි',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              'අද $currentSlotName සැසිය තවම කර නැත!',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final isSinhala = ref.watch(languageProvider).isSinhala;
    final elderDisplayName = _resolveDisplayName(authState, isSinhala);
    final dayPeriod = _getCurrentDayPeriod(_now);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                const SizedBox(height: 24),

                // 3. Quick Access Title & 4 Large Action Cards
                _buildQuickAccessSection(context, isSinhala),
                const SizedBox(height: 24),

                // 4. Bottom Row (My Wellness, Recent Activity, Nature Quote)
                _buildBottomDashboardRow(context, isSinhala),
                const SizedBox(height: 20),

                // 5. Animated swaying floral garden at the bottom of the page content
                _buildAnimatedBottomFlowerGarden(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // 2. Beautiful floating butterflies overlay (IgnorePointer - completely touch & scroll safe)
          const Positioned.fill(
            child: IgnorePointer(
              child: _FloatingButterfliesOverlay(),
            ),
          ),
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
          final angleLeft = (sway - 0.5) * 0.08;
          final angleRight = (0.5 - sway) * 0.08;

          return SizedBox(
            height: 110,
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

                // Left corner swaying floral bouquet accent
                Positioned(
                  left: 16,
                  bottom: -14,
                  child: Transform.rotate(
                    angle: angleLeft,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: 0.72,
                      child: Image.asset(
                        'assets/images/banner_flowers_fade.png',
                        width: 120,
                        height: 110,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

                // Right corner swaying floral bouquet accent
                Positioned(
                  right: 16,
                  bottom: -14,
                  child: Transform.scale(
                    scaleX: -1,
                    child: Transform.rotate(
                      angle: angleRight,
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: 0.72,
                        child: Image.asset(
                          'assets/images/banner_flowers_fade.png',
                          width: 120,
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
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

  // =========================================================================
  // 2. HERO PURPLE INTERACTIVE GREETING BANNER
  // =========================================================================
  Widget _buildInteractiveHeroBanner(String displayName, DayPeriod period, String? avatarUrl) {
    String greetingTitle;
    String greetingSubtitle;
    String mascotBubble;
    String mascotSpeech;

    String card1Icon;
    String card1Title;
    String card1Speak;
    String card1YesFeedback;
    String card1NoFeedback;

    String card2Icon;
    String card2Title;
    String card2Speak;
    String card2YesFeedback;
    String card2NoFeedback;

    switch (period) {
      case DayPeriod.morning:
        greetingTitle = 'සුබ උදෑසනක්, $displayName! 👋';
        greetingSubtitle = 'ප්‍රීතිමත්, සුවබර උදෑසනක්! 💕';
        mascotBubble = 'අද උදයේ\nමූලික පුරුදු\nකරගත්තාද? 💜';
        mascotSpeech = 'නෆියා ඔබෙන් අසනවා: අද උදයේ මූලික පුරුදු කරගත්තාද?';

        card1Icon = '☕';
        card1Title = 'ඔබ අද\nතේ බිව්වද?';
        card1Speak = 'ඔබ අද තේ බිව්වද?';
        card1YesFeedback = 'ඔබ තේ පානය කර තිබීම සතුටක්!';
        card1NoFeedback = 'ඔබ තවම තේ බීලා නැත්නම්, මම රැකබලා ගන්නාට දැන්වුවා ඔබට උණුසුම් තේ එකක් ගෙන එන්න.';

        card2Icon = '🚿';
        card2Title = 'මුහුණ\nහෝදාගත්තාද?';
        card2Speak = 'මුහුණ හෝදාගත්තාද?';
        card2YesFeedback = 'ඉතා විශිෂ්ටයි! ඔබ ප්‍රබෝධමත්ව අද දවස සතුටින් ගත කිරීමට සූදානම්.';
        card2NoFeedback = 'අපි මුහුණ සෝදා ප්‍රබෝධමත් වෙමු. ඔබට උදව් අවශ්‍ය නම් රැකබලා ගන්නා දැනුවත් කර ඇත.';
        break;

      case DayPeriod.afternoon:
        greetingTitle = 'සුබ දහවලක්, $displayName! 👋';
        greetingSubtitle = 'ප්‍රබෝධමත්, සුවදායක දහවලක්! 💕';
        mascotBubble = 'අද දහවල්\nසුවපහසු විවේකය\nලබාගත්තාද? 💜';
        mascotSpeech = 'නෆියා ඔබෙන් අසනවා: අද දහවල් සුවපහසු විවේකය ලබාගත්තාද?';

        card1Icon = '🍲';
        card1Title = 'දිවා ආහාරය\nගත්තාද?';
        card1Speak = 'දිවා ආහාරය ගත්තාද?';
        card1YesFeedback = 'ඔබ දිවා ආහාරය ගෙන තිබීම සතුටක්!';
        card1NoFeedback = 'ඔබ තවම දිවා ආහාරය ගෙන නැත්නම්, ඔබට උදව් කිරීමට රැකබලා ගන්නා දැනුවත් කර ඇත.';

        card2Icon = '🛋️';
        card2Title = 'කෙටි විවේකයක්\nගත්තාද?';
        card2Speak = 'කෙටි විවේකයක් ගත්තාද?';
        card2YesFeedback = 'ඉතා විශිෂ්ටයි! කෙටි විවේකයක් ගැනීමෙන් ඔබේ මනසට සහ සිරුරට නව ප්‍රබෝධයක් ලැබේ.';
        card2NoFeedback = 'සුවදායක කෙටි විවේකයක් ලබා ගැනීමට සහායක කණ්ඩායම දැනුවත් කර ඇත.';
        break;

      case DayPeriod.evening:
        // 4:00 PM to 6:59 PM (Evening / සවස / සන්ධ්‍යාව)
        greetingTitle = 'සුබ සන්ධ්‍යාවක්, $displayName! 👋';
        greetingSubtitle = 'සන්සුන්, ප්‍රීතිමත් සන්ධ්‍යාවක්! 💕';
        mascotBubble = 'අද සවස\nනැවුම් සුවය\nවින්දාද? 💜';
        mascotSpeech = 'නෆියා ඔබෙන් අසනවා: අද සවස නැවුම් සුවය වින්දාද?';

        card1Icon = '☕';
        card1Title = 'සවස තේ පැන්\nපානය කළාද?';
        card1Speak = 'සවස තේ පැන් පානය කළාද?';
        card1YesFeedback = 'සවස උණුසුම් තේ පැන් පානය කර තිබීම සතුටක්!';
        card1NoFeedback = 'ඔබ තවම සවස තේ බීලා නැත්නම්, රැකබලා ගන්නා ඔබ වෙත පැමිණෙනු ඇත.';

        card2Icon = '🌿';
        card2Title = 'නැවුම් සුළං\nසුවය වින්දාද?';
        card2Speak = 'නැවුම් සුළං සුවය වින්දාද?';
        card2YesFeedback = 'නැවුම් සවස සුළං සුවය විඳීම ඔබේ මනස සන්සුන් කරයි!';
        card2NoFeedback = 'සවස නැවුම් සුළං සුවය විඳීමට ඔබට උපකාර කිරීමට රැකබලා ගන්නා පැමිණෙනු ඇත.';
        break;

      case DayPeriod.night:
        // 7:00 PM onwards (Night / රාත්‍රිය)
        greetingTitle = 'සුබ රාත්‍රියක්, $displayName! 👋';
        greetingSubtitle = 'සුවබර, සැනසිලිදායක රාත්‍රියක්! 💕';
        mascotBubble = 'අද රාත්‍රී\nසුව නින්දකට\nසූදානම්ද? 💜';
        mascotSpeech = 'නෆියා ඔබෙන් අසනවා: අද රාත්‍රී සුව නින්දකට සූදානම්ද?';

        card1Icon = '💊';
        card1Title = 'රාත්‍රී ආහාර හා\nඖෂධ ගත්තාද?';
        card1Speak = 'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද?';
        card1YesFeedback = 'ඉතා විශිෂ්ටයි! රාත්‍රී ආහාර සහ ඖෂධ නියමිත වේලාවට ලබා ගැනීම නීරෝගී බවට ඉතා වැදගත්.';
        card1NoFeedback = 'ඔබ තවම රාත්‍රී ආහාර හෝ ඖෂධ ගෙන නැත්නම්, ඔබට උදව් කිරීමට රැකබලා ගන්නා දැනුවත් කළා.';

        card2Icon = '🛏️';
        card2Title = 'සුව නින්දකට\nසූදානම්ද?';
        card2Speak = 'සුව නින්දකට සූදානම්ද?';
        card2YesFeedback = 'සුවබර, සැනසිලිදායක නින්දක් සහ මිහිරි සිහින ඔබට ප්‍රාර්ථනා කරනවා!';
        card2NoFeedback = 'සුව නින්දකට සූදානම් වීමට ඔබට උපකාර කිරීමට රැකබලා ගන්නා දැනුවත් කර ඇත.';
        break;
    }

    // Dynamic Mascot Reminder based on 3 Daily Assessment Slots
    final currentSlot = _getCurrentAssessmentSlot(_now);
    final currentSlotName = _getSlotNameSi(currentSlot);
    final emotionalSlotDone = _isSlotDone('emotional', currentSlot);
    final memorySlotDone = _isSlotDone('memory', currentSlot);

    if (!emotionalSlotDone) {
      mascotBubble = 'අද $currentSlotName\nසුවතා කතාබහ\nකරමුද? 💜';
      mascotSpeech = 'නෆියා ඔබෙන් අසනවා: අද $currentSlotName මානසික සුවතා කතාබහ කරමුද?';
    } else if (!memorySlotDone) {
      mascotBubble = 'අද $currentSlotName\nමතක ක්‍රීඩා\nකරමුද? 🧩';
      mascotSpeech = 'නෆියා ඔබෙන් අසනවා: අද $currentSlotName මතක පරීක්ෂාව සහ විනෝද ක්‍රීඩා කරමුද?';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6D28D9), // vibrant, elegant royal violet (softened from dark 0xFF3B0764)
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
            // Floral background decoration
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
              left: 380,
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

            // Main Banner Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1020;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left: Elder Photo & Dynamic Period Greeting
                            Expanded(
                              flex: 11,
                              child: _buildBannerLeftGreeting(greetingTitle, greetingSubtitle, avatarUrl),
                            ),
                            const SizedBox(width: 14),

                            // Center: Mascot & Speech Bubble
                            Expanded(
                              flex: 7,
                              child: _buildBannerCenterMascot(mascotBubble, mascotSpeech),
                            ),
                            const SizedBox(width: 14),

                            // Right: Routine Cards
                            Expanded(
                              flex: 14,
                              child: _buildBannerRightRoutineCards(
                                card1Icon: card1Icon,
                                card1Title: card1Title,
                                card1Speak: card1Speak,
                                card1YesFeedback: card1YesFeedback,
                                card1NoFeedback: card1NoFeedback,
                                card2Icon: card2Icon,
                                card2Title: card2Title,
                                card2Speak: card2Speak,
                                card2YesFeedback: card2YesFeedback,
                                card2NoFeedback: card2NoFeedback,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildBannerLeftGreeting(greetingTitle, greetingSubtitle, avatarUrl),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: _buildBannerCenterMascot(mascotBubble, mascotSpeech)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildBannerRightRoutineCards(
                              card1Icon: card1Icon,
                              card1Title: card1Title,
                              card1Speak: card1Speak,
                              card1YesFeedback: card1YesFeedback,
                              card1NoFeedback: card1NoFeedback,
                              card2Icon: card2Icon,
                              card2Title: card2Title,
                              card2Speak: card2Speak,
                              card2YesFeedback: card2YesFeedback,
                              card2NoFeedback: card2NoFeedback,
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  // Bottom Hydration Reminder Pill
                  if (_showHydrationReminder) ...[
                    const SizedBox(height: 10),
                    _buildHydrationReminderPill(),
                  ],
                ],
              ),
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
        // Elder photo
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            image: DecorationImage(
              image: _resolveAvatarImage(avatarUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Text Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),

              // Audio Pill "ඔබ ගැන අදත් හොඳින් සලකමු!"
              InkWell(
                onTap: () => _speak('$title $subtitle ඔබ ගැන අදත් හොඳින් සලකමු!'),
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.volume2, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'ඔබ ගැන අදත් හොඳින් සලකමු! ·|||··||·',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
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
    );
  }

  // Center mascot & dynamic speech bubble
  Widget _buildBannerCenterMascot(String bubbleText, String speakText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Robot mascot with breathing animation
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final dy = math.sin(_pulseController.value * math.pi) * 4.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Image.asset(
                'assets/images/clean_robot_transparent.png',
                width: 68,
                height: 68,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/elder_robot_mascot.png',
                  width: 68,
                  height: 68,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(LucideIcons.bot, size: 50, color: Colors.white),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),

        // Speech bubble
        Flexible(
          child: InkWell(
            onTap: () => _speak(speakText),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      bubbleText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B21A8),
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.volume2, size: 16, color: Color(0xFF7E22CE)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Right side: Routine Question Cards
  Widget _buildBannerRightRoutineCards({
    required String card1Icon,
    required String card1Title,
    required String card1Speak,
    required String card1YesFeedback,
    required String card1NoFeedback,
    required String card2Icon,
    required String card2Title,
    required String card2Speak,
    required String card2YesFeedback,
    required String card2NoFeedback,
  }) {
    return Row(
      children: [
        // Card 1
        Expanded(
          child: _buildSingleRoutineCard(
            icon: card1Icon,
            title: card1Title,
            speakText: card1Speak,
            isYes: _routine1AnsweredYes,
            isNo: _routine1AnsweredNo,
            onYes: () {
              setState(() {
                _routine1AnsweredYes = true;
                _routine1AnsweredNo = false;
              });
              _speak(card1YesFeedback);
            },
            onNo: () {
              setState(() {
                _routine1AnsweredYes = false;
                _routine1AnsweredNo = true;
              });
              _speak(card1NoFeedback);
            },
          ),
        ),
        const SizedBox(width: 10),

        // Card 2
        Expanded(
          child: _buildSingleRoutineCard(
            icon: card2Icon,
            title: card2Title,
            speakText: card2Speak,
            isYes: _routine2AnsweredYes,
            isNo: _routine2AnsweredNo,
            onYes: () {
              setState(() {
                _routine2AnsweredYes = true;
                _routine2AnsweredNo = false;
              });
              _speak(card2YesFeedback);
            },
            onNo: () {
              setState(() {
                _routine2AnsweredYes = false;
                _routine2AnsweredNo = true;
              });
              _speak(card2NoFeedback);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSingleRoutineCard({
    required String icon,
    required String title,
    required String speakText,
    required bool isYes,
    required bool isNo,
    required VoidCallback onYes,
    required VoidCallback onNo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Icon + Title + Speaker
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.2,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _speak(speakText),
                child: const Padding(
                  padding: EdgeInsets.all(3.0),
                  child: Icon(LucideIcons.volume2, size: 16, color: Color(0xFF7E22CE)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Action Buttons: ඔව් / තවම නැහැ
          Row(
            children: [
              // Yes Button
              Expanded(
                child: InkWell(
                  onTap: onYes,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: isYes ? const Color(0xFF16A34A) : const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: isYes
                          ? [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.check, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isYes ? 'කළා' : 'ඔව්',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Not yet Button
              Expanded(
                child: InkWell(
                  onTap: onNo,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: isNo ? const Color(0xFFF1F5F9) : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: isNo ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                        width: isNo ? 1.5 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 12,
                          color: isNo ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'තවම නැහැ',
                          style: TextStyle(
                            color: isNo ? const Color(0xFFEF4444) : const Color(0xFF475569),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
  }

  // Bottom Hydration Reminder
  Widget _buildHydrationReminderPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _speak('ජලය ප්‍රමාණවත් ලෙස පානය කිරීමට අමතක නොකරන්න.'),
            child: const Row(
              children: [
                Text(
                  'ජලය ප්‍රමාණවත් ලෙස පානය කිරීමට අමතක නොකරන්න. 💧',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(width: 8),
                Icon(LucideIcons.volume2, size: 16, color: Color(0xFF7E22CE)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => setState(() => _showHydrationReminder = false),
            child: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. QUICK ACCESS SECTION (4 UNIQUE, ATTRACTIVE ELDER-FRIENDLY CARDS)
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
        const Text(
          'ඉක්මන් සේවාවන් (Quick Access)',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 980;
            final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 980;

            final cards = [
              // Card 1: මානසික සුවතා කතාබහ (Rose/Pink Theme with Grandma Avatar & Blossom Trim)
              _buildQuickCard(
                backgroundColor: const Color(0xFFFFF0F5), // soft lavender blush / rose
                borderColor: emotionalDone ? const Color(0xFF86EFAC) : const Color(0xFFFECDD3),
                badgeIcon: '💓',
                topRightIllustration: _buildGrandmaWithHearts(),
                title: 'මානසික සුවතා\nකතාබහ',
                description: 'මගේ හැඟීම් බෙදාගන්න සහ මගේ මානසික සුවතාව තහවුරු කරන්න.',
                statusBadgeWidget: _buildSlotStatusBadge(
                  isCurrentDone: emotionalDone,
                  currentSlotName: currentSlotName,
                  activeColor: const Color(0xFF7E22CE),
                ),
                sessionTrackerWidget: _buildDailySessionTracker(
                  activity: 'emotional',
                  currentSlot: currentSlot,
                  activeThemeColor: const Color(0xFF7E22CE),
                ),
                buttonText: emotionalDone ? 'සම්පූර්ණයි ($nextSlotTime ට) ⏰' : 'ආරම්භ කරන්න →',
                buttonGradient: emotionalDone
                    ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
                    : const [Color(0xFF7E22CE), Color(0xFF9333EA)],
                bottomDecoration: _buildCard1BlossomTrim(),
                onTap: () {
                  if (emotionalDone) {
                    _showSessionAlreadyCompletedDialog(
                      context: context,
                      activityTitle: 'මානසික සුවතා කතාබහ',
                      activityKey: 'emotional',
                      slot: currentSlot,
                      onContinueAnyway: () {
                        context.go('/dashboard/emotional');
                      },
                    );
                  } else {
                    _markSessionCompleted('emotional', currentSlot);
                    _speak('මානසික සුවතා කතාබහ වෙත ඔබව සාදරයෙන් පිළිගන්නවා.');
                    context.go('/dashboard/emotional');
                  }
                },
              ),

              // Card 2: මතක පරීක්ෂාව සහ විනෝද ක්‍රීඩා (Warm Gold Theme with Calendar Puzzle & Autumn Leaves)
              _buildQuickCard(
                backgroundColor: const Color(0xFFFFFBEB), // warm cream/amber
                borderColor: memoryDone ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                badgeIcon: '🧩',
                topRightIllustration: _buildCalendarPuzzleIllustration(),
                title: 'මතක පරීක්ෂාව\nසහ විනෝද ක්‍රීඩා',
                description: 'මතකය සුවපත් කිරීම සහ මනස සැහැල්ලු කිරීම සඳහා ක්‍රියාකාරකම්.',
                statusBadgeWidget: _buildSlotStatusBadge(
                  isCurrentDone: memoryDone,
                  currentSlotName: currentSlotName,
                  activeColor: const Color(0xFFD97706),
                ),
                sessionTrackerWidget: _buildDailySessionTracker(
                  activity: 'memory',
                  currentSlot: currentSlot,
                  activeThemeColor: const Color(0xFFD97706),
                ),
                buttonText: memoryDone ? 'සම්පූර්ණයි ($nextSlotTime ට) ⏰' : 'ක්‍රීඩා කරන්න 🎮',
                buttonGradient: memoryDone
                    ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
                    : const [Color(0xFFD97706), Color(0xFFF59E0B)],
                bottomDecoration: _buildCard2LeavesTrim(),
                onTap: () {
                  if (memoryDone) {
                    _showSessionAlreadyCompletedDialog(
                      context: context,
                      activityTitle: 'මතක පරීක්ෂාව සහ විනෝද ක්‍රීඩා',
                      activityKey: 'memory',
                      slot: currentSlot,
                      onContinueAnyway: () {
                        context.go('/dashboard/memory-games');
                      },
                    );
                  } else {
                    _markSessionCompleted('memory', currentSlot);
                    _speak('මතක පරීක්ෂාව සහ විනෝද ක්‍රීඩා පිටුවට යමු.');
                    context.go('/dashboard/memory-games');
                  }
                },
              ),

              // Card 3: සන්සුන් සංගීතය සහ විවේක සුවය (Emerald Theme with Headphones & Park Landscape)
              _buildQuickCard(
                backgroundColor: const Color(0xFFF0FDF4), // soft mint emerald
                borderColor: const Color(0xFFBBF7D0),
                badgeIcon: '🎧',
                topRightIllustration: _buildHeadphonesMusicIllustration(),
                title: 'සන්සුන් සංගීතය\nසහ විවේක සුවය',
                description: 'සිත සන්සුන් කිරීම සහ සුවසේ විවේක ගැනීම.',
                buttonText: 'සංගීතය අසන්න ▶',
                buttonGradient: const [Color(0xFF059669), Color(0xFF10B981)],
                bottomDecoration: _buildParkNatureLandscape(),
                onTap: () {
                  _speak('සන්සුන් සංගීතය සහ ස්වභාවික ශබ්ද ඔබ වෙනුවෙන් වාදනය කරමු.');
                  _showMusicPlayerModal(context);
                },
              ),

              // Card 4: උපකාර ඉල්ලීම (Sky Blue Theme with Caregiver Avatar & Meadow Landscape)
              _buildQuickCard(
                backgroundColor: const Color(0xFFF0F9FF), // soft sky
                borderColor: const Color(0xFFBAE6FD),
                badgeIcon: '📞',
                topRightIllustration: _buildCaregiverWithHeadsetIllustration(),
                title: 'උපකාර ඉල්ලීම\n(සත්කාරක සම්බන්ධ වන්න)',
                description: 'ඔබට අවශ්‍යතාවයක් ඇති නම් රැකබලා ගන්නාට දැන්ම අමතන්න.',
                buttonText: '📞 අමතන්න දැන්ම',
                buttonGradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                bottomDecoration: _buildCottageMeadowLandscape(),
                onTap: () {
                  _handleEmergencyCall(context);
                },
              ),
            ];

            final isWide = constraints.maxWidth >= 680;

            if (isWide) {
              return Column(
                children: [
                  // Row 1 (Top): මානසික සුවතා කතාබහ & මතක පරීක්ෂාව සහ විනෝද ක්‍රීඩා
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Row 2 (Bottom): සන්සුන් සංගීතය සහ විවේක සුවය & උපකාර ඉල්ලීම
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: cards
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: c,
                        ))
                    .toList(),
              );
            }
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TOP-RIGHT ILLUSTRATIONS & BOTTOM SCENIC DECORATIONS FOR CARDS
  // =========================================================================

  // Card 1: Elder Grandmother with Floating Hearts
  Widget _buildGrandmaWithHearts() {
    return SizedBox(
      width: 90,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft radial glow
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFF472B6).withValues(alpha: 0.35),
                  const Color(0xFFFBCFE8).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          // Grandma portrait
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              color: const Color(0xFFFDE8E9),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/landing/testimonial_1.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('👵', style: TextStyle(fontSize: 34)),
                ),
              ),
            ),
          ),
          // Floating Hearts & Sparkles
          const Positioned(
            top: -2,
            right: 0,
            child: Text('💕', style: TextStyle(fontSize: 16)),
          ),
          const Positioned(
            top: 10,
            left: 0,
            child: Text('💖', style: TextStyle(fontSize: 13)),
          ),
          const Positioned(
            bottom: 2,
            right: 2,
            child: Text('✨', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Card 2: 3D Calendar + Pencil + Floating Puzzle Pieces
  Widget _buildCalendarPuzzleIllustration() {
    return SizedBox(
      width: 90,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft golden glow
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  const Color(0xFFFEF3C7).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          // Calendar sheet icon/card
          Transform.rotate(
            angle: 0.08,
            child: Container(
              width: 56,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Red calendar header bar
                  Container(
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CircleAvatar(radius: 1.5, backgroundColor: Colors.white),
                        CircleAvatar(radius: 1.5, backgroundColor: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        '28',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Angled Pencil
          Positioned(
            right: 0,
            bottom: 4,
            child: Transform.rotate(
              angle: -0.5,
              child: const Text('✏️', style: TextStyle(fontSize: 20)),
            ),
          ),
          // Floating puzzle piece
          const Positioned(
            top: -4,
            left: 2,
            child: Text('🧩', style: TextStyle(fontSize: 18)),
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
          // Soft cyan glow
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
          // Headphones circle
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
          // Floating notes
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
          // Soft sky blue glow
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
          // Caregiver avatar
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
          // Speech bubble
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
          // Headset pill
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

  // Card 3 Bottom Park Scenery with Rolling Hills, Tree & Bench
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
            Color(0xFFE0F2FE), // Soft sunny sky
            Color(0xFFBBF7D0), // Rolling green horizon
            Color(0xFF4ADE80), // Lush grass
            Color(0xFF16A34A), // Deep green meadow
          ],
        ),
      ),
      child: Stack(
        children: [
          // Gentle golden sun in background
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
          // Green Rolling Hill (Back)
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
          // Green Hill Foreground
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
          // Leafy Tree on right
          const Positioned(
            right: 18,
            bottom: 12,
            child: Text('🌳', style: TextStyle(fontSize: 42)),
          ),
          // Wooden Park Bench in center
          Positioned(
            left: 45,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF78350F), // warm rich wood
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

  // Card 4 Bottom Countryside Cottage Meadow Landscape
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
            Color(0xFFE0F2FE), // Soft sunny sky
            Color(0xFFBAE6FD),
            Color(0xFF86EFAC), // Lush meadow
            Color(0xFF15803D), // Deep green grass
          ],
        ),
      ),
      child: Stack(
        children: [
          // Soft cloud
          const Positioned(
            left: 20,
            top: 10,
            child: Text('☁️', style: TextStyle(fontSize: 20)),
          ),
          // Soft rolling hills (Back)
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
          // Rolling hill (Foreground)
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
          // Cozy Countryside Cottage House
          const Positioned(
            left: 36,
            bottom: 12,
            child: Text('🏡', style: TextStyle(fontSize: 38)),
          ),
          // Pine tree / shade tree
          const Positioned(
            right: 32,
            bottom: 14,
            child: Text('🌲', style: TextStyle(fontSize: 36)),
          ),
        ],
      ),
    );
  }

  // Card 1 Bottom Blossom Trim
  Widget _buildCard1BlossomTrim() {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(bottom: 6),
      alignment: Alignment.bottomCenter,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌸', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text('🌺', style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Text('🌸', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text('🌷', style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Text('🌸', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // Card 2 Bottom Autumn Leaves Trim
  Widget _buildCard2LeavesTrim() {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(bottom: 6),
      alignment: Alignment.bottomCenter,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🍂', style: TextStyle(fontSize: 15)),
          SizedBox(width: 8),
          Text('🍁', style: TextStyle(fontSize: 17)),
          SizedBox(width: 8),
          Text('🌾', style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Text('🍁', style: TextStyle(fontSize: 17)),
          SizedBox(width: 8),
          Text('🍂', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  // =========================================================================
  // UNIFIED QUICK ACCESS CARD WIDGET
  // =========================================================================
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
    Widget? statusBadgeWidget,
    Widget? sessionTrackerWidget,
    Widget? bottomDecoration,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 450),
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
            // Top Padding & Main Content
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Circular Icon on Left & Rich Illustration on Right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Circular Icon Badge
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(badgeIcon, style: const TextStyle(fontSize: 30)),
                      ),

                      // Top-Right Illustration
                      topRightIllustration,
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Optional Status Badge (e.g. 🔔 තවම කර නැත / ✅ සම්පූර්ණයි)
                  if (statusBadgeWidget != null) ...[
                    statusBadgeWidget,
                    const SizedBox(height: 10),
                  ],

                  // Left-Aligned Title (clean, bold Sinhala typography)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      height: 1.22,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Left-Aligned Description
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Optional 3-Daily Sessions Tracker
                  if (sessionTrackerWidget != null) ...[
                    sessionTrackerWidget,
                    const SizedBox(height: 12),
                  ],

                  // Action Button (when tracker exists or no bottom scenery)
                  if (bottomDecoration == null || sessionTrackerWidget != null) ...[
                    InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: buttonGradient),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: buttonGradient.first.withValues(alpha: 0.40),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          buttonText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // For Card 3 or Card 4: Action button above the scenery
            if (bottomDecoration != null && sessionTrackerWidget == null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: buttonGradient),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: buttonGradient.first.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      buttonText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],


            // Bottom Scenery or Blossom/Leaves Trim
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
