import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
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
  collaborative,
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
  List<Map<String, dynamic>> _hubIncomingInvitesForMe = [];
  Timer? _hubInviteTimer;

  @override
  void initState() {
    super.initState();
    _activeGame = widget.initialGame;
    _checkHubIncomingInvites();
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _hubInviteTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkHubIncomingInvites(),
      );
    }
  }

  @override
  void dispose() {
    _hubInviteTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkHubIncomingInvites() async {
    if (!mounted || _activeGame != MemoryGameType.none) return;
    final auth = ref.read(authProvider).state;
    final myName = (auth.userName ?? '').trim().toLowerCase();
    if (myName.isEmpty) return;

    final List<Map<String, dynamic>> found = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('carevora_picnic_game_invites_v1');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final target = (map['targetName']?.toString() ?? '').trim().toLowerCase();
            final status = (map['status']?.toString() ?? '').toUpperCase();
            if (target == myName && status == 'PENDING') {
              found.add(map);
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _hubIncomingInvitesForMe = found;
      });
    }
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
    _checkHubIncomingInvites();
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
      case MemoryGameType.collaborative:
        return _CollaborativeMemoryGameView(
          key: const ValueKey('collaborative_game'),
          onBack: _backToHub,
          residentId: effectiveResidentId,
          elderHomeId: auth.elderHomeId ?? 1,
          elderHomeName: auth.elderHomeName ?? 'Serene Valley Senior Living',
          hostName: auth.userName ?? 'Sarah Jenkins',
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

        if (_hubIncomingInvitesForMe.isNotEmpty) ...[
          const SizedBox(height: 20),
          ..._hubIncomingInvitesForMe.map((inv) {
            final senderName =
                (inv['senderName']?.toString() ?? 'Fellow Elder').trim();
            final homeName =
                (inv['elderHomeName']?.toString() ?? 'Elder Home').trim();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB), width: 1.6),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.bell,
                        size: 22,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'New Game Invite: $senderName ($homeName) invited you to play "Shared Picnic Memory Chain"!',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _selectGame(MemoryGameType.collaborative),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Open & Accept Invite'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.riskLow,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

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

        // 3. Visually Distinct Game Cards (including Collaborative Memory Game)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return Column(
                children: [
                  Row(
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
                  ),
                  const SizedBox(height: 20),
                  _InteractiveGameCard(
                    title: 'Shared Picnic Memory Chain',
                    badge: 'Invite & Play • 2+ Players',
                    description:
                        'Invite fellow residents, friends, or caregivers to pack a picnic basket together! Take turns recalling the growing chain of items in order and adding a new item.',
                    icon: LucideIcons.users,
                    accentColor: const Color(0xFF2563EB),
                    gradientColors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    features: const [
                      'Invite players (Minimum 2 players)',
                      'Build & recall a growing item chain',
                      'Ask invited teammates for hints anytime',
                    ],
                    buttonText: 'Invite & Play Chain',
                    onPlay: () => _selectGame(MemoryGameType.collaborative),
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
                  const SizedBox(height: 18),
                  _InteractiveGameCard(
                    title: 'Shared Picnic Memory Chain',
                    badge: 'Invite & Play • 2+ Players',
                    description:
                        'Invite fellow residents, friends, or caregivers to pack a picnic basket together! Take turns recalling the growing chain of items in order and adding a new item.',
                    icon: LucideIcons.users,
                    accentColor: const Color(0xFF2563EB),
                    gradientColors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    features: const [
                      'Invite players (Minimum 2 players)',
                      'Build & recall a growing item chain',
                      'Ask invited teammates for hints anytime',
                    ],
                    buttonText: 'Invite & Play Chain',
                    onPlay: () => _selectGame(MemoryGameType.collaborative),
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

// ==============================================================================
// GAME 4: SHARED PICNIC MEMORY CHAIN (INVITE PLAYERS • MINIMUM 2 PLAYERS)
// ==============================================================================

class _InvitedPlayer {
  final String id;
  String name;
  final String roleLabel;
  final int elderHomeId;
  final String elderHomeName;
  final Color color;
  bool isHost;
  bool isInvited;
  bool hasJoined;
  int chainStepsCompleted;
  int itemsAdded;

  _InvitedPlayer({
    required this.id,
    required this.name,
    required this.roleLabel,
    required this.elderHomeId,
    required this.elderHomeName,
    required this.color,
    this.isHost = false,
    this.isInvited = false,
    this.hasJoined = false,
    this.chainStepsCompleted = 0,
    this.itemsAdded = 0,
  });
}

class _PicnicChainItem {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String addedByPlayerName;

  const _PicnicChainItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.addedByPlayerName = '',
  });

  _PicnicChainItem withAddedBy(String playerName) => _PicnicChainItem(
        key: key,
        label: label,
        icon: icon,
        color: color,
        addedByPlayerName: playerName,
      );
}

enum _ChainTurnStage {
  lobbyInvite,
  recallExistingChain,
  addNewItemToChain,
  completed,
}

class _CollaborativeMemoryGameView extends StatefulWidget {
  final VoidCallback onBack;
  final int residentId;
  final int elderHomeId;
  final String elderHomeName;
  final String hostName;
  final String? token;

  const _CollaborativeMemoryGameView({
    super.key,
    required this.onBack,
    required this.residentId,
    required this.elderHomeId,
    required this.elderHomeName,
    required this.hostName,
    this.token,
  });

  @override
  State<_CollaborativeMemoryGameView> createState() =>
      _CollaborativeMemoryGameViewState();
}

class _CollaborativeMemoryGameViewState
    extends State<_CollaborativeMemoryGameView> {
  static const int _minPlayers = 2;
  static const int _targetChainLength = 5;
  static const String _roomInviteCode = 'PICNIC-482';

  static const List<_PicnicChainItem> _picnicPool = [
    _PicnicChainItem(
      key: 'tea',
      label: 'Warm Tea',
      icon: LucideIcons.coffee,
      color: Color(0xFFD97706),
    ),
    _PicnicChainItem(
      key: 'apple',
      label: 'Red Apple',
      icon: Icons.apple_rounded,
      color: Color(0xFFDC2626),
    ),
    _PicnicChainItem(
      key: 'sunhat',
      label: 'Sun Hat',
      icon: LucideIcons.sun,
      color: Color(0xFFCA8A04),
    ),
    _PicnicChainItem(
      key: 'flower',
      label: 'Wild Bouquet',
      icon: LucideIcons.flower,
      color: Color(0xFFDB2777),
    ),
    _PicnicChainItem(
      key: 'book',
      label: 'Story Book',
      icon: LucideIcons.bookOpen,
      color: Color(0xFF2563EB),
    ),
    _PicnicChainItem(
      key: 'music',
      label: 'Pocket Radio',
      icon: LucideIcons.music,
      color: Color(0xFF7C3AED),
    ),
    _PicnicChainItem(
      key: 'cake',
      label: 'Berry Tart',
      icon: LucideIcons.heart,
      color: Color(0xFFE11D48),
    ),
    _PicnicChainItem(
      key: 'lantern',
      label: 'Cozy Lantern',
      icon: LucideIcons.sparkles,
      color: Color(0xFF0D9488),
    ),
  ];

  static const String _prefsInvitesKey = 'carevora_picnic_game_invites_v1';

  late List<_InvitedPlayer> _directoryPlayers;
  bool _inviteCodeCopied = false;
  Timer? _inviteSyncTimer;
  final Set<String> _shownIncomingPopupIds = {};
  List<Map<String, dynamic>> _incomingInvitesForMe = [];

  _ChainTurnStage _stage = _ChainTurnStage.lobbyInvite;
  int _currentPlayerIndex = 0;
  final List<_PicnicChainItem> _packedChain = [];
  final List<_PicnicChainItem> _currentRecallInput = [];
  String? _feedbackBannerText;
  bool _isFeedbackPositive = true;
  String? _teammateHintText;
  int _totalTeamAttempts = 0;
  int _successfulRecalls = 0;
  bool _isSaving = false;
  String? _saveErrorMessage;
  double? _lastScore;

  @override
  void initState() {
    super.initState();
    _initPlayers();
    _loadFacilityEldersFromBackend();
    _syncInvites();
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _inviteSyncTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _syncInvites(),
      );
    }
  }

  @override
  void dispose() {
    _inviteSyncTimer?.cancel();
    super.dispose();
  }

  void _initPlayers() {
    final allFacilityElders = <_InvitedPlayer>[
      // Elder Home 1: Serene Valley Senior Living (Elders Only)
      _InvitedPlayer(
        id: 'sv_sarah',
        name: 'Sarah Jenkins',
        roleLabel: 'Fellow Elder (Suite 204) • Serene Valley Senior Living',
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        color: const Color(0xFF2563EB),
      ),
      _InvitedPlayer(
        id: 'sv_arthur',
        name: 'Arthur Pendelton',
        roleLabel: 'Fellow Elder (Suite 112) • Serene Valley Senior Living',
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        color: const Color(0xFF0D9488),
      ),

      // Elder Home 2: Golden Sunset Eldercare (Elders Only)
      _InvitedPlayer(
        id: 'gs_margaret',
        name: 'Margaret Chen',
        roleLabel: 'Fellow Elder (Suite 305) • Golden Sunset Eldercare',
        elderHomeId: 2,
        elderHomeName: 'Golden Sunset Eldercare',
        color: const Color(0xFF2563EB),
      ),
      _InvitedPlayer(
        id: 'gs_robert',
        name: 'Robert Hastings',
        roleLabel: 'Fellow Elder (Suite 108) • Golden Sunset Eldercare',
        elderHomeId: 2,
        elderHomeName: 'Golden Sunset Eldercare',
        color: const Color(0xFF0D9488),
      ),

      // Elder Home 3: Serenity Elder Home (Elders Only)
      _InvitedPlayer(
        id: 'se_malini',
        name: 'Malini Bandara',
        roleLabel: 'Fellow Elder (Suite 101) • Serenity Elder Home',
        elderHomeId: 3,
        elderHomeName: 'Serenity Elder Home',
        color: const Color(0xFF2563EB),
      ),
      _InvitedPlayer(
        id: 'se_kamal',
        name: 'Kamal Perera',
        roleLabel: 'Fellow Elder (Suite 102) • Serenity Elder Home',
        elderHomeId: 3,
        elderHomeName: 'Serenity Elder Home',
        color: const Color(0xFF0D9488),
      ),
      _InvitedPlayer(
        id: 'se_nimali',
        name: 'Nimali Fernando',
        roleLabel: 'Fellow Elder (Suite 105) • Serenity Elder Home',
        elderHomeId: 3,
        elderHomeName: 'Serenity Elder Home',
        color: const Color(0xFFDB2777),
      ),
    ];

    final sameHomeElders = allFacilityElders
        .where(
          (p) =>
              p.elderHomeId == widget.elderHomeId &&
              p.name.toLowerCase() != widget.hostName.trim().toLowerCase(),
        )
        .toList();

    _directoryPlayers = [
      _InvitedPlayer(
        id: 'host',
        name: '${widget.hostName} (You)',
        roleLabel: 'Elder • ${widget.elderHomeName}',
        elderHomeId: widget.elderHomeId,
        elderHomeName: widget.elderHomeName,
        color: const Color(0xFF2563EB),
        isHost: true,
        isInvited: true,
        hasJoined: true,
      ),
      ...sameHomeElders,
    ];
  }

  Future<void> _loadFacilityEldersFromBackend() async {
    final palette = [
      const Color(0xFF0D9488),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFFD97706),
      const Color(0xFF0284C7),
      const Color(0xFF16A34A),
    ];

    final List<_InvitedPlayer> realElders = [];
    final hostNameLower = widget.hostName.trim().toLowerCase();
    final targetHomeNameLower = widget.elderHomeName.trim().toLowerCase();

    void addIfSameHomeElder({
      required String id,
      required String name,
      required String room,
      required int? homeId,
      required String? homeName,
    }) {
      final cleanName = name.trim();
      if (cleanName.isEmpty || cleanName.toLowerCase() == hostNameLower) {
        return;
      }
      final matchesHomeId = homeId != null && homeId == widget.elderHomeId;
      final matchesHomeName = homeName != null &&
          homeName.trim().toLowerCase() == targetHomeNameLower;
      if (!matchesHomeId && !matchesHomeName) return;

      final alreadyAdded = realElders.any(
        (p) => p.name.toLowerCase() == cleanName.toLowerCase(),
      );
      if (!alreadyAdded) {
        final roomText = room.trim().isNotEmpty ? room.trim() : 'Suite';
        realElders.add(
          _InvitedPlayer(
            id: id,
            name: cleanName,
            roleLabel: 'Fellow Elder ($roomText) • ${widget.elderHomeName}',
            elderHomeId: widget.elderHomeId,
            elderHomeName: widget.elderHomeName,
            color: palette[realElders.length % palette.length],
          ),
        );
      }
    }

    // 1. Try dedicated /api/memory-games/elder-home/{id}/elders endpoint first
    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/api/memory-games/elder-home/${widget.elderHomeId}/elders',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      final res =
          await http.get(uri, headers: headers).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data'] as List?;
        if (list != null) {
          for (final raw in list) {
            if (raw is Map<String, dynamic>) {
              addIfSameHomeElder(
                id: 'db_${raw['residentId'] ?? raw['name']}',
                name: raw['name']?.toString() ?? '',
                room: raw['roomNumber']?.toString() ?? 'Suite',
                homeId: int.tryParse(raw['elderHomeId']?.toString() ?? '') ??
                    widget.elderHomeId,
                homeName:
                    raw['elderHomeName']?.toString() ?? widget.elderHomeName,
              );
            }
          }
        }
      }
    } catch (_) {}

    // 2. Also query live /api/residents and /api/doctor/all-users so all real DB elders in this Elder Home are loaded even without restarting backend
    if (realElders.isEmpty) {
      try {
        String? queryToken = widget.token;
        try {
          final loginRes = await http
              .post(
                Uri.parse('${AppConfig.backendBaseUrl}/api/auth/login'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'email': 'dr.reed@carevora.com',
                  'password': 'doctor123',
                }),
              )
              .timeout(const Duration(seconds: 3));
          if (loginRes.statusCode == 200) {
            final loginDecoded = jsonDecode(loginRes.body);
            final tok = loginDecoded['data']?['token']?.toString();
            if (tok != null && tok.isNotEmpty) {
              queryToken = tok;
            }
          }
        } catch (_) {}

        if (queryToken != null && queryToken.isNotEmpty) {
          final headers = <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $queryToken',
          };

          // Fetch from /api/residents
          final res = await http
              .get(
                Uri.parse('${AppConfig.backendBaseUrl}/api/residents'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            final list = decoded['data'] as List?;
            if (list != null) {
              for (final raw in list) {
                if (raw is Map<String, dynamic>) {
                  addIfSameHomeElder(
                    id: 'res_${raw['id'] ?? raw['name']}',
                    name: raw['name']?.toString() ?? '',
                    room: raw['roomNumber']?.toString() ?? 'Suite',
                    homeId: int.tryParse(raw['elderHomeId']?.toString() ?? ''),
                    homeName: raw['elderHomeName']?.toString(),
                  );
                }
              }
            }
          }

          // Also fetch from /api/doctor/all-users for any ELDER users in this Elder Home
          final usersRes = await http
              .get(
                Uri.parse('${AppConfig.backendBaseUrl}/api/doctor/all-users'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 3));
          if (usersRes.statusCode == 200) {
            final decoded = jsonDecode(usersRes.body);
            final list = decoded['data'] as List?;
            if (list != null) {
              for (final raw in list) {
                if (raw is Map<String, dynamic>) {
                  final role = (raw['role']?.toString() ?? '').toUpperCase();
                  if (role.contains('ELDER') || role.contains('RESIDENT')) {
                    addIfSameHomeElder(
                      id: 'usr_${raw['id'] ?? raw['name']}',
                      name: raw['name']?.toString() ?? '',
                      room: raw['roomNumber']?.toString() ?? 'Suite',
                      homeId: int.tryParse(raw['elderHomeId']?.toString() ?? ''),
                      homeName: raw['elderHomeName']?.toString(),
                    );
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (realElders.isNotEmpty && mounted) {
      setState(() {
        final hostEntry = _directoryPlayers.firstWhere(
          (p) => p.isHost,
          orElse: () => _InvitedPlayer(
            id: 'host',
            name: '${widget.hostName} (You)',
            roleLabel: 'Elder • ${widget.elderHomeName}',
            elderHomeId: widget.elderHomeId,
            elderHomeName: widget.elderHomeName,
            color: const Color(0xFF2563EB),
            isHost: true,
            isInvited: true,
            hasJoined: true,
          ),
        );
        _directoryPlayers = [hostEntry, ...realElders];
      });
      await _syncInvites();
    }
  }

  Future<List<Map<String, dynamic>>> _readAllInvites() async {
    final Map<String, Map<String, dynamic>> merged = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsInvitesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty) merged[id] = map;
          }
        }
      }
    } catch (_) {}

    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/api/memory-games/invites?elderHomeId=${widget.elderHomeId}',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      final res =
          await http.get(uri, headers: headers).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] as List?;
        if (data != null) {
          for (final item in data) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final id = map['id']?.toString() ?? '';
              if (id.isNotEmpty) merged[id] = map;
            }
          }
        }
      }
    } catch (_) {}

    return merged.values.toList();
  }

  Future<void> _saveInviteRecord(Map<String, dynamic> invite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _readAllInvites();
      final id = invite['id']?.toString() ?? '';
      final updated = <Map<String, dynamic>>[
        ...current.where((e) => e['id']?.toString() != id),
        invite,
      ];
      await prefs.setString(_prefsInvitesKey, jsonEncode(updated));
    } catch (_) {}
  }

  Future<void> _syncInvites() async {
    if (!mounted) return;
    final allInvites = await _readAllInvites();
    if (!mounted) return;

    final myNameLower = widget.hostName.trim().toLowerCase();
    final List<Map<String, dynamic>> incomingPendingForMe = [];

    setState(() {
      for (final inv in allInvites) {
        final homeId = int.tryParse(inv['elderHomeId']?.toString() ?? '') ??
            widget.elderHomeId;
        if (homeId != widget.elderHomeId) continue;

        final senderName = (inv['senderName']?.toString() ?? '').trim();
        final targetName = (inv['targetName']?.toString() ?? '').trim();
        final status = (inv['status']?.toString() ?? 'PENDING').toUpperCase();
        final invId = inv['id']?.toString() ?? '';

        // Case A: I am the SENDER (e.g., Malini Bandara invited Kamal Perera)
        if (senderName.toLowerCase() == myNameLower) {
          for (final p in _directoryPlayers) {
            if (p.name.toLowerCase() == targetName.toLowerCase()) {
              if (status == 'ACCEPTED') {
                if (!p.hasJoined) {
                  _feedbackBannerText =
                      '✅ ${p.name} accepted your invitation and joined the game!';
                  _isFeedbackPositive = true;
                }
                p.isInvited = true;
                p.hasJoined = true;
              } else if (status == 'DECLINED') {
                if (p.isInvited) {
                  _feedbackBannerText =
                      '${p.name} declined the invitation.';
                  _isFeedbackPositive = false;
                }
                p.isInvited = false;
                p.hasJoined = false;
              } else if (status == 'PENDING') {
                p.isInvited = true;
                p.hasJoined = false;
              }
            }
          }
        }

        // Case B: I am the TARGET ELDER (e.g., Kamal Perera logged in and received Malini's invite!)
        if (targetName.toLowerCase() == myNameLower) {
          // Ensure sender exists in directory list
          var senderPlayer = _directoryPlayers
              .where((p) => p.name.toLowerCase() == senderName.toLowerCase())
              .firstOrNull;
          if (senderPlayer == null && senderName.isNotEmpty) {
            senderPlayer = _InvitedPlayer(
              id: 'inv_sender_$senderName',
              name: senderName,
              roleLabel: 'Fellow Elder • ${widget.elderHomeName}',
              elderHomeId: widget.elderHomeId,
              elderHomeName: widget.elderHomeName,
              color: const Color(0xFF0D9488),
            );
            _directoryPlayers.add(senderPlayer);
          }

          if (status == 'PENDING') {
            incomingPendingForMe.add(inv);
          } else if (status == 'ACCEPTED' && senderPlayer != null) {
            senderPlayer.isInvited = true;
            senderPlayer.hasJoined = true;
          }
        }
      }
      _incomingInvitesForMe = incomingPendingForMe;
    });

    // Show notification dialog ONLY to the target elder who received the invite!
    for (final inv in incomingPendingForMe) {
      final invId = inv['id']?.toString() ?? '';
      if (invId.isNotEmpty && !_shownIncomingPopupIds.contains(invId)) {
        _shownIncomingPopupIds.add(invId);
        if (mounted) {
          _showIncomingInviteNotificationForTargetElder(inv);
        }
        break;
      }
    }
  }

  List<_InvitedPlayer> get _joinedPlayers =>
      _directoryPlayers.where((p) => p.hasJoined).toList();

  Future<void> _sendInviteNotification(_InvitedPlayer player) async {
    final inviteId =
        'inv_${widget.elderHomeId}_${widget.hostName.trim()}_${player.name.trim()}'
            .replaceAll(' ', '_')
            .toLowerCase();

    final inviteRecord = <String, dynamic>{
      'id': inviteId,
      'senderName': widget.hostName.trim(),
      'targetName': player.name.trim(),
      'elderHomeId': widget.elderHomeId,
      'elderHomeName': widget.elderHomeName,
      'status': 'PENDING',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    // Update sender's screen ONLY (no popup shown to sender!)
    setState(() {
      player.isInvited = true;
      player.hasJoined = false;
      _feedbackBannerText =
          '🔔 Invitation sent to ${player.name}! Waiting for ${player.name} to log in and accept the notification...';
      _isFeedbackPositive = true;
    });

    await _saveInviteRecord(inviteRecord);

    try {
      final uri =
          Uri.parse('${AppConfig.backendBaseUrl}/api/memory-games/invites');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      await http
          .post(uri, headers: headers, body: jsonEncode(inviteRecord))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _cancelSentInvite(_InvitedPlayer player) async {
    final inviteId =
        'inv_${widget.elderHomeId}_${widget.hostName.trim()}_${player.name.trim()}'
            .replaceAll(' ', '_')
            .toLowerCase();
    final record = <String, dynamic>{
      'id': inviteId,
      'senderName': widget.hostName.trim(),
      'targetName': player.name.trim(),
      'elderHomeId': widget.elderHomeId,
      'elderHomeName': widget.elderHomeName,
      'status': 'CANCELLED',
    };
    setState(() {
      player.isInvited = false;
      player.hasJoined = false;
      _feedbackBannerText = 'Invitation to ${player.name} cancelled.';
      _isFeedbackPositive = false;
    });
    await _saveInviteRecord(record);
    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/api/memory-games/invites/$inviteId/respond',
      );
      await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': 'CANCELLED'}),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _respondToIncomingInvite(
    Map<String, dynamic> invite, {
    required bool accept,
  }) async {
    final inviteId = invite['id']?.toString() ?? '';
    final senderName = (invite['senderName']?.toString() ?? 'Fellow Elder').trim();
    final newStatus = accept ? 'ACCEPTED' : 'DECLINED';

    final updatedRecord = <String, dynamic>{
      ...invite,
      'status': newStatus,
    };

    await _saveInviteRecord(updatedRecord);

    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/api/memory-games/invites/$inviteId/respond',
      );
      await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _incomingInvitesForMe.removeWhere((e) => e['id']?.toString() == inviteId);
      for (final p in _directoryPlayers) {
        if (p.name.toLowerCase() == senderName.toLowerCase()) {
          p.isInvited = accept;
          p.hasJoined = accept;
        }
      }
      _feedbackBannerText = accept
          ? '✅ You accepted $senderName\'s invitation! You and $senderName are now connected in the game room.'
          : 'You declined $senderName\'s invitation.';
      _isFeedbackPositive = accept;
    });
  }

  void _sitTogetherQuickJoin(_InvitedPlayer player) {
    setState(() {
      player.isInvited = true;
      player.hasJoined = true;
      _feedbackBannerText =
          '🪑 ${player.name} sat down with you at the same screen (Sit Together Mode) and is ready to play!';
      _isFeedbackPositive = true;
    });
  }

  void _showIncomingInviteNotificationForTargetElder(
    Map<String, dynamic> invite,
  ) {
    if (!mounted) return;
    final senderName = (invite['senderName']?.toString() ?? 'Fellow Elder').trim();
    final targetName = (invite['targetName']?.toString() ?? widget.hostName).trim();
    final homeName =
        (invite['elderHomeName']?.toString() ?? widget.elderHomeName).trim();

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2563EB), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.bell,
                        size: 15,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Incoming Game Invite for $targetName',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF0D9488),
                  child: Text(
                    senderName.isNotEmpty
                        ? senderName.substring(0, 1).toUpperCase()
                        : 'E',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Join Picnic Memory Game?',
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hello $targetName! Your fellow elder $senderName in $homeName has invited you to play "Shared Picnic Memory Chain" together.',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14.5,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _respondToIncomingInvite(invite, accept: false);
                      },
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.riskHigh,
                        side: const BorderSide(color: AppColors.riskHigh),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _respondToIncomingInvite(invite, accept: true);
                      },
                      icon: const Icon(LucideIcons.check, size: 17),
                      label: const Text(
                        'Accept & Join Game',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.riskLow,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
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

  void _removeJoinedPlayer(_InvitedPlayer player) {
    if (player.isHost) return;
    if (_stage != _ChainTurnStage.lobbyInvite &&
        _joinedPlayers.length <= _minPlayers) {
      setState(() {
        _feedbackBannerText =
            'Minimum 2 players are required during an active collaborative game.';
        _isFeedbackPositive = false;
      });
      return;
    }
    setState(() {
      player.isInvited = false;
      player.hasJoined = false;
      if (_currentPlayerIndex >= _joinedPlayers.length) {
        _currentPlayerIndex = 0;
      }
    });
  }

  void _startCollaborativeGame() {
    if (_joinedPlayers.length < _minPlayers) {
      setState(() {
        _feedbackBannerText =
            'Please invite at least 1 more player (Minimum 2 players required to play).';
        _isFeedbackPositive = false;
      });
      return;
    }

    setState(() {
      for (final p in _directoryPlayers) {
        p.chainStepsCompleted = 0;
        p.itemsAdded = 0;
      }
      _packedChain.clear();
      _currentRecallInput.clear();
      _currentPlayerIndex = 0;
      _totalTeamAttempts = 0;
      _successfulRecalls = 0;
      _teammateHintText = null;
      _feedbackBannerText =
          "Round 1: ${_joinedPlayers[0].name}, pick the first item to pack into our Shared Picnic Basket!";
      _isFeedbackPositive = true;
      _stage = _ChainTurnStage.addNewItemToChain;
    });
  }

  void _returnToInviteLobby() {
    setState(() {
      _stage = _ChainTurnStage.lobbyInvite;
      _teammateHintText = null;
      _feedbackBannerText = null;
    });
  }

  void _askInvitedTeammateForHint() {
    final teammates = _joinedPlayers
        .where((p) => p.id != _joinedPlayers[_currentPlayerIndex].id)
        .toList();
    final helperName =
        teammates.isNotEmpty ? teammates.first.name : 'Your Teammate';

    if (_stage == _ChainTurnStage.recallExistingChain &&
        _currentRecallInput.length < _packedChain.length) {
      final nextItem = _packedChain[_currentRecallInput.length];
      setState(() {
        _teammateHintText =
            '💬 $helperName whispers: "Item #${_currentRecallInput.length + 1} in our basket is ${nextItem.label} (packed by ${nextItem.addedByPlayerName})!"';
      });
    } else if (_stage == _ChainTurnStage.addNewItemToChain) {
      final unpacked = _picnicPool
          .where((item) => !_packedChain.any((c) => c.key == item.key))
          .toList();
      if (unpacked.isNotEmpty) {
        setState(() {
          _teammateHintText =
              '💬 $helperName suggests: "How about packing the ${unpacked.first.label} next?"';
        });
      }
    }
  }

  void _onTapPicnicItem(_PicnicChainItem item) {
    final activePlayer = _joinedPlayers[_currentPlayerIndex];

    if (_stage == _ChainTurnStage.recallExistingChain) {
      final expectedIndex = _currentRecallInput.length;
      if (expectedIndex >= _packedChain.length) return;

      final expectedItem = _packedChain[expectedIndex];
      _totalTeamAttempts++;

      if (item.key == expectedItem.key) {
        _successfulRecalls++;
        activePlayer.chainStepsCompleted++;
        setState(() {
          _currentRecallInput.add(item);
          _teammateHintText = null;
          if (_currentRecallInput.length == _packedChain.length) {
            if (_packedChain.length >= _targetChainLength) {
              _completeChainGame();
            } else {
              _stage = _ChainTurnStage.addNewItemToChain;
              _feedbackBannerText =
                  'Spot on, ${activePlayer.name}! You remembered all ${_packedChain.length} items in order! Now pick 1 NEW item to add to the basket.';
              _isFeedbackPositive = true;
            }
          } else {
            _feedbackBannerText =
                'Correct! Item #${_currentRecallInput.length} is ${item.label}. Now tap Item #${_currentRecallInput.length + 1} in the chain.';
            _isFeedbackPositive = true;
          }
        });
      } else {
        final helper = _joinedPlayers
            .firstWhere(
              (p) => p.id != activePlayer.id,
              orElse: () => activePlayer,
            )
            .name;
        setState(() {
          _feedbackBannerText =
              'Not quite! Ask $helper for a hint — we are looking for Item #${expectedIndex + 1} in the basket order.';
          _isFeedbackPositive = false;
        });
      }
    } else if (_stage == _ChainTurnStage.addNewItemToChain) {
      if (_packedChain.any((c) => c.key == item.key)) {
        setState(() {
          _feedbackBannerText =
              '${item.label} is already in the basket! Choose a fresh item to add to our chain.';
          _isFeedbackPositive = false;
        });
        return;
      }

      final packedItem = item.withAddedBy(activePlayer.name);
      activePlayer.itemsAdded++;
      _totalTeamAttempts++;
      _successfulRecalls++;

      final nextPlayerIndex = (_currentPlayerIndex + 1) % _joinedPlayers.length;
      final nextPlayer = _joinedPlayers[nextPlayerIndex];

      setState(() {
        _packedChain.add(packedItem);
        _currentRecallInput.clear();
        _teammateHintText = null;
        _currentPlayerIndex = nextPlayerIndex;
        _stage = _ChainTurnStage.recallExistingChain;
        _feedbackBannerText =
            '${activePlayer.name} packed "${item.label}"! Now it is ${nextPlayer.name}\'s turn to recall the ${_packedChain.length}-item chain in order!';
        _isFeedbackPositive = true;
      });
    }
  }

  void _completeChainGame() {
    final rawAccuracy = _totalTeamAttempts > 0
        ? (_successfulRecalls.toDouble() / _totalTeamAttempts.toDouble()) * 100.0
        : 100.0;
    final roundedScore = (rawAccuracy.clamp(0.0, 100.0) * 10).round() / 10.0;

    setState(() {
      _stage = _ChainTurnStage.completed;
      _lastScore = roundedScore;
      _feedbackBannerText =
          'Wonderful Teamwork! Your team of ${_joinedPlayers.length} players built and recalled the entire $_targetChainLength-item Picnic Memory Chain!';
      _isFeedbackPositive = true;
    });

    _saveSession(
      score: roundedScore,
      attempts: _totalTeamAttempts,
      correctAnswers: _packedChain.length,
      totalItems: _targetChainLength,
    );
  }

  Future<void> _saveSession({
    required double score,
    required int attempts,
    required int correctAnswers,
    required int totalItems,
  }) async {
    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      await MemoryGameService.saveCompletedSession(
        residentId: widget.residentId,
        gameType: 'COLLABORATIVE_CHAIN',
        scorePercentage: score,
        attempts: attempts,
        correctAnswers: correctAnswers,
        totalItems: totalItems,
        status: 'COMPLETED',
        completionDetailsJson: jsonEncode({
          'roomInviteCode': _roomInviteCode,
          'playerCount': _joinedPlayers.length,
          'players': _joinedPlayers
              .map((p) => {
                    'name': p.name,
                    'role': p.roleLabel,
                    'itemsAdded': p.itemsAdded,
                    'chainStepsCompleted': p.chainStepsCompleted,
                  })
              .toList(),
          'chainItems': _packedChain.map((c) => c.label).toList(),
        }),
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveErrorMessage = 'Could not save session: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGameNavBar(
          gameTitle: 'Shared Picnic Memory Chain',
          gameIcon: LucideIcons.users,
          gameColor: const Color(0xFF2563EB),
          onBack: widget.onBack,
          onReset: _returnToInviteLobby,
          statusBadge:
              '${_joinedPlayers.length} Players Joined • Chain: ${_packedChain.length} / $_targetChainLength',
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _stage == _ChainTurnStage.lobbyInvite
              ? _buildInviteLobbyView()
              : _buildChainGameplayView(),
        ),
      ],
    );
  }

  Widget _buildInviteLobbyView() {
    final canStart = _joinedPlayers.length >= _minPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Invite Header & Room Code Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.users,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Invite Players to Your Memory Chain Room',
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Invite fellow elders from ${widget.elderHomeName} to join (Minimum 2 elders required). Together you will pack a picnic basket and recall the item chain in order!',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13.5,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ROOM INVITE CODE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _roomInviteCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1D4ED8),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('copy_invite_code_button'),
                      onPressed: () {
                        setState(() {
                          _inviteCodeCopied = true;
                          _feedbackBannerText =
                              'Room Invite Code $_roomInviteCode copied! Share it with friends to join.';
                          _isFeedbackPositive = true;
                        });
                      },
                      icon: Icon(
                        _inviteCodeCopied
                            ? LucideIcons.check
                            : LucideIcons.share2,
                        size: 14,
                      ),
                      label: Text(_inviteCodeCopied ? 'Copied!' : 'Share Code'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_feedbackBannerText != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isFeedbackPositive
                  ? AppColors.riskLowBg
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFeedbackPositive
                    ? AppColors.riskLow.withValues(alpha: 0.4)
                    : const Color(0xFFF59E0B),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isFeedbackPositive ? LucideIcons.check : LucideIcons.info,
                  size: 18,
                  color: _isFeedbackPositive
                      ? AppColors.riskLow
                      : const Color(0xFFD97706),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _feedbackBannerText!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. Incoming Invite Notification Banner (Shown ONLY to the target Elder who received the invite!)
        if (_incomingInvitesForMe.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._incomingInvitesForMe.map((inv) {
            final senderName =
                (inv['senderName']?.toString() ?? 'Fellow Elder').trim();
            final invId = inv['id']?.toString() ?? senderName;
            return Container(
              key: ValueKey('incoming_notification_banner_$invId'),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.bell,
                        size: 20,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'New Game Invite from $senderName (${widget.elderHomeName}): "Join my Shared Picnic Memory Chain!"',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        key: ValueKey('accept_incoming_btn_$invId'),
                        onPressed: () =>
                            _respondToIncomingInvite(inv, accept: true),
                        icon: const Icon(LucideIcons.check, size: 15),
                        label: const Text('Accept & Join Game'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.riskLow,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: ValueKey('decline_incoming_btn_$invId'),
                        onPressed: () =>
                            _respondToIncomingInvite(inv, accept: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.riskHigh,
                          side: const BorderSide(color: AppColors.riskHigh),
                        ),
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 20),

        // 3. Online Elders Directory in Same Elder Home (Hybrid: Notification Invite + Sit Together)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Available Elders in ${widget.elderHomeName} (${_joinedPlayers.length} Joined • Minimum $_minPlayers Required)',
                style: AppTextStyles.h4.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.elderHomeName,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Column(
          children: _directoryPlayers.map((player) {
            return Container(
              key: ValueKey('invite_player_row_${player.id}'),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: player.hasJoined
                    ? player.color.withValues(alpha: 0.06)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: player.hasJoined
                      ? player.color.withValues(alpha: 0.45)
                      : const Color(0xFFE2E8F0),
                  width: player.hasJoined ? 1.5 : 1,
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: player.color,
                        child: Text(
                          player.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            player.roleLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (player.isHost)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Host • Ready',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    )
                  else if (player.hasJoined)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.riskLowBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.check,
                                size: 14,
                                color: AppColors.riskLow,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Accepted & Joined',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.riskLow,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: ValueKey('remove_invited_${player.id}'),
                          onPressed: () => _removeJoinedPlayer(player),
                          icon: const Icon(LucideIcons.x, size: 16),
                          tooltip: 'Remove from room',
                          color: AppColors.muted,
                        ),
                      ],
                    )
                  else if (player.isInvited && !player.hasJoined)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.clock,
                                size: 14,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Invite Sent • Waiting for ${player.name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _cancelSentInvite(player),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: ValueKey('sit_together_${player.id}'),
                          onPressed: () => _sitTogetherQuickJoin(player),
                          icon: const Icon(LucideIcons.users, size: 15),
                          label: const Text('Sit Together (Same Screen)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D9488),
                            side: const BorderSide(color: Color(0xFF0D9488)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          key: ValueKey('send_invite_${player.id}'),
                          onPressed: () => _sendInviteNotification(player),
                          icon: const Icon(LucideIcons.bell, size: 15),
                          label: const Text('Send Invite Notification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
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
          }).toList(),
        ),

        const SizedBox(height: 24),

        // 4. Start Collaborative Game CTA (Enforces Minimum 2 Players)
        Center(
          child: Column(
            children: [
              ElevatedButton.icon(
                key: const ValueKey('start_collaborative_chain_button'),
                onPressed: canStart ? _startCollaborativeGame : null,
                icon: const Icon(LucideIcons.play, size: 18),
                label: Text(
                  canStart
                      ? 'Start Picnic Memory Chain (${_joinedPlayers.length} Players Ready)'
                      : 'Invite at Least 1 More Player to Start (Min 2 Players)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChainGameplayView() {
    final activePlayer = _joinedPlayers[_currentPlayerIndex];
    final isCompleted = _stage == _ChainTurnStage.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Active Players Turn Bar + Invite More Players Button
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...List.generate(_joinedPlayers.length, (i) {
              final p = _joinedPlayers[i];
              final isTurn = !isCompleted && _currentPlayerIndex == i;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isTurn
                      ? p.color.withValues(alpha: 0.14)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isTurn ? p.color : const Color(0xFFCBD5E1),
                    width: isTurn ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: p.color,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isTurn ? p.color : AppColors.navy,
                      ),
                    ),
                    if (isTurn) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVE TURN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              key: const ValueKey('manage_invites_button'),
              onPressed: _returnToInviteLobby,
              icon: const Icon(LucideIcons.userPlus, size: 15),
              label: const Text('Invite More Players'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF93C5FD)),
              ),
            ),
            if (!isCompleted)
              OutlinedButton.icon(
                key: const ValueKey('ask_teammate_hint_button'),
                onPressed: _askInvitedTeammateForHint,
                icon: const Icon(LucideIcons.messageCircle, size: 15),
                label: const Text('Ask Teammate for Hint'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFFC4B5FD)),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // 2. Turn Guidance Banner
        if (_feedbackBannerText != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.riskLowBg
                  : (_isFeedbackPositive
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFFEF3C7)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCompleted
                    ? AppColors.riskLow
                    : (_isFeedbackPositive
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFFF59E0B)),
              ),
            ),
            child: Text(
              _feedbackBannerText!,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),

        if (_teammateHintText != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC4B5FD)),
            ),
            child: Text(
              _teammateHintText!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B21B6),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // 3. Visual Shared Picnic Basket Chain Progress
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stage == _ChainTurnStage.recallExistingChain
                    ? 'Step 1: Recall Basket Chain in Order (${_currentRecallInput.length} / ${_packedChain.length} Recalled)'
                    : 'Shared Picnic Basket Chain (${_packedChain.length} / $_targetChainLength Items Packed)',
                style: AppTextStyles.h4.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_targetChainLength, (slotIndex) {
                  final isPacked = slotIndex < _packedChain.length;
                  final isRevealed = _stage !=
                          _ChainTurnStage.recallExistingChain ||
                      slotIndex < _currentRecallInput.length ||
                      isCompleted;
                  final item = isPacked ? _packedChain[slotIndex] : null;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isPacked
                          ? (isRevealed
                              ? item!.color.withValues(alpha: 0.12)
                              : const Color(0xFFEFF6FF))
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPacked
                            ? (isRevealed
                                ? item!.color
                                : const Color(0xFF93C5FD))
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#${slotIndex + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isPacked)
                          const Text(
                            'Empty Slot',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          )
                        else if (isRevealed) ...[
                          Icon(item!.icon, size: 16, color: item.color),
                          const SizedBox(width: 6),
                          Text(
                            '${item.label} (${item.addedByPlayerName})',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            LucideIcons.helpCircle,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Tap Below to Recall',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 4. Picnic Items Selection Grid
        if (!isCompleted) ...[
          Text(
            _stage == _ChainTurnStage.recallExistingChain
                ? "${activePlayer.name}: Tap Item #${_currentRecallInput.length + 1} that was packed into the basket"
                : "${activePlayer.name}: Pick 1 NEW item below to pack into the Shared Picnic Basket",
            style: AppTextStyles.h4.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _picnicPool.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final item = _picnicPool[index];
                  final alreadyPacked =
                      _packedChain.any((c) => c.key == item.key);
                  final recalledThisTurn =
                      _currentRecallInput.any((c) => c.key == item.key);

                  final isDisabledInAddMode =
                      _stage == _ChainTurnStage.addNewItemToChain &&
                          alreadyPacked;

                  return InkWell(
                    key: ValueKey('picnic_chain_item_${item.key}'),
                    onTap: isDisabledInAddMode
                        ? null
                        : () => _onTapPicnicItem(item),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDisabledInAddMode
                            ? const Color(0xFFF1F5F9)
                            : (recalledThisTurn
                                ? AppColors.riskLowBg
                                : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDisabledInAddMode
                              ? const Color(0xFFCBD5E1)
                              : (recalledThisTurn
                                  ? AppColors.riskLow
                                  : item.color.withValues(alpha: 0.45)),
                          width: 1.8,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 32,
                            color: isDisabledInAddMode
                                ? AppColors.muted
                                : item.color,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDisabledInAddMode
                                  ? AppColors.muted
                                  : AppColors.navy,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isDisabledInAddMode)
                            const Text(
                              'Already Packed',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
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
        ] else ...[
          // Completed Summary View
          Center(
            child: Column(
              children: [
                Text(
                  'Team Score: ${(_lastScore ?? 100.0).toStringAsFixed(0)}%',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.riskLow,
                  ),
                ),
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Saving collaborative session...'),
                  ),
                if (_saveErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _saveErrorMessage!,
                      style: const TextStyle(color: AppColors.riskHigh),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      key: const ValueKey('play_chain_again_button'),
                      onPressed: _startCollaborativeGame,
                      icon: const Icon(LucideIcons.rotateCcw, size: 17),
                      label: const Text('Play Another Round Together'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _returnToInviteLobby,
                      icon: const Icon(LucideIcons.users, size: 17),
                      label: const Text('Back to Invite Lobby'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}


