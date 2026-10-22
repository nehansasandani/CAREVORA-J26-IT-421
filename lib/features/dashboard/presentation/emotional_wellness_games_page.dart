import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../assessment/application/care_plans_service.dart';
import '../../auth/application/auth_controller.dart';

enum EmotionalGameType {
  none,
  gratitudeGarden,
  wisdomMatch,
  butterflyCalm,
}

class EmotionalWellnessGamesPage extends ConsumerStatefulWidget {
  final EmotionalGameType initialGame;

  const EmotionalWellnessGamesPage({
    super.key,
    this.initialGame = EmotionalGameType.none,
  });

  @override
  ConsumerState<EmotionalWellnessGamesPage> createState() =>
      _EmotionalWellnessGamesPageState();
}

class _EmotionalWellnessGamesPageState
    extends ConsumerState<EmotionalWellnessGamesPage> {
  late EmotionalGameType _activeGame;
  int _joyPoints = 120;
  final bool _audioEnabled = true;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _activeGame = widget.initialGame;
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  void _speak(String text) {
    if (_audioEnabled) {
      try {
        _tts.speak(text);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _selectGame(EmotionalGameType game) {
    setState(() => _activeGame = game);
    _speak('Starting game. Relax, enjoy, and have a wonderful time.');
  }

  void _backToHub() {
    _tts.stop();
    setState(() => _activeGame = EmotionalGameType.none);
  }

  void _addJoyPoints(int points) {
    setState(() => _joyPoints += points);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final elderName = authState.userName ?? 'Resident Elder';

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _activeGame == EmotionalGameType.none
                    ? _buildGameHub(elderName)
                    : _buildActiveGameView(elderName),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. GAME HUB (Selector & Daily Wellness Stats)
  // -------------------------------------------------------------
  Widget _buildGameHub(String elderName) {
    return Column(
      key: const ValueKey('game_hub'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back to Assessment / Dashboard
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard/emotional');
                }
              },
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text('Back to Emotional Wellness', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF472B6).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6),
                ],
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFFDB2777)),
                  const SizedBox(width: 8),
                  Text(
                    'Joy Points: $_joyPoints ⭐',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Hero Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFCE7F3), Color(0xFFEDE9FE), Color(0xFFE0E7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFBCFE8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDB2777).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                  ],
                ),
                child: const Icon(LucideIcons.heartHandshake, size: 36, color: Color(0xFFDB2777)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Welcome, $elderName! 🌸',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDB2777),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '15-Minute Joy Sessions',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'මනෝ සුව සහ ප්‍රීතිමත් ක්‍රීඩා • Gentle, joyful, and peaceful interactive games tailored for senior relaxation, positive mood enhancement, and social connection.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title
        const Text(
          'Choose an Emotional Wellness Game (ක්‍රීඩාවක් තෝරන්න)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        const SizedBox(height: 6),
        const Text(
          'Each game is designed for a relaxing 15-minute session to bring happiness, calm, and nostalgia.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),

        // 3 Game Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                _buildGameCard(
                  width: isWide ? (constraints.maxWidth - 36) / 3 : constraints.maxWidth,
                  icon: LucideIcons.flower2,
                  iconColor: const Color(0xFFDB2777),
                  iconBg: const Color(0xFFFCE7F3),
                  title: 'Gratitude Garden',
                  sinhalaTitle: 'සතුටු මල් උයන',
                  description: 'Select positive memories, happy blessings, and watch colorful flowers bloom with gentle chimes.',
                  duration: '15 Mins',
                  moodBenefit: 'Uplifting • Gratitude',
                  onPlay: () => _selectGame(EmotionalGameType.gratitudeGarden),
                ),
                _buildGameCard(
                  width: isWide ? (constraints.maxWidth - 36) / 3 : constraints.maxWidth,
                  icon: LucideIcons.puzzle,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFEDE9FE),
                  title: 'Wisdom & Proverbs Harmony',
                  sinhalaTitle: 'ප්‍රස්ථා පිරුළු සහ මනෝ සුව රිද්මය',
                  description: 'Match classic beloved Sinhala proverbs and comforting sayings to stimulate joyful reminiscing.',
                  duration: '15 Mins',
                  moodBenefit: 'Nostalgia • Peaceful Joy',
                  onPlay: () => _selectGame(EmotionalGameType.wisdomMatch),
                ),
                _buildGameCard(
                  width: isWide ? (constraints.maxWidth - 36) / 3 : constraints.maxWidth,
                  icon: LucideIcons.sparkles,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  title: 'Serenity Touch & Butterfly Calm',
                  sinhalaTitle: 'සන්සුන් සමනල සහ නෙලුම් සැනසීම',
                  description: 'Gently tap floating butterflies and blooming lotus petals accompanied by guided mindful breathing.',
                  duration: '15 Mins',
                  moodBenefit: 'Relaxation • Stress Relief',
                  onPlay: () => _selectGame(EmotionalGameType.butterflyCalm),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // Weekly Recommendation & Tips
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.smile, color: Color(0xFF166534), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clinical Benefit of 15-Minute Emotional Play (මනෝ සුව ක්‍රීඩා වල වැදගත්කම)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Engaging in lighthearted relaxation games for 15 minutes stimulates dopaminergic reward pathways, significantly lowers subjective isolation scores, and fosters a cheerful, grounded sense of accomplishment.',
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

  Widget _buildGameCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String sinhalaTitle,
    required String description,
    required String duration,
    required String moodBenefit,
    required VoidCallback onPlay,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(duration, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 2),
          Text(
            sinhalaTitle,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppColors.body, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              moodBenefit,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPlay,
              icon: const Icon(LucideIcons.playCircle, size: 16),
              label: const Text('Play 15-Min Game (ක්‍රීඩා කරන්න)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. ACTIVE GAME CONTROLLER & WRAPPER
  // -------------------------------------------------------------
  Widget _buildActiveGameView(String elderName) {
    switch (_activeGame) {
      case EmotionalGameType.gratitudeGarden:
        return _GratitudeGardenGame(
          key: const ValueKey('gratitude_garden'),
          elderName: elderName,
          onBack: _backToHub,
          onComplete: (points) {
            _addJoyPoints(points);
            _backToHub();
          },
        );
      case EmotionalGameType.wisdomMatch:
        return _WisdomMatchGame(
          key: const ValueKey('wisdom_match'),
          elderName: elderName,
          onBack: _backToHub,
          onComplete: (points) {
            _addJoyPoints(points);
            _backToHub();
          },
        );
      case EmotionalGameType.butterflyCalm:
        return _ButterflyCalmGame(
          key: const ValueKey('butterfly_calm'),
          elderName: elderName,
          onBack: _backToHub,
          onComplete: (points) {
            _addJoyPoints(points);
            _backToHub();
          },
        );
      case EmotionalGameType.none:
        return const SizedBox.shrink();
    }
  }
}

// ====================================================================
// GAME 1: GRATITUDE BLOSSOM GARDEN (සතුටු මල් උයන)
// ====================================================================
class _GratitudeGardenGame extends StatefulWidget {
  final String elderName;
  final VoidCallback onBack;
  final ValueChanged<int> onComplete;

  const _GratitudeGardenGame({
    super.key,
    required this.elderName,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<_GratitudeGardenGame> createState() => _GratitudeGardenGameState();
}

class _GratitudeGardenGameState extends State<_GratitudeGardenGame> {
  int _secondsRemaining = 900; // 15 minutes = 900 seconds
  Timer? _sessionTimer;
  int _bloomedCount = 0;
  String _activeAffirmation = 'Choose a memory or blessing to water and blossom!';
  String _activeAffirmationSinhala = 'ඔබ කැමති ප්‍රීතිමත් මතකයක් තෝරා මල් පිබිදෙන්න සලස්වන්න!';

  final List<Map<String, dynamic>> _flowers = [
    {
      'title': 'Family Love',
      'sinhala': 'පවුලේ ආදරය සහ බැඳීම',
      'icon': LucideIcons.heart,
      'color': const Color(0xFFDB2777),
      'isBloomed': false,
      'affirmation': 'Your family loves and cherishes your presence every single day.',
      'affSinhala': 'ඔබගේ පවුල සැමවිටම ඔබට ආදරය හා ගෞරවය දක්වයි.',
    },
    {
      'title': 'Sunny Morning Calm',
      'sinhala': 'උදෑසන මෘදු හිරු එළිය',
      'icon': LucideIcons.sun,
      'color': const Color(0xFFD97706),
      'isBloomed': false,
      'affirmation': 'Each morning is a fresh gift of peace, health, and quiet joy.',
      'affSinhala': 'සෑම උදෑසනක්ම නැවුම් සාමකාමී ආශිර්වාදයකි.',
    },
    {
      'title': 'A Melody of Memories',
      'sinhala': 'ප්‍රියතම මිහිරි ගීතයක්',
      'icon': LucideIcons.music,
      'color': const Color(0xFF7C3AED),
      'isBloomed': false,
      'affirmation': 'Music brings timeless nostalgia and lightens your heart with serenity.',
      'affSinhala': 'සන්සුන් ගීතය සිතට අසීමිත සැනසීම හා ප්‍රීතිය ගෙනදෙයි.',
    },
    {
      'title': 'Warm Cup of Ceylon Tea',
      'sinhala': 'මිතුරෙකු සමඟ තේ පානය',
      'icon': LucideIcons.coffee,
      'color': const Color(0xFF059669),
      'isBloomed': false,
      'affirmation': 'Simple comforts and friendly conversation brighten the whole afternoon.',
      'affSinhala': 'සුහද කතාබහ සිතට ලෙන්ගතු බව හා සතුට එක් කරයි.',
    },
    {
      'title': 'Kindness Received & Given',
      'sinhala': 'කරුණාවන්ත සිතුවිලි',
      'icon': LucideIcons.smile,
      'color': const Color(0xFF0284C7),
      'isBloomed': false,
      'affirmation': 'Your kind heart radiates warmth to everyone in your facility.',
      'affSinhala': 'ඔබගේ කාරුණික හදවත සැමට සැනසීමක් ගෙන දෙයි.',
    },
    {
      'title': 'Green Nature & Birds',
      'sinhala': 'සොබාදහමේ සුන්දරත්වය',
      'icon': LucideIcons.trees,
      'color': const Color(0xFF16A34A),
      'isBloomed': false,
      'affirmation': 'Nature breathes life and tranquil peace into your thoughts.',
      'affSinhala': 'ගහකොළ සහ සොබාදහම මනස නිරවුල් කර සන්සුන් කරයි.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        _celebrateCompletion();
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _bloomFlower(int index) {
    if (_flowers[index]['isBloomed'] == true) return;
    setState(() {
      _flowers[index]['isBloomed'] = true;
      _bloomedCount++;
      _activeAffirmation = _flowers[index]['affirmation'] as String;
      _activeAffirmationSinhala = _flowers[index]['affSinhala'] as String;
    });

    if (_bloomedCount == _flowers.length) {
      _celebrateCompletion();
    }
  }

  void _celebrateCompletion() {
    _sessionTimer?.cancel();
    final now = DateTime.now();
    final dateStr = '${now.day} Oct ${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    CarePlansService.recordCompletedSession(
      songTitle: 'Gratitude Garden Blossom (සතුටු මල් උයන)',
      songArtist: '15-Min Emotional Wellness Game',
      dateText: dateStr,
      durationText: '15 Mins',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.flower2, size: 48, color: Color(0xFFDB2777)),
            const SizedBox(height: 12),
            const Text(
              '🌸 Garden in Full Bloom!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            const Text(
              'ඔබ විනාඩි 15 ක සතුටු මල් උයන සාර්ථකව අවසන් කළා! සිතට සතුට හා සහනය පිරී ඇත.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.body),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE7F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '+150 Joy Points Earned! ⭐',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF831843)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onComplete(150);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDB2777),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Continue (ඉදිරියට යන්න)'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimer(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Game Header Bar with 15-min countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text('Back to Games Hub', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF43F5E)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.timer, size: 16, color: Color(0xFFE11D48)),
                  const SizedBox(width: 6),
                  Text(
                    '15-Min Timer: ${_formatTimer(_secondsRemaining)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFBE123C)),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _celebrateCompletion,
              icon: const Icon(LucideIcons.checkCheck, size: 14),
              label: const Text('Finish Early ✓'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Affirmation Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFBCFE8)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.sparkles, color: Color(0xFFDB2777), size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeAffirmationSinhala,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF831843)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeAffirmation,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Flowers Garden Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
          ),
          itemCount: _flowers.length,
          itemBuilder: (ctx, i) {
            final f = _flowers[i];
            final bool bloomed = f['isBloomed'] as bool;
            final Color color = f['color'] as Color;

            return InkWell(
              onTap: () => _bloomFlower(i),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bloomed ? color.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: bloomed ? color : AppColors.border,
                    width: bloomed ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      bloomed ? LucideIcons.flower2 : (f['icon'] as IconData),
                      size: 34,
                      color: bloomed ? color : AppColors.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      f['sinhala'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: bloomed ? color : AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f['title'] as String,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bloomed ? '🌸 Bloomed (පිබිදුණි)' : '💧 Tap to Water',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: bloomed ? const Color(0xFF059669) : color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ====================================================================
// GAME 2: WISDOM & PROVERBS HARMONY (ප්‍රස්ථා පිරුළු සහ මනෝ සුව රිද්මය)
// ====================================================================
class _WisdomMatchGame extends StatefulWidget {
  final String elderName;
  final VoidCallback onBack;
  final ValueChanged<int> onComplete;

  const _WisdomMatchGame({
    super.key,
    required this.elderName,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<_WisdomMatchGame> createState() => _WisdomMatchGameState();
}

class _WisdomMatchGameState extends State<_WisdomMatchGame> {
  int _secondsRemaining = 900;
  Timer? _timer;
  int _currentIndex = 0;
  int _score = 0;
  String? _feedback;
  bool _answered = false;

  final List<Map<String, dynamic>> _proverbs = [
    {
      'firstHalf': 'කළ හොඳ කවදාවත්...',
      'englishPrompt': 'Good deeds done with a pure heart...',
      'correctAnswer': 'නැතිවෙන්නේ නෑ (Are never lost)',
      'options': [
        'නැතිවෙන්නේ නෑ (Are never lost)',
        'අමතක වෙයි (Get forgotten)',
        'ආපසු එන්නේ නෑ (Never return)',
      ],
      'comfortingMessage': 'ඉතා විශිෂ්ටයි! ඔබගේ යහපත් ක්‍රියා සදාකාලික සතුටක් ගෙන දේ.',
    },
    {
      'firstHalf': 'සිනහවෙන් පිරි මුහුණක්...',
      'englishPrompt': 'A joyful smiling face...',
      'correctAnswer': 'හදවතට සැනසීමකි (Brings peace to the heart)',
      'options': [
        'වෙහෙසකරයි (Is exhausting)',
        'හදවතට සැනසීමකි (Brings peace to the heart)',
        'කාලය නාස්තියකි (Wastes time)',
      ],
      'comfortingMessage': 'සුන්දරයි! සිනහව ඔබගේ ශරීරයටත් මනසටත් ඖෂධයකි.',
    },
    {
      'firstHalf': 'හිත හොඳ නම්...',
      'englishPrompt': 'If your heart is pure and calm...',
      'correctAnswer': 'හැමදේම යහපත් වේ (Everything turns into good)',
      'options': [
        'කරදර වැඩිවේ (Troubles increase)',
        'හැමදේම යහපත් වේ (Everything turns into good)',
        'අමාරුයි (It is difficult)',
      ],
      'comfortingMessage': 'විශිෂ්ටයි! පිරිසිදු සිත සැමවිටම ජයග්‍රහණය කරයි.',
    },
    {
      'firstHalf': 'සන්සුන් සිතක් ඇත්තා...',
      'englishPrompt': 'The one with a peaceful tranquil mind...',
      'correctAnswer': 'සුවසේ සැතපේ (Enjoys deep peaceful rest)',
      'options': [
        'සුවසේ සැතපේ (Enjoys deep peaceful rest)',
        'බියෙන් පසුවේ (Lives in fear)',
        'වෙහෙස වේ (Feels tired)',
      ],
      'comfortingMessage': 'අගෙයි! සන්සුන් සිතුවිලි සුවබර නින්දකට මඟ පාදයි.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        _finishGame();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _chooseOption(String option) {
    if (_answered) return;
    final item = _proverbs[_currentIndex];
    final bool correct = option == item['correctAnswer'];

    setState(() {
      _answered = true;
      if (correct) {
        _score += 30;
        _feedback = item['comfortingMessage'] as String;
      } else {
        _feedback = 'නැවත උත්සාහ කරන්න: නිවැරදි පිළිතුර — ${item['correctAnswer']}';
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentIndex < _proverbs.length - 1) {
        setState(() {
          _currentIndex++;
          _answered = false;
          _feedback = null;
        });
      } else {
        _finishGame();
      }
    });
  }

  void _finishGame() {
    _timer?.cancel();
    final now = DateTime.now();
    final dateStr = '${now.day} Oct ${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    CarePlansService.recordCompletedSession(
      songTitle: 'Wisdom & Proverbs Harmony (ප්‍රස්ථා පිරුළු)',
      songArtist: '15-Min Emotional Wellness Game',
      dateText: dateStr,
      durationText: '15 Mins',
    );

    widget.onComplete(_score);
  }

  String _formatTimer(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final current = _proverbs[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text('Back to Games Hub', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF8B5CF6)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    '15-Min Timer: ${_formatTimer(_secondsRemaining)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                  ),
                ],
              ),
            ),
            Text('Score: $_score ⭐', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
          ],
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(LucideIcons.quote, size: 38, color: Color(0xFF7C3AED)),
              const SizedBox(height: 14),
              Text(
                current['firstHalf'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 6),
              Text(
                current['englishPrompt'] as String,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              if (_feedback != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                  ),
                ),
              Column(
                children: (current['options'] as List<String>).map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _answered ? null : () => _chooseOption(opt),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F3FF),
                          foregroundColor: const Color(0xFF5B21B6),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFDDD6FE), width: 1.5),
                          ),
                        ),
                        child: Text(
                          opt,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// GAME 3: SERENITY BUTTERFLY & LOTUS CALM (සන්සුන් සමනල සැනසීම)
// ====================================================================
class _ButterflyCalmGame extends StatefulWidget {
  final String elderName;
  final VoidCallback onBack;
  final ValueChanged<int> onComplete;

  const _ButterflyCalmGame({
    super.key,
    required this.elderName,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<_ButterflyCalmGame> createState() => _ButterflyCalmGameState();
}

class _ButterflyCalmGameState extends State<_ButterflyCalmGame> {
  int _secondsRemaining = 900;
  Timer? _timer;
  int _taps = 0;
  String _breathStep = 'ගැඹුරින් හුස්ම ගන්න (Breathe in slowly...)';
  Color _breathColor = const Color(0xFF0284C7);

  @override
  void initState() {
    super.initState();
    _startTimer();
    _cycleBreathing();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        _finishGame();
      }
    });
  }

  void _cycleBreathing() {
    Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_breathStep.contains('Breathe in')) {
          _breathStep = 'සෙමින් පිටකරන්න (Gently exhale and let go of stress...)';
          _breathColor = const Color(0xFF059669);
        } else {
          _breathStep = 'ගැඹුරින් හුස්ම ගන්න (Breathe in peaceful energy...)';
          _breathColor = const Color(0xFF0284C7);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finishGame() {
    _timer?.cancel();
    final now = DateTime.now();
    final dateStr = '${now.day} Oct ${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    CarePlansService.recordCompletedSession(
      songTitle: 'Serenity Butterfly & Lotus Calm (සන්සුන් සමනල සැනසීම)',
      songArtist: '15-Min Emotional Wellness Game',
      dateText: dateStr,
      durationText: '15 Mins',
    );

    widget.onComplete(100);
  }

  String _formatTimer(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text('Back to Games Hub', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    '15-Min Timer: ${_formatTimer(_secondsRemaining)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _finishGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Complete Session ✓'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Mindful Breathing Guide Bubble
        AnimatedContainer(
          duration: const Duration(seconds: 1),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _breathColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _breathColor.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(LucideIcons.wind, size: 30, color: _breathColor),
              const SizedBox(height: 8),
              Text(
                _breathStep,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _breathColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Floating Lotus & Butterfly Serenity Lake Area
        Container(
          height: 360,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD), Color(0xFFE0E7FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF7DD3FC)),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 20,
                left: 30,
                child: _buildInteractiveLotus(1, 'Lotus Calm 🪷'),
              ),
              Positioned(
                top: 50,
                left: 100,
                child: _buildInteractiveButterfly(1, 'Blue Breeze 🦋', Colors.blue),
              ),
              Positioned(
                top: 140,
                right: 90,
                child: _buildInteractiveButterfly(2, 'Golden Glow 🦋', Colors.amber),
              ),
              Positioned(
                bottom: 30,
                right: 40,
                child: _buildInteractiveLotus(2, 'Pink Peace 🪷'),
              ),
              Positioned(
                top: 40,
                right: 180,
                child: _buildInteractiveButterfly(3, 'Purple Grace 🦋', Colors.purple),
              ),
              Center(
                child: Text(
                  'Taps of Serenity: $_taps 🌟\n(Gently tap flowers & butterflies to release gentle ripples)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0369A1).withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveButterfly(int id, String label, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() => _taps++);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10),
          ],
        ),
        child: Icon(LucideIcons.sparkle, size: 28, color: color),
      ),
    );
  }

  Widget _buildInteractiveLotus(int id, String label) {
    return GestureDetector(
      onTap: () {
        setState(() => _taps++);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF472B6)),
        ),
        child: Row(
          children: const [
            Icon(LucideIcons.flower2, size: 20, color: Color(0xFFDB2777)),
            SizedBox(width: 6),
            Text('Lotus Serenity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
          ],
        ),
      ),
    );
  }
}
