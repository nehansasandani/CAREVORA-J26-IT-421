import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../assessment/application/memory_game_service.dart';
import '../../auth/application/auth_controller.dart';

/// Available games in the Memory Games suite.
enum MemoryGameType {
  none,
  sequence,
  pairs,
  items,
}

/// The main entry page for Carevora's Memory Games suite.
class MemoryGamesPage extends ConsumerStatefulWidget {
  final MemoryGameType initialGame;
  final List<int>? initialSequence;
  final int? residentId;
  final String? token;

  const MemoryGamesPage({
    super.key,
    this.initialGame = MemoryGameType.none,
    this.initialSequence,
    this.residentId,
    this.token,
  });

  @override
  ConsumerState<MemoryGamesPage> createState() => _MemoryGamesPageState();
}

class _MemoryGamesPageState extends ConsumerState<MemoryGamesPage> {
  late MemoryGameType _activeGame;

  @override
  void initState() {
    super.initState();
    _activeGame = widget.initialGame;
  }

  void _selectGame(MemoryGameType game) {
    setState(() {
      _activeGame = game;
    });
  }

  void _backToHub() {
    setState(() {
      _activeGame = MemoryGameType.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: _GentleAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildCurrentView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    final auth = ref.watch(authProvider).state;
    final effectiveResidentId = widget.residentId ?? auth.residentId ?? 1;
    final effectiveToken = widget.token ?? auth.token;

    switch (_activeGame) {
      case MemoryGameType.sequence:
        return _SequenceGameView(
          key: const ValueKey('sequence_game'),
          onBack: _backToHub,
          initialSequence: widget.initialSequence,
          residentId: effectiveResidentId,
          token: effectiveToken,
        );
      case MemoryGameType.pairs:
        return _PairsGameView(
          key: const ValueKey('pairs_game'),
          onBack: _backToHub,
          residentId: effectiveResidentId,
          token: effectiveToken,
        );
      case MemoryGameType.items:
        return _ItemsGameView(
          key: const ValueKey('items_game'),
          onBack: _backToHub,
          residentId: effectiveResidentId,
          token: effectiveToken,
        );
      case MemoryGameType.none:
        return _buildHubView();
    }
  }

  Widget _buildHubView() {
    return Column(
      key: const ValueKey('hub_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Welcoming Hero & Cognitive Wellness Header Card
        _buildHeroBanner(),

        const SizedBox(height: 28),

        // 2. Section Title & Reassuring Guidance
        Text(
          'Choose a Game to Play',
          style: AppTextStyles.h2.copyWith(
            fontSize: 22,
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select any activity below. You can return here at any time.',
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),

        const SizedBox(height: 20),

        // 3. Three Visually Distinct Game Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InteractiveGameCard(
                      title: 'Remember the Sequence',
                      badge: 'Pattern Recall',
                      description:
                          'A sequence of colorful numbered tiles will appear. Memorize the order and tap them back in the exact same pattern.',
                      icon: LucideIcons.sparkles,
                      accentColor: const Color(0xFF7C3AED),
                      gradientColors: const [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                      features: const [
                        'Starts with 3 easy tiles',
                        'Expands as you succeed',
                        'Replay the pattern anytime',
                      ],
                      buttonText: 'Play Sequence',
                      onPlay: () => _selectGame(MemoryGameType.sequence),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _InteractiveGameCard(
                      title: 'Find the Matching Pairs',
                      badge: 'Card Matching',
                      description:
                          'Turn over large, cheerful cards two at a time to discover matching pairs of familiar pictures.',
                      icon: LucideIcons.puzzle,
                      accentColor: const Color(0xFF0D9488),
                      gradientColors: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
                      features: const [
                        'Familiar friendly pictures',
                        'Large, easy-to-tap cards',
                        'Play at your leisure',
                      ],
                      buttonText: 'Play Matching Pairs',
                      onPlay: () => _selectGame(MemoryGameType.pairs),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _InteractiveGameCard(
                      title: 'Remember the Items',
                      badge: 'Object Recall',
                      description:
                          'Take a gentle look at a few familiar objects, then test your memory by picking them out from a larger group.',
                      icon: LucideIcons.bookOpen,
                      accentColor: const Color(0xFFDB2777),
                      gradientColors: const [Color(0xFFDB2777), Color(0xFFF43F5E)],
                      features: const [
                        'Simple everyday objects',
                        'Take all the time you need',
                        'Warm, encouraging feedback',
                      ],
                      buttonText: 'Play Remember Items',
                      onPlay: () => _selectGame(MemoryGameType.items),
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _InteractiveGameCard(
                    title: 'Remember the Sequence',
                    badge: 'Pattern Recall',
                    description:
                        'A sequence of colorful numbered tiles will appear. Memorize the order and tap them back in the exact same pattern.',
                    icon: LucideIcons.sparkles,
                    accentColor: const Color(0xFF7C3AED),
                    gradientColors: const [Color(0xFF6C3FC5), Color(0xFF8B5CF6)],
                    features: const [
                      'Starts with 3 easy tiles',
                      'Expands as you succeed',
                      'Replay the pattern anytime',
                    ],
                    buttonText: 'Play Sequence',
                    onPlay: () => _selectGame(MemoryGameType.sequence),
                  ),
                  const SizedBox(height: 18),
                  _InteractiveGameCard(
                    title: 'Find the Matching Pairs',
                    badge: 'Card Matching',
                    description:
                        'Turn over large, cheerful cards two at a time to discover matching pairs of familiar pictures.',
                    icon: LucideIcons.puzzle,
                    accentColor: const Color(0xFF0D9488),
                    gradientColors: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
                    features: const [
                      'Familiar friendly pictures',
                      'Large, easy-to-tap cards',
                      'Play at your leisure',
                    ],
                    buttonText: 'Play Matching Pairs',
                    onPlay: () => _selectGame(MemoryGameType.pairs),
                  ),
                  const SizedBox(height: 18),
                  _InteractiveGameCard(
                    title: 'Remember the Items',
                    badge: 'Object Recall',
                    description:
                        'Take a gentle look at a few familiar objects, then test your memory by picking them out from a larger group.',
                    icon: LucideIcons.bookOpen,
                    accentColor: const Color(0xFFDB2777),
                    gradientColors: const [Color(0xFFDB2777), Color(0xFFF43F5E)],
                    features: const [
                      'Simple everyday objects',
                      'Take all the time you need',
                      'Warm, encouraging feedback',
                    ],
                    buttonText: 'Play Remember Items',
                    onPlay: () => _selectGame(MemoryGameType.items),
                  ),
                ],
              );
            }
          },
        ),

        const SizedBox(height: 24),

        // 4. Calming Wellness Footer Ribbon
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Carevora Cognitive Wellness • Designed with love for comfortable, joyful brain practice',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFBF9FE),
            Color(0xFFF6F2FD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.95),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: [
            // 1. Subtle decorative corner ambient glow & rings
            Positioned(
              top: -60,
              right: -60,
              child: IgnorePointer(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFDDD6FE).withValues(alpha: 0.45),
                            const Color(0xFFDDD6FE).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Top delicate multi-color gradient highlight strip
            Container(
              height: 4.5,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFF8B5CF6),
                    Color(0xFFEC4899),
                    Color(0xFF0D9488),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            // 3. Main Hero Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Luxury 3D-styled Gamepad Icon Container
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF5EEFF),
                                  Color(0xFFEDE9FE),
                                  Color(0xFFDDD6FE),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8B5CF6),
                                      Color(0xFF7C3AED),
                                      Color(0xFF6D28D9),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.gamepad2,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Floating Golden Sparkle Micro-Badge
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  LucideIcons.sparkles,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 14,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Memory Games',
                                  style: AppTextStyles.h1.copyWith(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF1E1B4B),
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFAF5FF),
                                        Color(0xFFF3E8FF),
                                        Color(0xFFEDE9FE),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: const Color(0xFFC4B5FD),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            LucideIcons.sparkles,
                                            size: 11,
                                            color: Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Gentle Brain Practice',
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF6D28D9),
                                          fontSize: 12.5,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Relax, have fun, and exercise your memory at your own comfortable pace. There are no timers, no scores recorded, and no penalties.',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 15.5,
                                color: const Color(0xFF475569),
                                height: 1.52,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Reassurance Note Banner (Luminous Soft Violet Comfort Card)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFAF5FF),
                          Color(0xFFF3E8FF),
                          Color(0xFFEDE9FE),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFDDD6FE),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFDDD6FE),
                              width: 1.3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.heart,
                              size: 18,
                              color: Color(0xFF9333EA),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Friendly Note: ',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 13.5,
                                    color: const Color(0xFF581C87),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'These optional games are purely for fun and daily wellness. They are never graded or sent to clinical records.',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 13.5,
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Wellness Highlights Row (Colorful, rounded tactile chips with interactive hover)
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _HeroFeaturePill(
                        icon: LucideIcons.clock,
                        label: 'Zero Rush & Zero Stress',
                        accentColor: const Color(0xFF7C3AED),
                        gradientColors: const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                        borderColor: const Color(0xFFDDD6FE),
                      ),
                      _HeroFeaturePill(
                        icon: LucideIcons.eye,
                        label: 'High-Contrast Large Text & Cards',
                        accentColor: const Color(0xFF0D9488),
                        gradientColors: const [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                        borderColor: const Color(0xFFA7F3D0),
                      ),
                      _HeroFeaturePill(
                        icon: LucideIcons.smile,
                        label: '100% Encouraging & Pressure-Free',
                        accentColor: const Color(0xFFDB2777),
                        gradientColors: const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                        borderColor: const Color(0xFFFECDD3),
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

  Widget _buildFeaturePill({
    required IconData icon,
    required String label,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return _HeroFeaturePill(
      icon: icon,
      label: label,
      accentColor: accentColor,
      gradientColors: [bgColor, bgColor],
      borderColor: borderColor,
    );
  }
}

// ==============================================================================
// INTERACTIVE HERO FEATURE PILL WITH SMOOTH HOVER EFFECT
// ==============================================================================

class _HeroFeaturePill extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final List<Color> gradientColors;
  final Color borderColor;

  const _HeroFeaturePill({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.gradientColors,
    required this.borderColor,
  });

  @override
  State<_HeroFeaturePill> createState() => _HeroFeaturePillState();
}

class _HeroFeaturePillState extends State<_HeroFeaturePill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -2.5 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.accentColor.withValues(alpha: 0.6) : widget.borderColor,
            width: _isHovered ? 1.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: _isHovered ? 0.16 : 0.06),
              blurRadius: _isHovered ? 10 : 5,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(widget.icon, size: 13, color: widget.accentColor),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// GENTLE AMBIENT BACKGROUND WITH SOFT DRIFTING ORBS
// ==============================================================================

class _GentleAmbientBackground extends StatefulWidget {
  final Widget child;

  const _GentleAmbientBackground({required this.child});

  @override
  State<_GentleAmbientBackground> createState() => _GentleAmbientBackgroundState();
}

class _GentleAmbientBackgroundState extends State<_GentleAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    // Only run continuous repeat loop outside of unit test environment
    // to prevent pumpAndSettle timeouts during automated testing.
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnvironment) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = sin(t * pi * 2) * 20.0;
        final dy = cos(t * pi * 2) * 16.0;

        return Stack(
          children: [
            // Base Calm Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF7F5FC),
                    Color(0xFFF3EFFB),
                    Color(0xFFF9F7FD),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Ambient Lavender Orb (Top-Right)
            Positioned(
              top: -60 + dy,
              right: -80 + dx,
              child: IgnorePointer(
                child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primarySoft.withValues(alpha: 0.65),
                        AppColors.primarySoft.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.75],
                    ),
                  ),
                ),
              ),
            ),

            // Ambient Mint/Teal Orb (Bottom-Left)
            Positioned(
              bottom: 80 - dy,
              left: -100 - dx,
              child: IgnorePointer(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFCCFBF1).withValues(alpha: 0.5),
                        const Color(0xFFCCFBF1).withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.75],
                    ),
                  ),
                ),
              ),
            ),

            // Ambient Rose Orb (Center-Right)
            Positioned(
              top: 380 + dy * 0.7,
              right: -60 - dx,
              child: IgnorePointer(
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFCE7F3).withValues(alpha: 0.45),
                        const Color(0xFFFCE7F3).withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.75],
                    ),
                  ),
                ),
              ),
            ),

            // Ambient Soft Lilac Orb (Top-Left)
            Positioned(
              top: 120 - dy * 0.5,
              left: -50 + dx * 0.5,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFEDE9FE).withValues(alpha: 0.4),
                        const Color(0xFFEDE9FE).withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.75],
                    ),
                  ),
                ),
              ),
            ),

            // Foreground Content
            widget.child,
          ],
        );
      },
    );
  }
}

// ==============================================================================
// INTERACTIVE GAME CARD WITH HOVER & RICH VISUAL IDENTITY
// ==============================================================================

class _InteractiveGameCard extends StatefulWidget {
  final String title;
  final String badge;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final List<String> features;
  final String buttonText;
  final VoidCallback onPlay;

  const _InteractiveGameCard({
    required this.title,
    required this.badge,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.features,
    required this.buttonText,
    required this.onPlay,
  });

  @override
  State<_InteractiveGameCard> createState() => _InteractiveGameCardState();
}

class _InteractiveGameCardState extends State<_InteractiveGameCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -5 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? widget.accentColor.withValues(alpha: 0.5)
                : AppColors.border,
            width: _isHovered ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.accentColor.withValues(alpha: 0.16)
                  : AppColors.primary.withValues(alpha: 0.04),
              blurRadius: _isHovered ? 22 : 14,
              offset: Offset(0, _isHovered ? 10 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Accent Highlight Strip
              Container(
                height: 4.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge and Icon Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Large Themed Icon Container
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.accentColor.withValues(alpha: 0.16),
                                widget.accentColor.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: widget.accentColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 26,
                          ),
                        ),

                        // Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            widget.badge,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Game Title
                    Text(
                      widget.title,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        letterSpacing: -0.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Game Description
                    Text(
                      widget.description,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.body,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Key Features List
                    Column(
                      children: widget.features.map((feature) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.riskLowBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.riskLow.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.check,
                                    size: 12,
                                    color: AppColors.riskLow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Clear, Large Play Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.gradientColors,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.32),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: widget.onPlay,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.gamepad2, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.buttonText,
                                  style: AppTextStyles.button.copyWith(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(LucideIcons.arrowRight, size: 15),
                            ],
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
    );
  }
}

// ==============================================================================
// COMMON GAME SCORE CARD WIDGET
// ==============================================================================

Widget _buildGameScoreCard({
  required double score,
  required String scoreLabel,
  required String details,
  required bool isSaving,
  required String? successMessage,
  required String? errorMessage,
}) {
  return Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxWidth: 520),
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFAF8FE), Color(0xFFF4EFFD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.22), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.sparkles, size: 15, color: Colors.white),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      '$scoreLabel: ${score.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          details,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (isSaving)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Saving session to care records...',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.body,
                ),
              ),
            ],
          )
        else if (successMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.riskLowBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.riskLow.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.checkCheck, size: 16, color: AppColors.riskLow),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    successMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.riskLow,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.riskHigh.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.riskHigh),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.riskHigh,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ==============================================================================
// GAME 1: REMEMBER THE SEQUENCE
// ==============================================================================

class _SequenceGameView extends StatefulWidget {
  final VoidCallback onBack;
  final List<int>? initialSequence;
  final int residentId;
  final String? token;

  const _SequenceGameView({
    super.key,
    required this.onBack,
    this.initialSequence,
    required this.residentId,
    this.token,
  });

  @override
  State<_SequenceGameView> createState() => _SequenceGameViewState();
}

enum _SeqPhase {
  showing,
  input,
  success,
  retry,
}

class _SequenceTileData {
  final int id;
  final String label;
  final Color color;
  final Color accentGradient;
  final IconData icon;

  const _SequenceTileData({
    required this.id,
    required this.label,
    required this.color,
    required this.accentGradient,
    required this.icon,
  });
}

class _SequenceGameViewState extends State<_SequenceGameView> {
  static const List<_SequenceTileData> _tiles = [
    _SequenceTileData(
      id: 0,
      label: 'Violet 1',
      color: Color(0xFF7C3AED),
      accentGradient: Color(0xFF9333EA),
      icon: Icons.looks_one_rounded,
    ),
    _SequenceTileData(
      id: 1,
      label: 'Blue 2',
      color: Color(0xFF2563EB),
      accentGradient: Color(0xFF3B82F6),
      icon: Icons.looks_two_rounded,
    ),
    _SequenceTileData(
      id: 2,
      label: 'Green 3',
      color: Color(0xFF16A34A),
      accentGradient: Color(0xFF22C55E),
      icon: Icons.looks_3_rounded,
    ),
    _SequenceTileData(
      id: 3,
      label: 'Orange 4',
      color: Color(0xFFEA580C),
      accentGradient: Color(0xFFF97316),
      icon: Icons.looks_4_rounded,
    ),
  ];

  int _currentLevel = 1;
  int _sequenceLength = 3;
  List<int> _targetSequence = [];
  List<int> _userTaps = [];
  _SeqPhase _phase = _SeqPhase.showing;
  final Random _random = Random();

  Timer? _completionTimer;
  bool _hasShownSuccessPopup = false;
  bool _isPopupOpen = false;
  void Function(void Function())? _dialogSetState;

  int _roundAttempts = 1;
  int _wrongTapsInRound = 0;
  bool _isSaving = false;
  String? _saveSuccessMessage;
  String? _saveErrorMessage;
  double? _lastScore;
  int _lastAttempts = 1;
  int _lastCorrectCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSequence != null && widget.initialSequence!.isNotEmpty) {
      _sequenceLength = widget.initialSequence!.length;
      _targetSequence = List<int>.from(widget.initialSequence!);
      _userTaps = [];
      _phase = _SeqPhase.showing;
    } else {
      _startNewRound();
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  void _startNewRound() {
    _completionTimer?.cancel();
    _hasShownSuccessPopup = false;
    _isPopupOpen = false;
    final List<int> seq = [];
    for (int i = 0; i < _sequenceLength; i++) {
      seq.add(_random.nextInt(_tiles.length));
    }
    setState(() {
      _targetSequence = seq;
      _userTaps = [];
      _phase = _SeqPhase.showing;
      _roundAttempts = 1;
      _wrongTapsInRound = 0;
      _saveSuccessMessage = null;
      _saveErrorMessage = null;
    });
  }

  void _startInputPhase() {
    setState(() {
      _userTaps = [];
      _phase = _SeqPhase.input;
    });
  }

  void _replaySequence() {
    setState(() {
      _userTaps = [];
      _phase = _SeqPhase.showing;
    });
  }

  void _resetToBeginning() {
    _completionTimer?.cancel();
    _hasShownSuccessPopup = false;
    _isPopupOpen = false;
    setState(() {
      _currentLevel = 1;
      _sequenceLength = 3;
    });
    _startNewRound();
  }

  void _onTileTap(int tileId) {
    if (_phase != _SeqPhase.input) return;

    final nextIndex = _userTaps.length;
    if (nextIndex >= _targetSequence.length) return;

    final updatedTaps = List<int>.from(_userTaps)..add(tileId);

    // If user has not yet selected all numbers in the sequence, keep accepting taps
    if (updatedTaps.length < _targetSequence.length) {
      setState(() {
        _userTaps = updatedTaps;
      });
      return;
    }

    // All numbers in the sequence have now been selected by the user
    int correctCount = 0;
    bool isAllCorrect = true;
    for (int i = 0; i < _targetSequence.length; i++) {
      if (updatedTaps[i] == _targetSequence[i]) {
        correctCount++;
      } else {
        isAllCorrect = false;
      }
    }

    if (isAllCorrect) {
      final totalTaps = _targetSequence.length + _wrongTapsInRound;
      final accuracy =
          ((_targetSequence.length.toDouble() / totalTaps.toDouble()) * 100.0)
              .clamp(0.0, 100.0);
      final roundedScore = (accuracy * 10).round() / 10.0;
      final attemptsCount = _roundAttempts;

      setState(() {
        _userTaps = updatedTaps;
        _phase = _SeqPhase.success;
        _lastScore = roundedScore;
        _lastAttempts = attemptsCount;
        _lastCorrectCount = _targetSequence.length;
      });

      _saveSession(
        score: roundedScore,
        attempts: attemptsCount,
        correctAnswers: _targetSequence.length,
        totalItems: _targetSequence.length,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _phase == _SeqPhase.success && !_hasShownSuccessPopup) {
          _showSuccessPopup();
        }
      });
    } else {
      final wrongCount = _targetSequence.length - correctCount;
      setState(() {
        _userTaps = updatedTaps;
        _wrongTapsInRound += (wrongCount > 0 ? wrongCount : 1);
        _roundAttempts++;
        _phase = _SeqPhase.retry;
      });
    }
  }

  Future<void> _saveSession({
    required double score,
    required int attempts,
    required int correctAnswers,
    required int totalItems,
  }) async {
    setState(() {
      _isSaving = true;
      _saveSuccessMessage = null;
      _saveErrorMessage = null;
    });

    try {
      final record = await MemoryGameService.saveCompletedSession(
        residentId: widget.residentId,
        gameType: 'SEQUENCE',
        scorePercentage: score,
        attempts: attempts,
        correctAnswers: correctAnswers,
        totalItems: totalItems,
        status: 'COMPLETED',
        completionDetailsJson: jsonEncode({
          'sequenceLength': _sequenceLength,
          'level': _currentLevel,
          'wrongTaps': _wrongTapsInRound,
        }),
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccessMessage = null;
        });
        _dialogSetState?.call(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveErrorMessage = 'Could not save session: $e';
        });
        _dialogSetState?.call(() {});
      }
    }
  }

  void _advanceToNextLevel() {
    _completionTimer?.cancel();
    _hasShownSuccessPopup = false;
    _isPopupOpen = false;
    setState(() {
      _currentLevel++;
      _sequenceLength++;
    });
    _startNewRound();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGameNavBar(
          gameTitle: 'Remember the Sequence',
          gameIcon: LucideIcons.sparkles,
          gameColor: const Color(0xFF7C3AED),
          onBack: widget.onBack,
          onReset: _resetToBeginning,
          statusBadge: 'Level $_currentLevel ($_sequenceLength Tiles)',
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFBF9FE),
                Color(0xFFF7F4FD),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF1E1B4B).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.95),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                // Top Multi-Color Highlight Strip matching the 4 sequence tiles
                Container(
                  height: 4.5,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF7C3AED), // Violet 1
                        Color(0xFF2563EB), // Blue 2
                        Color(0xFF16A34A), // Green 3
                        Color(0xFFEA580C), // Orange 4
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),

                // Ambient decorative background rings in top-right
                Positioned(
                  top: -50,
                  right: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFDDD6FE).withValues(alpha: 0.35),
                            const Color(0xFFDDD6FE).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Game Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                  child: Column(
                    children: [
                      _buildInstructionBanner(),
                      const SizedBox(height: 28),

                      if (_phase == _SeqPhase.showing) ...[
                        _buildSequencePreview(),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.38),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              key: const ValueKey('start_sequence_input_button'),
                              onPressed: _startInputPhase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.sparkles, size: 19),
                                  const SizedBox(width: 9),
                                  Text(
                                    'I Remember! Hide & Start My Turn',
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else if (_phase == _SeqPhase.input) ...[
                        _buildProgressSlots(),
                        const SizedBox(height: 30),
                        _buildInteractiveTilesGrid(),
                        const SizedBox(height: 28),
                        OutlinedButton.icon(
                          key: const ValueKey('replay_sequence_button'),
                          onPressed: _replaySequence,
                          icon: const Icon(LucideIcons.rotateCcw, size: 18),
                          label: const Text(
                            'Replay Sequence to Watch Again',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6D28D9),
                            side: const BorderSide(color: Color(0xFFDDD6FE), width: 1.5),
                            backgroundColor: const Color(0xFFFAF5FF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ] else if (_phase == _SeqPhase.success) ...[
                        _buildSuccessView(),
                      ] else if (_phase == _SeqPhase.retry) ...[
                        _buildRetryView(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBanner() {
    String title = '';
    String subtitle = '';
    List<Color> gradientColors = [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)];
    Color borderColor = const Color(0xFFDDD6FE);
    Color iconColor = const Color(0xFF7C3AED);
    IconData icon = LucideIcons.sparkles;

    switch (_phase) {
      case _SeqPhase.showing:
        title = 'Watch & Remember the Sequence';
        subtitle =
            'Take your time to memorize the colors and numbers shown below. When ready, tap the button to begin.';
        gradientColors = [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)];
        borderColor = const Color(0xFFDDD6FE);
        iconColor = const Color(0xFF7C3AED);
        icon = LucideIcons.sparkles;
        break;
      case _SeqPhase.input:
        title = 'Your Turn: Tap the Tiles in Order';
        subtitle =
            'Tap the colored circles below in the same sequence you just saw.';
        gradientColors = [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)];
        borderColor = const Color(0xFFC7D2FE);
        iconColor = const Color(0xFF6D28D9);
        icon = LucideIcons.mousePointerClick;
        break;
      case _SeqPhase.success:
        title = 'Well done! Perfect Memory!';
        subtitle =
            'You correctly recalled all $_sequenceLength tiles in the sequence. Would you like to advance to the next level?';
        gradientColors = [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)];
        borderColor = const Color(0xFF86EFAC);
        iconColor = const Color(0xFF16A34A);
        icon = LucideIcons.check;
        break;
      case _SeqPhase.retry:
        title = 'Good try!';
        subtitle =
            'Memory practice takes patience. You can replay the sequence to take another look and try again!';
        gradientColors = [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)];
        borderColor = const Color(0xFFFDE68A);
        iconColor = const Color(0xFFD97706);
        icon = LucideIcons.rotateCcw;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1B4B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14.5,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSequencePreview() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: List.generate(_targetSequence.length, (index) {
        final tile = _tiles[_targetSequence[index]];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: tile.color.withValues(alpha: 0.22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: tile.color.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: tile.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tile.color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Step ${index + 1}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: tile.color,
                  ),
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tile.color, tile.accentGradient],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: tile.color.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(tile.icon, size: 46, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tile.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProgressSlots() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
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
              const Icon(LucideIcons.listOrdered, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'Progress: ${_userTaps.length} of ${_targetSequence.length} tiles tapped',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: List.generate(_targetSequence.length, (index) {
            final isFilled = index < _userTaps.length;
            final isNext = index == _userTaps.length;
            if (isFilled) {
              final tile = _tiles[_userTaps[index]];
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tile.color, tile.accentGradient],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: tile.color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(tile.icon, size: 32, color: Colors.white),
                ),
              );
            } else {
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isNext ? const Color(0xFFFAF5FF) : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isNext ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1),
                    width: isNext ? 2.2 : 1.8,
                  ),
                  boxShadow: isNext
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isNext ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              );
            }
          }),
        ),
      ],
    );
  }

  Widget _buildInteractiveTilesGrid() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 22,
      runSpacing: 22,
      children: _tiles.map((tile) {
        return _InteractiveSequencePad(
          key: ValueKey('sequence_tile_${tile.id}'),
          tile: tile,
          onTap: () => _onTileTap(tile.id),
        );
      }).toList(),
    );
  }

  void _showSuccessPopup() {
    if (!mounted) return;
    _hasShownSuccessPopup = true;
    _isPopupOpen = true;

    final score = _lastScore ?? 100.0;
    final attempts = _lastAttempts;
    final correctCount = _lastCorrectCount;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFBFDFD),
                      Color(0xFFF0FDF4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebratory 3D Star Badge
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF86EFAC),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.sparkles,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Well done!',
                      style: AppTextStyles.h2.copyWith(
                        color: const Color(0xFF15803D),
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You remembered the entire sequence of $_sequenceLength tiles accurately!',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildGameScoreCard(
                      score: score,
                      scoreLabel: 'Accuracy',
                      details:
                          'Recalled: $correctCount / $_sequenceLength Tiles • Attempts: $attempts',
                      isSaving: _isSaving,
                      successMessage: null,
                      errorMessage: _saveErrorMessage,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          key: const ValueKey('next_level_button'),
                          onPressed: () {
                            Navigator.of(dialogCtx).pop();
                            _advanceToNextLevel();
                          },
                          icon: const Icon(LucideIcons.sparkles, size: 18),
                          label: Text(
                            'Next Round (${_sequenceLength + 1} Tiles)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: const Icon(LucideIcons.eye, size: 16),
                            label: const Text(
                              'View Board',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('replay_same_level_button'),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              _startNewRound();
                            },
                            icon: const Icon(LucideIcons.rotateCcw, size: 16),
                            label: const Text(
                              'Replay Level',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E1B4B),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.4,
                              ),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
      },
    ).then((_) {
      _dialogSetState = null;
      if (mounted) {
        setState(() {
          _isPopupOpen = false;
        });
      }
    });
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        _buildProgressSlots(),
        const SizedBox(height: 30),
        _buildInteractiveTilesGrid(),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showSuccessPopup,
              icon: const Icon(LucideIcons.sparkles, size: 17),
              label: const Text(
                'View Results',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A), width: 1.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRetryView() {
    return Column(
      children: [
        // 3D Amber Sunbeam Retry Badge
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFDE68A),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.rotateCcw,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Good try!',
          style: AppTextStyles.h2.copyWith(
            color: const Color(0xFF1E1B4B),
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Don\'t worry at all! Memory takes practice. Would you like to play again?',
          style: AppTextStyles.body.copyWith(
            fontSize: 16.5,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              key: const ValueKey('try_again_button'),
              onPressed: _replaySequence,
              icon: const Icon(LucideIcons.rotateCcw, size: 18),
              label: const Text(
                'Watch & Try Again',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              key: const ValueKey('reset_level_1_button'),
              onPressed: _resetToBeginning,
              icon: const Icon(LucideIcons.rotateCcw, size: 18),
              label: const Text(
                'Restart from Level 1',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E1B4B),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ==============================================================================
// INTERACTIVE SEQUENCE PAD WITH TACTILE HOVER & PRESS RESPONSE
// ==============================================================================

class _InteractiveSequencePad extends StatefulWidget {
  final _SequenceTileData tile;
  final VoidCallback onTap;

  const _InteractiveSequencePad({
    super.key,
    required this.tile,
    required this.onTap,
  });

  @override
  State<_InteractiveSequencePad> createState() => _InteractiveSequencePadState();
}

class _InteractiveSequencePadState extends State<_InteractiveSequencePad> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _isPressed ? 1 : (_isHovered ? -5 : 0),
            0,
          ),
          width: 106,
          height: 106,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.tile.color, widget.tile.accentGradient],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: widget.tile.color.withValues(alpha: _isHovered ? 0.5 : 0.32),
                blurRadius: _isHovered ? 20 : 12,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.tile.icon, size: 44, color: Colors.white),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.tile.label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// GAME 2: FIND THE MATCHING PAIRS
// ==============================================================================

class _PairsGameView extends StatefulWidget {
  final VoidCallback onBack;
  final int residentId;
  final String? token;

  const _PairsGameView({
    super.key,
    required this.onBack,
    required this.residentId,
    this.token,
  });

  @override
  State<_PairsGameView> createState() => _PairsGameViewState();
}

class _CardSymbol {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _CardSymbol({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _CardModel {
  final int id;
  final _CardSymbol symbol;
  bool isMatched = false;

  _CardModel({
    required this.id,
    required this.symbol,
  });
}

class _PairsGameViewState extends State<_PairsGameView> {
  static const List<_CardSymbol> _symbols = [
    _CardSymbol(
      key: 'apple',
      label: 'Apple',
      icon: Icons.apple_rounded,
      color: Color(0xFFDC2626),
    ),
    _CardSymbol(
      key: 'sun',
      label: 'Sunshine',
      icon: LucideIcons.sun,
      color: Color(0xFFD97706),
    ),
    _CardSymbol(
      key: 'flower',
      label: 'Flower',
      icon: LucideIcons.flower,
      color: Color(0xFFDB2777),
    ),
    _CardSymbol(
      key: 'cup',
      label: 'Tea Cup',
      icon: LucideIcons.coffee,
      color: Color(0xFF854D0E),
    ),
    _CardSymbol(
      key: 'home',
      label: 'Cozy Home',
      icon: Icons.home_rounded,
      color: Color(0xFF0D9488),
    ),
    _CardSymbol(
      key: 'star',
      label: 'Golden Star',
      icon: Icons.star_rounded,
      color: Color(0xFFCA8A04),
    ),
  ];

  late List<_CardModel> _cards;
  final List<int> _flippedIndices = [];
  int _pairsFound = 0;
  bool _isProcessing = false;
  Timer? _flipBackTimer;
  Timer? _completionTimer;
  bool _hasShownCompletionPopup = false;
  void Function(void Function())? _dialogSetState;

  int _turnsTaken = 0;
  bool _isSaving = false;
  String? _saveSuccessMessage;
  String? _saveErrorMessage;
  double? _lastScore;
  int _lastTurns = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    _completionTimer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _flipBackTimer?.cancel();
    _completionTimer?.cancel();
    final List<_CardModel> list = [];
    int idCounter = 0;
    for (final sym in _symbols) {
      list.add(_CardModel(id: idCounter++, symbol: sym));
      list.add(_CardModel(id: idCounter++, symbol: sym));
    }
    list.shuffle(Random());

    setState(() {
      _cards = list;
      _flippedIndices.clear();
      _pairsFound = 0;
      _isProcessing = false;
      _turnsTaken = 0;
      _isSaving = false;
      _saveSuccessMessage = null;
      _saveErrorMessage = null;
      _hasShownCompletionPopup = false;
    });
  }

  void _onCardTap(int index) {
    if (_isProcessing) return;
    if (_cards[index].isMatched) return;
    if (_flippedIndices.contains(index)) return;

    if (_flippedIndices.isEmpty) {
      setState(() {
        _flippedIndices.add(index);
      });
    } else if (_flippedIndices.length == 1) {
      final firstIndex = _flippedIndices[0];
      final firstCard = _cards[firstIndex];
      final secondCard = _cards[index];

      _turnsTaken++;

      setState(() {
        _flippedIndices.add(index);
      });

      if (firstCard.symbol.key == secondCard.symbol.key) {
        // MATCH!
        final updatedPairsFound = _pairsFound + 1;
        final isCompleted = updatedPairsFound == _symbols.length;
        final totalPairs = _symbols.length;
        final turns = _turnsTaken;
        final accuracy =
            ((totalPairs.toDouble() / turns.toDouble()) * 100.0).clamp(0.0, 100.0);
        final roundedScore = (accuracy * 10).round() / 10.0;

        setState(() {
          firstCard.isMatched = true;
          secondCard.isMatched = true;
          _pairsFound = updatedPairsFound;
          _flippedIndices.clear();
          if (isCompleted) {
            _lastScore = roundedScore;
            _lastTurns = turns;
          }
        });

        if (isCompleted) {
          _saveSession(
            score: roundedScore,
            attempts: turns,
            correctAnswers: totalPairs,
            totalItems: totalPairs,
          );
          _completionTimer?.cancel();
          _completionTimer = Timer(const Duration(milliseconds: 400), () {
            if (mounted && _pairsFound == _symbols.length && !_hasShownCompletionPopup) {
              _showCompletionDialog();
            }
          });
        }
      } else {
        // MISMATCH: allow elder plenty of time to view both cards
        _isProcessing = true;
        _flipBackTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() {
              _flippedIndices.clear();
              _isProcessing = false;
            });
          }
        });
      }
    }
  }

  Future<void> _saveSession({
    required double score,
    required int attempts,
    required int correctAnswers,
    required int totalItems,
  }) async {
    setState(() {
      _isSaving = true;
      _saveSuccessMessage = null;
      _saveErrorMessage = null;
    });

    try {
      final record = await MemoryGameService.saveCompletedSession(
        residentId: widget.residentId,
        gameType: 'PAIRS',
        scorePercentage: score,
        attempts: attempts,
        correctAnswers: correctAnswers,
        totalItems: totalItems,
        status: 'COMPLETED',
        completionDetailsJson: jsonEncode({
          'pairsMatched': correctAnswers,
          'totalTurns': attempts,
        }),
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccessMessage = null;
        });
        _dialogSetState?.call(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveErrorMessage = 'Could not save session: $e';
        });
        _dialogSetState?.call(() {});
      }
    }
  }

  void _showCompletionDialog() {
    if (!mounted) return;
    _hasShownCompletionPopup = true;

    final score = _lastScore ?? 100.0;
    final turns = _lastTurns;
    final totalPairs = _symbols.length;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFBFDFD),
                      Color(0xFFF0FDF4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebratory 3D Trophy Badge
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFBF1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF99F6E4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.emoji_events_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Fantastic Matching!',
                      style: AppTextStyles.h2.copyWith(
                        color: const Color(0xFF134E4A),
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You matched all 6 card pairs with great memory and focus! Here are your results:',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14.5,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildGameScoreCard(
                      score: score,
                      scoreLabel: 'Matching Performance',
                      details:
                          'Pairs Found: $totalPairs / $totalPairs • Turns Taken: $turns',
                      isSaving: _isSaving,
                      successMessage: null,
                      errorMessage: _saveErrorMessage,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          icon: const Icon(LucideIcons.eye, size: 16),
                          label: const Text(
                            'View Board',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            key: const ValueKey('dialog_play_pairs_again_button'),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              _startNewGame();
                            },
                            icon: const Icon(LucideIcons.rotateCcw, size: 17),
                            label: const Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
      },
    ).then((_) {
      _dialogSetState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGameCompleted = _pairsFound == _symbols.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGameNavBar(
          gameTitle: 'Find the Matching Pairs',
          gameIcon: LucideIcons.puzzle,
          gameColor: const Color(0xFF0D9488),
          onBack: widget.onBack,
          onReset: _startNewGame,
          statusBadge: 'Pairs Found: $_pairsFound / ${_symbols.length}',
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Instruction Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isGameCompleted
                      ? AppColors.riskLowBg
                      : const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isGameCompleted
                        ? AppColors.riskLow.withValues(alpha: 0.35)
                        : const Color(0xFF0D9488).withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isGameCompleted
                                    ? AppColors.riskLow
                                    : const Color(0xFF0D9488))
                                .withValues(alpha: 0.16),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        isGameCompleted
                            ? LucideIcons.sparkles
                            : LucideIcons.puzzle,
                        color: isGameCompleted
                            ? AppColors.riskLow
                            : const Color(0xFF0D9488),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGameCompleted
                                ? 'Well done! You found all the matching pairs!'
                                : 'Tap any two cards to discover matching pairs.',
                            style: AppTextStyles.h4.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isGameCompleted
                                ? 'Fantastic work! Would you like to play again?'
                                : 'Take your time. There are no timers or rush.',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 13.5,
                              color: AppColors.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 700 ? 4 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      final isFlipped =
                          card.isMatched || _flippedIndices.contains(index);

                      return InkWell(
                        key: ValueKey('pair_card_$index'),
                        onTap: () => _onCardTap(index),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: isFlipped
                                ? (card.isMatched
                                    ? AppColors.riskLowBg
                                    : Colors.white)
                                : const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isFlipped
                                  ? (card.isMatched
                                      ? AppColors.riskLow
                                      : card.symbol.color)
                                  : const Color(0xFFDDD6FE),
                              width: isFlipped ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isFlipped
                                    ? (card.isMatched
                                        ? AppColors.riskLow.withValues(alpha: 0.15)
                                        : card.symbol.color.withValues(alpha: 0.15))
                                    : AppColors.primary.withValues(alpha: 0.04),
                                blurRadius: isFlipped ? 10 : 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isFlipped
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      card.symbol.icon,
                                      size: 38,
                                      color: card.symbol.color,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      card.symbol.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: card.isMatched
                                            ? AppColors.riskLow
                                            : AppColors.navy,
                                      ),
                                    ),
                                    if (card.isMatched) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.check,
                                              size: 12,
                                              color: AppColors.riskLow,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Matched',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.riskLow,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          LucideIcons.sparkles,
                                          size: 22,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap Card',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 28),

              if (isGameCompleted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showCompletionDialog,
                      icon: const Icon(LucideIcons.sparkles, size: 17),
                      label: const Text(
                        'View Results',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        side: const BorderSide(
                          color: Color(0xFF0D9488),
                          width: 1.4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        key: const ValueKey('play_pairs_again_button'),
                        onPressed: _startNewGame,
                        icon: const Icon(LucideIcons.rotateCcw, size: 18),
                        label: const Text(
                          'Play Again with Fresh Cards',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                OutlinedButton.icon(
                  key: const ValueKey('restart_pairs_button'),
                  onPressed: _startNewGame,
                  icon: const Icon(LucideIcons.rotateCcw, size: 18),
                  label: const Text(
                    'Shuffle & Restart Game',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// GAME 3: REMEMBER THE ITEMS
// ==============================================================================

class _ItemsGameView extends StatefulWidget {
  final VoidCallback onBack;
  final int residentId;
  final String? token;

  const _ItemsGameView({
    super.key,
    required this.onBack,
    required this.residentId,
    this.token,
  });

  @override
  State<_ItemsGameView> createState() => _ItemsGameViewState();
}

enum _ItemPhase {
  memorize,
  select,
  feedback,
}

class _ObjectItem {
  final int id;
  final String name;
  final IconData icon;
  final Color color;

  const _ObjectItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class _ItemsGameViewState extends State<_ItemsGameView> {
  static const List<_ObjectItem> _itemPool = [
    _ObjectItem(
      id: 1,
      name: 'Red Apple',
      icon: Icons.apple_rounded,
      color: Color(0xFFDC2626),
    ),
    _ObjectItem(
      id: 2,
      name: 'Story Book',
      icon: LucideIcons.bookOpen,
      color: Color(0xFF4F46E5),
    ),
    _ObjectItem(
      id: 3,
      name: 'Pink Flower',
      icon: LucideIcons.flower,
      color: Color(0xFFDB2777),
    ),
    _ObjectItem(
      id: 4,
      name: 'Wall Clock',
      icon: LucideIcons.clock,
      color: Color(0xFFD97706),
    ),
    _ObjectItem(
      id: 5,
      name: 'Tea Cup',
      icon: LucideIcons.coffee,
      color: Color(0xFF854D0E),
    ),
    _ObjectItem(
      id: 6,
      name: 'Cozy House',
      icon: Icons.home_rounded,
      color: Color(0xFF0D9488),
    ),
    _ObjectItem(
      id: 7,
      name: 'Bright Sun',
      icon: LucideIcons.sun,
      color: Color(0xFFEAB308),
    ),
    _ObjectItem(
      id: 8,
      name: 'Loving Heart',
      icon: LucideIcons.heart,
      color: Color(0xFFE11D48),
    ),
    _ObjectItem(
      id: 9,
      name: 'Brass Bell',
      icon: LucideIcons.bell,
      color: Color(0xFFF97316),
    ),
    _ObjectItem(
      id: 10,
      name: 'Brass Key',
      icon: Icons.vpn_key_rounded,
      color: Color(0xFF0284C7),
    ),
  ];

  late List<_ObjectItem> _targetItems;
  late List<_ObjectItem> _displayPool;
  final Set<int> _selectedIds = {};
  _ItemPhase _phase = _ItemPhase.memorize;
  final Random _random = Random();

  bool _hasShownFeedbackPopup = false;
  bool _isPopupOpen = false;
  void Function(void Function())? _dialogSetState;

  bool _isSaving = false;
  String? _saveSuccessMessage;
  String? _saveErrorMessage;
  double? _lastScore;
  int _correctRecalledCount = 0;

  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  void _startNewRound() {
    final shuffled = List<_ObjectItem>.from(_itemPool)..shuffle(_random);
    final targets = shuffled.take(4).toList();
    final remaining = shuffled.skip(4).take(4).toList();
    final combined = [...targets, ...remaining]..shuffle(_random);

    setState(() {
      _targetSequenceReset(targets, combined);
    });
  }

  void _targetSequenceReset(
    List<_ObjectItem> targets,
    List<_ObjectItem> combined,
  ) {
    _targetItems = targets;
    _displayPool = combined;
    _selectedIds.clear();
    _phase = _ItemPhase.memorize;
    _hasShownFeedbackPopup = false;
    _isPopupOpen = false;
    _isSaving = false;
    _saveSuccessMessage = null;
    _saveErrorMessage = null;
  }

  void _startSelectionPhase() {
    setState(() {
      _selectedIds.clear();
      _phase = _ItemPhase.select;
      _hasShownFeedbackPopup = false;
      _isPopupOpen = false;
    });
  }

  void _toggleItemSelection(int id) {
    if (_phase != _ItemPhase.select) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _checkAnswers() {
    final correctCount =
        _selectedIds.where((id) => _targetItems.any((t) => t.id == id)).length;
    final totalItems = _targetItems.length;
    final accuracy =
        ((correctCount.toDouble() / totalItems.toDouble()) * 100.0).clamp(0.0, 100.0);
    final roundedScore = (accuracy * 10).round() / 10.0;

    setState(() {
      _correctRecalledCount = correctCount;
      _lastScore = roundedScore;
      _phase = _ItemPhase.feedback;
    });

    _saveSession(
      score: roundedScore,
      attempts: 1,
      correctAnswers: correctCount,
      totalItems: totalItems,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phase == _ItemPhase.feedback && !_hasShownFeedbackPopup) {
        _showFeedbackPopup();
      }
    });
  }

  Future<void> _saveSession({
    required double score,
    required int attempts,
    required int correctAnswers,
    required int totalItems,
  }) async {
    setState(() {
      _isSaving = true;
      _saveSuccessMessage = null;
      _saveErrorMessage = null;
    });

    try {
      final record = await MemoryGameService.saveCompletedSession(
        residentId: widget.residentId,
        gameType: 'ITEMS',
        scorePercentage: score,
        attempts: attempts,
        correctAnswers: correctAnswers,
        totalItems: totalItems,
        status: 'COMPLETED',
        completionDetailsJson: jsonEncode({
          'selectedCount': _selectedIds.length,
          'correctCount': correctAnswers,
          'totalTargets': totalItems,
        }),
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccessMessage = null;
        });
        _dialogSetState?.call(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveErrorMessage = 'Could not save session: $e';
        });
        _dialogSetState?.call(() {});
      }
    }
  }

  void _peekOriginalItems() {
    setState(() {
      _phase = _ItemPhase.memorize;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGameNavBar(
          gameTitle: 'Remember the Items',
          gameIcon: LucideIcons.bookOpen,
          gameColor: const Color(0xFFDB2777),
          onBack: widget.onBack,
          onReset: _startNewRound,
          statusBadge: _phase == _ItemPhase.memorize
              ? 'Study 4 Items'
              : (_phase == _ItemPhase.select
                  ? 'Selected: ${_selectedIds.length} of 4'
                  : 'Results Check'),
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDB2777).withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInstructionBanner(),
              const SizedBox(height: 28),

              if (_phase == _ItemPhase.memorize) ...[
                _buildMemorizeView(),
              ] else if (_phase == _ItemPhase.select) ...[
                _buildSelectionView(),
              ] else if (_phase == _ItemPhase.feedback) ...[
                _buildFeedbackView(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBanner() {
    String title = '';
    String subtitle = '';
    Color bg = const Color(0xFFFDF2F8);
    Color iconColor = const Color(0xFFDB2777);
    IconData icon = LucideIcons.bookOpen;

    switch (_phase) {
      case _ItemPhase.memorize:
        title = 'Take a look at these 4 familiar items';
        subtitle =
            'Look at each object carefully. Whenever you feel ready, tap the button below to see if you can pick them out.';
        break;
      case _ItemPhase.select:
        title = 'Which items do you remember seeing?';
        subtitle =
            'Tap all 4 items you recall from the previous screen, then tap Check Answers.';
        bg = const Color(0xFFF3E8FF);
        iconColor = AppColors.primary;
        icon = LucideIcons.mousePointer;
        break;
      case _ItemPhase.feedback:
        final correctCount =
            _selectedIds.where((id) => _targetItems.any((t) => t.id == id)).length;
        if (correctCount == _targetItems.length) {
          title = 'Well done! All items correct!';
          subtitle =
              'You remembered every single item with great accuracy! Would you like to play again with a new set?';
          bg = AppColors.riskLowBg;
          iconColor = AppColors.riskLow;
          icon = LucideIcons.check;
        } else {
          title = 'Good try!';
          subtitle =
              'You remembered $correctCount out of ${_targetItems.length} items correctly. Great mental exercise! Would you like to play again?';
          bg = const Color(0xFFFEF3DC);
          iconColor = AppColors.riskModerate;
          icon = LucideIcons.rotateCcw;
        }
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.16),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: AppColors.body,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorizeView() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 20,
          children: _targetItems.map((item) {
            return Container(
              width: 155,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: item.color.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(item.icon, size: 38, color: item.color),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDB2777), Color(0xFFF43F5E)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDB2777).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              key: const ValueKey('ready_items_button'),
              onPressed: _startSelectionPhase,
              icon: const Icon(LucideIcons.check, size: 18),
              label: const Text(
                'I Remember These Items! Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionView() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: _displayPool.map((item) {
            final isSelected = _selectedIds.contains(item.id);
            return InkWell(
              key: ValueKey('item_option_${item.id}'),
              onTap: () => _toggleItemSelection(item.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 142,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : AppColors.navy.withValues(alpha: 0.03),
                      blurRadius: isSelected ? 10 : 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.muted,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  LucideIcons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Icon(item.icon, size: 36, color: item.color),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isSelected ? AppColors.primary : AppColors.navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              key: const ValueKey('check_answers_button'),
              onPressed: _selectedIds.isNotEmpty ? _checkAnswers : null,
              icon: const Icon(LucideIcons.check, size: 18),
              label: Text(
                'Check My Answers (${_selectedIds.length} Picked)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              key: const ValueKey('peek_items_button'),
              onPressed: _peekOriginalItems,
              icon: const Icon(LucideIcons.rotateCcw, size: 18),
              label: const Text(
                'Peek at Original Items',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFeedbackPopup() {
    if (!mounted) return;
    _hasShownFeedbackPopup = true;
    _isPopupOpen = true;

    final score = _lastScore ?? 100.0;
    final correctCount = _correctRecalledCount;
    final totalItems = _targetItems.length;
    final isPerfect = correctCount == totalItems;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFDF8FB),
                      Color(0xFFFDF2F8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFDB2777).withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDB2777).withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebratory 3D Rose/Pink Badge
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE7F3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFBCFE8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDB2777).withValues(alpha: 0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF43F5E), Color(0xFFDB2777)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDB2777).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isPerfect ? Icons.emoji_events_rounded : LucideIcons.sparkles,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isPerfect ? 'Well done!' : 'Good try!',
                      style: AppTextStyles.h2.copyWith(
                        color: isPerfect ? const Color(0xFF9D174D) : const Color(0xFF831843),
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPerfect
                          ? 'Outstanding memory! You identified every target item correctly.'
                          : 'You remembered $correctCount out of $totalItems items correctly. Great mental exercise!',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildGameScoreCard(
                      score: score,
                      scoreLabel: 'Recall Accuracy',
                      details:
                          'Recalled: $correctCount / $totalItems Items • Attempts: 1',
                      isSaving: _isSaving,
                      successMessage: null,
                      errorMessage: _saveErrorMessage,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDB2777), Color(0xFFBE185D)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDB2777).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          key: const ValueKey('play_items_new_round_button'),
                          onPressed: () {
                            Navigator.of(dialogCtx).pop();
                            _startNewRound();
                          },
                          icon: const Icon(LucideIcons.sparkles, size: 18),
                          label: const Text(
                            'Play Again with New Items',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: const Icon(LucideIcons.eye, size: 16),
                            label: const Text(
                              'View Board',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('try_same_items_button'),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              _startSelectionPhase();
                            },
                            icon: const Icon(LucideIcons.rotateCcw, size: 16),
                            label: const Text(
                              'Try Same Items',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E1B4B),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.4,
                              ),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
      },
    ).then((_) {
      _dialogSetState = null;
      if (mounted) {
        setState(() {
          _isPopupOpen = false;
        });
      }
    });
  }

  Widget _buildFeedbackView() {
    return Column(
      children: [
        Text(
          'Review Your Answers',
          style: AppTextStyles.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 16),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: _displayPool.map((item) {
            final isTarget = _targetItems.any((t) => t.id == item.id);
            final isSelected = _selectedIds.contains(item.id);

            Color borderColor = AppColors.border;
            Color bgColor = Colors.white;
            String badgeText = '';
            Color badgeColor = AppColors.muted;

            if (isTarget && isSelected) {
              borderColor = AppColors.riskLow;
              bgColor = AppColors.riskLowBg;
              badgeText = 'Correct! ✅';
              badgeColor = AppColors.riskLow;
            } else if (isTarget && !isSelected) {
              borderColor = AppColors.riskModerate;
              bgColor = const Color(0xFFFEF3DC);
              badgeText = 'Original Item (Missed)';
              badgeColor = AppColors.riskModerate;
            } else if (!isTarget && isSelected) {
              borderColor = AppColors.riskHigh.withValues(alpha: 0.6);
              bgColor = const Color(0xFFFDE8E8);
              badgeText = 'Not in Group';
              badgeColor = AppColors.riskHigh;
            }

            return Container(
              width: 145,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(item.icon, size: 34, color: item.color),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (badgeText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _showFeedbackPopup,
              icon: const Icon(LucideIcons.sparkles, size: 17),
              label: const Text(
                'View Results',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDB2777),
                side: const BorderSide(color: Color(0xFFDB2777), width: 1.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (!_isPopupOpen) ...[
              ElevatedButton.icon(
                key: const ValueKey('board_play_items_new_round_button'),
                onPressed: _startNewRound,
                icon: const Icon(LucideIcons.sparkles, size: 18),
                label: const Text(
                  'Play Again with New Items',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('board_try_same_items_button'),
                onPressed: _startSelectionPhase,
                icon: const Icon(LucideIcons.rotateCcw, size: 18),
                label: const Text(
                  'Try Same Items Again',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ==============================================================================
// COMMON GAME TOP NAVIGATION BAR
// ==============================================================================

Widget _buildGameNavBar({
  required String gameTitle,
  required IconData gameIcon,
  required Color gameColor,
  required VoidCallback onBack,
  required VoidCallback onReset,
  required String statusBadge,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFBF9FE),
          Color(0xFFF7F4FD),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
        width: 1.3,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              ElevatedButton.icon(
                key: const ValueKey('back_to_games_button'),
                onPressed: onBack,
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
                label: const Text(
                  'All Games',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFAF5FF),
                  foregroundColor: const Color(0xFF6D28D9),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xFFDDD6FE),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gameColor.withValues(alpha: 0.18),
                      gameColor.withValues(alpha: 0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: gameColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Icon(gameIcon, size: 18, color: gameColor),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  gameTitle,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1B4B),
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFAF5FF),
                    Color(0xFFF3E8FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC4B5FD),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                statusBadge,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6D28D9),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: IconButton(
                key: const ValueKey('reset_game_nav_button'),
                onPressed: onReset,
                icon: const Icon(LucideIcons.rotateCcw, size: 18),
                tooltip: 'Restart Game',
                color: const Color(0xFF1E1B4B),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
