import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';

class ElderInteractiveHomePage extends ConsumerStatefulWidget {
  const ElderInteractiveHomePage({super.key});

  @override
  ConsumerState<ElderInteractiveHomePage> createState() =>
      _ElderInteractiveHomePageState();
}

class _ElderInteractiveHomePageState
    extends ConsumerState<ElderInteractiveHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Routine check state
  bool _teaAnsweredYes = false;
  bool _teaAnsweredNo = false;
  bool _foodAnsweredYes = false;
  bool _foodAnsweredNo = false;
  bool _showHydrationReminder = true;
  bool _isPlayingVoice = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });

    // Warm greeting speech on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInitialGreeting();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  void _speakInitialGreeting() {
    final hour = _now.hour;
    String greeting;
    if (hour < 12) {
      greeting = 'සුබ උදෑසනක්, මල්ලී අම්මා! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
    } else if (hour < 17) {
      greeting = 'සුබ දහවලක්, මල්ලී අම්මා! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
    } else if (hour < 21) {
      greeting = 'සුබ සන්ධ්‍යාවක්, මල්ලී අම්මා! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
    } else {
      greeting = 'සුබ රාත්‍රියක්, මල්ලී අම්මා! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද?';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final isSinhala = ref.watch(languageProvider).isSinhala;

    final elderDisplayName = authState.userName != null && authState.userName!.isNotEmpty
        ? (isSinhala ? 'මල්ලී අම්මා' : authState.userName!)
        : (isSinhala ? 'මල්ලී අම්මා' : 'Sarah Jenkins');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar / Status Strip
            _buildTopStatusStrip(elderDisplayName, isSinhala),
            const SizedBox(height: 16),

            // 2. Hero Purple Interactive Greeting Banner
            _buildInteractiveHeroBanner(elderDisplayName, isSinhala),
            const SizedBox(height: 24),

            // 3. Quick Access Title & 4 Large Action Cards
            _buildQuickAccessSection(context, isSinhala),
            const SizedBox(height: 24),

            // 4. Bottom Row (My Wellness, Recent Activity, Nature Quote)
            _buildBottomDashboardRow(context, isSinhala),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. TOP STATUS STRIP
  // =========================================================================
  Widget _buildTopStatusStrip(String displayName, bool isSinhala) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: [
          // Date & Time Pills
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      _formatSinhalaDate(_now),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(_now),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Language, Notifications & Profile
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Language Selector Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Text('🇱🇰', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'සිංහල',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF64748B)),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Notification Bell
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.bell, size: 18, color: Color(0xFF475569)),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Elder Avatar & Details
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA855F7), width: 2),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/landing/testimonial_1.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Text(
                        'වයස: 72',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
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

  // =========================================================================
  // 2. HERO PURPLE INTERACTIVE GREETING BANNER
  // =========================================================================
  Widget _buildInteractiveHeroBanner(String displayName, bool isSinhala) {
    final hour = _now.hour;
    String greetingTitle;
    String greetingSubtitle = 'ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද? 🤍';

    if (hour < 12) {
      greetingTitle = 'සුබ උදෑසනක්, $displayName! 👋';
    } else if (hour < 17) {
      greetingTitle = 'සුබ දහවලක්, $displayName! 👋';
    } else if (hour < 21) {
      greetingTitle = 'සුබ සන්ධ්‍යාවක්, $displayName! 👋';
    } else {
      greetingTitle = 'සුබ රාත්‍රියක්, $displayName! 👋';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3B0764), // deep violet
            Color(0xFF581C87), // vivid purple
            Color(0xFF7E22CE), // rich purple
            Color(0xFF9333EA), // electric purple
            Color(0xFFA855F7), // lavender glow
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: const Color(0xFFC084FC).withValues(alpha: 0.85),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
                            // Left: Elder Photo & Greeting
                            Expanded(
                              flex: 11,
                              child: _buildBannerLeftGreeting(greetingTitle, greetingSubtitle),
                            ),
                            const SizedBox(width: 14),

                            // Center: Mascot & Speech Bubble
                            Expanded(
                              flex: 7,
                              child: _buildBannerCenterMascot(),
                            ),
                            const SizedBox(width: 14),

                            // Right: Routine Cards
                            Expanded(
                              flex: 14,
                              child: _buildBannerRightRoutineCards(),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildBannerLeftGreeting(greetingTitle, greetingSubtitle),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: _buildBannerCenterMascot()),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildBannerRightRoutineCards(),
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

  // Left side of banner: Elder smiling photo + Greeting
  Widget _buildBannerLeftGreeting(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Elder photo with green nature aura
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
            image: const DecorationImage(
              image: AssetImage('assets/images/landing/testimonial_1.jpg'),
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
                  fontSize: 20,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),

              // Audio Pill "ඔබ ගැන අදත් හොඳින් සලකමු!"
              InkWell(
                onTap: () => _speak('සුබ දහවලක්, මල්ලී අම්මා! ඔබගේ සුවබර දිනය අදත් හොඳින් ගතවේවි ද? ඔබ ගැන අදත් හොඳින් සලකමු!'),
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.volume2, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text(
                        'ඔබ ගැන අදත් හොඳින් සලකමු! ·|||··||·',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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

  // Center mascot & speech bubble
  Widget _buildBannerCenterMascot() {
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
            onTap: () => _speak('මගේ දෛනික පුරුදු පිළිබඳ සොයා බලන්න. අද ඔබට උදාවුණානේද?'),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'මගේ දෛනික පුරුදු\nපිළිබඳ සුමන්ද? 💜',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B21A8),
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(LucideIcons.volume2, size: 14, color: Color(0xFF7E22CE)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Right side: Routine Question Cards (Tea & Meal)
  Widget _buildBannerRightRoutineCards() {
    return Row(
      children: [
        // Card 1: ඔබ අද තේ බිව්වද?
        Expanded(
          child: _buildSingleRoutineCard(
            icon: '☕',
            title: 'ඔබ අද\nතේ බිව්වද?',
            speakText: 'ඔබ අද තේ බිව්වද?',
            isYes: _teaAnsweredYes,
            isNo: _teaAnsweredNo,
            onYes: () {
              setState(() {
                _teaAnsweredYes = true;
                _teaAnsweredNo = false;
              });
              _speak('ඔබ තේ පානය කර තිබීම සතුටක්!');
            },
            onNo: () {
              setState(() {
                _teaAnsweredYes = false;
                _teaAnsweredNo = true;
              });
              _speak('ඔබ තවම තේ බීලා නැත්නම්, මම රැකබලා ගන්නාට දැන්වුවා ඔබට උණුසුම් තේ එකක් ගෙන එන්න.');
            },
          ),
        ),
        const SizedBox(width: 10),

        // Card 2: ඔබ අද ආහාර ගත්තාද?
        Expanded(
          child: _buildSingleRoutineCard(
            icon: '🍲',
            title: 'ඔබ අද\nආහාර ගත්තාද?',
            speakText: 'ඔබ අද ආහාර ගත්තාද?',
            isYes: _foodAnsweredYes,
            isNo: _foodAnsweredNo,
            onYes: () {
              setState(() {
                _foodAnsweredYes = true;
                _foodAnsweredNo = false;
              });
              _speak('ඔබ දිවා ආහාරය ගෙන තිබීම සතුටක්!');
            },
            onNo: () {
              setState(() {
                _foodAnsweredYes = false;
                _foodAnsweredNo = true;
              });
              _speak('ඔබ තවම ආහාර ගෙන නැත්නම්, ඔබට උදව් කිරීමට රැකබලා ගන්නා දැනුවත් කර ඇත.');
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
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.15,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _speak(speakText),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(LucideIcons.volume2, size: 14, color: Color(0xFF7E22CE)),
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
                    padding: const EdgeInsets.symmetric(vertical: 5),
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
                        const Icon(LucideIcons.check, size: 11, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          isYes ? 'බිව්වා' : 'ඔව්',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
                    padding: const EdgeInsets.symmetric(vertical: 5),
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
                          size: 10,
                          color: isNo ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'තවම නැහැ',
                          style: TextStyle(
                            color: isNo ? const Color(0xFFEF4444) : const Color(0xFF475569),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
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
          const Text('🔔', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _speak('ජලය ප්‍රමාණවත් ලෙස පානය කිරීමට අමතක නොකරන්න.'),
            child: const Row(
              children: [
                Text(
                  'ජලය ප්‍රමාණවත් ලෙස පානය කිරීමට අමතක නොකරන්න. 💧',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(width: 6),
                Icon(LucideIcons.volume2, size: 13, color: Color(0xFF7E22CE)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => setState(() => _showHydrationReminder = false),
            child: const Icon(LucideIcons.x, size: 14, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. QUICK ACCESS SECTION (4 LARGE ATTRACTIVE CARDS)
  // =========================================================================
  Widget _buildQuickAccessSection(BuildContext context, bool isSinhala) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ඉක්මන් සේවාවන් (Quick Access)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
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
              // Card 1: මානසික සුවතා කතාබහ
              _buildQuickCard(
                backgroundColor: const Color(0xFFFFF1F2), // soft rose
                borderColor: const Color(0xFFFECDD3),
                badgeIcon: '💖',
                title: 'මානසික සුවතා\nකතාබහ',
                description: 'මගේ හැඟීම් බෙදාගන්න සහ මගේ මානසික සුවතාව තහවුරු කරගන්න.',
                buttonText: 'ආරම්භ කරන්න →',
                buttonGradient: const [Color(0xFF7E22CE), Color(0xFF9333EA)],
                onTap: () {
                  _speak('මානසික සුවතා කතාබහ වෙත ඔබව සාදරයෙන් පිළිගන්නවා.');
                  context.go('/dashboard/emotional');
                },
              ),

              // Card 2: මතක පරීක්ෂාව සහ විනෝද ක්‍රීඩා
              _buildQuickCard(
                backgroundColor: const Color(0xFFFFFBEB), // soft amber
                borderColor: const Color(0xFFFDE68A),
                badgeIcon: '🧩',
                title: 'මතක පරීක්ෂාව\nසහ විනෝද ක්‍රීඩා',
                description: 'මතකය සුවපත් කරන සුවිශේෂී ක්‍රීඩා විඳින්න.',
                buttonText: 'ක්‍රීඩා කරන්න 🎮',
                buttonGradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                onTap: () {
                  _speak('මතක පරීක්ෂාව සහ විනෝද ක්‍රීඩා පිටුවට යමු.');
                  context.go('/dashboard/memory-games');
                },
              ),

              // Card 3: සන්සුන් සංගීතය සහ ස්වභාවික නාද
              _buildQuickCard(
                backgroundColor: const Color(0xFFF0FDF4), // soft emerald
                borderColor: const Color(0xFFBBF7D0),
                badgeIcon: '🎧',
                title: 'සන්සුන් සංගීතය\nසහ ස්වභාවික නාද',
                description: 'සිත සන්සුන් කරන ගීත සහ පරිසර ශබ්ද ශ්‍රවණය කරන්න.',
                buttonText: 'සංගීතය අසන්න ▶',
                buttonGradient: const [Color(0xFF059669), Color(0xFF10B981)],
                onTap: () {
                  _speak('සන්සුන් සංගීතය සහ ස්වභාවික ශබ්ද ඔබ වෙනුවෙන් වාදනය කරමු.');
                  _showMusicPlayerModal(context);
                },
              ),

              // Card 4: උපකාර ඉල්ලීම
              _buildQuickCard(
                backgroundColor: const Color(0xFFF0F9FF), // soft sky
                borderColor: const Color(0xFFBAE6FD),
                badgeIcon: '📞',
                title: 'උපකාර ඉල්ලීම\n(සත්කාරක සමඟ සම්බන්ධ වන්න)',
                description: 'ඔබට අවශ්‍යතාවයක් ඇති නම් රැකබලා ගන්නාට දැනුම් දෙන්න.',
                buttonText: 'ඇමතුමක් දෙන්න 📞',
                buttonGradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                onTap: () {
                  _handleEmergencyCall(context);
                },
              ),
            ];

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
              );
            } else if (isTablet) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildQuickCard({
    required Color backgroundColor,
    required Color borderColor,
    required String badgeIcon,
    required String title,
    required String description,
    required String buttonText,
    required List<Color> buttonGradient,
    required VoidCallback onTap,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Icon Circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(badgeIcon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: buttonGradient),
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: buttonGradient.first.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
                  fontSize: 13,
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
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          '78%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Wellness Score',
                          style: TextStyle(
                            fontSize: 8,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('😊', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ඔබගේ මානසික සුවතාව හොඳ මට්ටමක පවතී! 🌿',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'දිගටම ඔබේ දෛනික පුරුදු පවත්වාගෙන යන්න.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
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
                  fontSize: 13,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
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
              fontSize: 10,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Flexible(
                        child: Text(
                          '“සුබ සිතක්,\nසුවබර ජීවිතයකට\nමගක් වේ.”',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4C1D95),
                            height: 1.3,
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
        title: Row(
          children: const [
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
            Row(
              children: const [
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
