import 'dart:async';
import 'dart:math';
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
  petFriendsJoy,
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
                      'මනෝ සුව සහ ප්‍රීතිමත් ක්‍රීඩා • Gentle, joyful, and active interactive games tailored for senior happiness, mental stimulation, and cheerful smiles.',
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
          'Each game is designed for a relaxing 15-minute session to bring happiness, calm, and active joy.',
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
                  icon: LucideIcons.heartHandshake,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  title: 'Playful Pet Friends & Joy Garden',
                  sinhalaTitle: 'සතුටු සුරතල් මිතුරු උයන',
                  description: 'Tap cheerful puppies, purring kittens, and lucky surprise gifts popping up to collect love, cheerful combos, and endless joy.',
                  duration: '15 Mins',
                  moodBenefit: 'Active Fun • Instant Joy & Laughter',
                  onPlay: () => _selectGame(EmotionalGameType.petFriendsJoy),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // Clinical Benefit Note
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
      case EmotionalGameType.petFriendsJoy:
        return _PetFriendsJoyGame(
          key: const ValueKey('pet_friends_joy'),
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
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final dateStr = '${now.day} Oct ${now.year}, ${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';

    CarePlansService.recordCompletedSession(
      songTitle: 'Gratitude Garden Blossom (සතුටු මල් උයන)',
      songArtist: '15-Min Emotional Wellness Game',
      dateText: dateStr,
      durationText: '15 Mins',
      residentName: widget.elderName,
      residentId: 1,
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
              'ඔබ විනාඩි 15 ක සතුටු මල් උයන සාර්ථකව අවසන් කළා! සත්කාරක වාර්තාව, සත්කාර සැලැස්ම සහ සමාජ විගණනය (Social Isolation අඩු කරමින්) යාවත්කාලීන විය.',
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
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final dateStr = '${now.day} Oct ${now.year}, ${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';

    CarePlansService.recordCompletedSession(
      songTitle: 'Wisdom & Proverbs Harmony (ප්‍රස්ථා පිරුළු)',
      songArtist: '15-Min Emotional Wellness Game',
      dateText: dateStr,
      durationText: '15 Mins',
      residentName: widget.elderName,
      residentId: 1,
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
// GAME 3: PLAYFUL PET FRIENDS & JOY GARDEN (සතුටු සුරතල් මිතුරු උයන)
// An active, engaging, and joyful interactive game specially designed
// for seniors to tap cheerful popping friends, fruits, & lucky surprises.
// ====================================================================
class _PetFriendsJoyGame extends StatefulWidget {
  final String elderName;
  final VoidCallback onBack;
  final ValueChanged<int> onComplete;

  const _PetFriendsJoyGame({
    super.key,
    required this.elderName,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<_PetFriendsJoyGame> createState() => _PetFriendsJoyGameState();
}

class _BurrowSpot {
  final int id;
  bool isUp = false;
  bool isTapped = false;
  Map<String, dynamic>? item;
  Timer? hideTimer;

  _BurrowSpot({
    required this.id,
  });
}

class _FloatingSparkleEffect {
  final String text;
  final double x;
  final double y;
  double opacity = 1.0;
  double offsetY = 0.0;

  _FloatingSparkleEffect({
    required this.text,
    required this.x,
    required this.y,
  });
}

class _PetFriendsJoyGameState extends State<_PetFriendsJoyGame>
    with TickerProviderStateMixin {
  int _secondsRemaining = 900; // 15 Mins
  Timer? _sessionTimer;
  Timer? _spawnerTimer;
  Timer? _fxTicker;
  final FlutterTts _tts = FlutterTts();

  int _score = 0;
  int _cuddlesCollected = 0;
  int _streak = 0;
  int _level = 1;
  int _activeThemeIndex = 0; // 0: Pets, 1: Fruits, 2: Gems

  String _activeAffirmation = 'Tap the happy pets and lucky surprise gifts as they pop up to collect joy!';
  String _activeAffirmationSinhala = 'උයනේ මතුවන සතුටු සුරතල් මිතුරන් හා රන් තෑගි ස්පර්ශ කර සිනහව හා ආදරය එකතු කරන්න!';

  late List<_BurrowSpot> _burrows;
  final List<_FloatingSparkleEffect> _sparkles = [];

  final List<List<Map<String, dynamic>>> _themes = [
    // Theme 0: Fluffy Pets (සුරතල් සතුන්)
    [
      {'emoji': '🐶', 'name': 'සතුටු පැටියා', 'en': 'Puppy Love', 'color': const Color(0xFFF59E0B), 'speech': 'Good puppy! So sweet and lovely!'},
      {'emoji': '🐱', 'name': 'පූස් පැටියා', 'en': 'Sweet Kitten', 'color': const Color(0xFFEC4899), 'speech': 'Sweet kitty! Beautiful cat!'},
      {'emoji': '🐰', 'name': 'සුදු හාවා', 'en': 'Gentle Bunny', 'color': const Color(0xFF38BDF8), 'speech': 'Gentle bunny! Wonderful friend!'},
      {'emoji': '🐼', 'name': 'පැන්ඩා මිතුරා', 'en': 'Cuddly Panda', 'color': const Color(0xFF10B981), 'speech': 'Happy panda! So cute and playful!'},
      {'emoji': '🐤', 'name': 'කහ කුරුල්ලා', 'en': 'Chirpy Bird', 'color': const Color(0xFFFACC15), 'speech': 'Chirpy bird! Sweet morning melody!'},
      {'emoji': '🎁', 'name': 'රන් තෑග්ග', 'en': 'Lucky Gift', 'color': const Color(0xFFE11D48), 'speech': 'Lucky surprise gift! Bonus points!', 'isBonus': true},
    ],
    // Theme 1: Sweet Garden Fruits (මිහිරි පළතුරු)
    [
      {'emoji': '🍓', 'name': 'ස්ට්‍රෝබෙරි', 'en': 'Sweet Strawberry', 'color': const Color(0xFFE11D48), 'speech': 'Sweet strawberry! Delicious!'},
      {'emoji': '🥭', 'name': 'ඉදුණු අඹ', 'en': 'Golden Mango', 'color': const Color(0xFFF59E0B), 'speech': 'Juicy golden mango! Fresh and sweet!'},
      {'emoji': '🍉', 'name': 'පැණි කොමඩු', 'en': 'Crisp Melon', 'color': const Color(0xFF10B981), 'speech': 'Refreshing sweet watermelon!'},
      {'emoji': '🍍', 'name': 'රන් අන්නාසි', 'en': 'Ripe Pineapple', 'color': const Color(0xFFFACC15), 'speech': 'Sweet golden pineapple!'},
      {'emoji': '🍇', 'name': 'මිදි පොකුර', 'en': 'Juicy Grapes', 'color': const Color(0xFF8B5CF6), 'speech': 'Delicious juicy grapes!'},
      {'emoji': '🌟', 'name': 'රන් තරුව', 'en': 'Magic Star', 'color': const Color(0xFFF59E0B), 'speech': 'Magic Golden Star bonus!', 'isBonus': true},
    ],
    // Theme 2: Golden Treasures (වාසනාවන්ත මැණික්)
    [
      {'emoji': '💎', 'name': 'දිදුලන මැණික', 'en': 'Sparkle Diamond', 'color': const Color(0xFF38BDF8), 'speech': 'Sparkling diamond! Beautiful shine!'},
      {'emoji': '🪙', 'name': 'රන් කාසිය', 'en': 'Golden Coin', 'color': const Color(0xFFF59E0B), 'speech': 'Lucky gold coin! Great blessing!'},
      {'emoji': '👑', 'name': 'රන් ඔටුන්න', 'en': 'Royal Crown', 'color': const Color(0xFFEAB308), 'speech': 'Royal golden crown of happiness!'},
      {'emoji': '🌈', 'name': 'සුන්දර දේදුන්න', 'en': 'Magic Rainbow', 'color': const Color(0xFF8B5CF6), 'speech': 'Peaceful magic rainbow in the sky!'},
      {'emoji': '⭐', 'name': 'වාසනා තරුව', 'en': 'Lucky Star', 'color': const Color(0xFFFACC15), 'speech': 'Shining lucky star!'},
      {'emoji': '🏆', 'name': 'රන් කුසලානය', 'en': 'Golden Trophy', 'color': const Color(0xFFD97706), 'speech': 'Grand Champion Trophy bonus!', 'isBonus': true},
    ],
  ];

  final List<Map<String, String>> _cheers = [
    {
      'si': 'ඔබගේ ආදරණීය ස්පර්ශයට සුරතලුන් අතිශයින් සතුටු වේ!',
      'en': 'Your loving care makes all your playful pet friends jump with joy!',
    },
    {
      'si': 'සතුටින් පිරි ක්‍රීඩාවෙන් සිතට මහත් ප්‍රබෝධයක් හා ශක්තියක් ලැබේ!',
      'en': 'Engaging in lighthearted play refreshes your vitality and warms your heart!',
    },
    {
      'si': 'ඔබ අද දවසේ ඉතාම දක්ෂ සුරතල් මිතුරාය! දිගටම සතුටින් ඉන්න!',
      'en': 'You are a wonderful champion friend today! Keep smiling brightly!',
    },
    {
      'si': 'සෑම සිනහවක්ම ශරීරයේ රුධිර ගමනාගමනය හා සුවය වැඩිදියුණු කරයි!',
      'en': 'Every burst of cheerful laughter enhances relaxation and positive wellbeing!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _burrows = List.generate(6, (i) => _BurrowSpot(id: i));
    _startTimer();
    _spawnRandomFriend(); // Instant first friendly character!
    _startSpawner();
    _startParticleTicker();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.44);
      await _tts.setPitch(1.05);
    } catch (_) {}
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

  void _startSpawner() {
    _spawnerTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (!mounted) return;
      _spawnRandomFriend();
    });
  }

  void _startParticleTicker() {
    _fxTicker = Timer.periodic(const Duration(milliseconds: 32), (t) {
      if (!mounted) return;
      if (_sparkles.isEmpty) return;
      setState(() {
        for (int i = _sparkles.length - 1; i >= 0; i--) {
          final s = _sparkles[i];
          s.offsetY -= 2.2;
          s.opacity -= 0.04;
          if (s.opacity <= 0.05) {
            _sparkles.removeAt(i);
          }
        }
      });
    });
  }

  void _spawnRandomFriend() {
    final available = _burrows.where((b) => !b.isUp).toList();
    if (available.isEmpty) return;

    final random = Random();
    final countToSpawn = (available.length >= 3 && random.nextBool()) ? 2 : 1;

    for (int k = 0; k < countToSpawn; k++) {
      if (available.isEmpty) break;
      final spot = available.removeAt(random.nextInt(available.length));
      final currentList = _themes[_activeThemeIndex];
      final item = currentList[random.nextInt(currentList.length)];

      setState(() {
        spot.isUp = true;
        spot.isTapped = false;
        spot.item = item;
      });

      // Elder-friendly duration: stays visible for 2.6 to 3.2 seconds so elders never feel rushed!
      final stayDuration = 2600 + random.nextInt(600);
      spot.hideTimer?.cancel();
      spot.hideTimer = Timer(Duration(milliseconds: stayDuration), () {
        if (!mounted) return;
        if (spot.isUp && !spot.isTapped) {
          setState(() {
            spot.isUp = false;
            if (_streak > 0) _streak--;
          });
        }
      });
    }
  }

  void _tapBurrow(_BurrowSpot spot, double tapX, double tapY) {
    if (!spot.isUp || spot.isTapped) return;

    final item = spot.item;
    if (item == null) return;

    spot.hideTimer?.cancel();

    final isBonus = item['isBonus'] == true;
    final int points = (isBonus ? 30 : 15) * (_streak >= 3 ? 2 : 1);

    setState(() {
      spot.isTapped = true;
      _score += points;
      _cuddlesCollected++;
      _streak++;

      // Heartwarming affirmation update
      final c = _cheers[_cuddlesCollected % _cheers.length];
      _activeAffirmationSinhala = c['si']!;
      _activeAffirmation = c['en']!;

      // Add cheerful floating particle
      _sparkles.add(_FloatingSparkleEffect(
        text: '+$points ${item['emoji']}',
        x: tapX,
        y: tapY,
      ));

      // Level Progression: Level up every 8 cuddles!
      if (_cuddlesCollected % 8 == 0) {
        _level++;
      }
    });

    // Speak encouraging prompt
    final speechText = item['speech'] as String? ?? 'Good job! Wonderful!';
    try {
      _tts.speak(speechText);
    } catch (_) {}

    // Burrow hides gently after celebratory reaction
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        spot.isUp = false;
        spot.isTapped = false;
      });
    });
  }

  void _celebrateCompletion() {
    _sessionTimer?.cancel();
    _spawnerTimer?.cancel();
    _fxTicker?.cancel();

    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final dateStr = '${now.day} Oct ${now.year}, ${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';

    final gameTitle = _activeThemeIndex == 1
        ? 'Sweet Garden Fruits & Joy Play (මිහිරි පළතුරු උයන)'
        : (_activeThemeIndex == 2
            ? 'Lucky Treasures & Joy Gems (රන් තෑගි සහ මැණික්)'
            : 'Playful Pet Friends & Joy Garden (සතුටු සුරතල් මිතුරු උයන)');

    CarePlansService.recordCompletedSession(
      songTitle: gameTitle,
      songArtist: '15-Min Emotional Wellness Game',
      dateText: dateStr,
      durationText: '15 Mins',
      residentName: widget.elderName,
      residentId: 1,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: Text(
                _activeThemeIndex == 0 ? '🐶' : (_activeThemeIndex == 1 ? '🍓' : '💎'),
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _activeThemeIndex == 1
                  ? '🎉 Garden Fruit Harvest Champion!'
                  : (_activeThemeIndex == 2 ? '🎉 Royal Treasure Champion!' : '🎉 Pet Paradise Champion!'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'ඔබ $_cuddlesCollected වරක් සහභාගී වී ලකුණු $_score ක් උපයා ගත්තා! මෙම තොරතුරු සත්කාරක වාර්තාවට (Caregiver Emotional Wellness), සත්කාර සැලැස්මට (Care Plans) සහ සමාජ විගණනයට (Social Isolation අඩු කරමින්) සාර්ථකව යොමු කරන ලදී.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.sparkles, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Text(
                    'Level $_level Champion ⭐ (+150 Joy Points)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onComplete(150);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Continue (ඉදිරියට යන්න)', style: TextStyle(fontWeight: FontWeight.bold)),
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
  void dispose() {
    _sessionTimer?.cancel();
    _spawnerTimer?.cancel();
    _fxTicker?.cancel();
    for (final b in _burrows) {
      b.hideTimer?.cancel();
    }
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressToNextLevel = (_cuddlesCollected % 8) / 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Game Header with Live Stats & 15-Min Session Timer
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
                border: Border.all(color: const Color(0xFF0284C7)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    '15-Min Session: ${_formatTimer(_secondsRemaining)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBAE6FD)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
                ],
              ),
              child: Row(
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    'Lvl $_level',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                  ),
                  const SizedBox(width: 10),
                  const Text('💖', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 4),
                  Text(
                    '$_cuddlesCollected ($_score pts)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFBE185D)),
                  ),
                  if (_streak >= 2) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🔥 ${_streak}x',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                      ),
                    ),
                  ],
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
        const SizedBox(height: 14),

        // Live Affirmation & Cheering Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE0F2FE), Color(0xFFF0FDF4), Color(0xFFFFFBEB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBAE6FD)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _activeThemeIndex == 0 ? '🐶' : (_activeThemeIndex == 1 ? '🍓' : '💎'),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeAffirmationSinhala,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeAffirmation,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Level Progress Mini Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Level Progress: ${(_cuddlesCollected % 8)}/8',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 90,
                      height: 8,
                      child: LinearProgressIndicator(
                        value: progressToNextLevel,
                        backgroundColor: const Color(0xFFBAE6FD),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Interactive Theme Switcher Pills (Pets, Fruits, Treasures)
        Row(
          children: [
            const Text(
              'Choose Theme (තේමාව තෝරන්න): ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(width: 8),
            _buildThemePill(0, '🐶 Fluffy Pets (සුරතල් සතුන්)'),
            const SizedBox(width: 8),
            _buildThemePill(1, '🍓 Sweet Fruits (පළතුරු උයන)'),
            const SizedBox(width: 8),
            _buildThemePill(2, '💎 Lucky Treasures (රන් තෑගි)'),
          ],
        ),
        const SizedBox(height: 14),

        // Interactive Garden Canvas (6 Cozy Pots / Burrows)
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7), Color(0xFFFEF3C7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF86EFAC), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main Content (dictates natural canvas height so nothing is clipped!)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Garden Sky & Atmosphere Header Strip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Text('☀️', style: TextStyle(fontSize: 26)),
                              SizedBox(width: 8),
                              Text('☁️', style: TextStyle(fontSize: 22)),
                              SizedBox(width: 8),
                              Text('🌈', style: TextStyle(fontSize: 24)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF16A34A)),
                                SizedBox(width: 6),
                                Text(
                                  'Tap the friendly surprises as they appear! (මතුවන විට ස්පර්ශ කරන්න)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: const [
                              Text('🌸', style: TextStyle(fontSize: 22)),
                              SizedBox(width: 6),
                              Text('🌼', style: TextStyle(fontSize: 22)),
                              SizedBox(width: 6),
                              Text('🌻', style: TextStyle(fontSize: 22)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6 Cozy Garden Burrows Grid
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isWide = constraints.maxWidth > 700;
                          final crossAxisCount = isWide ? 3 : 2;
                          final childAspectRatio = isWide ? 1.3 : 1.15;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 18,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: _burrows.length,
                            itemBuilder: (context, index) {
                              final burrow = _burrows[index];
                              return _buildBurrowPot(burrow);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Floating Particle Sparkles (+Points, Emojis)
                ..._sparkles.map((s) {
                  return Positioned(
                    left: s.x,
                    top: s.y + s.offsetY,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: s.opacity.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Text(
                            s.text,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Quick Comforting Note for Elders
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: const [
              Icon(LucideIcons.smile, size: 18, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'There is no rush! Tap gently whenever your cute pet friends pop their heads up. Enjoy the playful smiles, cuddles, and joyful music.',
                  style: TextStyle(fontSize: 12, color: AppColors.body),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemePill(int index, String title) {
    final bool isSelected = _activeThemeIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _activeThemeIndex = index;
          for (final b in _burrows) {
            b.isUp = false;
            b.isTapped = false;
            b.item = null;
            b.hideTimer?.cancel();
          }
        });
        _spawnRandomFriend();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF0369A1),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingSpot() {
    final String iconEmoji;
    final String spotTitle;
    final String spotSinhala;
    if (_activeThemeIndex == 1) {
      iconEmoji = '🌱';
      spotTitle = 'Garden Patch';
      spotSinhala = 'පළතුරු පාත්තිය';
    } else if (_activeThemeIndex == 2) {
      iconEmoji = '✨';
      spotTitle = 'Lucky Spot';
      spotSinhala = 'වාසනා තැන';
    } else {
      iconEmoji = '🐾';
      spotTitle = 'Cozy Nest';
      spotSinhala = 'මිතුරු කූඩුව';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(iconEmoji, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 6),
        Text(
          spotSinhala,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF15803D),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          spotTitle,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Waiting... (සූදානම්)',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF166534),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSpot(Map<String, dynamic> item, bool isTapped) {
    final itemColor = item['color'] as Color? ?? const Color(0xFFF59E0B);
    final isBonus = item['isBonus'] == true;

    return AnimatedScale(
      scale: isTapped ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: itemColor.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: itemColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              item['emoji'] as String? ?? '🐶',
              style: const TextStyle(fontSize: 34),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: itemColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              '${item['name']} • ${item['en']}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: itemColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: isBonus
                  ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFE11D48)])
                  : LinearGradient(colors: [itemColor, itemColor.withValues(alpha: 0.85)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: itemColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBonus ? LucideIcons.sparkles : LucideIcons.heart,
                  size: 11,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  isBonus ? 'BONUS +30 PTS!' : 'TAP ME! (+15)',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurrowPot(_BurrowSpot burrow) {
    final bool hasItem = burrow.isUp && burrow.item != null;
    final item = burrow.item;
    final itemColor = item != null ? (item['color'] as Color? ?? const Color(0xFFF59E0B)) : const Color(0xFF86EFAC);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final localPos = box.globalToLocal(details.globalPosition);
              _tapBurrow(burrow, localPos.dx, localPos.dy);
            } else {
              _tapBurrow(burrow, constraints.maxWidth / 2, constraints.maxHeight / 2);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasItem
                    ? [
                        Colors.white,
                        itemColor.withValues(alpha: 0.12),
                      ]
                    : const [
                        Color(0xFFFEFDF7),
                        Color(0xFFF0FDF4),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasItem ? itemColor : const Color(0xFF86EFAC).withValues(alpha: 0.7),
                width: hasItem ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasItem
                      ? itemColor.withValues(alpha: 0.22)
                      : const Color(0xFF16A34A).withValues(alpha: 0.05),
                  blurRadius: hasItem ? 14 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bottom Soil / Meadow Rim Bed
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: hasItem
                            ? itemColor.withValues(alpha: 0.2)
                            : const Color(0xFF16A34A).withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  // Center Content (either active item or waiting spot)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: hasItem
                        ? _buildActiveSpot(item!, burrow.isTapped)
                        : _buildWaitingSpot(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
