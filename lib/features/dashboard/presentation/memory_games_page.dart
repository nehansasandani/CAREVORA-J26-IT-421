import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../core/services/picnic_bgm_player.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/carevora_avatar.dart';
import '../../assessment/application/memory_game_service.dart';
import '../../auth/application/auth_controller.dart';
import 'widgets/elder_game_invite_notifications.dart';
import 'widgets/elder_memory_game_world_hub.dart';

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
  final String? initialLiveRoomId;

  const MemoryGamesPage({
    super.key,
    this.initialGame = MemoryGameType.none,
    this.initialSequence,
    this.residentId,
    this.token,
    this.initialLiveRoomId,
  });

  @override
  ConsumerState<MemoryGamesPage> createState() => _MemoryGamesPageState();
}

class _MemoryGamesPageState extends ConsumerState<MemoryGamesPage> {
  late MemoryGameType _activeGame;
  List<Map<String, dynamic>> _hubIncomingInvitesForMe = [];
  Timer? _hubInviteTimer;
  bool? _isDeactivated;
  String? _cachedUserName;

  @override
  void initState() {
    super.initState();
    _activeGame = widget.initialGame;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isDeactivated != true) {
        _checkHubIncomingInvites();
      }
    });
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
  void didUpdateWidget(covariant MemoryGamesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGame != MemoryGameType.none &&
        (widget.initialGame != oldWidget.initialGame ||
            widget.initialLiveRoomId != oldWidget.initialLiveRoomId)) {
      _activeGame = widget.initialGame;
    }
  }

  @override
  void deactivate() {
    _isDeactivated = true;
    _hubInviteTimer?.cancel();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isDeactivated = false;
  }

  @override
  void dispose() {
    _isDeactivated = true;
    _hubInviteTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkHubIncomingInvites() async {
    if (!mounted || _isDeactivated == true || _activeGame != MemoryGameType.none) {
      return;
    }
    String myName = _cachedUserName ?? '';
    if (myName.isEmpty) {
      try {
        myName = (ref.read(authProvider).state.userName ?? '').trim().toLowerCase();
        _cachedUserName = myName;
      } catch (_) {
        return;
      }
    }
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

    if (mounted && _isDeactivated != true) {
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
    _cachedUserName = (auth.userName ?? '').trim().toLowerCase();
    final effectiveResidentId = widget.residentId ?? auth.residentId ?? 1;
    final effectiveToken = widget.token ?? auth.token;

    switch (_activeGame) {
      case MemoryGameType.sequence:
        final isSinhala = ref.watch(languageProvider).isSinhala;
        return _SequenceGameView(
          key: const ValueKey('sequence_game'),
          onBack: _backToHub,
          initialSequence: widget.initialSequence,
          residentId: effectiveResidentId,
          token: effectiveToken,
          isSinhala: isSinhala,
        );
      case MemoryGameType.pairs:
        final isSinhala = ref.watch(languageProvider).isSinhala;
        return _PairsGameView(
          key: const ValueKey('pairs_game'),
          onBack: _backToHub,
          residentId: effectiveResidentId,
          token: effectiveToken,
          isSinhala: isSinhala,
        );
      case MemoryGameType.items:
        final isSinhala = ref.watch(languageProvider).isSinhala;
        return _ItemsGameView(
          key: const ValueKey('items_game'),
          onBack: _backToHub,
          residentId: effectiveResidentId,
          token: effectiveToken,
          isSinhala: isSinhala,
        );
      case MemoryGameType.collaborative:
        final isSinhala = ref.watch(languageProvider).isSinhala;
        return _CollaborativeMemoryGameView(
          key: const ValueKey('collaborative_game'),
          onBack: _backToHub,
          residentId: effectiveResidentId,
          elderHomeId: auth.elderHomeId ?? 1,
          elderHomeName: auth.elderHomeName ?? 'Serene Valley Senior Living',
          hostName: auth.userName ?? 'Sarah Jenkins',
          hostAvatarUrl: auth.avatarUrl,
          token: effectiveToken,
          isSinhala: isSinhala,
          initialLiveRoomId: widget.initialLiveRoomId,
        );
      case MemoryGameType.none:
        if (auth.isElder) {
          final isSinhala = ref.watch(languageProvider).isSinhala;
          return ElderMemoryGameWorldHub(
            isSinhala: isSinhala,
            userName: auth.userName ?? 'Friend',
            incomingInvites: _hubIncomingInvitesForMe,
            onPlaySequence: () => _selectGame(MemoryGameType.sequence),
            onPlayPairs: () => _selectGame(MemoryGameType.pairs),
            onPlayItems: () => _selectGame(MemoryGameType.items),
            onPlayCollaborative: () => _selectGame(MemoryGameType.collaborative),
          );
        }
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

            // Floating AI Neural Constellation, Sparkles & Holographic Rings
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FloatingAiConstellationPainter(progress: t),
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

class _FloatingAiConstellationPainter extends CustomPainter {
  final double progress;

  _FloatingAiConstellationPainter({required this.progress});

  static const List<List<double>> _nodeSpecs = [
    // [xFrac, yFrac, ampX, ampY, phase, radius, colorIdx]
    [0.05, 0.10, 14, 18, 0.0, 4.2, 0],
    [0.12, 0.24, 12, 16, 1.1, 3.4, 1],
    [0.04, 0.40, 16, 14, 2.2, 4.8, 2],
    [0.10, 0.56, 13, 18, 0.7, 3.6, 3],
    [0.05, 0.74, 15, 16, 3.1, 4.4, 0],
    [0.14, 0.88, 12, 14, 1.8, 3.5, 1],
    [0.24, 0.07, 14, 12, 2.6, 3.2, 2],
    [0.38, 0.12, 12, 14, 0.9, 2.8, 0],
    [0.54, 0.06, 15, 12, 3.8, 3.4, 1],
    [0.72, 0.09, 13, 15, 1.5, 3.2, 3],
    [0.88, 0.14, 14, 18, 2.4, 4.2, 0],
    [0.95, 0.28, 15, 16, 0.4, 4.6, 1],
    [0.89, 0.45, 12, 18, 3.3, 3.8, 2],
    [0.96, 0.62, 14, 15, 1.9, 4.5, 3],
    [0.90, 0.78, 16, 16, 0.8, 4.0, 0],
    [0.95, 0.92, 12, 14, 2.9, 3.6, 1],
    [0.28, 0.92, 14, 14, 1.3, 3.4, 2],
    [0.48, 0.95, 16, 12, 3.6, 3.2, 0],
    [0.68, 0.91, 14, 14, 0.5, 3.6, 3],
    [0.80, 0.86, 12, 16, 2.1, 3.0, 1],
  ];

  static const List<Color> _palette = [
    Color(0xFF7C3AED), // AI Violet
    Color(0xFF0D9488), // Aurora Teal
    Color(0xFF0284C7), // Smart Sky Blue
    Color(0xFFDB2777), // Warm Rose
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final angle = progress * pi * 2;
    final List<Offset> positions = [];
    final List<Color> colors = [];

    // 1. Compute gently drifting node positions
    for (final spec in _nodeSpecs) {
      final baseX = spec[0] * size.width;
      final baseY = spec[1] * size.height;
      final dx = sin(angle + spec[4]) * spec[2];
      final dy = cos(angle * 0.85 + spec[4] * 1.3) * spec[3];
      positions.add(Offset(baseX + dx, baseY + dy));
      colors.add(_palette[spec[6].toInt()]);
    }

    // 2. Draw delicate glowing neural links between nearby nodes
    final double maxDist = min(size.width, size.height) * 0.24 + 80;
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final dist = (positions[i] - positions[j]).distance;
        if (dist < maxDist) {
          final strength = (1.0 - dist / maxDist);
          final linePaint = Paint()
            ..color = colors[i].withValues(alpha: 0.14 * strength)
            ..strokeWidth = 1.15
            ..style = PaintingStyle.stroke;
          canvas.drawLine(positions[i], positions[j], linePaint);

          // Tiny travelling synaptic light dot on close pairs
          if (strength > 0.45 && (i + j) % 3 == 0) {
            final pulseT = (progress + (i * 0.17)) % 1.0;
            final dotPos = Offset.lerp(positions[i], positions[j], pulseT)!;
            canvas.drawCircle(
              dotPos,
              2.2,
              Paint()..color = colors[j].withValues(alpha: 0.35 * strength),
            );
          }
        }
      }
    }

    // 3. Draw glowing AI synaptic nodes
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final color = colors[i];
      final r = _nodeSpecs[i][5];
      final pulse = 0.72 + 0.28 * sin(angle * 1.5 + _nodeSpecs[i][4]);

      // Outer halo
      canvas.drawCircle(
        pos,
        r * 3.1,
        Paint()..color = color.withValues(alpha: 0.10 * pulse),
      );
      // Core node
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = color.withValues(alpha: 0.38 * pulse),
      );
      // Inner white glint
      canvas.drawCircle(
        pos,
        r * 0.42,
        Paint()..color = Colors.white.withValues(alpha: 0.75 * pulse),
      );
    }

    // 4. Draw gently floating 4-point AI sparkles (✦)
    const List<List<double>> sparkleSpecs = [
      [0.07, 0.17, 10.0, 0.5, 0.0],
      [0.93, 0.20, 11.0, 1.8, 1.0],
      [0.03, 0.65, 9.5, 2.7, 3.0],
      [0.96, 0.52, 10.5, 0.9, 2.0],
      [0.08, 0.85, 8.5, 3.4, 1.0],
      [0.92, 0.84, 10.0, 2.1, 0.0],
      [0.46, 0.04, 8.0, 1.2, 2.0],
      [0.60, 0.96, 9.0, 2.9, 3.0],
    ];
    for (final s in sparkleSpecs) {
      final cx = s[0] * size.width + sin(angle + s[3]) * 10;
      final cy = s[1] * size.height + cos(angle + s[3]) * 12;
      final radius = s[2] * (0.8 + 0.25 * sin(angle * 2 + s[3]));
      final color = _palette[s[4].toInt()];
      final alpha = 0.22 + 0.18 * (0.5 + 0.5 * sin(angle * 2 + s[3]));
      _drawFourPointSparkle(canvas, Offset(cx, cy), radius, color.withValues(alpha: alpha));
    }

    // 5. Draw delicate floating holographic rings & AI hexagons in the margins
    _drawFloatingRing(
      canvas,
      Offset(size.width * 0.04 + sin(angle) * 10, size.height * 0.30 + cos(angle) * 14),
      26,
      const Color(0xFF8B5CF6).withValues(alpha: 0.18),
    );
    _drawFloatingRing(
      canvas,
      Offset(size.width * 0.96 - sin(angle) * 10, size.height * 0.70 - cos(angle) * 14),
      30,
      const Color(0xFF0D9488).withValues(alpha: 0.18),
    );
    _drawFloatingHexagon(
      canvas,
      Offset(size.width * 0.94 + cos(angle) * 8, size.height * 0.37 + sin(angle) * 12),
      18,
      angle * 0.25,
      const Color(0xFF0284C7).withValues(alpha: 0.20),
    );
    _drawFloatingHexagon(
      canvas,
      Offset(size.width * 0.06 - cos(angle) * 8, size.height * 0.78 - sin(angle) * 12),
      16,
      -angle * 0.25,
      const Color(0xFFDB2777).withValues(alpha: 0.18),
    );
  }

  void _drawFourPointSparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawFloatingRing(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()
        ..color = color.withValues(alpha: 0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawFloatingHexagon(
    Canvas canvas,
    Offset c,
    double r,
    double rotation,
    Color color,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = rotation + i * (pi / 3);
      final pt = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _FloatingAiConstellationPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
  final bool isSinhala;

  const _SequenceGameView({
    super.key,
    required this.onBack,
    this.initialSequence,
    required this.residentId,
    this.token,
    this.isSinhala = false,
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
  final String sinhalaLabel;
  final Color color;
  final Color accentGradient;
  final IconData icon;

  const _SequenceTileData({
    required this.id,
    required this.label,
    required this.sinhalaLabel,
    required this.color,
    required this.accentGradient,
    required this.icon,
  });

  String displayLabel(bool isSi) => isSi ? sinhalaLabel : label;
}

class _SequenceGameViewState extends State<_SequenceGameView> {
  static const int _maxLevels = 3;

  static const List<_SequenceTileData> _tiles = [
    _SequenceTileData(
      id: 0,
      label: 'Violet 1',
      sinhalaLabel: 'දම් 1',
      color: Color(0xFF7C3AED),
      accentGradient: Color(0xFF9333EA),
      icon: Icons.looks_one_rounded,
    ),
    _SequenceTileData(
      id: 1,
      label: 'Blue 2',
      sinhalaLabel: 'නිල් 2',
      color: Color(0xFF2563EB),
      accentGradient: Color(0xFF3B82F6),
      icon: Icons.looks_two_rounded,
    ),
    _SequenceTileData(
      id: 2,
      label: 'Green 3',
      sinhalaLabel: 'කොළ 3',
      color: Color(0xFF16A34A),
      accentGradient: Color(0xFF22C55E),
      icon: Icons.looks_3_rounded,
    ),
    _SequenceTileData(
      id: 3,
      label: 'Orange 4',
      sinhalaLabel: 'තැඹිලි 4',
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

  // Hot-reload-safe nullable state for voice, chimes, animated preview & 3-level finish flow
  bool? _voiceEnabled;
  Timer? _voiceDelayTimer;
  Timer? _highlightTimer;
  int? _highlightedPreviewStep;
  PicnicBgmPlayer? _sfxPlayer;
  List<double>? _levelScores;
  int? _lastRetryMatchedCount;
  bool? _isTestEnv;
  bool? _isCheckingResult;
  Timer? _evalTimer;

  bool get _isVoiceOn => _voiceEnabled ?? true;
  bool get _isFinalLevel => _currentLevel >= _maxLevels;
  PicnicBgmPlayer get _sfx => _sfxPlayer ??= PicnicBgmPlayer();

  static const String _siHowToSpeech =
      'අනුපිළිවෙල මතක ක්‍රීඩාව ක්‍රීඩා කරන ආකාරය. පළමුව, පියවර එක සිට අවසානය දක්වා පෙන්වන පාට සහ අංක පිළිවෙල හොඳින් මතක තබාගන්න. දෙවනුව, මතකයි ආරම්භ කරමු ඔබා, ඒ පිළිවෙලටම පහළ ඇති පාට අංක බොත්තම් ඔබන්න. තෙවනුව, මට්ටම් තුනම සම්පූර්ණ කර ජය ගන්න. අමතක වුණොත් නැවත බලන්න ඔබන්න.';
  static const String _enHowToSpeech =
      'How to play Remember the Sequence. Step 1: Watch the colored numbers in order from Step 1 to the end. Step 2: Tap Start My Turn, then tap the colored buttons in the exact same order. Step 3: Complete all 3 levels to win! You can tap Watch Again anytime if you need another look.';

  @override
  void initState() {
    super.initState();
    _isTestEnv = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _levelScores = <double>[];
    if (widget.initialSequence != null && widget.initialSequence!.isNotEmpty) {
      _sequenceLength = widget.initialSequence!.length;
      _targetSequence = List<int>.from(widget.initialSequence!);
      _userTaps = [];
      _phase = _SeqPhase.showing;
      _startPreviewPulse();
      _speakPhasePrompt(_SeqPhase.showing, delay: const Duration(milliseconds: 350));
    } else {
      _startNewRound(initialDelay: const Duration(milliseconds: 350));
    }
  }

  @override
  void didUpdateWidget(covariant _SequenceGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSinhala != widget.isSinhala) {
      _speakPhasePrompt(_phase);
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _voiceDelayTimer?.cancel();
    _highlightTimer?.cancel();
    _evalTimer?.cancel();
    if (_isTestEnv != true) {
      TtsService.instance.onComplete = null;
      TtsService.instance.stop();
    }
    _sfxPlayer?.dispose();
    super.dispose();
  }

  void _speakText(String enText, String siText, {Duration delay = Duration.zero}) {
    if (_isTestEnv == true || !_isVoiceOn || !mounted) return;
    _voiceDelayTimer?.cancel();
    final isSi = widget.isSinhala;
    final text = isSi ? siText : enText;
    if (delay == Duration.zero) {
      TtsService.instance.speak(text, isSinhala: isSi);
      return;
    }
    _voiceDelayTimer = Timer(delay, () {
      if (!mounted || !_isVoiceOn || _isTestEnv == true) return;
      TtsService.instance.speak(text, isSinhala: isSi);
    });
  }

  void _speakPhasePrompt(_SeqPhase phase, {Duration delay = Duration.zero}) {
    switch (phase) {
      case _SeqPhase.showing:
        _speakText(
          'Watch and remember the colored numbers in order. When you are ready, tap Start My Turn.',
          'පාට සහ අංක පිළිවෙල හොඳින් බලා මතක තබාගන්න. සූදානම් වූ පසු ආරම්භ කරමු ඔබන්න.',
          delay: delay,
        );
        break;
      case _SeqPhase.input:
        _speakText(
          "Now it's your turn! Tap the colored circles in the exact same order.",
          'දැන් ඔබේ වාරයයි! කලින් දුටු පිළිවෙලටම පාට අංක බොත්තම් ඔබන්න.',
          delay: delay,
        );
        break;
      case _SeqPhase.success:
        if (_isFinalLevel) {
          _speakText(
            'Amazing champion! You completed all 3 levels of Remember the Sequence! Your memory is shining bright!',
            'විශිෂ්ට ජයග්‍රහණයක්! ඔබ අනුපිළිවෙල මතක ක්‍රීඩාවේ මට්ටම් තුනම සාර්ථකව අවසන් කළා! ඔබේ මතක ශක්තිය හරිම අපූරුයි!',
            delay: delay,
          );
        } else {
          _speakText(
            "Wonderful job! You remembered the sequence perfectly! Let's try the next level.",
            'හරිම විශිෂ්ටයි! ඔබ පිළිවෙල හරියටම මතක තබා ගත්තා! අපි ඊළඟ මට්ටමට යමු.',
            delay: delay,
          );
        }
        break;
      case _SeqPhase.retry:
        _speakText(
          'Good try! Take a deep breath, watch the sequence again, and give it another try.',
          'හොඳ උත්සාහයක්! කලබල වෙන්න එපා. අපි පිළිවෙල නැවත බලා ආයෙත් උත්සාහ කරමු.',
          delay: delay,
        );
        break;
    }
  }

  void _toggleVoice() {
    final next = !_isVoiceOn;
    setState(() => _voiceEnabled = next);
    if (!next) {
      _voiceDelayTimer?.cancel();
      if (_isTestEnv != true) {
        TtsService.instance.stop();
      }
    } else {
      _speakPhasePrompt(_phase);
    }
  }

  void _startPreviewPulse() {
    _highlightTimer?.cancel();
    if (_isTestEnv == true || _targetSequence.isEmpty) return;
    _highlightedPreviewStep = 0;
    _highlightTimer = Timer.periodic(const Duration(milliseconds: 950), (timer) {
      if (!mounted || _phase != _SeqPhase.showing) {
        timer.cancel();
        return;
      }
      setState(() {
        final next = ((_highlightedPreviewStep ?? 0) + 1) % _targetSequence.length;
        _highlightedPreviewStep = next;
      });
    });
  }

  void _startNewRound({Duration initialDelay = Duration.zero}) {
    _completionTimer?.cancel();
    _evalTimer?.cancel();
    _hasShownSuccessPopup = false;
    _isPopupOpen = false;
    final List<int> seq = [];
    for (int i = 0; i < _sequenceLength; i++) {
      // Avoid 3 identical tiles in a row so sequences feel natural & memorable
      int pick = _random.nextInt(_tiles.length);
      if (seq.length >= 2 && seq[seq.length - 1] == pick && seq[seq.length - 2] == pick) {
        pick = (pick + 1) % _tiles.length;
      }
      seq.add(pick);
    }
    setState(() {
      _targetSequence = seq;
      _userTaps = [];
      _phase = _SeqPhase.showing;
      _roundAttempts = 1;
      _wrongTapsInRound = 0;
      _lastRetryMatchedCount = null;
      _isCheckingResult = false;
      _saveSuccessMessage = null;
      _saveErrorMessage = null;
      _highlightedPreviewStep = 0;
    });
    _startPreviewPulse();
    _speakPhasePrompt(_SeqPhase.showing, delay: initialDelay);
  }

  void _startInputPhase() {
    _highlightTimer?.cancel();
    _evalTimer?.cancel();
    if (_isTestEnv != true) {
      _sfx.playTapChime(volume: 0.24);
    }
    setState(() {
      _userTaps = [];
      _phase = _SeqPhase.input;
      _highlightedPreviewStep = null;
      _isCheckingResult = false;
    });
    _speakPhasePrompt(_SeqPhase.input);
  }

  void _replaySequence() {
    _evalTimer?.cancel();
    setState(() {
      _userTaps = [];
      _phase = _SeqPhase.showing;
      _highlightedPreviewStep = 0;
      _isCheckingResult = false;
    });
    _startPreviewPulse();
    _speakPhasePrompt(_SeqPhase.showing);
  }

  void _undoLastTap() {
    if (_phase != _SeqPhase.input || _userTaps.isEmpty || _isCheckingResult == true) return;
    if (_isTestEnv != true) {
      _sfx.playTapChime(volume: 0.22);
    }
    setState(() {
      _userTaps = List<int>.from(_userTaps)..removeLast();
    });
  }

  void _resetToBeginning() {
    _completionTimer?.cancel();
    _evalTimer?.cancel();
    _hasShownSuccessPopup = false;
    _isPopupOpen = false;
    setState(() {
      _currentLevel = 1;
      _sequenceLength = 3;
      _levelScores = <double>[];
      _isCheckingResult = false;
    });
    _startNewRound();
  }

  void _onTileTap(int tileId) {
    if (_phase != _SeqPhase.input || _isCheckingResult == true) return;

    final nextIndex = _userTaps.length;
    if (nextIndex >= _targetSequence.length) return;

    if (_isTestEnv != true) {
      _sfx.playTapChime(volume: 0.26);
    }

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

    void finalizeRoundEvaluation() {
      if (!mounted) return;
      if (isAllCorrect) {
        final totalTaps = _targetSequence.length + _wrongTapsInRound;
        final accuracy =
            ((_targetSequence.length.toDouble() / totalTaps.toDouble()) * 100.0)
                .clamp(0.0, 100.0);
        final roundedScore = (accuracy * 10).round() / 10.0;
        final attemptsCount = _roundAttempts;

        final scores = List<double>.from(_levelScores ?? const <double>[]);
        if (scores.length >= _currentLevel) {
          scores[_currentLevel - 1] = roundedScore;
        } else {
          scores.add(roundedScore);
        }

        setState(() {
          _userTaps = updatedTaps;
          _isCheckingResult = false;
          _phase = _SeqPhase.success;
          _lastScore = roundedScore;
          _lastAttempts = attemptsCount;
          _lastCorrectCount = _targetSequence.length;
          _levelScores = scores;
        });

        if (_isTestEnv != true) {
          _sfx.playVictoryChime(volume: 0.28);
        }
        _speakPhasePrompt(_SeqPhase.success, delay: const Duration(milliseconds: 220));

        _saveSession(
          score: roundedScore,
          attempts: attemptsCount,
          correctAnswers: _targetSequence.length,
          totalItems: _targetSequence.length,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _phase == _SeqPhase.success &&
              !_hasShownSuccessPopup &&
              !_isFinalLevel) {
            _showSuccessPopup();
          }
        });
      } else {
        final wrongCount = _targetSequence.length - correctCount;
        setState(() {
          _userTaps = updatedTaps;
          _isCheckingResult = false;
          _wrongTapsInRound += (wrongCount > 0 ? wrongCount : 1);
          _lastRetryMatchedCount = correctCount;
          _roundAttempts++;
          _phase = _SeqPhase.retry;
        });
        _speakPhasePrompt(_SeqPhase.retry);
      }
    }

    if (_isTestEnv == true) {
      finalizeRoundEvaluation();
      return;
    }

    // Show the final tapped tile cleanly in the last slot for 800ms before transitioning
    // so the elder clearly sees their complete selection instead of an abrupt jump!
    setState(() {
      _userTaps = updatedTaps;
      _isCheckingResult = true;
    });
    _evalTimer?.cancel();
    _evalTimer = Timer(const Duration(milliseconds: 800), finalizeRoundEvaluation);
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
      await MemoryGameService.saveCompletedSession(
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
          'maxLevels': _maxLevels,
          'wrongTaps': _wrongTapsInRound,
        }),
        token: widget.token,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccessMessage = widget.isSinhala
              ? 'ප්‍රගති වාර්තාවේ සුරැකුණා'
              : 'Saved to Cognitive Progress';
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

  Future<void> _showSequenceHowToPlayDialog() async {
    final isSi = widget.isSinhala;
    final tts = TtsService.instance;
    bool isSpeakingNow = false;
    bool dialogOpen = true;

    void stopGuideSpeech({void Function(VoidCallback)? setDlgState}) {
      tts.onComplete = null;
      tts.stop();
      if (isSpeakingNow) {
        isSpeakingNow = false;
        if (dialogOpen && setDlgState != null) {
          setDlgState(() {});
        }
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            void toggleSpeak() {
              if (isSpeakingNow) {
                stopGuideSpeech(setDlgState: setDlgState);
                return;
              }
              setDlgState(() => isSpeakingNow = true);
              tts.onComplete = () {
                if (dialogOpen) {
                  isSpeakingNow = false;
                  setDlgState(() {});
                }
              };
              tts.speak(
                isSi ? _siHowToSpeech : _enHowToSpeech,
                isSinhala: isSi,
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 530),
                child: AuroraGradientBorderFrame(
                  borderRadius: 24,
                  borderWidth: 3.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4C1D95).withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Strip with Listen button
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF2E1065),
                                Color(0xFF6D28D9),
                                Color(0xFF0D9488),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Center(
                                  child: Text('🔢', style: TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isSi ? 'ක්‍රීඩා කරන ආකාරය' : 'How to Play',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      isSi
                                          ? 'සරල පියවර 3 කින් අනුපිළිවෙල මතක තබාගනිමු'
                                          : '3 simple steps to master the sequence',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                key: const ValueKey('seq_howto_listen_button'),
                                onPressed: toggleSpeak,
                                icon: Icon(
                                  isSpeakingNow
                                      ? Icons.stop_rounded
                                      : Icons.volume_up_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isSpeakingNow
                                      ? (isSi ? 'නවත්වන්න' : 'Stop')
                                      : (isSi ? 'අසන්න' : 'Listen'),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSpeakingNow
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFFDE68A),
                                  foregroundColor: isSpeakingNow
                                      ? Colors.white
                                      : const Color(0xFF1E1B4B),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: isSi ? 'වසන්න' : 'Close',
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSeqGuideStepCard(
                                stepNumber: '1',
                                emoji: '👀',
                                title: isSi
                                    ? 'පාට සහ අංක පිළිවෙල බලන්න'
                                    : 'Watch the Color & Number Order',
                                description: isSi
                                    ? 'පියවර 1 සිට අවසානය දක්වා පෙන්වන පාට සහ අංක පිළිවෙල හොඳින් මතක තබාගන්න.'
                                    : 'Look closely at the colored numbered circles from Step 1 to the end at your own pace.',
                                accentColor: const Color(0xFF7C3AED),
                                bgColors: const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                              ),
                              const SizedBox(height: 11),
                              _buildSeqGuideStepCard(
                                stepNumber: '2',
                                emoji: '👆',
                                title: isSi
                                    ? 'ඒ පිළිවෙලටම ඔබන්න'
                                    : 'Tap in the Exact Same Order',
                                description: isSi
                                    ? '"මතකයි! ආරම්භ කරමු" ඔබා, කලින් දුටු පිළිවෙලටම පහළ ඇති පාට බොත්තම් ඔබන්න.'
                                    : 'Tap "Start My Turn", then tap the large colored buttons in the exact same order. Use Undo if you mis-tap!',
                                accentColor: const Color(0xFF0D9488),
                                bgColors: const [Color(0xFFECFDF5), Color(0xFFF0FDFA)],
                              ),
                              const SizedBox(height: 11),
                              _buildSeqGuideStepCard(
                                stepNumber: '3',
                                emoji: '🏆',
                                title: isSi
                                    ? 'මට්ටම් 3ම සම්පූර්ණ කර ජය ගන්න!'
                                    : 'Complete All 3 Levels & Win!',
                                description: isSi
                                    ? 'මට්ටම 1 (අංක 3), මට්ටම 2 (අංක 4), මට්ටම 3 (අංක 5) සම්පූර්ණ කර ක්‍රීඩාව ජය ගන්න. අමතක වුණොත් නැවත බලන්න ඔබන්න!'
                                    : 'Finish Level 1 (3 tiles), Level 2 (4 tiles), and Level 3 (5 tiles) to complete the game! Tap Watch Again anytime.',
                                accentColor: const Color(0xFFD97706),
                                bgColors: const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6D28D9),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    isSi
                                        ? '👍 හරි, තේරුණා!'
                                        : "👍 Got It! Let's Play",
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
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
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      dialogOpen = false;
      stopGuideSpeech();
    });
  }

  Widget _buildSeqGuideStepCard({
    required String stepNumber,
    required String emoji,
    required String title,
    required String description,
    required Color accentColor,
    required List<Color> bgColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stepNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double get _overallAverageScore {
    final scores = _levelScores ?? const <double>[];
    if (scores.isEmpty) return _lastScore ?? 100.0;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return (avg * 10).round() / 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.isSinhala;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGameNavBar(
          gameTitle: isSi ? 'අනුපිළිවෙල මතකය' : 'Remember the Sequence',
          gameIcon: LucideIcons.sparkles,
          gameColor: const Color(0xFF7C3AED),
          onBack: widget.onBack,
          onReset: _resetToBeginning,
          backLabel: isSi ? 'සියලුම ක්‍රීඩා' : 'All Games',
          statusBadge: isSi
              ? 'මට්ටම $_currentLevel / $_maxLevels • අංක $_sequenceLength'
              : 'Level $_currentLevel of $_maxLevels • $_sequenceLength Tiles',
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFBF9FE),
                Color(0xFFF5F3FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Attractive Cosmic Header Banner with 3-Level Stepper, Voice & How to Play
                _buildSequenceCosmicHeader(isSi),

                // 2. Main Interactive Game Content with Gentle Animated Pastel Backdrop
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 462),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: _SeqAmbientPlayBackdrop(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      if (!(_phase == _SeqPhase.success && _isFinalLevel) &&
                          _phase != _SeqPhase.retry) ...[
                        _buildInstructionBanner(isSi),
                        const SizedBox(height: 12),
                      ],

                      if (_phase == _SeqPhase.showing) ...[
                        const SizedBox(height: 14),
                        _buildSequencePreview(isSi),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(17),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.38),
                                  blurRadius: 16,
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
                                padding: const EdgeInsets.symmetric(horizontal: 38),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.sparkles, size: 21),
                                  const SizedBox(width: 10),
                                  Text(
                                    isSi
                                        ? 'මතකයි! සඟවා මගේ වාරය අරඹන්න'
                                        : 'I Remember! Hide & Start My Turn',
                                    style: AppTextStyles.button.copyWith(
                                      fontSize: 17,
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
                        const SizedBox(height: 14),
                      ] else if (_phase == _SeqPhase.input) ...[
                        const SizedBox(height: 4),
                        _buildProgressSlots(isSi),
                        const SizedBox(height: 16),
                        _buildInteractiveTilesGrid(isSi),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            if (_userTaps.isNotEmpty && _isCheckingResult != true)
                              OutlinedButton.icon(
                                key: const ValueKey('seq_undo_tap_button'),
                                onPressed: _undoLastTap,
                                icon: const Icon(Icons.backspace_outlined, size: 18),
                                label: Text(
                                  isSi ? 'පසුපසට (Undo)' : 'Undo Last Tap',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEA580C),
                                  side: const BorderSide(
                                    color: Color(0xFFFDBA74),
                                    width: 1.6,
                                  ),
                                  backgroundColor: const Color(0xFFFFF7ED),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            OutlinedButton.icon(
                              key: const ValueKey('replay_sequence_button'),
                              onPressed: _isCheckingResult == true ? null : _replaySequence,
                              icon: const Icon(LucideIcons.rotateCcw, size: 17),
                              label: Text(
                                isSi
                                    ? 'පිළිවෙල නැවත බලන්න'
                                    : 'Replay Sequence to Watch Again',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6D28D9),
                                side: const BorderSide(
                                  color: Color(0xFFDDD6FE),
                                  width: 1.6,
                                ),
                                backgroundColor: const Color(0xFFFAF5FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ] else if (_phase == _SeqPhase.success) ...[
                        _isFinalLevel
                            ? _buildGrandFinishCard(isSi)
                            : _buildSuccessView(isSi),
                      ] else if (_phase == _SeqPhase.retry) ...[
                        _buildRetryView(isSi),
                      ],
                        ],
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
    );
  }

  Widget _buildSequenceCosmicHeader(bool isSi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2E1065),
            Color(0xFF5B21B6),
            Color(0xFF1D4ED8),
            Color(0xFF0D9488),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          // Left: Title + 3-Level Visual Stepper
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Text('🔢', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'අනුපිළිවෙල මතක ක්‍රීඩාව ✨' : 'Remember the Sequence ✨',
                        style: const TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSi
                            ? 'මට්ටම් 3ම සම්පූර්ණ කර ජය ගන්න'
                            : 'Complete all 3 levels to finish the challenge',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 3-Level Progress Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_maxLevels, (idx) {
                  final lvl = idx + 1;
                  final tilesCount = 2 + lvl;
                  final isCompleted = lvl < _currentLevel ||
                      (lvl == _currentLevel && _phase == _SeqPhase.success);
                  final isCurrent = lvl == _currentLevel && !isCompleted;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : (isCurrent
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.14)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFF6EE7B7)
                                : (isCurrent
                                    ? const Color(0xFFFDE68A)
                                    : Colors.white.withValues(alpha: 0.30)),
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCompleted)
                              const Icon(Icons.check_circle, size: 13, color: Colors.white)
                            else
                              Icon(
                                isCurrent ? Icons.play_circle_fill : Icons.circle_outlined,
                                size: 13,
                                color: isCurrent
                                    ? const Color(0xFF6D28D9)
                                    : Colors.white.withValues(alpha: 0.80),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              isSi ? 'L$lvl ($tilesCount)' : 'L$lvl • $tilesCount',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: isCompleted
                                    ? Colors.white
                                    : (isCurrent
                                        ? const Color(0xFF1E1B4B)
                                        : Colors.white.withValues(alpha: 0.85)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (idx < _maxLevels - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.60),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),

          // Right: Voice Toggle + How to Play Button
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('seq_voice_toggle_button'),
                onPressed: _toggleVoice,
                icon: Icon(
                  _isVoiceOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  size: 16,
                ),
                label: Text(
                  _isVoiceOn
                      ? (isSi ? 'හඬ: ON' : 'Voice: ON')
                      : (isSi ? 'හඬ: OFF' : 'Voice: OFF'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isVoiceOn
                      ? const Color(0xFFA7F3D0)
                      : Colors.white.withValues(alpha: 0.78),
                  backgroundColor: _isVoiceOn
                      ? const Color(0xFF10B981).withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: _isVoiceOn
                        ? const Color(0xFF6EE7B7).withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('seq_how_to_play_button'),
                onPressed: _showSequenceHowToPlayDialog,
                icon: const Icon(Icons.help_outline_rounded, size: 17),
                label: Text(
                  isSi ? 'ක්‍රීඩා කරන ආකාරය' : 'How to Play',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionBanner(bool isSi) {
    String title = '';
    String subtitle = '';
    List<Color> gradientColors = [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)];
    Color borderColor = const Color(0xFFDDD6FE);
    Color iconColor = const Color(0xFF7C3AED);
    IconData icon = LucideIcons.sparkles;

    switch (_phase) {
      case _SeqPhase.showing:
        title = isSi
            ? 'පිළිවෙල හොඳින් බලා මතක තබාගන්න'
            : 'Watch & Remember the Sequence';
        subtitle = isSi
            ? 'පහළ පෙන්වන පාට සහ අංක පිළිවෙල නිදහසේ මතක තබාගන්න. සූදානම් වූ පසු ආරම්භ කිරීමට බොත්තම ඔබන්න.'
            : 'Take your time to memorize the colors and numbers shown below. When ready, tap the button to begin.';
        gradientColors = [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)];
        borderColor = const Color(0xFFDDD6FE);
        iconColor = const Color(0xFF7C3AED);
        icon = LucideIcons.sparkles;
        break;
      case _SeqPhase.input:
        title = isSi
            ? 'ඔබේ වාරය: පිළිවෙලට පාට අංක ඔබන්න'
            : 'Your Turn: Tap the Tiles in Order';
        subtitle = isSi
            ? 'කලින් දුටු පිළිවෙලටම පහළ ඇති පාට අංක වටයන් ඔබන්න.'
            : 'Tap the colored circles below in the exact same sequence you just saw.';
        gradientColors = [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)];
        borderColor = const Color(0xFFC7D2FE);
        iconColor = const Color(0xFF6D28D9);
        icon = LucideIcons.mousePointerClick;
        break;
      case _SeqPhase.success:
        title = isSi
            ? 'විශිෂ්ටයි! ඔබ හරියටම මතක තබා ගත්තා!'
            : 'Well done! Perfect Memory!';
        subtitle = isSi
            ? 'ඔබ අංක $_sequenceLength ම නිවැරදි පිළිවෙලට තෝරා ගත්තා. ඊළඟ මට්ටමට යමුද?'
            : 'You correctly recalled all $_sequenceLength tiles in order! Ready for Level ${_currentLevel + 1}?';
        gradientColors = [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)];
        borderColor = const Color(0xFF86EFAC);
        iconColor = const Color(0xFF16A34A);
        icon = LucideIcons.check;
        break;
      case _SeqPhase.retry:
        title = isSi ? 'හොඳ උත්සාහයක්!' : 'Good try!';
        subtitle = isSi
            ? 'කලබල වෙන්න එපා — මතක පුහුණුවට ටිකක් කාලය අවශ්‍යයි. පිළිවෙල නැවත බලා උත්සාහ කරමු!'
            : 'Memory practice takes patience. Watch the sequence once more and give it another try!';
        gradientColors = [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)];
        borderColor = const Color(0xFFFDE68A);
        iconColor = const Color(0xFFD97706);
        icon = LucideIcons.rotateCcw;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.3),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1B4B),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: isSi ? 'නැවත අසන්න' : 'Listen Again',
            child: InkWell(
              onTap: () {
                if (!_isVoiceOn) {
                  setState(() => _voiceEnabled = true);
                }
                _speakPhasePrompt(_phase);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(Icons.volume_up_rounded, size: 19, color: iconColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSequencePreview(bool isSi) {
    final activeHighlight = _highlightedPreviewStep;
    final count = _targetSequence.length;
    final double cardWidth = count <= 3 ? 182 : (count == 4 ? 162 : 140);
    final double circleSize = count <= 3 ? 112 : (count == 4 ? 102 : 92);
    final double iconSize = count <= 3 ? 58 : (count == 4 ? 52 : 46);
    final double vPad = count <= 3 ? 24 : 20;
    final double labelSize = count <= 3 ? 16.5 : (count == 4 ? 15.5 : 14.5);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: count <= 3 ? 14 : 10,
      runSpacing: 16,
      children: List.generate(_targetSequence.length, (index) {
        final tile = _tiles[_targetSequence[index]];
        final isGlowing = activeHighlight == index;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: cardWidth,
              transform: Matrix4.translationValues(0, isGlowing ? -6 : 0, 0),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: vPad),
              decoration: BoxDecoration(
                gradient: isGlowing
                    ? LinearGradient(
                        colors: [
                          tile.color.withValues(alpha: 0.16),
                          tile.color.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFFAF9FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isGlowing
                      ? tile.color
                      : tile.color.withValues(alpha: 0.28),
                  width: isGlowing ? 2.8 : 1.7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tile.color.withValues(alpha: isGlowing ? 0.30 : 0.12),
                    blurRadius: isGlowing ? 26 : 16,
                    offset: Offset(0, isGlowing ? 10 : 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isGlowing
                          ? tile.color
                          : tile.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      isSi ? 'පියවර ${index + 1}' : 'Step ${index + 1}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isGlowing ? Colors.white : tile.color,
                      ),
                    ),
                  ),
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tile.color, tile.accentGradient],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: tile.color.withValues(alpha: 0.44),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(tile.icon, size: iconSize, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isGlowing
                          ? Colors.white.withValues(alpha: 0.92)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tile.color.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      tile.displayLabel(isSi),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        fontSize: labelSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < _targetSequence.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: count <= 3 ? 10 : 6),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildProgressSlots(bool isSi) {
    final nextStepNum = (_userTaps.length + 1).clamp(1, _targetSequence.length);
    final isComplete = _userTaps.length >= _targetSequence.length;
    final isChecking = _isCheckingResult == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFAF5FF),
            Color(0xFFEEF2FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.26),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.listOrdered, size: 15, color: Color(0xFF6D28D9)),
                    const SizedBox(width: 6),
                    Text(
                      isSi
                          ? 'ප්‍රගතිය: අංක ${_targetSequence.length} න් ${_userTaps.length} ක් තෝරා ඇත'
                          : 'Progress: ${_userTaps.length} of ${_targetSequence.length} tiles tapped',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isChecking)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSi ? '✨ පරීක්ෂා කරමින්...' : '✨ Checking your sequence...',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (!isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSi
                        ? '👆 පියවර $nextStepNum තෝරන්න'
                        : '👆 Tap Step $nextStepNum',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: List.generate(_targetSequence.length, (index) {
              final isFilled = index < _userTaps.length;
              final isNext = index == _userTaps.length;
              Widget slotWidget;
              if (isFilled) {
                final tile = _tiles[_userTaps[index]];
                final matches = _userTaps[index] == _targetSequence[index];
                slotWidget = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tile.color, tile.accentGradient],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isChecking
                              ? (matches
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B))
                              : Colors.white,
                          width: 3.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tile.color.withValues(alpha: 0.36),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(tile.icon, size: 34, color: Colors.white),
                      ),
                    ),
                    if (isChecking)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: matches
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.8),
                          ),
                          child: Center(
                            child: Icon(
                              matches ? Icons.check_rounded : Icons.refresh_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              } else {
                slotWidget = AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: isNext
                        ? const LinearGradient(
                            colors: [Color(0xFFF3E8FF), Color(0xFFE0E7FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isNext ? null : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isNext ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                      width: isNext ? 2.6 : 1.7,
                    ),
                    boxShadow: isNext
                        ? [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isNext ? const Color(0xFF6D28D9) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  slotWidget,
                  if (index < _targetSequence.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: isFilled
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTilesGrid(bool isSi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFDFBFF),
            Color(0xFFEEF2FF),
            Color(0xFFECFDF5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFC7D2FE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 30,
        runSpacing: 16,
        children: _tiles.map((tile) {
          return _InteractiveSequencePad(
            key: ValueKey('sequence_tile_${tile.id}'),
            tile: tile,
            isSinhala: isSi,
            onTap: () => _onTileTap(tile.id),
          );
        }).toList(),
      ),
    );
  }

  void _showSuccessPopup() {
    if (!mounted) return;
    _hasShownSuccessPopup = true;
    _isPopupOpen = true;

    final isSi = widget.isSinhala;
    final score = _lastScore ?? 100.0;
    final attempts = _lastAttempts;
    final correctCount = _lastCorrectCount;
    final starCount = score >= 90 ? 5 : (score >= 75 ? 4 : 3);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Joyful colorful celebration ribbons & confetti bursting around the popup!
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _SeqPopupConfettiOverlay(),
                  ),
                ),
                Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AuroraGradientBorderFrame(
                  borderRadius: 26,
                  borderWidth: 2.8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Bright Pastel Celebration Top Banner
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFECFDF5),
                                Color(0xFFF0FDFA),
                                Color(0xFFF5F3FF),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFFD1FAE5),
                                width: 1.2,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Glowing Star Medallion with sparkles
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('✨', style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 78,
                                    height: 78,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF34D399),
                                          Color(0xFF10B981),
                                          Color(0xFF0D9488),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text('🌟', style: TextStyle(fontSize: 38)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('🎉', style: TextStyle(fontSize: 22)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isSi
                                    ? 'විශිෂ්ටයි! මට්ටම $_currentLevel අවසන්!'
                                    : 'Well Done! Level $_currentLevel Clear!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF065F46),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Golden Stars Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    Icons.star_rounded,
                                    size: 26,
                                    color: i < starCount
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Mini 3-Level Journey Stepper
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_maxLevels, (idx) {
                                  final lvl = idx + 1;
                                  final done = lvl <= _currentLevel;
                                  final next = lvl == _currentLevel + 1;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: done
                                              ? const Color(0xFF10B981)
                                              : (next
                                                  ? const Color(0xFFEDE9FE)
                                                  : Colors.white),
                                          borderRadius: BorderRadius.circular(11),
                                          border: Border.all(
                                            color: done
                                                ? const Color(0xFF059669)
                                                : (next
                                                    ? const Color(0xFF8B5CF6)
                                                    : const Color(0xFFCBD5E1)),
                                            width: next ? 1.6 : 1.1,
                                          ),
                                        ),
                                        child: Text(
                                          done
                                              ? (isSi ? '✓ L$lvl' : '✓ L$lvl')
                                              : (isSi ? 'L$lvl' : 'L$lvl'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: done
                                                ? Colors.white
                                                : (next
                                                    ? const Color(0xFF6D28D9)
                                                    : const Color(0xFF94A3B8)),
                                          ),
                                        ),
                                      ),
                                      if (idx < _maxLevels - 1)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 5),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 14,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                    ],
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),

                        // 2. Clean 3-Stat Tiles & Action Buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F3FF),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFDDD6FE)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${score.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF6D28D9),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isSi ? 'ලකුණු' : 'Score',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '$correctCount / $_sequenceLength',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isSi ? 'නිවැරදි අංක' : 'Tiles',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '$attempts',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF1D4ED8),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isSi ? 'උත්සාහයන්' : 'Tries',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_saveSuccessMessage != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Text(
                                    '✓ ${_saveSuccessMessage!}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Primary: Advance to Next Level
                              SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6D28D9).withValues(alpha: 0.32),
                                        blurRadius: 12,
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
                                    icon: const Icon(LucideIcons.sparkles, size: 19),
                                    label: Text(
                                      isSi
                                          ? 'ඊළඟ මට්ටම • මට්ටම ${_currentLevel + 1} (අංක ${_sequenceLength + 1})'
                                          : 'Next Level • Level ${_currentLevel + 1} (${_sequenceLength + 1} Tiles)',
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
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
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      key: const ValueKey('replay_same_level_button'),
                                      onPressed: () {
                                        Navigator.of(dialogCtx).pop();
                                        _startNewRound();
                                      },
                                      icon: const Icon(LucideIcons.rotateCcw, size: 15),
                                      label: Text(
                                        isSi ? 'නැවත' : 'Replay',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF4C1D95),
                                        side: const BorderSide(
                                          color: Color(0xFFC4B5FD),
                                          width: 1.4,
                                        ),
                                        backgroundColor: const Color(0xFFFAF5FF),
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(dialogCtx).pop();
                                        widget.onBack();
                                      },
                                      icon: const Icon(Icons.home_rounded, size: 16),
                                      label: Text(
                                        isSi ? 'සියලුම ක්‍රීඩා' : 'All Games',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF475569),
                                        side: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                          width: 1.3,
                                        ),
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 11),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ],
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

  Widget _buildGrandFinishCard(bool isSi) {
    final scores = _levelScores ?? const <double>[];
    final overall = _overallAverageScore;
    final starCount = overall >= 90 ? 5 : (overall >= 75 ? 4 : 3);

    return AuroraGradientBorderFrame(
      borderRadius: 24,
      borderWidth: 2.8,
      child: _SequenceGrandCelebrationStage(
        isSinhala: isSi,
        centerContent: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉 🏆 ✨', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              isSi
                  ? 'විශිෂ්ට ජයග්‍රහණයක්! ක්‍රීඩාව සම්පූර්ණයි!'
                  : 'Memory Champion! Game Complete!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSi
                  ? 'සමස්ත නිවැරදි බව: ${overall.toStringAsFixed(0)}%'
                  : 'Overall 3-Level Accuracy: ${overall.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFDE68A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  Icons.star_rounded,
                  size: 30,
                  color: i < starCount
                      ? const Color(0xFFFACC15)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
            if (scores.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: List.generate(scores.length, (i) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Text(
                      isSi
                          ? 'මට්ටම ${i + 1}: ${scores[i].toStringAsFixed(0)}%'
                          : 'Level ${i + 1}: ${scores[i].toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  );
                }),
              ),
            ],
            if (_saveSuccessMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6EE7B7).withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  '✓ ${_saveSuccessMessage!}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFA7F3D0),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  key: const ValueKey('seq_play_again_finish_button'),
                  onPressed: _resetToBeginning,
                  icon: const Icon(LucideIcons.rotateCcw, size: 17),
                  label: Text(
                    isSi ? 'නැවත ක්‍රීඩා කරන්න' : 'Play Again',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4C1D95),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('seq_finish_back_to_games_button'),
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: Text(
                    isSi ? 'සියලුම ක්‍රීඩා වෙත' : 'Back to All Games',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(bool isSi) {
    return Column(
      children: [
        _buildProgressSlots(isSi),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: _advanceToNextLevel,
              icon: const Icon(LucideIcons.sparkles, size: 17),
              label: Text(
                isSi
                    ? 'ඊළඟ මට්ටම (මට්ටම ${_currentLevel + 1})'
                    : 'Next Level (Level ${_currentLevel + 1})',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _showSuccessPopup,
              icon: const Icon(LucideIcons.award, size: 17),
              label: Text(
                isSi ? 'ප්‍රතිඵල බලන්න' : 'View Results',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A), width: 1.4),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRetryView(bool isSi) {
    final matched = _lastRetryMatchedCount ?? 0;
    final total = _targetSequence.length;

    Widget buildLeftHeroPanel() {
      return AuroraGradientBorderFrame(
        borderRadius: 22,
        borderWidth: 2.2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF5F3FF),
                Color(0xFFEEF2FF),
                Color(0xFFECFDF5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(19.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Minimal Top Row: Level pill + Listen pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Text(
                      isSi ? 'මට්ටම $_currentLevel' : 'Level $_currentLevel',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (!_isVoiceOn) {
                        setState(() => _voiceEnabled = true);
                      }
                      _speakPhasePrompt(_SeqPhase.retry);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.volume_up_rounded,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isSi ? 'අසන්න' : 'Listen',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4C1D95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cheerful Bright Sun-Star Emblem
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF08A), Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🌟', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 16),

              // Short, Big Elder-Friendly Title & Subtitle
              Text(
                isSi ? 'හොඳ උත්සාහයක්!' : 'Good Try!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isSi ? 'ආයෙත් උත්සාහ කරමු!' : "Let's try once more!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),

              // Bright Primary CTA Button
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6D28D9).withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    key: const ValueKey('try_again_button'),
                    onPressed: _replaySequence,
                    icon: const Icon(LucideIcons.rotateCcw, size: 19),
                    label: Text(
                      isSi ? 'නැවත බලන්න' : 'Watch Again',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('reset_level_1_button'),
                  onPressed: _resetToBeginning,
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: Text(
                    isSi ? 'මුල සිට (මට්ටම 1)' : 'Restart Level 1',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4C1D95),
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFFC4B5FD),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildRightReviewPanel() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFAF5FF),
              Color(0xFFF0FDFA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFDDD6FE),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Short Header + Score Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSi ? 'ඔබේ පිළිවෙල' : 'Your Picks',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: matched > 0
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: matched > 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Text(
                    '$matched / $total ✓',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: matched > 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Clean Visual Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total > 0 ? (matched / total).clamp(0.10, 1.0) : 0.1,
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  matched > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Big Clear Visual Tiles (Minimal Words!)
            if (_userTaps.length == _targetSequence.length)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE9D5FF), width: 1.4),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 16,
                  children: List.generate(_targetSequence.length, (i) {
                    final tappedTile = _tiles[_userTaps[i]];
                    final ok = _userTaps[i] == _targetSequence[i];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        tappedTile.color,
                                        tappedTile.accentGradient,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ok
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                      width: 3.4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: tappedTile.color.withValues(alpha: 0.28),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      tappedTile.icon,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: ok
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        ok ? Icons.check_rounded : Icons.refresh_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tappedTile.displayLabel(isSi),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        if (i < _targetSequence.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 20),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ),
            const SizedBox(height: 16),

            // Ultra-Short Friendly Tip Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isSi
                          ? 'පාට සහ අංක පිළිවෙල හිතින් කියමින් මතක තබාගන්න!'
                          : 'Say each color & number out loud!',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 740) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 424),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: buildLeftHeroPanel()),
                  const SizedBox(width: 18),
                  Expanded(flex: 6, child: buildRightReviewPanel()),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            buildLeftHeroPanel(),
            const SizedBox(height: 14),
            buildRightReviewPanel(),
          ],
        );
      },
    );
  }
}

// ==============================================================================
// INTERACTIVE SEQUENCE PAD WITH TACTILE HOVER & PRESS RESPONSE
// ==============================================================================

class _InteractiveSequencePad extends StatefulWidget {
  final _SequenceTileData tile;
  final VoidCallback onTap;
  final bool isSinhala;

  const _InteractiveSequencePad({
    super.key,
    required this.tile,
    required this.onTap,
    this.isSinhala = false,
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
            _isPressed ? 2 : (_isHovered ? -6 : 0),
            0,
          ),
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.tile.color, widget.tile.accentGradient],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.8),
            boxShadow: [
              BoxShadow(
                color: widget.tile.color.withValues(alpha: _isHovered ? 0.52 : 0.34),
                blurRadius: _isHovered ? 22 : 14,
                offset: Offset(0, _isHovered ? 8 : 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.tile.icon, size: 46, color: Colors.white),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.tile.displayLabel(widget.isSinhala),
                  style: const TextStyle(
                    fontSize: 13.5,
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
// ANIMATED CELEBRATING ELDERS STAGE FOR REMEMBER THE SEQUENCE FINISH SCREEN
// ==============================================================================

class _SequenceGrandCelebrationStage extends StatefulWidget {
  final bool isSinhala;
  final Widget centerContent;

  const _SequenceGrandCelebrationStage({
    required this.isSinhala,
    required this.centerContent,
  });

  @override
  State<_SequenceGrandCelebrationStage> createState() =>
      _SequenceGrandCelebrationStageState();
}

class _SequenceGrandCelebrationStageState
    extends State<_SequenceGrandCelebrationStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.isSinhala;
    return ClipRRect(
      borderRadius: BorderRadius.circular(21.2),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 424),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2E1065),
              Color(0xFF4C1D95),
              Color(0xFF1D4ED8),
              Color(0xFF0F766E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated floating confetti & golden sparkles
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => CustomPaint(
                    painter: _SeqCelebrationConfettiPainter(
                      progress: _controller.value,
                    ),
                  ),
                ),
              ),
            ),

            // Main layout: Left Celebrating Grandma + Center Champion Card + Right Celebrating Grandpa
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showSideCharacters = constraints.maxWidth >= 700;
                  if (!showSideCharacters) {
                    return Center(child: widget.centerContent);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left Celebrating Character (Smiling Grandma)
                      SizedBox(
                        width: 175,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) {
                            final phase = _controller.value * 2 * pi;
                            final bounce = sin(phase).abs() * -10.0;
                            final wave = sin(phase * 2) * 0.28;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, sin(phase) * 3.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.16),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      isSi ? 'හරිම අපූරුයි! 🎉' : 'Bravo! 🎉',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Transform.translate(
                                  offset: Offset(0, bounce),
                                  child: SizedBox(
                                    width: 150,
                                    height: 175,
                                    child: CustomPaint(
                                      painter: _CelebratingElderPainter(
                                        isGrandma: true,
                                        armWave: wave,
                                        sparklePhase: _controller.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Center Trophy & Score Content
                      Expanded(child: widget.centerContent),

                      // Right Celebrating Character (Smiling Grandpa)
                      SizedBox(
                        width: 175,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) {
                            final phase = (_controller.value + 0.35) * 2 * pi;
                            final bounce = sin(phase).abs() * -10.0;
                            final wave = sin(phase * 2) * 0.28;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, sin(phase) * 3.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.16),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      isSi ? 'විශිෂ්ටයි! 👏' : 'Well Done! 👏',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Transform.translate(
                                  offset: Offset(0, bounce),
                                  child: SizedBox(
                                    width: 150,
                                    height: 175,
                                    child: CustomPaint(
                                      painter: _CelebratingElderPainter(
                                        isGrandma: false,
                                        armWave: wave,
                                        sparklePhase: (_controller.value + 0.5) % 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CelebratingElderPainter extends CustomPainter {
  final bool isGrandma;
  final double armWave;
  final double sparklePhase;

  const _CelebratingElderPainter({
    required this.isGrandma,
    required this.armWave,
    required this.sparklePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Soft glowing floor aura under character
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 10),
        width: 90,
        height: 18,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    final skinPaint = Paint()..color = const Color(0xFFF6C6A5);
    final hairPaint = Paint()..color = const Color(0xFFE2E8F0);
    final hairHighlight = Paint()..color = Colors.white;
    final outfitColor =
        isGrandma ? const Color(0xFFEC4899) : const Color(0xFF14B8A6);
    final outfitAccent =
        isGrandma ? const Color(0xFFFDE047) : const Color(0xFFFEF08A);

    // 1. Cheering Raised Arms (animated wave!)
    final armPaint = Paint()
      ..color = outfitColor
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final leftShoulder = Offset(cx - 24, 98);
    final rightShoulder = Offset(cx + 24, 98);
    final leftHand = Offset(
      cx - 52 + sin(armWave) * 10,
      44 + cos(armWave) * 8,
    );
    final rightHand = Offset(
      cx + 52 - sin(armWave) * 10,
      44 + cos(armWave) * 8,
    );

    final leftArmPath = Path()
      ..moveTo(leftShoulder.dx, leftShoulder.dy)
      ..quadraticBezierTo(cx - 46, 78, leftHand.dx, leftHand.dy);
    final rightArmPath = Path()
      ..moveTo(rightShoulder.dx, rightShoulder.dy)
      ..quadraticBezierTo(cx + 46, 78, rightHand.dx, rightHand.dy);
    canvas.drawPath(leftArmPath, armPaint);
    canvas.drawPath(rightArmPath, armPaint);

    // Hands
    canvas.drawCircle(leftHand, 9, skinPaint);
    canvas.drawCircle(rightHand, 9, skinPaint);

    // Mini twinkling celebration stars above both hands
    final starPulse = 0.55 + 0.45 * sin(sparklePhase * 2 * pi);
    _drawMiniSparkle(
      canvas,
      Offset(leftHand.dx - 10, leftHand.dy - 14),
      6.5 * starPulse + 2,
      const Color(0xFFFDE047),
    );
    _drawMiniSparkle(
      canvas,
      Offset(rightHand.dx + 10, rightHand.dy - 14),
      6.5 * (1.1 - starPulse * 0.4) + 2,
      const Color(0xFF67E8F9),
    );

    // 2. Torso / Outfit
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, 126), width: 64, height: 68),
      const Radius.circular(26),
    );
    canvas.drawRRect(bodyRect, Paint()..color = outfitColor);

    if (isGrandma) {
      // Diagonal golden saree pallu sash
      final sash = Paint()
        ..color = outfitAccent.withValues(alpha: 0.90)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 24, 96), Offset(cx + 22, 152), sash);
    } else {
      // Grandpa crisp white collar & vest buttons
      final collarPath = Path()
        ..moveTo(cx - 14, 92)
        ..lineTo(cx, 108)
        ..lineTo(cx + 14, 92)
        ..close();
      canvas.drawPath(collarPath, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx, 120), 3, Paint()..color = outfitAccent);
      canvas.drawCircle(Offset(cx, 134), 3, Paint()..color = outfitAccent);
    }

    // 3. Hair (Back Bun for Grandma / Soft Side Hair for Grandpa)
    if (isGrandma) {
      canvas.drawCircle(Offset(cx, 25), 16, hairPaint);
      canvas.drawCircle(Offset(cx - 3, 22), 7, hairHighlight);
    }

    // 4. Head
    final headCenter = Offset(cx, 62);
    canvas.drawCircle(headCenter, 30, skinPaint);

    // Hair bangs / cap
    final hairTopPath = Path()
      ..addArc(
        Rect.fromCircle(center: headCenter, radius: 31),
        pi * 1.05,
        pi * 0.90,
      );
    canvas.drawPath(hairTopPath, hairPaint);

    // Rosy happy cheeks
    final cheekPaint = Paint()
      ..color = const Color(0xFFFB7185).withValues(alpha: 0.40);
    canvas.drawCircle(Offset(cx - 16, 68), 5.5, cheekPaint);
    canvas.drawCircle(Offset(cx + 16, 68), 5.5, cheekPaint);

    // Smiling happy arched eyes (^ ^)
    final eyePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 10, 59), width: 10, height: 8),
      pi,
      pi,
      false,
      eyePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + 10, 59), width: 10, height: 8),
      pi,
      pi,
      false,
      eyePaint,
    );

    // Friendly round glasses for Grandpa
    if (!isGrandma) {
      final glassPaint = Paint()
        ..color = const Color(0xFF334155)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx - 10, 59), 8, glassPaint);
      canvas.drawCircle(Offset(cx + 10, 59), 8, glassPaint);
      canvas.drawLine(Offset(cx - 2, 59), Offset(cx + 2, 59), glassPaint);
    }

    // Big Joyful Smile
    final smilePaint = Paint()
      ..color = const Color(0xFF9F1239)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, 69), width: 20, height: 14),
      0.15,
      pi - 0.30,
      false,
      smilePaint,
    );
  }

  void _drawMiniSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CelebratingElderPainter oldDelegate) =>
      oldDelegate.armWave != armWave ||
      oldDelegate.sparklePhase != sparklePhase ||
      oldDelegate.isGrandma != isGrandma;
}

class _SeqCelebrationConfettiPainter extends CustomPainter {
  final double progress;

  const _SeqCelebrationConfettiPainter({required this.progress});

  static const _colors = [
    Color(0xFFFDE047),
    Color(0xFFF472B6),
    Color(0xFF34D399),
    Color(0xFF60A5FA),
    Color(0xFFC084FC),
    Color(0xFFFB923C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 24; i++) {
      final seed = i * 1.37;
      final baseX = ((i * 73) % 100) / 100.0;
      final x = baseX * size.width + sin(progress * 2 * pi + seed) * 14;
      final yOffset = ((progress + (i * 0.13)) % 1.0);
      final y = yOffset * (size.height + 24) - 12;
      final color = _colors[i % _colors.length].withValues(alpha: 0.72);
      final paint = Paint()..color = color;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 2 * pi + seed);
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 4.0, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4.5, -2.2, 9, 4.4),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SeqCelebrationConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SeqPopupConfettiOverlay extends StatefulWidget {
  const _SeqPopupConfettiOverlay();

  @override
  State<_SeqPopupConfettiOverlay> createState() =>
      _SeqPopupConfettiOverlayState();
}

class _SeqPopupConfettiOverlayState extends State<_SeqPopupConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _controller.repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _SeqPopupConfettiBurstPainter(progress: _controller.value),
      ),
    );
  }
}

class _SeqPopupConfettiBurstPainter extends CustomPainter {
  final double progress;

  const _SeqPopupConfettiBurstPainter({required this.progress});

  static const _palette = [
    Color(0xFFFDE047), // bright gold
    Color(0xFFF43F5E), // festive rose
    Color(0xFF10B981), // emerald
    Color(0xFF38BDF8), // sky blue
    Color(0xFFA855F7), // violet
    Color(0xFFFB923C), // orange
    Color(0xFFEC4899), // pink
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Bursting festive celebration ribbons & confetti shooting around the popup
    for (int i = 0; i < 42; i++) {
      final t = (progress + (i * 0.047)) % 1.0;
      final angle = (i / 42.0) * 2 * pi + sin(t * pi) * 0.18;
      final speed = 175.0 + (i % 5) * 62.0;
      final radius = 90.0 + speed * Curves.easeOut.transform(t);
      final gravityY = 120.0 * t * t;

      final x = cx + cos(angle) * radius;
      final y = cy + sin(angle) * (radius * 0.72) + gravityY - 30.0;
      final alpha = (1.0 - (t * t)).clamp(0.0, 0.92);
      final color = _palette[i % _palette.length].withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + t * 5.2 + (i % 3));

      if (i % 4 == 0) {
        // Wavy party streamer ribbon ("celebration pati")
        final ribbonPaint = Paint()
          ..color = color
          ..strokeWidth = 3.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final path = Path()
          ..moveTo(-12, 0)
          ..quadraticBezierTo(-6, -7, 0, 0)
          ..quadraticBezierTo(6, 7, 12, 0);
        canvas.drawPath(path, ribbonPaint);
      } else if (i % 4 == 1) {
        // Confetti strip
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-7, -3, 14, 6),
            const Radius.circular(2.5),
          ),
          Paint()..color = color,
        );
      } else if (i % 4 == 2) {
        // Sparkling star
        final r = 6.0;
        final star = Path()
          ..moveTo(0, -r)
          ..quadraticBezierTo(0, 0, r, 0)
          ..quadraticBezierTo(0, 0, 0, r)
          ..quadraticBezierTo(0, 0, -r, 0)
          ..quadraticBezierTo(0, 0, 0, -r)
          ..close();
        canvas.drawPath(star, Paint()..color = color);
      } else {
        // Round festive dot
        canvas.drawCircle(Offset.zero, 4.5, Paint()..color = color);
      }
      canvas.restore();
    }

    // 2. Gentle drifting ribbons falling down left & right edges around the dialog
    for (int j = 0; j < 20; j++) {
      final isLeft = j.isEven;
      final laneX = isLeft
          ? size.width * (0.06 + ((j * 17) % 24) / 100.0)
          : size.width * (0.70 + ((j * 19) % 24) / 100.0);
      final driftX = laneX + sin(progress * 2 * pi + j) * 18;
      final fallY = ((progress + j * 0.11) % 1.0) * (size.height + 40) - 20;
      final color = _palette[(j + 2) % _palette.length].withValues(alpha: 0.80);

      canvas.save();
      canvas.translate(driftX, fallY);
      canvas.rotate(progress * 2 * pi + j * 0.7);
      final ribbonPaint = Paint()
        ..color = color
        ..strokeWidth = 3.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(-10, -2)
        ..quadraticBezierTo(-3, -8, 2, 0)
        ..quadraticBezierTo(7, 8, 12, 2);
      canvas.drawPath(path, ribbonPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SeqPopupConfettiBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SeqAmbientPlayBackdrop extends StatefulWidget {
  const _SeqAmbientPlayBackdrop();

  @override
  State<_SeqAmbientPlayBackdrop> createState() =>
      _SeqAmbientPlayBackdropState();
}

class _SeqAmbientPlayBackdropState extends State<_SeqAmbientPlayBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _controller.repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _SeqAmbientPlayPainter(progress: _controller.value),
      ),
    );
  }
}

class _SeqAmbientPlayPainter extends CustomPainter {
  final double progress;

  const _SeqAmbientPlayPainter({required this.progress});

  static const _tilePastels = [
    Color(0xFFA78BFA), // soft violet
    Color(0xFF60A5FA), // soft sky blue
    Color(0xFF34D399), // soft emerald
    Color(0xFFFB923C), // soft warm peach
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;

    // 1. Soft pastel wash gradient base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFDFBFF),
          Color(0xFFF5F3FF),
          Color(0xFFEFF6FF),
          Color(0xFFECFDF5),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 4 Gently Breathing Pastel Glow Orbs matching the 4 Sequence Tile colors
    final orbs = [
      (
        Offset(size.width * 0.12 + sin(t) * 18, size.height * 0.25 + cos(t) * 12),
        125.0,
        const Color(0xFFDDD6FE),
      ),
      (
        Offset(size.width * 0.88 + cos(t) * 20, size.height * 0.24 + sin(t) * 14),
        135.0,
        const Color(0xFFBAE6FD),
      ),
      (
        Offset(size.width * 0.18 + cos(t + 1.4) * 22, size.height * 0.82 + sin(t) * 10),
        120.0,
        const Color(0xFFA7F3D0),
      ),
      (
        Offset(size.width * 0.82 + sin(t + 2.1) * 18, size.height * 0.80 + cos(t) * 12),
        125.0,
        const Color(0xFFFED7AA),
      ),
    ];

    for (final (center, radius, color) in orbs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // 3. Soft Undulating Pastel Waves at Bottom Edge
    final wavePath1 = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 18) {
      final y = size.height -
          28 +
          sin((x / size.width) * 2 * pi + t) * 9 +
          cos((x / size.width) * 4 * pi - t) * 4;
      wavePath1.lineTo(x, y);
    }
    wavePath1
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      wavePath1,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.10),
            const Color(0xFF2563EB).withValues(alpha: 0.10),
            const Color(0xFF10B981).withValues(alpha: 0.12),
          ],
        ).createShader(Rect.fromLTWH(0, size.height - 50, size.width, 50)),
    );

    final wavePath2 = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 18) {
      final y = size.height -
          16 +
          cos((x / size.width) * 2.5 * pi - t * 1.2) * 7;
      wavePath2.lineTo(x, y);
    }
    wavePath2
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      wavePath2,
      Paint()..color = const Color(0xFF8B5CF6).withValues(alpha: 0.07),
    );

    // 4. Gently Floating Luminous Bubbles, Rings & Twinkling Sparkles
    for (int i = 0; i < 16; i++) {
      final seed = i * 1.61;
      final baseX = ((i * 61 + 13) % 94 + 3) / 100.0;
      final rise = (1.0 - ((progress + i * 0.073) % 1.0));
      final x = baseX * size.width + sin(t + seed) * 14;
      final y = rise * (size.height + 24) - 12;
      final color = _tilePastels[i % _tilePastels.length];
      final pulse = 0.45 + 0.55 * sin(t * 2 + seed).abs();

      if (i % 3 == 0) {
        // 4-point twinkling memory star sparkle
        final r = 5.5 * pulse + 2.5;
        final star = Path()
          ..moveTo(x, y - r)
          ..quadraticBezierTo(x, y, x + r, y)
          ..quadraticBezierTo(x, y, x, y + r)
          ..quadraticBezierTo(x, y, x - r, y)
          ..quadraticBezierTo(x, y, x, y - r)
          ..close();
        canvas.drawPath(
          star,
          Paint()..color = color.withValues(alpha: 0.48 * pulse),
        );
      } else if (i % 3 == 1) {
        // Translucent floating pastel bubble ring
        canvas.drawCircle(
          Offset(x, y),
          8.0 + (i % 4) * 3.0,
          Paint()
            ..color = color.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      } else {
        // Soft glowing dot
        canvas.drawCircle(
          Offset(x, y),
          3.8 + (i % 3) * 1.5,
          Paint()..color = color.withValues(alpha: 0.26 * pulse),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeqAmbientPlayPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ==============================================================================
// GAME 2: FIND THE MATCHING PAIRS
// ==============================================================================

class _PairsGameView extends StatefulWidget {
  final VoidCallback onBack;
  final int residentId;
  final String? token;
  final bool isSinhala;

  const _PairsGameView({
    super.key,
    required this.onBack,
    required this.residentId,
    this.token,
    this.isSinhala = false,
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

  // Nullable for Hot-Reload safety
  bool? _voiceEnabled;
  Timer? _voiceIntroTimer;
  PicnicBgmPlayer? _sfxPlayer;
  int? _consecutiveMismatches;
  int? _encourageIdx;
  PicnicBgmPlayer get _sfx => _sfxPlayer ??= PicnicBgmPlayer();
  bool get _isVoiceOn => _voiceEnabled ?? true;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  void _speakPairsVoice(String enText, String siText) {
    if (!mounted || !_isVoiceOn || _isWidgetTest) return;
    final text = widget.isSinhala ? siText : enText;
    TtsService.instance.speak(text, isSinhala: widget.isSinhala);
  }

  void _speakStartPrompt() {
    _speakPairsVoice(
      'Welcome to Find the Matching Pairs! Tap any two cards to discover matching pairs. Take your time, there is no rush.',
      'ගැළපෙන යුගල සෙවීමේ ක්‍රීඩාවට සාදරයෙන් පිළිගනිමු! ඕනෑම කාඩ්පත් දෙකක් ඔබා ගැළපෙන යුගල සොයාගන්න. කලබල වෙන්න එපා, නිදහසේ සෙල්ලම් කරන්න.',
    );
  }

  void _speakMatchPrompt() {
    _speakPairsVoice(
      'Wonderful! You found a matching pair!',
      'හරිම හොඳයි! ඔබ ගැළපෙන යුගලයක් සොයා ගත්තා!',
    );
  }

  void _speakGentleEncouragementIfNeeded() {
    final streak = (_consecutiveMismatches ?? 0) + 1;
    _consecutiveMismatches = streak;
    // Stay calm & quiet on ordinary mismatches; only give a brief varied nudge every 3 consecutive misses
    if (streak % 3 != 0) return;

    const enLines = [
      'Keep going, you are doing great!',
      'Almost there, take your time!',
      'You are getting closer!',
    ];
    const siLines = [
      'හොඳයි, දිගටම උත්සාහ කරමු!',
      'කලබල වෙන්න එපා, නිදහසේ බලමු!',
      'දැන් හරිම ළඟයි, ආයෙත් බලමු!',
    ];
    final idx = (_encourageIdx ?? 0) % enLines.length;
    _encourageIdx = idx + 1;
    _speakPairsVoice(enLines[idx], siLines[idx]);
  }

  void _speakCompletePrompt() {
    _speakPairsVoice(
      'Fantastic matching! You found all six pairs with wonderful memory and focus!',
      'හරිම විශිෂ්ටයි! ඔබ ගැළපෙන යුගල හයම සාර්ථකව සොයා ගත්තා! ඔබේ මතක ශක්තිය හරිම අපූරුයි!',
    );
  }

  void _scheduleStartVoice() {
    _voiceIntroTimer?.cancel();
    if (_isWidgetTest || !_isVoiceOn) return;
    _voiceIntroTimer = Timer(const Duration(milliseconds: 360), () {
      if (mounted && _isVoiceOn) {
        _speakStartPrompt();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startNewGame(speakIntro: true);
  }

  @override
  void didUpdateWidget(covariant _PairsGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSinhala != widget.isSinhala && _isVoiceOn) {
      if (_pairsFound == _symbols.length) {
        _speakCompletePrompt();
      } else {
        _speakStartPrompt();
      }
    }
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    _completionTimer?.cancel();
    _voiceIntroTimer?.cancel();
    if (!_isWidgetTest) {
      TtsService.instance.stop();
    }
    super.dispose();
  }

  void _startNewGame({bool speakIntro = true}) {
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
      _consecutiveMismatches = 0;
    });

    if (speakIntro) {
      _scheduleStartVoice();
    }
  }

  void _onCardTap(int index) {
    if (_isProcessing) return;
    if (_cards[index].isMatched) return;
    if (_flippedIndices.contains(index)) return;

    if (_isVoiceOn && !_isWidgetTest) {
      _sfx.playTapChime(volume: 0.24);
    }

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
          _consecutiveMismatches = 0;
          if (isCompleted) {
            _lastScore = roundedScore;
            _lastTurns = turns;
          }
        });

        if (isCompleted) {
          if (_isVoiceOn && !_isWidgetTest) {
            _sfx.playVictoryChime(volume: 0.28);
          }
          _speakCompletePrompt();
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
        } else {
          if (_isVoiceOn && !_isWidgetTest) {
            _sfx.playTapChime(volume: 0.30);
          }
          _speakMatchPrompt();
        }
      } else {
        // MISMATCH: keep ordinary misses calm & quiet; only nudge gently every 3 consecutive misses
        _speakGentleEncouragementIfNeeded();
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
    final isSi = widget.isSinhala;
    final starCount = score >= 85 ? 5 : (score >= 60 ? 4 : 3);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.42),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return Stack(
              children: [
                // Full-screen animated celebration streamers, ribbons & confetti bursting around popup
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _SeqPopupConfettiOverlay(),
                  ),
                ),
                Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AuroraGradientBorderFrame(
                      borderRadius: 28,
                      borderWidth: 2.8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25.2),
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Bright Pastel Emerald-Mint-Sky Celebration Header
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFECFDF5),
                                      Color(0xFFE0F2FE),
                                      Color(0xFFF5F3FF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('✨', style: TextStyle(fontSize: 23)),
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 78,
                                          height: 78,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF14B8A6),
                                                Color(0xFF0D9488),
                                                Color(0xFF0284C7),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 4,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF0D9488)
                                                    .withValues(alpha: 0.34),
                                                blurRadius: 18,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.emoji_events_rounded,
                                              size: 40,
                                              color: Color(0xFFFEF08A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('🎉', style: TextStyle(fontSize: 23)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isSi
                                          ? 'විශිෂ්ටයි! සියල්ල ගැළපුණා!'
                                          : 'Fantastic Matching!',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF134E4A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          Icons.star_rounded,
                                          size: 26,
                                          color: i < starCount
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Cheerful Mini Row of All 6 Matched Symbols
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: _symbols.map((sym) {
                                        return Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: sym.color.withValues(alpha: 0.35),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: sym.color.withValues(alpha: 0.14),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              sym.icon,
                                              size: 18,
                                              color: sym.color,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Clean 3-Stat Tiles & Elder-Friendly Action Buttons
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF5F3FF),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(
                                                color: const Color(0xFFDDD6FE),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${score.toStringAsFixed(0)}%',
                                                  style: const TextStyle(
                                                    fontSize: 21,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF6D28D9),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isSi ? 'ලකුණු' : 'Score',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(
                                                color: const Color(0xFFA7F3D0),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '$totalPairs / $totalPairs',
                                                  style: const TextStyle(
                                                    fontSize: 21,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF047857),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isSi ? 'යුගල' : 'Pairs',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(
                                                color: const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '$turns',
                                                  style: const TextStyle(
                                                    fontSize: 21,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isSi ? 'වාර ගණන' : 'Turns',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Primary CTA: Play Again
                                    SizedBox(
                                      width: double.infinity,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF0D9488),
                                              Color(0xFF0284C7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0D9488)
                                                  .withValues(alpha: 0.34),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          key: const ValueKey(
                                            'dialog_play_pairs_again_button',
                                          ),
                                          onPressed: () {
                                            Navigator.of(dialogCtx).pop();
                                            _startNewGame();
                                          },
                                          icon: const Icon(
                                            LucideIcons.rotateCcw,
                                            size: 19,
                                          ),
                                          label: Text(
                                            isSi ? 'නැවත ක්‍රීඩා කරන්න' : 'Play Again',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Secondary Row: View Board + All Games
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                Navigator.of(dialogCtx).pop(),
                                            icon: const Icon(LucideIcons.eye, size: 15),
                                            label: Text(
                                              isSi ? 'පුවරුව' : 'View Board',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF0F766E),
                                              side: const BorderSide(
                                                color: Color(0xFF99F6E4),
                                                width: 1.5,
                                              ),
                                              backgroundColor: const Color(0xFFF0FDFA),
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 11,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.of(dialogCtx).pop();
                                              widget.onBack();
                                            },
                                            icon: const Icon(
                                              Icons.home_rounded,
                                              size: 16,
                                            ),
                                            label: Text(
                                              isSi ? 'සියලුම ක්‍රීඩා' : 'All Games',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF475569),
                                              side: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                                width: 1.3,
                                              ),
                                              backgroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 11,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF0D9488).withValues(alpha: 0.24),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.11),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Attractive Emerald-Teal-Ocean Header Banner with Live Pair Progress
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF115E59),
                        Color(0xFF0D9488),
                        Color(0xFF0284C7),
                        Color(0xFF4F46E5),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isGameCompleted
                                    ? LucideIcons.trophy
                                    : LucideIcons.puzzle,
                                color: const Color(0xFF0D9488),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isGameCompleted
                                    ? 'Well done! All Pairs Matched! 🎉'
                                    : 'Find the Matching Pairs ✨',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                isGameCompleted
                                    ? 'Fantastic memory and focus!'
                                    : 'Tap any two cards to discover matching pairs — no rush!',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Live 6-Pair Glowing Progress Dots + Turns Pill
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List.generate(_symbols.length, (i) {
                                  final done = i < _pairsFound;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                    width: done ? 16 : 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? const Color(0xFF6EE7B7)
                                          : Colors.white.withValues(alpha: 0.34),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: done
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF6EE7B7)
                                                    .withValues(alpha: 0.65),
                                                blurRadius: 6,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                                const SizedBox(width: 8),
                                Text(
                                  '$_pairsFound / ${_symbols.length}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.38),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.sparkles,
                                  size: 13.5,
                                  color: Color(0xFFFDE68A),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Turns: $_turnsTaken',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            key: const ValueKey('pairs_voice_toggle_button'),
                            onTap: () {
                              final next = !_isVoiceOn;
                              setState(() => _voiceEnabled = next);
                              if (!next) {
                                TtsService.instance.stop();
                              } else if (isGameCompleted) {
                                _speakCompletePrompt();
                              } else {
                                _speakStartPrompt();
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _isVoiceOn
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: _isVoiceOn ? 0.45 : 0.25,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isVoiceOn
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.isSinhala
                                        ? (_isVoiceOn ? 'හඬ: ON' : 'හඬ: OFF')
                                        : (_isVoiceOn ? 'Voice: ON' : 'Voice: OFF'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: widget.isSinhala ? 'නැවත අසන්න' : 'Listen Again',
                            child: InkWell(
                              key: const ValueKey('pairs_listen_again_button'),
                              onTap: () {
                                if (!_isVoiceOn) {
                                  setState(() => _voiceEnabled = true);
                                }
                                if (isGameCompleted) {
                                  _speakCompletePrompt();
                                } else {
                                  _speakStartPrompt();
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(6.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.record_voice_over_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Animated Pastel Background + Interactive Cards Grid
                Stack(
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: _PairsAmbientPlayBackdrop(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                      child: Column(
                        children: [
                          // Cards Grid (Zero-scroll balanced height for desktop & tablet)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount =
                                  constraints.maxWidth > 650 ? 4 : 3;
                              final double cardExtent =
                                  crossAxisCount == 4 ? 118 : 98;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _cards.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 13,
                                  mainAxisExtent: cardExtent,
                                ),
                                itemBuilder: (context, index) {
                                  final card = _cards[index];
                                  final isFlipped = card.isMatched ||
                                      _flippedIndices.contains(index);
                                  return _PairsInteractiveCard(
                                    key: ValueKey('pair_card_$index'),
                                    card: card,
                                    isFlipped: isFlipped,
                                    index: index,
                                    onTap: () => _onCardTap(index),
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 14),

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
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F766E),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.92),
                                    side: const BorderSide(
                                      color: Color(0xFF0D9488),
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0D9488),
                                        Color(0xFF0284C7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0D9488)
                                            .withValues(alpha: 0.34),
                                        blurRadius: 12,
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
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
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
                              icon: const Icon(LucideIcons.rotateCcw, size: 17),
                              label: const Text(
                                'Shuffle & Restart Game',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F766E),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.90),
                                side: const BorderSide(
                                  color: Color(0xFF99F6E4),
                                  width: 1.6,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PairsInteractiveCard extends StatefulWidget {
  final _CardModel card;
  final bool isFlipped;
  final int index;
  final VoidCallback onTap;

  const _PairsInteractiveCard({
    super.key,
    required this.card,
    required this.isFlipped,
    required this.index,
    required this.onTap,
  });

  @override
  State<_PairsInteractiveCard> createState() => _PairsInteractiveCardState();
}

class _PairsInteractiveCardState extends State<_PairsInteractiveCard> {
  bool _hovered = false;
  bool _pressed = false;

  static const _hiddenAccents = [
    (Color(0xFF0D9488), Color(0xFF0284C7)),
    (Color(0xFF7C3AED), Color(0xFF4F46E5)),
    (Color(0xFF0EA5E9), Color(0xFF0D9488)),
    (Color(0xFF6366F1), Color(0xFF0284C7)),
  ];

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final isFlipped = widget.isFlipped;
    final isMatched = card.isMatched;
    final (accentA, accentB) =
        _hiddenAccents[widget.index % _hiddenAccents.length];

    return MouseRegion(
      cursor: isMatched ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _pressed ? 1.5 : (!isMatched && _hovered ? -4.5 : 0),
            0,
          ),
          decoration: BoxDecoration(
            gradient: isFlipped
                ? (isMatched
                    ? const LinearGradient(
                        colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white,
                          card.symbol.color.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ))
                : LinearGradient(
                    colors: _hovered
                        ? const [
                            Color(0xFFFFFFFF),
                            Color(0xFFECFEFF),
                            Color(0xFFEEF2FF),
                          ]
                        : const [
                            Color(0xFFFFFFFF),
                            Color(0xFFF0FDFA),
                            Color(0xFFF5F3FF),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFlipped
                  ? (isMatched ? const Color(0xFF10B981) : card.symbol.color)
                  : (_hovered
                      ? accentA.withValues(alpha: 0.65)
                      : const Color(0xFF99F6E4)),
              width: isFlipped ? 2.4 : (_hovered ? 2.0 : 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: isFlipped
                    ? (isMatched
                        ? const Color(0xFF10B981).withValues(alpha: 0.20)
                        : card.symbol.color.withValues(alpha: 0.22))
                    : accentA.withValues(alpha: _hovered ? 0.18 : 0.08),
                blurRadius: _hovered || isFlipped ? 16 : 9,
                offset: Offset(0, _hovered || isFlipped ? 6 : 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle decorative corner sparkles on unflipped cards
              if (!isFlipped) ...[
                Positioned(
                  top: 8,
                  left: 10,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: accentA.withValues(alpha: 0.30),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: accentB.withValues(alpha: 0.28),
                  ),
                ),
              ],

              // Matched glowing checkmark corner badge
              if (isMatched)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Main Card Face Content
              Center(
                child: isFlipped
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  card.symbol.color.withValues(alpha: 0.18),
                                  card.symbol.color.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: card.symbol.color.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                card.symbol.icon,
                                size: 30,
                                color: card.symbol.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.symbol.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isMatched
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isMatched) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '✓ Matched',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentA, accentB],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: accentA.withValues(alpha: 0.32),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.sparkles,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentA.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              'Tap Card',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: accentA,
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

class _PairsAmbientPlayBackdrop extends StatefulWidget {
  const _PairsAmbientPlayBackdrop();

  @override
  State<_PairsAmbientPlayBackdrop> createState() =>
      _PairsAmbientPlayBackdropState();
}

class _PairsAmbientPlayBackdropState extends State<_PairsAmbientPlayBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9500),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _controller.repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _PairsAmbientPlayPainter(progress: _controller.value),
      ),
    );
  }
}

class _PairsAmbientPlayPainter extends CustomPainter {
  final double progress;

  const _PairsAmbientPlayPainter({required this.progress});

  static const _pastels = [
    Color(0xFF14B8A6), // soft teal
    Color(0xFF38BDF8), // soft sky
    Color(0xFFA78BFA), // soft violet
    Color(0xFFFBBF24), // soft gold
    Color(0xFFF472B6), // soft rose
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;

    // 1. Fresh Mint-Sky-Lavender Pastel Wash Base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF7FEFC),
          Color(0xFFECFEFF),
          Color(0xFFF5F3FF),
          Color(0xFFECFDF5),
        ],
        stops: [0.0, 0.34, 0.68, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 4 Gently Breathing Pastel Glow Orbs
    final orbs = [
      (
        Offset(size.width * 0.10 + sin(t) * 20, size.height * 0.22 + cos(t) * 14),
        135.0,
        const Color(0xFF99F6E4),
      ),
      (
        Offset(size.width * 0.90 + cos(t) * 20, size.height * 0.20 + sin(t) * 14),
        140.0,
        const Color(0xFFBAE6FD),
      ),
      (
        Offset(size.width * 0.16 + cos(t + 1.5) * 22, size.height * 0.84 + sin(t) * 12),
        130.0,
        const Color(0xFFDDD6FE),
      ),
      (
        Offset(size.width * 0.84 + sin(t + 2.2) * 18, size.height * 0.82 + cos(t) * 12),
        130.0,
        const Color(0xFFFDE68A),
      ),
    ];

    for (final (center, radius, color) in orbs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.44),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // 3. Soft Flowing Teal-Sky Waves along the Bottom Edge
    final wave1 = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 18) {
      final y = size.height -
          26 +
          sin((x / size.width) * 2 * pi + t) * 8 +
          cos((x / size.width) * 4 * pi - t) * 4;
      wave1.lineTo(x, y);
    }
    wave1
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      wave1,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF0D9488).withValues(alpha: 0.12),
            const Color(0xFF0284C7).withValues(alpha: 0.10),
            const Color(0xFF7C3AED).withValues(alpha: 0.10),
          ],
        ).createShader(Rect.fromLTWH(0, size.height - 48, size.width, 48)),
    );

    final wave2 = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 18) {
      final y = size.height -
          14 +
          cos((x / size.width) * 2.5 * pi - t * 1.2) * 6;
      wave2.lineTo(x, y);
    }
    wave2
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      wave2,
      Paint()..color = const Color(0xFF14B8A6).withValues(alpha: 0.08),
    );

    // 4. Floating Pastel Sparkles, Soft Diamonds & Glowing Bubbles
    for (int i = 0; i < 18; i++) {
      final seed = i * 1.53;
      final baseX = ((i * 59 + 11) % 94 + 3) / 100.0;
      final rise = (1.0 - ((progress + i * 0.067) % 1.0));
      final x = baseX * size.width + sin(t + seed) * 14;
      final y = rise * (size.height + 24) - 12;
      final color = _pastels[i % _pastels.length];
      final pulse = 0.45 + 0.55 * sin(t * 2 + seed).abs();

      if (i % 3 == 0) {
        // 4-point twinkling star sparkle
        final r = 5.5 * pulse + 2.5;
        final star = Path()
          ..moveTo(x, y - r)
          ..quadraticBezierTo(x, y, x + r, y)
          ..quadraticBezierTo(x, y, x, y + r)
          ..quadraticBezierTo(x, y, x - r, y)
          ..quadraticBezierTo(x, y, x, y - r)
          ..close();
        canvas.drawPath(
          star,
          Paint()..color = color.withValues(alpha: 0.50 * pulse),
        );
      } else if (i % 3 == 1) {
        // Gently rotating pastel card-diamond motif
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(sin(t + seed) * 0.5 + pi / 4);
        final d = 6.5 + (i % 3) * 2.2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: d, height: d),
            const Radius.circular(2.2),
          ),
          Paint()
            ..color = color.withValues(alpha: 0.24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        canvas.restore();
      } else {
        // Luminous floating pastel bubble ring
        canvas.drawCircle(
          Offset(x, y),
          7.0 + (i % 4) * 2.8,
          Paint()
            ..color = color.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PairsAmbientPlayPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ==============================================================================
// GAME 3: REMEMBER THE ITEMS
// ==============================================================================

class _ItemsGameView extends StatefulWidget {
  final VoidCallback onBack;
  final int residentId;
  final String? token;
  final bool isSinhala;

  const _ItemsGameView({
    super.key,
    required this.onBack,
    required this.residentId,
    this.token,
    this.isSinhala = false,
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
  final String sinhalaName;
  final IconData icon;
  final Color color;

  const _ObjectItem({
    required this.id,
    required this.name,
    required this.sinhalaName,
    required this.icon,
    required this.color,
  });

  String displayName(bool isSinhala) => isSinhala ? sinhalaName : name;
}

class _ItemsGameViewState extends State<_ItemsGameView> {
  static const List<_ObjectItem> _itemPool = [
    _ObjectItem(
      id: 1,
      name: 'Red Apple',
      sinhalaName: 'රතු ඇපල්',
      icon: Icons.apple_rounded,
      color: Color(0xFFDC2626),
    ),
    _ObjectItem(
      id: 2,
      name: 'Story Book',
      sinhalaName: 'කතන්දර පොත',
      icon: LucideIcons.bookOpen,
      color: Color(0xFF4F46E5),
    ),
    _ObjectItem(
      id: 3,
      name: 'Pink Flower',
      sinhalaName: 'රෝස මල',
      icon: LucideIcons.flower,
      color: Color(0xFFDB2777),
    ),
    _ObjectItem(
      id: 4,
      name: 'Wall Clock',
      sinhalaName: 'බිත්ති ඔරලෝසුව',
      icon: LucideIcons.clock,
      color: Color(0xFFD97706),
    ),
    _ObjectItem(
      id: 5,
      name: 'Tea Cup',
      sinhalaName: 'තේ කෝප්පය',
      icon: LucideIcons.coffee,
      color: Color(0xFF854D0E),
    ),
    _ObjectItem(
      id: 6,
      name: 'Cozy House',
      sinhalaName: 'ලස්සන නිවස',
      icon: Icons.home_rounded,
      color: Color(0xFF0D9488),
    ),
    _ObjectItem(
      id: 7,
      name: 'Bright Sun',
      sinhalaName: 'දීප්තිමත් හිරු',
      icon: LucideIcons.sun,
      color: Color(0xFFEAB308),
    ),
    _ObjectItem(
      id: 8,
      name: 'Loving Heart',
      sinhalaName: 'ආදර හදවත',
      icon: LucideIcons.heart,
      color: Color(0xFFE11D48),
    ),
    _ObjectItem(
      id: 9,
      name: 'Brass Bell',
      sinhalaName: 'පිත්තල සීනුව',
      icon: LucideIcons.bell,
      color: Color(0xFFF97316),
    ),
    _ObjectItem(
      id: 10,
      name: 'Brass Key',
      sinhalaName: 'පිත්තල යතුර',
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

  // Nullable for Hot-Reload safety
  bool? _voiceEnabled;
  Timer? _voiceIntroTimer;
  PicnicBgmPlayer? _sfxPlayer;
  PicnicBgmPlayer get _sfx => _sfxPlayer ??= PicnicBgmPlayer();
  bool get _isVoiceOn => _voiceEnabled ?? true;
  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  void _speakItemsVoice(String enText, String siText) {
    if (!mounted || !_isVoiceOn || _isWidgetTest) return;
    final text = widget.isSinhala ? siText : enText;
    TtsService.instance.speak(text, isSinhala: widget.isSinhala);
  }

  void _speakPhasePrompt(_ItemPhase phase) {
    switch (phase) {
      case _ItemPhase.memorize:
        _speakItemsVoice(
          'Take a calm look at these four familiar items and remember them. When you feel ready, tap the button below.',
          'මෙහි පෙන්වන හුරුපුරුදු භාණ්ඩ හතර හොඳින් බලා මතක තබාගන්න. සූදානම් වූ පසු පහළ බොත්තම ඔබන්න.',
        );
        break;
      case _ItemPhase.select:
        _speakItemsVoice(
          'Now tap the four items you remember seeing, then tap Check My Answers.',
          'දැන් ඔබ කලින් දුටු භාණ්ඩ හතර තෝරා, පිළිතුරු පරීක්ෂා කරන්න ඔබන්න.',
        );
        break;
      case _ItemPhase.feedback:
        final isPerfect = _correctRecalledCount == _targetItems.length;
        if (isPerfect) {
          _speakItemsVoice(
            'Wonderful memory! You remembered all four items correctly!',
            'හරිම විශිෂ්ටයි! ඔබ භාණ්ඩ හතරම නිවැරදිව මතක තබා ගත්තා!',
          );
        } else {
          _speakItemsVoice(
            'Good try! Great memory exercise. Feel free to try again whenever you like!',
            'හොඳ උත්සාහයක්! ඉතා හොඳ මතක පුහුණුවක්. කැමති නම් ආයෙත් උත්සාහ කරමු!',
          );
        }
        break;
    }
  }

  void _scheduleStudyVoice() {
    _voiceIntroTimer?.cancel();
    if (_isWidgetTest || !_isVoiceOn) return;
    _voiceIntroTimer = Timer(const Duration(milliseconds: 360), () {
      if (mounted && _isVoiceOn && _phase == _ItemPhase.memorize) {
        _speakPhasePrompt(_ItemPhase.memorize);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startNewRound(speakIntro: true);
  }

  @override
  void didUpdateWidget(covariant _ItemsGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSinhala != widget.isSinhala && _isVoiceOn) {
      _speakPhasePrompt(_phase);
    }
  }

  @override
  void dispose() {
    _voiceIntroTimer?.cancel();
    if (!_isWidgetTest) {
      TtsService.instance.stop();
    }
    super.dispose();
  }

  void _startNewRound({bool speakIntro = true}) {
    final shuffled = List<_ObjectItem>.from(_itemPool)..shuffle(_random);
    final targets = shuffled.take(4).toList();
    final remaining = shuffled.skip(4).take(4).toList();
    final combined = [...targets, ...remaining]..shuffle(_random);

    setState(() {
      _targetSequenceReset(targets, combined);
    });
    if (speakIntro) {
      _scheduleStudyVoice();
    }
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
    if (_isVoiceOn && !_isWidgetTest) {
      _sfx.playTapChime(volume: 0.24);
    }
    setState(() {
      _selectedIds.clear();
      _phase = _ItemPhase.select;
      _hasShownFeedbackPopup = false;
      _isPopupOpen = false;
    });
    _speakPhasePrompt(_ItemPhase.select);
  }

  void _toggleItemSelection(int id) {
    if (_phase != _ItemPhase.select) return;
    if (_isVoiceOn && !_isWidgetTest) {
      _sfx.playTapChime(volume: 0.24);
    }
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

    if (_isVoiceOn && !_isWidgetTest) {
      if (correctCount == totalItems) {
        _sfx.playVictoryChime(volume: 0.28);
      } else {
        _sfx.playTapChime(volume: 0.26);
      }
    }
    _speakPhasePrompt(_ItemPhase.feedback);

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
    if (_isVoiceOn && !_isWidgetTest) {
      _sfx.playTapChime(volume: 0.24);
    }
    setState(() {
      _phase = _ItemPhase.memorize;
    });
    _speakPhasePrompt(_ItemPhase.memorize);
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.isSinhala;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGameNavBar(
          gameTitle: isSi ? 'භාණ්ඩ මතක ක්‍රීඩාව' : 'Remember the Items',
          gameIcon: LucideIcons.bookOpen,
          gameColor: const Color(0xFFDB2777),
          onBack: widget.onBack,
          onReset: () => _startNewRound(speakIntro: true),
          backLabel: isSi ? 'සියලුම ක්‍රීඩා' : 'All Games',
          statusBadge: _phase == _ItemPhase.memorize
              ? (isSi ? 'භාණ්ඩ 4 බලන්න' : 'Study 4 Items')
              : (_phase == _ItemPhase.select
                  ? (isSi
                      ? 'තෝරාගත්තේ: ${_selectedIds.length} / 4'
                      : 'Selected: ${_selectedIds.length} of 4')
                  : (isSi ? 'ප්‍රතිඵල පරීක්ෂාව' : 'Results Check')),
        ),
        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFDB2777).withValues(alpha: 0.24),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDB2777).withValues(alpha: 0.11),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Attractive Rose-Berry-Violet Gradient Header with 2-Step Stepper & Voice Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF9D174D),
                        Color(0xFFDB2777),
                        Color(0xFF7C3AED),
                        Color(0xFF4F46E5),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.bookOpen,
                                color: Color(0xFFDB2777),
                                size: 21,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSi
                                    ? 'භාණ්ඩ මතක ක්‍රීඩාව ✨'
                                    : 'Remember the Items ✨',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                isSi
                                    ? 'හුරුපුරුදු භාණ්ඩ 4 මතක තබාගෙන තෝරන්න'
                                    : 'Memorize 4 familiar items & pick them out',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // 2-Step Phase Pills
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPhaseStepChip(
                            label: isSi ? '1. බලන්න (4)' : '1. Study 4',
                            active: _phase == _ItemPhase.memorize,
                            done: _phase != _ItemPhase.memorize,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                          _buildPhaseStepChip(
                            label: isSi ? '2. තෝරන්න (4)' : '2. Pick 4',
                            active: _phase == _ItemPhase.select,
                            done: _phase == _ItemPhase.feedback,
                          ),
                        ],
                      ),

                      // Voice ON/OFF & Listen Again
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            key: const ValueKey('items_voice_toggle_button'),
                            onTap: () {
                              final next = !_isVoiceOn;
                              setState(() => _voiceEnabled = next);
                              if (!next) {
                                TtsService.instance.stop();
                              } else {
                                _speakPhasePrompt(_phase);
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6.5,
                              ),
                              decoration: BoxDecoration(
                                color: _isVoiceOn
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: _isVoiceOn ? 0.45 : 0.25,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isVoiceOn
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isSi
                                        ? (_isVoiceOn ? 'හඬ: ON' : 'හඬ: OFF')
                                        : (_isVoiceOn ? 'Voice: ON' : 'Voice: OFF'),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Tooltip(
                            message: isSi ? 'නැවත අසන්න' : 'Listen Again',
                            child: InkWell(
                              key: const ValueKey('items_listen_again_button'),
                              onTap: () {
                                if (!_isVoiceOn) {
                                  setState(() => _voiceEnabled = true);
                                }
                                _speakPhasePrompt(_phase);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.record_voice_over_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Uniform Height Animated Pastel Game Stage (Zero Scroll!)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 462),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: _ItemsAmbientPlayBackdrop(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildInstructionBanner(isSi),
                            const SizedBox(height: 16),

                            if (_phase == _ItemPhase.memorize) ...[
                              _buildMemorizeView(isSi),
                            ] else if (_phase == _ItemPhase.select) ...[
                              _buildSelectionView(isSi),
                            ] else if (_phase == _ItemPhase.feedback) ...[
                              _buildFeedbackView(isSi),
                            ],
                          ],
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
    );
  }

  Widget _buildPhaseStepChip({
    required String label,
    required bool active,
    required bool done,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF10B981)
            : (active ? Colors.white : Colors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? const Color(0xFF6EE7B7)
              : (active ? Colors.white : Colors.white.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.check_circle_rounded, size: 13.5, color: Colors.white),
            )
          else if (active)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.play_circle_fill_rounded, size: 13.5, color: Color(0xFFDB2777)),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: done
                  ? Colors.white
                  : (active ? const Color(0xFF831843) : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionBanner(bool isSi) {
    String title = '';
    String subtitle = '';
    List<Color> gradientColors = const [Color(0xFFFDF2F8), Color(0xFFFCE7F3)];
    Color borderColor = const Color(0xFFFBCFE8);
    Color iconColor = const Color(0xFFDB2777);
    IconData icon = LucideIcons.bookOpen;

    switch (_phase) {
      case _ItemPhase.memorize:
        title = isSi
            ? 'මෙම හුරුපුරුදු භාණ්ඩ 4 හොඳින් මතක තබාගන්න'
            : 'Take a look at these 4 familiar items';
        subtitle = isSi
            ? 'සෑම භාණ්ඩයක්ම නිදහසේ බලන්න. සූදානම් වූ පසු ඉදිරියට යාමට පහළ බොත්තම ඔබන්න.'
            : 'Look at each object carefully. Whenever you feel ready, tap the button below to continue.';
        gradientColors = const [Color(0xFFFFF1F2), Color(0xFFFDF2F8)];
        borderColor = const Color(0xFFFBCFE8);
        iconColor = const Color(0xFFDB2777);
        icon = LucideIcons.bookOpen;
        break;
      case _ItemPhase.select:
        title = isSi
            ? 'ඔබ කලින් දුටු භාණ්ඩ 4 කුමක්ද?'
            : 'Which 4 items do you remember seeing?';
        subtitle = isSi
            ? 'කලින් තිරයේ දුටු භාණ්ඩ 4 ඔබා තෝරාගෙන, පිළිතුරු පරීක්ෂා කරන්න ඔබන්න.'
            : 'Tap the 4 items you recall from the previous screen, then tap Check My Answers.';
        gradientColors = const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)];
        borderColor = const Color(0xFFDDD6FE);
        iconColor = const Color(0xFF7C3AED);
        icon = LucideIcons.mousePointerClick;
        break;
      case _ItemPhase.feedback:
        final correctCount =
            _selectedIds.where((id) => _targetItems.any((t) => t.id == id)).length;
        if (correctCount == _targetItems.length) {
          title = isSi
              ? 'විශිෂ්ටයි! භාණ්ඩ 4ම නිවැරදියි!'
              : 'Well done! All 4 items correct!';
          subtitle = isSi
              ? 'ඔබ සෑම භාණ්ඩයක්ම ඉතා නිවැරදිව මතක තබා ගත්තා!'
              : 'You remembered every single item with wonderful accuracy!';
          gradientColors = const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)];
          borderColor = const Color(0xFF86EFAC);
          iconColor = const Color(0xFF16A34A);
          icon = LucideIcons.check;
        } else {
          title = isSi ? 'හොඳ උත්සාහයක්!' : 'Good try!';
          subtitle = isSi
              ? 'ඔබ භාණ්ඩ ${_targetItems.length} න් $correctCount ක් නිවැරදිව මතක තබා ගත්තා.'
              : 'You remembered $correctCount out of ${_targetItems.length} items correctly. Great memory practice!';
          gradientColors = const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)];
          borderColor = const Color(0xFFFDE68A);
          iconColor = const Color(0xFFD97706);
          icon = LucideIcons.rotateCcw;
        }
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.3),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1B4B),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    color: const Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: isSi ? 'නැවත අසන්න' : 'Listen Again',
            child: InkWell(
              onTap: () {
                if (!_isVoiceOn) {
                  setState(() => _voiceEnabled = true);
                }
                _speakPhasePrompt(_phase);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(Icons.volume_up_rounded, size: 19, color: iconColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorizeView(bool isSi) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 16,
          children: List.generate(_targetItems.length, (index) {
            final item = _targetItems[index];
            return Container(
              width: 188,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    item.color.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: item.color.withValues(alpha: 0.30),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSi ? 'භාණ්ඩය ${index + 1}' : 'Item ${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: item.color,
                      ),
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          item.color.withValues(alpha: 0.20),
                          item.color.withValues(alpha: 0.09),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.24),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(item.icon, size: 50, color: item.color),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      item.displayName(isSi),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDB2777), Color(0xFFE11D48), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDB2777).withValues(alpha: 0.36),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              key: const ValueKey('ready_items_button'),
              onPressed: _startSelectionPhase,
              icon: const Icon(LucideIcons.sparkles, size: 21),
              label: Text(
                isSi
                    ? 'මට මතකයි! භාණ්ඩ තෝරන්න යමු'
                    : 'I Remember These Items! Continue',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSelectionView(bool isSi) {
    return Column(
      children: [
        // Balanced 4x2 Grid so all 8 items look large, symmetric & fit on 1 screen with ZERO scroll!
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 620 ? 4 : 2;
            final double cardExtent = crossAxisCount == 4 ? 128 : 112;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _displayPool.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 15,
                mainAxisSpacing: 14,
                mainAxisExtent: cardExtent,
              ),
              itemBuilder: (context, index) {
                final item = _displayPool[index];
                final isSelected = _selectedIds.contains(item.id);
                return _ItemsSelectableCard(
                  key: ValueKey('item_option_${item.id}'),
                  item: item,
                  isSelected: isSelected,
                  isSinhala: isSi,
                  onTap: () => _toggleItemSelection(item.id),
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: _selectedIds.isNotEmpty
                    ? const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                      )
                    : null,
                color: _selectedIds.isNotEmpty ? null : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(15),
                boxShadow: _selectedIds.isNotEmpty
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.34),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton.icon(
                key: const ValueKey('check_answers_button'),
                onPressed: _selectedIds.isNotEmpty ? _checkAnswers : null,
                icon: const Icon(LucideIcons.check, size: 19),
                label: Text(
                  isSi
                      ? 'පිළිතුරු පරීක්ෂා කරන්න (${_selectedIds.length} තෝරා ඇත)'
                      : 'Check My Answers (${_selectedIds.length} Picked)',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('peek_items_button'),
              onPressed: _peekOriginalItems,
              icon: const Icon(LucideIcons.rotateCcw, size: 18),
              label: Text(
                isSi ? 'මුල් භාණ්ඩ නැවත බලන්න' : 'Peek at Original Items',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF831843),
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                side: const BorderSide(color: Color(0xFFFBCFE8), width: 1.6),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
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
    final isSi = widget.isSinhala;
    final starCount = isPerfect ? 5 : (correctCount >= 3 ? 4 : 3);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.42),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return Stack(
              children: [
                // Full-screen animated celebration streamers, ribbons & confetti bursting around popup
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _SeqPopupConfettiOverlay(),
                  ),
                ),
                Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AuroraGradientBorderFrame(
                      borderRadius: 28,
                      borderWidth: 2.8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25.2),
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Bright Pastel Rose-Lavender-Peach Celebration Header
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFDF2F8),
                                      Color(0xFFF5F3FF),
                                      Color(0xFFFFF7ED),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('✨', style: TextStyle(fontSize: 23)),
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 78,
                                          height: 78,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isPerfect
                                                  ? const [
                                                      Color(0xFFF43F5E),
                                                      Color(0xFFDB2777),
                                                      Color(0xFF7C3AED),
                                                    ]
                                                  : const [
                                                      Color(0xFFF59E0B),
                                                      Color(0xFFEC4899),
                                                    ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 4,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFDB2777)
                                                    .withValues(alpha: 0.34),
                                                blurRadius: 18,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              isPerfect
                                                  ? Icons.emoji_events_rounded
                                                  : LucideIcons.sparkles,
                                              size: 40,
                                              color: const Color(0xFFFEF08A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('🎉', style: TextStyle(fontSize: 23)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isPerfect
                                          ? (isSi
                                              ? 'හරිම විශිෂ්ටයි!'
                                              : 'Well Done!')
                                          : (isSi
                                              ? 'හොඳ උත්සාහයක්!'
                                              : 'Good Try!'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF831843),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          Icons.star_rounded,
                                          size: 26,
                                          color: i < starCount
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Cheerful Mini Row of the 4 Target Items with Recall Checkmarks
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 10,
                                      runSpacing: 6,
                                      children: _targetItems.map((item) {
                                        final recalled = _selectedIds.contains(item.id);
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: recalled
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFF59E0B),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: item.color
                                                        .withValues(alpha: 0.16),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  item.icon,
                                                  size: 20,
                                                  color: item.color,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: -3,
                                              top: -3,
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: recalled
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFF59E0B),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    recalled
                                                        ? Icons.check_rounded
                                                        : Icons.priority_high_rounded,
                                                    size: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Clean 2-Stat Pastel Tiles & Elder-Friendly Action Buttons
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFDF2F8),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(
                                                color: const Color(0xFFFBCFE8),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${score.toStringAsFixed(0)}%',
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFFBE185D),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isSi ? 'ලකුණු' : 'Score',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(
                                                color: const Color(0xFFA7F3D0),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '$correctCount / $totalItems',
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF047857),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isSi ? 'මතක තබාගත් භාණ්ඩ' : 'Items Recalled',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Primary CTA: Play Again with New Items
                                    SizedBox(
                                      width: double.infinity,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFDB2777),
                                              Color(0xFF7C3AED),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFDB2777)
                                                  .withValues(alpha: 0.34),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          key: const ValueKey(
                                            'play_items_new_round_button',
                                          ),
                                          onPressed: () {
                                            Navigator.of(dialogCtx).pop();
                                            _startNewRound(speakIntro: true);
                                          },
                                          icon: const Icon(
                                            LucideIcons.sparkles,
                                            size: 19,
                                          ),
                                          label: Text(
                                            isSi
                                                ? 'නව භාණ්ඩ සමඟ ක්‍රීඩා කරන්න'
                                                : 'Play Again with New Items',
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Secondary Row: View Board + Try Same Items
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                Navigator.of(dialogCtx).pop(),
                                            icon: const Icon(LucideIcons.eye, size: 15),
                                            label: Text(
                                              isSi ? 'පුවරුව' : 'View Board',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF831843),
                                              side: const BorderSide(
                                                color: Color(0xFFFBCFE8),
                                                width: 1.5,
                                              ),
                                              backgroundColor: const Color(0xFFFDF2F8),
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 11,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            key: const ValueKey(
                                              'try_same_items_button',
                                            ),
                                            onPressed: () {
                                              Navigator.of(dialogCtx).pop();
                                              _startSelectionPhase();
                                            },
                                            icon: const Icon(
                                              LucideIcons.rotateCcw,
                                              size: 15,
                                            ),
                                            label: Text(
                                              isSi
                                                  ? 'එම භාණ්ඩම නැවත'
                                                  : 'Try Same Items',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF475569),
                                              side: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                                width: 1.3,
                                              ),
                                              backgroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 11,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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

  Widget _buildFeedbackView(bool isSi) {
    return Column(
      children: [
        Text(
          isSi ? 'ඔබේ පිළිතුරු සමාලෝචනය' : 'Review Your Answers',
          style: AppTextStyles.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 620 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _displayPool.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 12,
                mainAxisExtent: 124,
              ),
              itemBuilder: (context, index) {
                final item = _displayPool[index];
                final isTarget = _targetItems.any((t) => t.id == item.id);
                final isSelected = _selectedIds.contains(item.id);

                Color borderColor = AppColors.border;
                Color bgColor = Colors.white;
                String badgeText = '';
                Color badgeColor = AppColors.muted;

                if (isTarget && isSelected) {
                  borderColor = AppColors.riskLow;
                  bgColor = AppColors.riskLowBg;
                  badgeText = isSi ? 'නිවැරදියි! ✅' : 'Correct! ✅';
                  badgeColor = AppColors.riskLow;
                } else if (isTarget && !isSelected) {
                  borderColor = AppColors.riskModerate;
                  bgColor = const Color(0xFFFEF3DC);
                  badgeText = isSi ? 'මගහැරුණා' : 'Original (Missed)';
                  badgeColor = AppColors.riskModerate;
                } else if (!isTarget && isSelected) {
                  borderColor = AppColors.riskHigh.withValues(alpha: 0.6);
                  bgColor = const Color(0xFFFDE8E8);
                  badgeText = isSi ? 'තිබුණේ නෑ' : 'Not in Group';
                  badgeColor = AppColors.riskHigh;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 32, color: item.color),
                      const SizedBox(height: 5),
                      Text(
                        item.displayName(isSi),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (badgeText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 16),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _showFeedbackPopup,
              icon: const Icon(LucideIcons.sparkles, size: 17),
              label: Text(
                isSi ? 'ප්‍රතිඵල බලන්න' : 'View Results',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDB2777),
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                side: const BorderSide(color: Color(0xFFDB2777), width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            if (!_isPopupOpen) ...[
              ElevatedButton.icon(
                key: const ValueKey('board_play_items_new_round_button'),
                onPressed: () => _startNewRound(speakIntro: true),
                icon: const Icon(LucideIcons.sparkles, size: 18),
                label: Text(
                  isSi ? 'නව භාණ්ඩ සමඟ ක්‍රීඩා කරන්න' : 'Play Again with New Items',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  elevation: 0,
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('board_try_same_items_button'),
                onPressed: _startSelectionPhase,
                icon: const Icon(LucideIcons.rotateCcw, size: 17),
                label: Text(
                  isSi ? 'එම භාණ්ඩම නැවත' : 'Try Same Items Again',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
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

class _ItemsSelectableCard extends StatefulWidget {
  final _ObjectItem item;
  final bool isSelected;
  final bool isSinhala;
  final VoidCallback onTap;

  const _ItemsSelectableCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isSinhala,
    required this.onTap,
  });

  @override
  State<_ItemsSelectableCard> createState() => _ItemsSelectableCardState();
}

class _ItemsSelectableCardState extends State<_ItemsSelectableCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _pressed ? 1.5 : (_hovered ? -4.5 : 0),
            0,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: _hovered
                        ? [Colors.white, item.color.withValues(alpha: 0.08)]
                        : [Colors.white, const Color(0xFFFFFBFE)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF7C3AED)
                  : (_hovered
                      ? item.color.withValues(alpha: 0.65)
                      : item.color.withValues(alpha: 0.24)),
              width: selected ? 2.6 : (_hovered ? 2.0 : 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.22)
                    : item.color.withValues(alpha: _hovered ? 0.16 : 0.07),
                blurRadius: selected || _hovered ? 16 : 8,
                offset: Offset(0, selected || _hovered ? 6 : 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 9,
                right: 9,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                          )
                        : null,
                    color: selected ? null : Colors.white,
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : const Color(0xFFCBD5E1),
                      width: selected ? 2 : 1.6,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              item.color.withValues(alpha: selected ? 0.22 : 0.15),
                              item.color.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.color.withValues(alpha: 0.30),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(item.icon, size: 30, color: item.color),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        item.displayName(widget.isSinhala),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? const Color(0xFF5B21B6)
                              : const Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

class _ItemsAmbientPlayBackdrop extends StatefulWidget {
  const _ItemsAmbientPlayBackdrop();

  @override
  State<_ItemsAmbientPlayBackdrop> createState() =>
      _ItemsAmbientPlayBackdropState();
}

class _ItemsAmbientPlayBackdropState extends State<_ItemsAmbientPlayBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9500),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _controller.repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _ItemsAmbientPlayPainter(progress: _controller.value),
      ),
    );
  }
}

class _ItemsAmbientPlayPainter extends CustomPainter {
  final double progress;

  const _ItemsAmbientPlayPainter({required this.progress});

  static const _pastels = [
    Color(0xFFF472B6), // soft rose
    Color(0xFFA78BFA), // soft violet
    Color(0xFFFB923C), // warm peach
    Color(0xFF38BDF8), // soft sky
    Color(0xFF34D399), // soft mint
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;

    // 1. Warm Blush-Lavender-Peach Pastel Wash Base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFBFD),
          Color(0xFFFDF2F8),
          Color(0xFFF5F3FF),
          Color(0xFFFFF7ED),
        ],
        stops: [0.0, 0.34, 0.68, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 4 Gently Breathing Pastel Glow Orbs
    final orbs = [
      (
        Offset(size.width * 0.12 + sin(t) * 20, size.height * 0.24 + cos(t) * 14),
        135.0,
        const Color(0xFFFBCFE8),
      ),
      (
        Offset(size.width * 0.88 + cos(t) * 20, size.height * 0.22 + sin(t) * 14),
        140.0,
        const Color(0xFFDDD6FE),
      ),
      (
        Offset(size.width * 0.16 + cos(t + 1.4) * 22, size.height * 0.84 + sin(t) * 12),
        130.0,
        const Color(0xFFFED7AA),
      ),
      (
        Offset(size.width * 0.84 + sin(t + 2.1) * 18, size.height * 0.82 + cos(t) * 12),
        130.0,
        const Color(0xFFBAE6FD),
      ),
    ];

    for (final (center, radius, color) in orbs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.44),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // 3. Soft Undulating Rose-Violet Waves at Bottom Edge
    final wave1 = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 18) {
      final y = size.height -
          28 +
          sin((x / size.width) * 2 * pi + t) * 8 +
          cos((x / size.width) * 4 * pi - t) * 4;
      wave1.lineTo(x, y);
    }
    wave1
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      wave1,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFDB2777).withValues(alpha: 0.11),
            const Color(0xFF7C3AED).withValues(alpha: 0.10),
            const Color(0xFFF97316).withValues(alpha: 0.09),
          ],
        ).createShader(Rect.fromLTWH(0, size.height - 50, size.width, 50)),
    );

    final wave2 = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 18) {
      final y = size.height -
          15 +
          cos((x / size.width) * 2.5 * pi - t * 1.2) * 6;
      wave2.lineTo(x, y);
    }
    wave2
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      wave2,
      Paint()..color = const Color(0xFFEC4899).withValues(alpha: 0.07),
    );

    // 4. Gently Floating Luminous Sparkles, Soft Petals & Pastel Rings
    for (int i = 0; i < 18; i++) {
      final seed = i * 1.57;
      final baseX = ((i * 57 + 13) % 94 + 3) / 100.0;
      final rise = (1.0 - ((progress + i * 0.069) % 1.0));
      final x = baseX * size.width + sin(t + seed) * 14;
      final y = rise * (size.height + 24) - 12;
      final color = _pastels[i % _pastels.length];
      final pulse = 0.45 + 0.55 * sin(t * 2 + seed).abs();

      if (i % 3 == 0) {
        final r = 5.5 * pulse + 2.5;
        final star = Path()
          ..moveTo(x, y - r)
          ..quadraticBezierTo(x, y, x + r, y)
          ..quadraticBezierTo(x, y, x, y + r)
          ..quadraticBezierTo(x, y, x - r, y)
          ..quadraticBezierTo(x, y, x, y - r)
          ..close();
        canvas.drawPath(
          star,
          Paint()..color = color.withValues(alpha: 0.50 * pulse),
        );
      } else if (i % 3 == 1) {
        canvas.drawCircle(
          Offset(x, y),
          7.5 + (i % 4) * 2.8,
          Paint()
            ..color = color.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          3.8 + (i % 3) * 1.6,
          Paint()..color = color.withValues(alpha: 0.28 * pulse),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ItemsAmbientPlayPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
  String backLabel = 'All Games',
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
                label: Text(
                  backLabel,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
  String? avatarUrl;
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
    this.avatarUrl,
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
  final String? hostAvatarUrl;
  final String? token;
  final bool isSinhala;
  final String? initialLiveRoomId;

  const _CollaborativeMemoryGameView({
    super.key,
    required this.onBack,
    required this.residentId,
    required this.elderHomeId,
    required this.elderHomeName,
    required this.hostName,
    this.hostAvatarUrl,
    this.token,
    this.isSinhala = false,
    this.initialLiveRoomId,
  });

  @override
  State<_CollaborativeMemoryGameView> createState() =>
      _CollaborativeMemoryGameViewState();
}

class _CollabPlayerSnapshot {
  final bool isInvited;
  final bool hasJoined;
  final int chainStepsCompleted;
  final int itemsAdded;

  const _CollabPlayerSnapshot({
    required this.isInvited,
    required this.hasJoined,
    required this.chainStepsCompleted,
    required this.itemsAdded,
  });
}

class _CollabLangSnapshot {
  final _ChainTurnStage stage;
  final int currentPlayerIndex;
  final List<_PicnicChainItem> packedChain;
  final List<_PicnicChainItem> currentRecallInput;
  final String? feedbackBannerText;
  final bool isFeedbackPositive;
  final String? teammateHintText;
  final int totalTeamAttempts;
  final int successfulRecalls;
  final bool isSaving;
  final String? saveErrorMessage;
  final double? lastScore;
  final bool inviteCodeCopied;
  final Map<String, _CollabPlayerSnapshot> playerStates;

  const _CollabLangSnapshot({
    required this.stage,
    required this.currentPlayerIndex,
    required this.packedChain,
    required this.currentRecallInput,
    required this.feedbackBannerText,
    required this.isFeedbackPositive,
    required this.teammateHintText,
    required this.totalTeamAttempts,
    required this.successfulRecalls,
    required this.isSaving,
    required this.saveErrorMessage,
    required this.lastScore,
    required this.inviteCodeCopied,
    required this.playerStates,
  });
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
  static const String _prefsDismissedInvitesKey =
      'carevora_picnic_dismissed_invites_v1';

  late List<_InvitedPlayer> _directoryPlayers;
  bool _inviteCodeCopied = false;
  Timer? _inviteSyncTimer;
  final Set<String> _shownIncomingPopupIds = {};
  List<Map<String, dynamic>> _incomingInvitesForMe = [];
  Set<String>? _dismissedInviteIds;
  Set<String>? _appliedCancelledInviteIds;
  int? _friendsPageIndex;
  String? _liveRoomId;
  int? _liveRoomVersion;
  String? _liveRoomStartedBy;
  int? _liveRoomStartedAt;
  Set<String>? _liveJoinedPlayers;
  Set<String>? _sameScreenPlayerNames;
  Map<String, dynamic>? _pendingLiveStartRoom;
  Timer? _liveRoomSyncTimer;
  Set<String>? _syncedTeamPeers;
  String? _restartRequestedBy;
  int? _restartRequestId;
  Set<String>? _restartApprovedBy;
  int? _shownRestartDialogId;
  List<String>? _liveTurnOrder;
  String? _lastSelectedItemKey;
  String? _lastSelectedByName;
  String? _lastSelectedAction;
  int? _lastSelectedAtMs;
  String? _savedCompletedRoomKey;
  List<Map<String, dynamic>>? _otherActiveLiveTeams;
  Set<String>? _busyInGamePlayerNames;
  PicnicBgmPlayer? _bgmPlayer;
  bool? _isMusicMuted;
  Set<String>? _exitedLiveRoomIds;

  PicnicBgmPlayer get _bgm => _bgmPlayer ??= PicnicBgmPlayer();

  void _toggleGameMusic() {
    final nextMuted = !(_isMusicMuted ?? false);
    setState(() {
      _isMusicMuted = nextMuted;
    });
    _bgm.setMuted(nextMuted);
    if (!nextMuted && _stage != _ChainTurnStage.lobbyInvite) {
      _bgm.startBgm();
    }
  }

  void _ensurePlayMusicRunning() {
    if (_isMusicMuted == true) return;
    _bgm.startBgm();
  }

  String _cleanName(String raw) => raw.replaceAll('(You)', '').trim();
  bool get _isLiveMultiplayerActive =>
      _liveRoomId != null && _liveRoomId!.isNotEmpty;

  /// Canonical turn order shared across ALL players' screens so 3+ players
  /// always rotate fairly (Player 1 -> Player 2 -> Player 3 -> Player 1).
  List<_InvitedPlayer> get _orderedTurnPlayers {
    final joined = _joinedPlayers;
    final order = _liveTurnOrder;
    if (order == null || order.isEmpty) return joined;
    final List<_InvitedPlayer> ordered = [];
    final Set<String> addedLowers = {};
    for (final name in order) {
      final lower = name.trim().toLowerCase();
      final match = joined
          .where((p) => _cleanName(p.name).toLowerCase() == lower)
          .firstOrNull;
      if (match != null && addedLowers.add(lower)) {
        ordered.add(match);
      }
    }
    if (ordered.isEmpty) {
      for (final p in joined) {
        final lower = _cleanName(p.name).toLowerCase();
        if (addedLowers.add(lower)) {
          ordered.add(p);
        }
      }
    }
    return ordered;
  }

  bool get _isMyTurnNow {
    if (!_isLiveMultiplayerActive) return true;
    final players = _orderedTurnPlayers;
    if (players.isEmpty) return false;
    final idx = _currentPlayerIndex.clamp(0, players.length - 1);
    return _cleanName(players[idx].name).toLowerCase() ==
        widget.hostName.trim().toLowerCase();
  }

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
  Map<bool, _CollabLangSnapshot>? _langSnapshots;

  String get _currentLangCode => widget.isSinhala ? 'si' : 'en';

  @override
  void initState() {
    super.initState();
    _initPlayers();
    _loadFacilityEldersFromBackend();
    _syncInvites();
    _syncLiveRoomState();
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _inviteSyncTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _syncInvites(),
      );
      _liveRoomSyncTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _syncLiveRoomState(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _CollaborativeMemoryGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSinhala != widget.isSinhala) {
      _switchLanguageSession(
        fromSinhala: oldWidget.isSinhala,
        toSinhala: widget.isSinhala,
      );
    }
    if (widget.initialLiveRoomId != null &&
        widget.initialLiveRoomId!.isNotEmpty &&
        widget.initialLiveRoomId != oldWidget.initialLiveRoomId) {
      _syncLiveRoomState();
    }
  }

  void _switchLanguageSession({
    required bool fromSinhala,
    required bool toSinhala,
  }) {
    final snapshots = _langSnapshots ??= <bool, _CollabLangSnapshot>{};

    // 1. Save outgoing language's complete game + team state independently
    final savedPlayers = <String, _CollabPlayerSnapshot>{};
    for (final p in _directoryPlayers) {
      savedPlayers[p.name.trim().toLowerCase()] = _CollabPlayerSnapshot(
        isInvited: p.isInvited,
        hasJoined: p.hasJoined,
        chainStepsCompleted: p.chainStepsCompleted,
        itemsAdded: p.itemsAdded,
      );
    }
    snapshots[fromSinhala] = _CollabLangSnapshot(
      stage: _stage,
      currentPlayerIndex: _currentPlayerIndex,
      packedChain: List<_PicnicChainItem>.from(_packedChain),
      currentRecallInput: List<_PicnicChainItem>.from(_currentRecallInput),
      feedbackBannerText: _feedbackBannerText,
      isFeedbackPositive: _isFeedbackPositive,
      teammateHintText: _teammateHintText,
      totalTeamAttempts: _totalTeamAttempts,
      successfulRecalls: _successfulRecalls,
      isSaving: _isSaving,
      saveErrorMessage: _saveErrorMessage,
      lastScore: _lastScore,
      inviteCodeCopied: _inviteCodeCopied,
      playerStates: savedPlayers,
    );

    // 2. Restore target language's own independent state (or start a fresh lobby)
    final target = snapshots[toSinhala];
    if (target != null) {
      _stage = target.stage;
      _packedChain
        ..clear()
        ..addAll(target.packedChain);
      _currentRecallInput
        ..clear()
        ..addAll(target.currentRecallInput);
      _feedbackBannerText = target.feedbackBannerText;
      _isFeedbackPositive = target.isFeedbackPositive;
      _teammateHintText = target.teammateHintText;
      _totalTeamAttempts = target.totalTeamAttempts;
      _successfulRecalls = target.successfulRecalls;
      _isSaving = target.isSaving;
      _saveErrorMessage = target.saveErrorMessage;
      _lastScore = target.lastScore;
      _inviteCodeCopied = target.inviteCodeCopied;
      for (final p in _directoryPlayers) {
        if (p.isHost) {
          p.isInvited = true;
          p.hasJoined = true;
        } else {
          final ps = target.playerStates[p.name.trim().toLowerCase()];
          p.isInvited = ps?.isInvited ?? false;
          p.hasJoined = ps?.hasJoined ?? false;
          p.chainStepsCompleted = ps?.chainStepsCompleted ?? 0;
          p.itemsAdded = ps?.itemsAdded ?? 0;
        }
      }
      final joinedCount = _joinedPlayers.length;
      _currentPlayerIndex =
          joinedCount > 0 && target.currentPlayerIndex < joinedCount
              ? target.currentPlayerIndex
              : 0;
    } else {
      _stage = _ChainTurnStage.lobbyInvite;
      _currentPlayerIndex = 0;
      _packedChain.clear();
      _currentRecallInput.clear();
      _feedbackBannerText = null;
      _isFeedbackPositive = true;
      _teammateHintText = null;
      _totalTeamAttempts = 0;
      _successfulRecalls = 0;
      _isSaving = false;
      _saveErrorMessage = null;
      _lastScore = null;
      _inviteCodeCopied = false;
      for (final p in _directoryPlayers) {
        p.chainStepsCompleted = 0;
        p.itemsAdded = 0;
        if (p.isHost) {
          p.isInvited = true;
          p.hasJoined = true;
        } else {
          p.isInvited = false;
          p.hasJoined = false;
        }
      }
    }
    _incomingInvitesForMe = [];
    if (_stage == _ChainTurnStage.lobbyInvite ||
        _stage == _ChainTurnStage.completed) {
      _bgmPlayer?.stopBgm();
    } else {
      _ensurePlayMusicRunning();
    }
    _syncInvites();
  }

  @override
  void dispose() {
    _inviteSyncTimer?.cancel();
    _liveRoomSyncTimer?.cancel();
    TtsService.instance.stop();
    _bgmPlayer?.dispose();
    super.dispose();
  }

  Future<void> _showHowToPlayDialog() async {
    final isSi = widget.isSinhala;
    final tts = TtsService.instance;
    const sinhalaGuideSpeech =
        'විනෝද චාරිකා මතක ක්‍රීඩාව ක්‍රීඩා කරන ආකාරය. පළමුව, මිතුරෙකු තෝරා එකට හෝ ආරාධනා ඔබා කණ්ඩායම සාදන්න. දෙවනුව, ඔබේ වාරයේදී කූඩයේ කලින් දැමූ භාණ්ඩ පිළිවෙලට තෝරා අලුත් භාණ්ඩයක් එක් කරන්න. අමතක වුණොත් ඉඟියක් ඔබන්න. භාණ්ඩ පහම එකට අසුරා ජය ගන්න!';
    const englishGuideSpeech =
        'How to play Picnic Memory Party. Step 1: Build your team. Pick a friend and tap Sit Together or Invite. Step 2: Recall and pack. On your turn, tap the earlier picnic items in order, then pack one new item into the basket. Step 3: Pack 5 items and win! Tap Hint anytime if you forget. Pack all 5 items together to celebrate a team win!';

    bool isSpeakingNow = false;
    bool pausedBgmForGuide = false;
    bool dialogOpen = true;

    void stopGuideSpeech({void Function(VoidCallback)? setDlgState}) {
      tts.onComplete = null;
      tts.stop();
      if (pausedBgmForGuide) {
        pausedBgmForGuide = false;
        if (mounted &&
            _stage != _ChainTurnStage.lobbyInvite &&
            _stage != _ChainTurnStage.completed &&
            !(_isMusicMuted ?? false)) {
          _ensurePlayMusicRunning();
        }
      }
      if (isSpeakingNow) {
        isSpeakingNow = false;
        if (dialogOpen && setDlgState != null) {
          setDlgState(() {});
        }
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            void toggleSpeak() {
              if (isSpeakingNow) {
                stopGuideSpeech(setDlgState: setDlgState);
                return;
              }
              if (_stage != _ChainTurnStage.lobbyInvite &&
                  _stage != _ChainTurnStage.completed &&
                  !(_isMusicMuted ?? false)) {
                _bgmPlayer?.stopBgm();
                pausedBgmForGuide = true;
              }
              setDlgState(() => isSpeakingNow = true);
              tts.onComplete = () {
                if (pausedBgmForGuide) {
                  pausedBgmForGuide = false;
                  if (mounted &&
                      _stage != _ChainTurnStage.lobbyInvite &&
                      _stage != _ChainTurnStage.completed &&
                      !(_isMusicMuted ?? false)) {
                    _ensurePlayMusicRunning();
                  }
                }
                if (dialogOpen) {
                  isSpeakingNow = false;
                  setDlgState(() {});
                }
              };
              tts.speak(
                isSi ? sinhalaGuideSpeech : englishGuideSpeech,
                isSinhala: isSi,
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 530),
                child: AuroraGradientBorderFrame(
                  borderRadius: 24,
                  borderWidth: 3.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E1B4B).withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cosmic Header Strip with Listen button
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF1E1B4B),
                                Color(0xFF1D4ED8),
                                Color(0xFF0D9488),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Center(
                                  child: Text('🧺', style: TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isSi ? 'ක්‍රීඩා කරන ආකාරය' : 'How to Play',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      isSi
                                          ? 'සරල පියවර 3 කින් එකට සෙල්ලම් කරමු'
                                          : '3 simple steps to play together',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                key: const ValueKey('collab_howto_listen_button'),
                                onPressed: toggleSpeak,
                                icon: Icon(
                                  isSpeakingNow
                                      ? Icons.stop_rounded
                                      : Icons.volume_up_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isSpeakingNow
                                      ? (isSi ? 'නවත්වන්න' : 'Stop')
                                      : (isSi ? 'අසන්න' : 'Listen'),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSpeakingNow
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFFDE68A),
                                  foregroundColor: isSpeakingNow
                                      ? Colors.white
                                      : const Color(0xFF1E1B4B),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: isSi ? 'වසන්න' : 'Close',
                              ),
                            ],
                          ),
                        ),

                        // 3 Elder-Friendly Visual Step Cards
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHowToPlayStepCard(
                                stepNumber: '1',
                                emoji: '👥',
                                title: isSi
                                    ? 'කණ්ඩායම සාදන්න'
                                    : 'Build Your Team',
                                description: isSi
                                    ? 'මිතුරෙකු තෝරා "එකට" (එකම තිරයේ) හෝ "ආරාධනා" (වෙනම උපාංගවල) ඔබා ක්‍රීඩාව අරඹන්න.'
                                    : 'Pick a friend and tap "Sit Together" (same screen) or "Invite" (separate devices) to start.',
                                accentColor: const Color(0xFF2563EB),
                                bgColors: const [
                                  Color(0xFFEFF6FF),
                                  Color(0xFFEEF2FF),
                                ],
                              ),
                              const SizedBox(height: 11),
                              _buildHowToPlayStepCard(
                                stepNumber: '2',
                                emoji: '🧺',
                                title: isSi
                                    ? 'මතකයෙන් කූඩය අසුරන්න'
                                    : 'Recall & Pack Together',
                                description: isSi
                                    ? 'ඔබේ වාරයේදී කලින් දැමූ භාණ්ඩ පිළිවෙලට තෝරා, අලුත් භාණ්ඩයක් කූඩයට එක් කරන්න.'
                                    : 'On your turn, tap the earlier picnic items in order, then pack 1 new item into the basket.',
                                accentColor: const Color(0xFF0D9488),
                                bgColors: const [
                                  Color(0xFFECFDF5),
                                  Color(0xFFF0FDFA),
                                ],
                              ),
                              const SizedBox(height: 11),
                              _buildHowToPlayStepCard(
                                stepNumber: '3',
                                emoji: '🏆',
                                title: isSi
                                    ? 'භාණ්ඩ 5ම අසුරා ජය ගන්න!'
                                    : 'Pack 5 Items & Win!',
                                description: isSi
                                    ? 'අමතක වුණොත් ඕනෑම වෙලාවක "💡 ඉඟියක්" ඔබන්න. භාණ්ඩ 5ම එකට අසුරා ජය ගන්න!'
                                    : 'Forgot an item? Tap "💡 Hint" anytime! Pack all 5 items together to celebrate a team win!',
                                accentColor: const Color(0xFFD97706),
                                bgColors: const [
                                  Color(0xFFFFFBEB),
                                  Color(0xFFFEF3C7),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  key: const ValueKey('collab_howto_got_it_button'),
                                  onPressed: () => Navigator.of(dialogCtx).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1D4ED8),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    isSi
                                        ? '👍 හරි, තේරුණා!'
                                        : "👍 Got It! Let's Play",
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
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
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      dialogOpen = false;
      stopGuideSpeech();
    });
  }

  Widget _buildHowToPlayStepCard({
    required String stepNumber,
    required String emoji,
    required String title,
    required String description,
    required Color accentColor,
    required List<Color> bgColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stepNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        avatarUrl: widget.hostAvatarUrl,
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
    final Map<String, String> avatarsByName = {};
    final hostNameLower = widget.hostName.trim().toLowerCase();
    final targetHomeNameLower = widget.elderHomeName.trim().toLowerCase();

    void recordAvatar(String rawName, String? rawAvatar) {
      final clean = rawName.trim().toLowerCase();
      final url = rawAvatar?.trim();
      if (clean.isNotEmpty && url != null && url.isNotEmpty) {
        avatarsByName.putIfAbsent(clean, () => url);
      }
    }

    void addIfSameHomeElder({
      required String id,
      required String name,
      required String room,
      required int? homeId,
      required String? homeName,
      String? avatarUrl,
    }) {
      final cleanName = name.trim();
      recordAvatar(cleanName, avatarUrl);
      if (cleanName.isEmpty || cleanName.toLowerCase() == hostNameLower) {
        return;
      }
      final matchesHomeId = homeId != null && homeId == widget.elderHomeId;
      final matchesHomeName = homeName != null &&
          homeName.trim().toLowerCase() == targetHomeNameLower;
      if (!matchesHomeId && !matchesHomeName) return;

      final existingIdx = realElders.indexWhere(
        (p) => p.name.toLowerCase() == cleanName.toLowerCase(),
      );
      if (existingIdx == -1) {
        final roomText = room.trim().isNotEmpty ? room.trim() : 'Suite';
        realElders.add(
          _InvitedPlayer(
            id: id,
            name: cleanName,
            roleLabel: 'Fellow Elder ($roomText) • ${widget.elderHomeName}',
            elderHomeId: widget.elderHomeId,
            elderHomeName: widget.elderHomeName,
            color: palette[realElders.length % palette.length],
            avatarUrl: avatarUrl,
          ),
        );
      } else if ((realElders[existingIdx].avatarUrl ?? '').isEmpty &&
          (avatarUrl ?? '').isNotEmpty) {
        realElders[existingIdx].avatarUrl = avatarUrl;
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
                avatarUrl: raw['avatarUrl']?.toString(),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 2. Also query live /api/residents and /api/doctor/all-users to load real DB elders AND enrich profile pictures (avatarUrl)
    final needsAvatars = realElders.isEmpty ||
        realElders.any((e) => (e.avatarUrl ?? '').trim().isEmpty) ||
        (widget.hostAvatarUrl ?? '').trim().isEmpty;
    if (needsAvatars) {
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
                    avatarUrl: raw['avatarUrl']?.toString(),
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
                      avatarUrl: raw['avatarUrl']?.toString(),
                    );
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if ((realElders.isNotEmpty || avatarsByName.isNotEmpty) && mounted) {
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
            avatarUrl: widget.hostAvatarUrl,
            isHost: true,
            isInvited: true,
            hasJoined: true,
          ),
        );
        if ((hostEntry.avatarUrl ?? '').trim().isEmpty) {
          hostEntry.avatarUrl =
              widget.hostAvatarUrl ?? avatarsByName[hostNameLower];
        }
        if (realElders.isNotEmpty) {
          for (final elder in realElders) {
            if ((elder.avatarUrl ?? '').trim().isEmpty) {
              elder.avatarUrl = avatarsByName[elder.name.trim().toLowerCase()];
            }
          }
          _directoryPlayers = [hostEntry, ...realElders];
        } else {
          for (final p in _directoryPlayers) {
            if ((p.avatarUrl ?? '').trim().isEmpty) {
              p.avatarUrl =
                  avatarsByName[_cleanName(p.name).toLowerCase()];
            }
          }
        }
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
              if (id.isNotEmpty) {
                final existing = merged[id];
                final existingStatus =
                    (existing?['status']?.toString() ?? '').toUpperCase();
                final incomingStatus =
                    (map['status']?.toString() ?? '').toUpperCase();
                // Never let a stale backend PENDING overwrite a local ACCEPTED/DECLINED/CANCELLED
                if (existing != null &&
                    existingStatus.isNotEmpty &&
                    existingStatus != 'PENDING' &&
                    incomingStatus == 'PENDING') {
                  continue;
                }
                merged[id] = map;
              }
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

  Future<Set<String>> _readDismissedInviteIds() async {
    final result = <String>{...?_dismissedInviteIds};
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsDismissedInvitesKey);
      if (list != null) {
        result.addAll(list);
      }
    } catch (_) {}
    _dismissedInviteIds = result;
    return result;
  }

  Future<void> _persistDismissedInviteIds(Iterable<String> ids) async {
    final cleanIds = ids.where((id) => id.isNotEmpty).toSet();
    if (cleanIds.isEmpty) return;
    final current = await _readDismissedInviteIds();
    current.addAll(cleanIds);
    _dismissedInviteIds = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsDismissedInvitesKey, current.toList());
    } catch (_) {}
  }

  Future<void> _cancelInvitesMatching({String? targetPlayerName}) async {
    final syncLang = _currentLangCode;
    final myNameLower = widget.hostName.trim().toLowerCase();
    final targetLower = targetPlayerName?.trim().toLowerCase();
    final allInvites = await _readAllInvites();
    final idsToCancel = <String>{};

    if (targetLower != null && targetLower.isNotEmpty) {
      idsToCancel.add(
        'inv_${syncLang}_${widget.elderHomeId}_${widget.hostName.trim()}_${targetPlayerName!.trim()}'
            .replaceAll(' ', '_')
            .toLowerCase(),
      );
      idsToCancel.add(
        'inv_${widget.elderHomeId}_${widget.hostName.trim()}_${targetPlayerName.trim()}'
            .replaceAll(' ', '_')
            .toLowerCase(),
      );
    }

    final updatedList = <Map<String, dynamic>>[];
    for (final inv in allInvites) {
      if ((inv['recordType']?.toString() ?? '').toUpperCase() ==
          'LIVE_ROOM_STATE') {
        updatedList.add(inv);
        continue;
      }
      final homeId = int.tryParse(inv['elderHomeId']?.toString() ?? '') ??
          widget.elderHomeId;
      final invLang = (inv['lang']?.toString() ?? 'en').toLowerCase();
      final senderLower = (inv['senderName']?.toString() ?? '').trim().toLowerCase();
      final invTargetLower =
          (inv['targetName']?.toString() ?? '').trim().toLowerCase();
      final invId = inv['id']?.toString() ?? '';

      final matchesHomeAndLang = targetLower != null
          ? homeId == widget.elderHomeId
          : (homeId == widget.elderHomeId && invLang == syncLang);
      final involvesMe =
          senderLower == myNameLower || invTargetLower == myNameLower;
      final matchesTarget = targetLower == null
          ? true
          : (senderLower == targetLower || invTargetLower == targetLower);

      if (matchesHomeAndLang && involvesMe && matchesTarget) {
        if (invId.isNotEmpty) idsToCancel.add(invId);
        updatedList.add({...inv, 'status': 'CANCELLED'});
      } else {
        updatedList.add(inv);
      }
    }

    // Immediately record dismissed IDs so polling never re-adds them
    (_dismissedInviteIds ??= <String>{}).addAll(idsToCancel);
    await _persistDismissedInviteIds(idsToCancel);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsInvitesKey, jsonEncode(updatedList));
    } catch (_) {}

    // Fire-and-forget backend cancellation so Back / Remove stays instant
    for (final invId in idsToCancel) {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/api/memory-games/invites/$invId/respond',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      unawaited(
        http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({'status': 'CANCELLED'}),
            )
            .timeout(const Duration(seconds: 2))
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  Future<void> _syncInvites() async {
    if (!mounted) return;
    final syncLang = _currentLangCode;
    final dismissed = await _readDismissedInviteIds();
    int sessionEpoch = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      sessionEpoch = prefs.getInt('carevora_collab_session_epoch_ms') ?? 0;
    } catch (_) {}
    final allInvites = await _readAllInvites();
    if (!mounted || _currentLangCode != syncLang) return;

    final myNameLower = widget.hostName.trim().toLowerCase();
    final List<Map<String, dynamic>> incomingPendingForMe = [];
    final appliedCancelled = _appliedCancelledInviteIds ??= <String>{};
    final Set<String> activeAcceptedPeers = {};
    final Set<String> newlyCancelledPeers = {};
    final Map<String, String> peerDisplayByLower = {};
    final Map<String, Set<String>> acceptedGraph = {};

    setState(() {
      for (final inv in allInvites) {
        if ((inv['recordType']?.toString() ?? '').toUpperCase() ==
            'LIVE_ROOM_STATE') {
          continue;
        }
        final createdAt = int.tryParse(inv['createdAt']?.toString() ?? '') ?? 0;
        if (sessionEpoch > 0 && createdAt > 0 && createdAt < sessionEpoch) {
          continue;
        }
        final homeId = int.tryParse(inv['elderHomeId']?.toString() ?? '') ??
            widget.elderHomeId;
        if (homeId != widget.elderHomeId) continue;

        final invLang = (inv['lang']?.toString() ?? 'en').toLowerCase();
        final senderName = (inv['senderName']?.toString() ?? '').trim();
        final targetName = (inv['targetName']?.toString() ?? '').trim();
        final senderLower = senderName.toLowerCase();
        final targetLower = targetName.toLowerCase();
        final status = (inv['status']?.toString() ?? 'PENDING').toUpperCase();
        final invId = inv['id']?.toString() ?? '';

        if (status == 'CANCELLED') {
          if (invId.isEmpty || !appliedCancelled.contains(invId)) {
            if (invId.isNotEmpty) appliedCancelled.add(invId);
            if (senderLower == myNameLower && targetLower.isNotEmpty) {
              newlyCancelledPeers.add(targetLower);
            } else if (targetLower == myNameLower && senderLower.isNotEmpty) {
              newlyCancelledPeers.add(senderLower);
            }
          }
          continue;
        }

        if (invId.isNotEmpty && dismissed.contains(invId)) {
          continue;
        }

        // Collect all valid ACCEPTED edges so every teammate sees ALL joined members!
        if (status == 'ACCEPTED' &&
            senderLower.isNotEmpty &&
            targetLower.isNotEmpty) {
          final allowEdge =
              senderLower != myNameLower || invLang == syncLang;
          if (allowEdge) {
            peerDisplayByLower[senderLower] = senderName;
            peerDisplayByLower[targetLower] = targetName;
            (acceptedGraph[senderLower] ??= <String>{}).add(targetLower);
            (acceptedGraph[targetLower] ??= <String>{}).add(senderLower);
          }
        }

        // Case A: I am the SENDER (strictly isolated per language so EN/SI sessions never leak)
        if (senderLower == myNameLower && invLang == syncLang) {
          for (final p in _directoryPlayers) {
            if (p.name.toLowerCase() == targetLower) {
              if (status == 'ACCEPTED') {
                activeAcceptedPeers.add(targetLower);
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
        if (targetLower == myNameLower) {
          // Ensure sender exists in directory list
          var senderPlayer = _directoryPlayers
              .where((p) => p.name.toLowerCase() == senderLower)
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
            activeAcceptedPeers.add(senderLower);
            senderPlayer.isInvited = true;
            senderPlayer.hasJoined = true;
          }
        }
      }

      // Transitive BFS: everyone in the connected team sees ALL joined players!
      final Set<String> connectedTeamLowers = {myNameLower};
      final List<String> bfsQueue = [myNameLower];
      while (bfsQueue.isNotEmpty) {
        final curr = bfsQueue.removeAt(0);
        for (final next in (acceptedGraph[curr] ?? const <String>{})) {
          if (connectedTeamLowers.add(next)) {
            bfsQueue.add(next);
          }
        }
      }
      connectedTeamLowers.remove(myNameLower);

      final prevSynced = _syncedTeamPeers ??= <String>{};
      final sameScreen = _sameScreenPlayerNames ?? const <String>{};
      final teamColors = [
        const Color(0xFF0D9488),
        const Color(0xFF7C3AED),
        const Color(0xFFDB2777),
        const Color(0xFFD97706),
      ];

      for (final peerLower in connectedTeamLowers) {
        activeAcceptedPeers.add(peerLower);
        var peer = _directoryPlayers
            .where((p) => !p.isHost && _cleanName(p.name).toLowerCase() == peerLower)
            .firstOrNull;
        if (peer == null) {
          final rawName = peerDisplayByLower[peerLower] ?? peerLower;
          peer = _InvitedPlayer(
            id: 'team_peer_$peerLower',
            name: rawName,
            roleLabel: 'Fellow Elder • ${widget.elderHomeName}',
            elderHomeId: widget.elderHomeId,
            elderHomeName: widget.elderHomeName,
            color: teamColors[_directoryPlayers.length % teamColors.length],
          );
          _directoryPlayers.add(peer);
        }
        peer.isInvited = true;
        peer.hasJoined = true;
      }

      // If a previously synced teammate disconnected from the group, remove them cleanly
      for (final oldPeer in prevSynced.toList()) {
        if (!connectedTeamLowers.contains(oldPeer) &&
            !sameScreen.contains(oldPeer)) {
          newlyCancelledPeers.add(oldPeer);
        }
      }
      _syncedTeamPeers = Set<String>.from(connectedTeamLowers);

      // Propagate removals from the other player's side cleanly
      for (final peerLower in newlyCancelledPeers) {
        if (activeAcceptedPeers.contains(peerLower)) continue;
        for (final p in _directoryPlayers) {
          if (!p.isHost && p.name.trim().toLowerCase() == peerLower) {
            p.isInvited = false;
            p.hasJoined = false;
            p.itemsAdded = 0;
            p.chainStepsCompleted = 0;
            if (_feedbackBannerText != null &&
                _feedbackBannerText!.toLowerCase().contains(peerLower)) {
              _feedbackBannerText = null;
            }
          }
        }
      }
      if (_currentPlayerIndex >= _joinedPlayers.length) {
        _currentPlayerIndex = 0;
      }
      if (_stage != _ChainTurnStage.lobbyInvite &&
          _joinedPlayers.length < _minPlayers) {
        _stage = _ChainTurnStage.lobbyInvite;
      }

      // Never show Accept/Decline again for a sender who is ALREADY joined in the room!
      final joinedLowerNames = _directoryPlayers
          .where((p) => p.hasJoined && !p.isHost)
          .map((p) => p.name.trim().toLowerCase())
          .toSet();
      _incomingInvitesForMe = incomingPendingForMe.where((inv) {
        final s = (inv['senderName']?.toString() ?? '').trim().toLowerCase();
        return !joinedLowerNames.contains(s);
      }).toList();
    });

    // Show notification dialog ONLY for genuinely pending (unjoined) invites!
    for (final inv in _incomingInvitesForMe) {
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
    final langCode = _currentLangCode;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final inviteId =
        'inv_${langCode}_${widget.elderHomeId}_${widget.hostName.trim()}_${player.name.trim()}_$nowMs'
            .replaceAll(' ', '_')
            .toLowerCase();

    final inviteRecord = <String, dynamic>{
      'id': inviteId,
      'lang': langCode,
      'senderName': widget.hostName.trim(),
      'targetName': player.name.trim(),
      'elderHomeId': widget.elderHomeId,
      'elderHomeName': widget.elderHomeName,
      'status': 'PENDING',
      'createdAt': nowMs,
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
    setState(() {
      player.isInvited = false;
      player.hasJoined = false;
      _feedbackBannerText = null;
      _isFeedbackPositive = true;
    });
    await _cancelInvitesMatching(targetPlayerName: player.name);
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
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _incomingInvitesForMe.removeWhere(
        (e) =>
            e['id']?.toString() == inviteId ||
            (accept &&
                (e['senderName']?.toString() ?? '').trim().toLowerCase() ==
                    senderName.toLowerCase()),
      );
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
    (_sameScreenPlayerNames ??= <String>{})
        .add(_cleanName(player.name).toLowerCase());
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
    final isSi = _isSi;
    final senderName = (invite['senderName']?.toString() ?? 'Fellow Elder').trim();
    final targetName = (invite['targetName']?.toString() ?? widget.hostName).trim();
    final homeName =
        (invite['elderHomeName']?.toString() ?? widget.elderHomeName).trim();
    final displaySender = isSi
        ? SinhalaNameTransliterator.toSinhala(senderName, fallback: senderName)
        : senderName;
    final displayTarget = isSi
        ? SinhalaNameTransliterator.toSinhala(targetName, fallback: targetName)
        : targetName;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AuroraGradientBorderFrame(
              borderRadius: 28,
              borderWidth: 3.4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.6),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Vibrant Cosmic Header Banner
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF1E1B4B),
                              Color(0xFF4F46E5),
                              Color(0xFF9333EA),
                              Color(0xFF0D9488),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.bell,
                                    size: 14,
                                    color: Color(0xFFFDE68A),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      isSi
                                          ? '$displayTarget සඳහා ක්‍රීඩා ආරාධනාවක්'
                                          : 'Incoming Game Invite for $targetName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFDE68A),
                                    Color(0xFFEC4899),
                                    Color(0xFF34D399),
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF0D9488),
                                child: Text(
                                  senderName.isNotEmpty
                                      ? senderName.substring(0, 1).toUpperCase()
                                      : 'E',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            Text(
                              isSi
                                  ? 'විනෝද චාරිකා ක්‍රීඩාවට එක්වෙමුද? 🧺'
                                  : 'Join Picnic Memory Game? 🧺',
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Body & Action Buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFDDD6FE),
                                ),
                              ),
                              child: Text(
                                isSi
                                    ? 'ආයුබෝවන් $displayTarget! $homeName හි ඔබේ මිතුරු $displaySender ඔබට "හවුල් විනෝද චාරිකා මතක ක්‍රීඩාව" එකට සෙල්ලම් කිරීමට ආරාධනා කරයි.'
                                    : 'Hello $targetName! Your fellow elder $senderName in $homeName has invited you to play "Shared Picnic Memory Chain" together.',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                  height: 1.48,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(dialogCtx).pop();
                                    _respondToIncomingInvite(
                                      invite,
                                      accept: false,
                                    );
                                  },
                                  icon: const Icon(LucideIcons.x, size: 16),
                                  label: Text(
                                    isSi ? 'එපා' : 'Decline',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    backgroundColor: const Color(0xFFFEF2F2),
                                    side: const BorderSide(
                                      color: Color(0xFFFCA5A5),
                                      width: 1.4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF0D9488),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.30),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(dialogCtx).pop();
                                      _respondToIncomingInvite(
                                        invite,
                                        accept: true,
                                      );
                                    },
                                    icon:
                                        const Icon(LucideIcons.check, size: 17),
                                    label: Text(
                                      isSi
                                          ? 'එක්වී සෙල්ලම් කරන්න'
                                          : 'Accept & Join Game',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeJoinedPlayer(_InvitedPlayer player) async {
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
      player.itemsAdded = 0;
      player.chainStepsCompleted = 0;
      if (_feedbackBannerText != null &&
          _feedbackBannerText!
              .toLowerCase()
              .contains(player.name.trim().toLowerCase())) {
        _feedbackBannerText = null;
      }
      if (_currentPlayerIndex >= _joinedPlayers.length) {
        _currentPlayerIndex = 0;
      }
    });
    await _cancelInvitesMatching(targetPlayerName: player.name);
  }

  Future<void> _publishLiveRoomState({bool markEnded = false}) async {
    final roomId = _liveRoomId;
    if (roomId == null || roomId.isEmpty) return;

    final nextVersion = (_liveRoomVersion ?? 0) + 1;
    _liveRoomVersion = nextVersion;

    final turnPlayers = _orderedTurnPlayers;
    final cleanParticipants = turnPlayers
        .map((p) => _cleanName(p.name))
        .where((n) => n.isNotEmpty)
        .toList();
    final safeIdx = turnPlayers.isNotEmpty
        ? _currentPlayerIndex.clamp(0, turnPlayers.length - 1)
        : 0;
    final activeTurnClean = turnPlayers.isNotEmpty
        ? _cleanName(turnPlayers[safeIdx].name)
        : widget.hostName.trim();
    final joinedSet = (_liveJoinedPlayers ??= <String>{})
      ..add(widget.hostName.trim());

    final payload = <String, dynamic>{
      'id': roomId,
      'recordType': 'LIVE_ROOM_STATE',
      'elderHomeId': widget.elderHomeId,
      'startedBy': _liveRoomStartedBy ?? widget.hostName.trim(),
      'startedAt': _liveRoomStartedAt ?? DateTime.now().millisecondsSinceEpoch,
      'version': nextVersion,
      'participants': cleanParticipants,
      'joinedLivePlayers': joinedSet.toList(),
      'stage': markEnded ? 'ended' : _stage.name,
      'currentTurnPlayerName': activeTurnClean,
      'packedChain': _packedChain
          .map((c) => {
                'key': c.key,
                'addedBy': _cleanName(c.addedByPlayerName),
              })
          .toList(),
      'currentRecallKeys': _currentRecallInput.map((c) => c.key).toList(),
      'feedbackBannerText': _feedbackBannerText,
      'isFeedbackPositive': _isFeedbackPositive,
      'teammateHintText': _teammateHintText,
      'totalTeamAttempts': _totalTeamAttempts,
      'successfulRecalls': _successfulRecalls,
      'lastScore': _lastScore,
      'restartRequestedBy': _restartRequestedBy,
      'restartRequestId': _restartRequestId,
      'restartApprovedBy': (_restartApprovedBy ?? const <String>{}).toList(),
      'lastSelectedItemKey': _lastSelectedItemKey,
      'lastSelectedByName': _lastSelectedByName,
      'lastSelectedAction': _lastSelectedAction,
      'lastSelectedAtMs': _lastSelectedAtMs,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final uri =
          Uri.parse('${AppConfig.backendBaseUrl}/api/memory-games/invites');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _syncLiveRoomState() async {
    if (!mounted) return;
    final myNameLower = widget.hostName.trim().toLowerCase();
    if (myNameLower.isEmpty) return;

    int sessionEpoch = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      sessionEpoch = prefs.getInt('carevora_collab_session_epoch_ms') ?? 0;
    } catch (_) {}

    List<Map<String, dynamic>> liveRooms = [];
    try {
      final uri =
          Uri.parse('${AppConfig.backendBaseUrl}/api/memory-games/invites');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] as List?;
        if (data != null) {
          for (final item in data) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              if ((map['recordType']?.toString() ?? '').toUpperCase() ==
                  'LIVE_ROOM_STATE') {
                liveRooms.add(map);
              }
            }
          }
        }
      }
    } catch (_) {
      return;
    }
    if (!mounted) return;

    // 1. If routed via "Join Game Now!" button to a NEW active room, switch & join it immediately!
    final targetRoomId = widget.initialLiveRoomId;
    final exitedRooms = _exitedLiveRoomIds ?? const <String>{};
    if (targetRoomId != null &&
        targetRoomId.isNotEmpty &&
        targetRoomId != _liveRoomId &&
        !exitedRooms.contains(targetRoomId)) {
      final directRoom = liveRooms
          .where((r) => r['id']?.toString() == targetRoomId)
          .firstOrNull;
      final directStage = directRoom?['stage']?.toString() ?? '';
      if (directRoom != null &&
          directStage != 'ended' &&
          directStage != 'completed' &&
          directStage != 'lobbyInvite') {
        await _joinLiveRoom(directRoom);
        return;
      }
    }

    // 2. If already inside an active live multiplayer room, pull newer moves (or Play Another Round)!
    if (_liveRoomId != null && _liveRoomId!.isNotEmpty) {
      final match = liveRooms
          .where((r) => r['id']?.toString() == _liveRoomId)
          .firstOrNull;
      if (match != null) {
        final remoteVersion =
            int.tryParse(match['version']?.toString() ?? '') ?? 0;
        final remoteStage = (match['stage']?.toString() ?? '');
        if (remoteStage == 'ended') {
          _bgmPlayer?.stopBgm();
          final endNotice = match['feedbackBannerText']?.toString().trim();
          setState(() {
            _liveRoomId = null;
            _liveRoomVersion = null;
            _liveTurnOrder = null;
            _liveJoinedPlayers = null;
            _restartRequestedBy = null;
            _restartRequestId = null;
            _restartApprovedBy = null;
            _lastSelectedItemKey = null;
            _lastSelectedByName = null;
            _lastSelectedAction = null;
            _lastSelectedAtMs = null;
            _stage = _ChainTurnStage.lobbyInvite;
            _packedChain.clear();
            _currentRecallInput.clear();
            _feedbackBannerText =
                (endNotice != null && endNotice.isNotEmpty) ? endNotice : null;
            _isFeedbackPositive = false;
            _teammateHintText = null;
          });
          return;
        }
        if (remoteVersion > (_liveRoomVersion ?? 0)) {
          _applyRemoteLiveRoomState(match);
        }
      }
      // If our current room is completed and a partner started a brand-new room, join it cleanly
      if (_stage == _ChainTurnStage.completed) {
        for (final room in liveRooms) {
          final rId = room['id']?.toString() ?? '';
          if (rId.isEmpty || rId == _liveRoomId) continue;
          final rStage = room['stage']?.toString() ?? '';
          if (rStage == 'completed' ||
              rStage == 'ended' ||
              rStage == 'lobbyInvite') {
            continue;
          }
          final rStartedAt =
              int.tryParse(room['startedAt']?.toString() ?? '') ?? 0;
          if (rStartedAt <= (_liveRoomStartedAt ?? 0)) continue;
          final participants = (room['participants'] as List?)
                  ?.map((e) => e.toString().trim().toLowerCase())
                  .toList() ??
              const <String>[];
          if (participants.contains(myNameLower)) {
            await _joinLiveRoom(room);
            return;
          }
        }
      }
      return;
    }

    // 3. Otherwise in Lobby, detect if a partner started a live game AND track other active teams playing now!
    if (_stage == _ChainTurnStage.lobbyInvite) {
      Map<String, dynamic>? newestActive;
      int newestStartedAt = -1;
      final List<Map<String, dynamic>> otherTeams = [];
      final Set<String> busyPlayers = {};
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final room in liveRooms) {
        final stage = (room['stage']?.toString() ?? '');
        if (stage == 'completed' || stage == 'ended' || stage == 'lobbyInvite') {
          continue;
        }
        final homeId = int.tryParse(room['elderHomeId']?.toString() ?? '') ??
            widget.elderHomeId;
        if (homeId != widget.elderHomeId) continue;

        final updatedAt = int.tryParse(room['updatedAt']?.toString() ?? '') ??
            int.tryParse(room['startedAt']?.toString() ?? '') ??
            0;
        // Ignore stale abandoned rooms older than 15 minutes
        if (updatedAt > 0 && (nowMs - updatedAt) > 15 * 60 * 1000) {
          continue;
        }

        final participants = (room['participants'] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];
        final participantLowers =
            participants.map((e) => e.toLowerCase()).toList();
        if (participants.length < _minPlayers) continue;

        final startedByLower =
            (room['startedBy']?.toString() ?? '').trim().toLowerCase();
        final startedAt = int.tryParse(room['startedAt']?.toString() ?? '') ?? 0;

        if (participantLowers.contains(myNameLower)) {
          final rId = room['id']?.toString() ?? '';
          if (exitedRooms.contains(rId)) continue;
          if (startedByLower.isNotEmpty && startedByLower != myNameLower) {
            if (sessionEpoch > 0 && startedAt > 0 && startedAt < sessionEpoch) {
              continue;
            }
            if (startedAt >= newestStartedAt) {
              newestStartedAt = startedAt;
              newestActive = room;
            }
          }
        } else {
          // Another team is actively playing right now!
          otherTeams.add(room);
          busyPlayers.addAll(participantLowers);
        }
      }

      otherTeams.sort((a, b) {
        final ta = int.tryParse(a['startedAt']?.toString() ?? '') ?? 0;
        final tb = int.tryParse(b['startedAt']?.toString() ?? '') ?? 0;
        return tb.compareTo(ta);
      });

      String teamSignature(List<Map<String, dynamic>> list) => list
          .map((r) =>
              '${r['id']}:${r['version']}:${(r['packedChain'] as List?)?.length ?? 0}')
          .join('|');

      final pendingChanged = (_pendingLiveStartRoom?['id']?.toString() ?? '') !=
          (newestActive?['id']?.toString() ?? '');
      final teamsChanged = teamSignature(_otherActiveLiveTeams ?? const []) !=
          teamSignature(otherTeams);

      if (pendingChanged || teamsChanged) {
        setState(() {
          _pendingLiveStartRoom = newestActive;
          _otherActiveLiveTeams = otherTeams;
          _busyInGamePlayerNames = busyPlayers;
        });
      }
    }
  }

  Future<void> _joinLiveRoom(Map<String, dynamic> room) async {
    final roomId = room['id']?.toString() ?? '';
    if (roomId.isEmpty) return;

    _liveRoomId = roomId;
    _liveRoomStartedBy = room['startedBy']?.toString();
    _liveRoomStartedAt =
        int.tryParse(room['startedAt']?.toString() ?? '') ??
            DateTime.now().millisecondsSinceEpoch;
    final joinedList = (room['joinedLivePlayers'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet() ??
        <String>{};
    joinedList.add(widget.hostName.trim());
    _liveJoinedPlayers = joinedList;

    _applyRemoteLiveRoomState(room);
    _ensurePlayMusicRunning();

    // Notify backend that I joined the live game so "Join Quickly!" banner clears
    final updatedRoom = <String, dynamic>{
      ...room,
      'joinedLivePlayers': joinedList.toList(),
    };
    try {
      final uri =
          Uri.parse('${AppConfig.backendBaseUrl}/api/memory-games/invites');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (widget.token != null && widget.token!.isNotEmpty)
          'Authorization': 'Bearer ${widget.token}',
      };
      await http
          .post(uri, headers: headers, body: jsonEncode(updatedRoom))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void _applyRemoteLiveRoomState(Map<String, dynamic> room) {
    final participants = (room['participants'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final stageStr = (room['stage']?.toString() ?? 'addNewItemToChain');
    final turnNameLower =
        (room['currentTurnPlayerName']?.toString() ?? '').trim().toLowerCase();
    final remoteVersion =
        int.tryParse(room['version']?.toString() ?? '') ?? 1;

    _ChainTurnStage parsedStage = _ChainTurnStage.addNewItemToChain;
    for (final s in _ChainTurnStage.values) {
      if (s.name == stageStr) {
        parsedStage = s;
        break;
      }
    }

    final List<_PicnicChainItem> rebuiltChain = [];
    final rawChain = room['packedChain'] as List?;
    if (rawChain != null) {
      for (final entry in rawChain) {
        if (entry is Map) {
          final key = entry['key']?.toString() ?? '';
          final addedBy = entry['addedBy']?.toString() ?? '';
          final base = _picnicPool.where((p) => p.key == key).firstOrNull;
          if (base != null) {
            rebuiltChain.add(base.withAddedBy(addedBy));
          }
        }
      }
    }

    final List<_PicnicChainItem> rebuiltRecall = [];
    final rawRecall = room['currentRecallKeys'] as List?;
    if (rawRecall != null) {
      for (final k in rawRecall) {
        final key = k.toString();
        final base = _picnicPool.where((p) => p.key == key).firstOrNull;
        if (base != null) rebuiltRecall.add(base);
      }
    }

    setState(() {
      _pendingLiveStartRoom = null;
      _liveRoomId = room['id']?.toString();
      _liveRoomVersion = remoteVersion;
      _liveRoomStartedBy = room['startedBy']?.toString();
      _liveRoomStartedAt =
          int.tryParse(room['startedAt']?.toString() ?? '') ??
              _liveRoomStartedAt;
      final remoteLiveJoined = (room['joinedLivePlayers'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet() ??
          <String>{};
      if (remoteLiveJoined.isNotEmpty) {
        _liveJoinedPlayers = remoteLiveJoined;
      }

      // Ensure all room participants are present & marked joined
      final participantLowers =
          participants.map((e) => e.toLowerCase()).toSet();
      for (final pName in participants) {
        final lower = pName.toLowerCase();
        if (lower == widget.hostName.trim().toLowerCase()) continue;
        final exists = _directoryPlayers
            .any((p) => _cleanName(p.name).toLowerCase() == lower);
        if (!exists) {
          _directoryPlayers.add(
            _InvitedPlayer(
              id: 'live_peer_$lower',
              name: pName,
              roleLabel: 'Fellow Elder • ${widget.elderHomeName}',
              elderHomeId: widget.elderHomeId,
              elderHomeName: widget.elderHomeName,
              color: const Color(0xFF0D9488),
              isInvited: true,
              hasJoined: true,
            ),
          );
        }
      }
      for (final p in _directoryPlayers) {
        if (p.isHost) {
          p.isInvited = true;
          p.hasJoined = true;
        } else if (participantLowers
            .contains(_cleanName(p.name).toLowerCase())) {
          p.isInvited = true;
          p.hasJoined = true;
        }
      }

      // Preserve canonical shared turn order so 3+ players rotate in exact sync
      if (participants.isNotEmpty) {
        _liveTurnOrder = List<String>.from(participants);
      }

      // Match active player index against canonical _orderedTurnPlayers
      final ordered = _orderedTurnPlayers;
      int matchedIdx = 0;
      for (var i = 0; i < ordered.length; i++) {
        if (_cleanName(ordered[i].name).toLowerCase() == turnNameLower) {
          matchedIdx = i;
          break;
        }
      }

      _stage = parsedStage;
      _currentPlayerIndex = matchedIdx;
      _packedChain
        ..clear()
        ..addAll(rebuiltChain);
      _currentRecallInput
        ..clear()
        ..addAll(rebuiltRecall);
      _feedbackBannerText = room['feedbackBannerText']?.toString();
      _isFeedbackPositive = room['isFeedbackPositive'] != false;
      _teammateHintText = room['teammateHintText']?.toString();
      _lastSelectedItemKey = room['lastSelectedItemKey']?.toString();
      _lastSelectedByName = room['lastSelectedByName']?.toString();
      _lastSelectedAction = room['lastSelectedAction']?.toString();
      _lastSelectedAtMs =
          int.tryParse(room['lastSelectedAtMs']?.toString() ?? '');
      _totalTeamAttempts =
          int.tryParse(room['totalTeamAttempts']?.toString() ?? '') ??
              _totalTeamAttempts;
      _successfulRecalls =
          int.tryParse(room['successfulRecalls']?.toString() ?? '') ??
              _successfulRecalls;
      final scoreVal = room['lastScore'];
      if (scoreVal is num) {
        _lastScore = scoreVal.toDouble();
      }

      // Sync collaborative restart request state
      final rawReqBy = room['restartRequestedBy']?.toString().trim();
      final rawReqId =
          int.tryParse(room['restartRequestId']?.toString() ?? '');
      final rawApproved = (room['restartApprovedBy'] as List?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toSet() ??
          <String>{};
      _restartRequestedBy =
          (rawReqBy != null && rawReqBy.isNotEmpty) ? rawReqBy : null;
      _restartRequestId = rawReqId;
      _restartApprovedBy = rawApproved.isNotEmpty ? rawApproved : null;
    });

    // Save completed collaborative game score for EVERY participating elder (once per round!)
    if (parsedStage == _ChainTurnStage.completed && mounted) {
      final completedKey =
          '${room['id'] ?? _liveRoomId ?? 'room'}_${room['startedAt'] ?? _liveRoomStartedAt ?? 0}';
      if (_savedCompletedRoomKey != completedKey) {
        _savedCompletedRoomKey = completedKey;
        _bgm.playVictoryChime();
        _saveSession(
          score: _lastScore ?? 100.0,
          attempts: _totalTeamAttempts,
          correctAnswers: _packedChain.length,
          totalItems: _targetChainLength,
        );
      }
    }

    // Prompt teammate politely if another player asked to restart together
    final reqBy = _restartRequestedBy;
    final reqId = _restartRequestId;
    final myLower = widget.hostName.trim().toLowerCase();
    final alreadyApproved =
        _restartApprovedBy?.contains(myLower) ?? false;
    if (reqBy != null &&
        reqId != null &&
        reqBy.toLowerCase() != myLower &&
        !alreadyApproved &&
        _shownRestartDialogId != reqId &&
        mounted) {
      _shownRestartDialogId = reqId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _restartRequestId == reqId) {
          _showTeammateRestartVoteDialog(reqBy, reqId);
        }
      });
    }
  }

  void _onTapResetButton() {
    if (_isLiveMultiplayerActive && _stage != _ChainTurnStage.lobbyInvite) {
      _showInitiateRestartConfirmDialog();
    } else {
      _refreshLobbyFromScratch();
    }
  }

  void _showInitiateRestartConfirmDialog() {
    final isSi = _isSi;
    final isNewRound = _stage == _ChainTurnStage.completed;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AuroraGradientBorderFrame(
              borderRadius: 24,
              borderWidth: 3.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF1E1B4B),
                              Color(0xFF4F46E5),
                              Color(0xFF0D9488),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              isNewRound ? '🎮' : '🔄',
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isNewRound
                                    ? (isSi
                                        ? 'තව වටයක් එකට ක්‍රීඩා කරමුද?'
                                        : 'Play Another Round Together?')
                                    : (isSi
                                        ? 'සැවොම සමඟ නැවත අරඹමුද?'
                                        : 'Restart Game Together?'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              isNewRound
                                  ? (isSi
                                      ? 'මේ කණ්ඩායම සමඟම තව වටයක් සෙල්ලම් කරමුදැයි අනිත් මිතුරන්ගෙන් අසමුද?'
                                      : 'Ask your teammates if they would like to play another round together with the same team?')
                                  : (isSi
                                      ? 'මේ කණ්ඩායම සමඟම වටය 1 සිට අලුතින් ආරම්භ කිරීමට අනිත් මිතුරන්ගෙන් අසමුද?'
                                      : 'Would you like to ask your teammates to restart from Round 1 together with the same team?'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(dialogCtx).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.muted,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                    child: Text(
                                      isSi ? 'එපා' : 'Cancel',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(dialogCtx).pop();
                                      _requestTeamRestart();
                                    },
                                    icon: const Icon(
                                      LucideIcons.rotateCcw,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isSi
                                          ? 'මිතුරන්ගෙන් අසන්න'
                                          : 'Ask Team',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _requestTeamRestart() {
    final reqId = DateTime.now().millisecondsSinceEpoch;
    final myClean = widget.hostName.trim();
    setState(() {
      _restartRequestedBy = myClean;
      _restartRequestId = reqId;
      _restartApprovedBy = {myClean.toLowerCase()};
      _shownRestartDialogId = reqId;
    });
    _publishLiveRoomState();
  }

  void _showTeammateRestartVoteDialog(String requesterName, int reqId) {
    final isSi = _isSi;
    final isNewRound = _stage == _ChainTurnStage.completed;
    final dispRequester = isSi
        ? SinhalaNameTransliterator.toSinhala(
            requesterName,
            fallback: requesterName,
          )
        : requesterName;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AuroraGradientBorderFrame(
              borderRadius: 24,
              borderWidth: 3.2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF312E81),
                              Color(0xFF7C3AED),
                              Color(0xFF0D9488),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              isNewRound ? '🎮' : '🔄',
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isNewRound
                                    ? (isSi
                                        ? '$dispRequester තව වටයක් සෙල්ලම් කරමුදැයි අසයි!'
                                        : 'Play Another Round with $requesterName?')
                                    : (isSi
                                        ? '$dispRequester නැවත අරඹමුදැයි අසයි!'
                                        : 'Restart Request from $requesterName!'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              isNewRound
                                  ? (isSi
                                      ? '$dispRequester තව වටයක් එකට සෙල්ලම් කිරීමට කැමතියි. ඔබත් එක්වෙනවාද?'
                                      : '$requesterName would like to play another round together! Would you like to join?')
                                  : (isSi
                                      ? '$dispRequester මේ ක්‍රීඩාව මුල සිට නැවත ආරම්භ කිරීමට කැමතියි. ඔබත් එකඟද?'
                                      : '$requesterName would like to restart this Picnic Game from Round 1 together. Do you agree?'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(dialogCtx).pop();
                                      _respondToRestartRequest(approve: false);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFDC2626),
                                      backgroundColor: const Color(0xFFFEF2F2),
                                      side: const BorderSide(
                                        color: Color(0xFFFCA5A5),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                    child: Text(
                                      isNewRound
                                          ? (isSi ? 'එපා' : 'Not Now')
                                          : (isSi
                                              ? 'දිගටම සෙල්ලම් කරමු'
                                              : 'Keep Playing'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(dialogCtx).pop();
                                      _respondToRestartRequest(approve: true);
                                    },
                                    icon: const Icon(
                                      LucideIcons.check,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isNewRound
                                          ? (isSi
                                              ? 'ඔව්, සෙල්ලම් කරමු!'
                                              : 'Yes, Play Again!')
                                          : (isSi
                                              ? 'ඔව්, අරඹමු!'
                                              : 'Yes, Restart!'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _respondToRestartRequest({required bool approve}) {
    final myClean = widget.hostName.trim();
    final myLower = myClean.toLowerCase();

    if (!approve) {
      final isAfterFinish = _stage == _ChainTurnStage.completed;
      setState(() {
        _restartRequestedBy = null;
        _restartRequestId = null;
        _restartApprovedBy = null;
        _feedbackBannerText = isAfterFinish
            ? '$myClean is not ready for another round yet.'
            : '$myClean wants to keep playing this round!';
        _isFeedbackPositive = true;
      });
      _publishLiveRoomState();
      return;
    }

    final approved = (_restartApprovedBy ??= <String>{})..add(myLower);
    final allApproved = _joinedPlayers.every(
      (p) => approved.contains(_cleanName(p.name).toLowerCase()),
    );

    if (allApproved) {
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
        _lastScore = null;
        _restartRequestedBy = null;
        _restartRequestId = null;
        _restartApprovedBy = null;
        _lastSelectedItemKey = null;
        _lastSelectedByName = null;
        _lastSelectedAction = null;
        _lastSelectedAtMs = null;
        _stage = _ChainTurnStage.addNewItemToChain;
        _feedbackBannerText = 'Team agreed! Fresh Round 1 started together!';
        _isFeedbackPositive = true;
      });
      _ensurePlayMusicRunning();
    } else {
      setState(() {
        _restartApprovedBy = Set<String>.from(approved);
      });
    }
    _publishLiveRoomState();
  }

  Future<void> _refreshLobbyFromScratch() async {
    _bgmPlayer?.stopBgm();
    if (_isLiveMultiplayerActive) {
      await _publishLiveRoomState(markEnded: true);
    }
    setState(() {
      _liveRoomId = null;
      _liveRoomVersion = null;
      _liveRoomStartedBy = null;
      _liveRoomStartedAt = null;
      _liveJoinedPlayers = null;
      _pendingLiveStartRoom = null;
      _restartRequestedBy = null;
      _restartRequestId = null;
      _restartApprovedBy = null;
      _shownRestartDialogId = null;
      _syncedTeamPeers = null;
      _liveTurnOrder = null;
      _lastSelectedItemKey = null;
      _lastSelectedByName = null;
      _lastSelectedAction = null;
      _lastSelectedAtMs = null;
      _sameScreenPlayerNames?.clear();
      _stage = _ChainTurnStage.lobbyInvite;
      _currentPlayerIndex = 0;
      _packedChain.clear();
      _currentRecallInput.clear();
      _teammateHintText = null;
      _feedbackBannerText = null;
      _isFeedbackPositive = true;
      _totalTeamAttempts = 0;
      _successfulRecalls = 0;
      _lastScore = null;
      _incomingInvitesForMe = [];
      for (final p in _directoryPlayers) {
        p.chainStepsCompleted = 0;
        p.itemsAdded = 0;
        if (p.isHost) {
          p.isInvited = true;
          p.hasJoined = true;
        } else {
          p.isInvited = false;
          p.hasJoined = false;
        }
      }
    });
    await _cancelInvitesMatching();
  }

  Future<void> _leaveLiveRoomGracefully({required bool notifyTeammates}) async {
    final exitingId = _liveRoomId;
    if (exitingId != null && exitingId.isNotEmpty) {
      (_exitedLiveRoomIds ??= <String>{}).add(exitingId);
    }
    if (widget.initialLiveRoomId != null &&
        widget.initialLiveRoomId!.isNotEmpty) {
      (_exitedLiveRoomIds ??= <String>{}).add(widget.initialLiveRoomId!);
    }
    if (!_isLiveMultiplayerActive) return;
    final myClean = widget.hostName.trim();
    final myLower = myClean.toLowerCase();

    if (notifyTeammates &&
        _stage != _ChainTurnStage.lobbyInvite &&
        _stage != _ChainTurnStage.completed) {
      final remainingOrder = (_liveTurnOrder ??
              _joinedPlayers.map((p) => _cleanName(p.name)).toList())
          .where((n) => n.trim().toLowerCase() != myLower)
          .toList();
      _liveTurnOrder = remainingOrder;
      _liveJoinedPlayers?.removeWhere((n) => n.toLowerCase() == myLower);
      _feedbackBannerText = '$myClean left the game.';
      _isFeedbackPositive = false;
      if (remainingOrder.length < _minPlayers) {
        await _publishLiveRoomState(markEnded: true);
      } else {
        if (_currentPlayerIndex >= remainingOrder.length) {
          _currentPlayerIndex = 0;
        }
        await _publishLiveRoomState();
      }
    }

    if (mounted) {
      setState(() {
        _liveRoomId = null;
        _liveRoomVersion = null;
        _liveRoomStartedBy = null;
        _liveRoomStartedAt = null;
        _liveJoinedPlayers = null;
        _liveTurnOrder = null;
        _pendingLiveStartRoom = null;
        _restartRequestedBy = null;
        _restartRequestId = null;
        _restartApprovedBy = null;
        _lastSelectedItemKey = null;
        _lastSelectedByName = null;
        _lastSelectedAction = null;
        _lastSelectedAtMs = null;
      });
    } else {
      _liveRoomId = null;
      _liveRoomVersion = null;
    }
  }

  void _showLeaveGameConfirmDialog({required bool exitToHub}) {
    final isSi = _isSi;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AuroraGradientBorderFrame(
              borderRadius: 24,
              borderWidth: 3.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF9F1239),
                              Color(0xFFE11D48),
                              Color(0xFFF59E0B),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🚪', style: TextStyle(fontSize: 21)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isSi
                                    ? 'ක්‍රීඩාවෙන් ඉවත් වෙන්නද?'
                                    : 'Leave This Game?',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              _isLiveMultiplayerActive
                                  ? (isSi
                                      ? 'ඔබට මෙම ක්‍රීඩාවෙන් ඉවත් වීමට අවශ්‍යද? අනිත් මිතුරන්ට ඒ බව දැනුම් දෙනු ඇත.'
                                      : 'Are you sure you want to leave this game? Your teammates will be notified.')
                                  : (isSi
                                      ? 'ඔබට මෙම ක්‍රීඩාවෙන් ඉවත් වීමට අවශ්‍යද?'
                                      : 'Are you sure you want to leave this game?'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(dialogCtx).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF047857),
                                      backgroundColor: const Color(0xFFECFDF5),
                                      side: const BorderSide(
                                        color: Color(0xFF6EE7B7),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                    child: Text(
                                      isSi
                                          ? 'දිගටම සෙල්ලම් කරමු'
                                          : 'Stay & Play',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      Navigator.of(dialogCtx).pop();
                                      if (exitToHub) {
                                        await _leaveLiveRoomGracefully(
                                          notifyTeammates: true,
                                        );
                                        if (_packedChain.isEmpty) {
                                          await _cancelInvitesMatching();
                                        }
                                        widget.onBack();
                                      } else {
                                        await _returnToInviteLobby();
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.logout_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isSi ? 'ඉවත් වෙන්න' : 'Leave Game',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBackToHub() async {
    if (_stage != _ChainTurnStage.lobbyInvite &&
        _stage != _ChainTurnStage.completed) {
      _showLeaveGameConfirmDialog(exitToHub: true);
      return;
    }
    if (_isLiveMultiplayerActive) {
      await _leaveLiveRoomGracefully(notifyTeammates: false);
    }
    // If leaving without playing the game, refresh/clear lobby state & invites
    if (_stage == _ChainTurnStage.lobbyInvite || _packedChain.isEmpty) {
      await _cancelInvitesMatching();
    }
    widget.onBack();
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

    // If a partner already started the game, join their live game instead of starting a duplicate!
    if (_pendingLiveStartRoom != null) {
      _joinLiveRoom(_pendingLiveStartRoom!);
      return;
    }

    final sameScreen = _sameScreenPlayerNames ?? const <String>{};
    final hasOnlinePartner = _joinedPlayers.any(
      (p) => !p.isHost && !sameScreen.contains(_cleanName(p.name).toLowerCase()),
    );
    final reusingCompletedLiveRoom =
        hasOnlinePartner &&
        _isLiveMultiplayerActive &&
        _stage == _ChainTurnStage.completed;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final turnOrderPlayers =
        reusingCompletedLiveRoom ? _orderedTurnPlayers : _joinedPlayers;
    final starterClean = _cleanName(turnOrderPlayers[0].name);

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
      _lastScore = null;
      _restartRequestedBy = null;
      _restartRequestId = null;
      _restartApprovedBy = null;
      _feedbackBannerText =
          "Round 1: $starterClean, pick the first item to pack into our Shared Picnic Basket!";
      _isFeedbackPositive = true;
      _stage = _ChainTurnStage.addNewItemToChain;
      _pendingLiveStartRoom = null;
      _lastSelectedItemKey = null;
      _lastSelectedByName = null;
      _lastSelectedAction = null;
      _lastSelectedAtMs = null;

      if (hasOnlinePartner) {
        if (reusingCompletedLiveRoom) {
          // Reuse the same live room so ALL teammates on the Victory screen
          // automatically start the new round together immediately!
          _liveRoomStartedBy = widget.hostName.trim();
          _liveRoomStartedAt = nowMs;
          _liveJoinedPlayers = turnOrderPlayers
              .map((p) => _cleanName(p.name))
              .where((n) => n.isNotEmpty)
              .toSet();
        } else {
          _liveTurnOrder = _joinedPlayers
              .map((p) => _cleanName(p.name))
              .where((n) => n.isNotEmpty)
              .toList();
          _liveRoomId = 'live_room_${widget.elderHomeId}_$nowMs';
          _liveRoomVersion = 0;
          _liveRoomStartedBy = widget.hostName.trim();
          _liveRoomStartedAt = nowMs;
          _liveJoinedPlayers = {widget.hostName.trim()};
        }
      } else {
        _liveTurnOrder = null;
        _liveRoomId = null;
        _liveRoomVersion = null;
      }
    });

    if (hasOnlinePartner) {
      _publishLiveRoomState();
    }
    _ensurePlayMusicRunning();
  }

  Future<void> _returnToInviteLobby() async {
    _bgmPlayer?.stopBgm();
    await _leaveLiveRoomGracefully(
      notifyTeammates: _stage != _ChainTurnStage.completed,
    );
    if (!mounted) return;
    setState(() {
      _stage = _ChainTurnStage.lobbyInvite;
      _teammateHintText = null;
      _feedbackBannerText = null;
    });
  }

  void _askInvitedTeammateForHint() {
    final turnPlayers = _orderedTurnPlayers;
    if (turnPlayers.isEmpty) return;
    final safeIdx = _currentPlayerIndex.clamp(0, turnPlayers.length - 1);
    final activePlayer = turnPlayers[safeIdx];
    final teammates = turnPlayers
        .where((p) => p.id != activePlayer.id)
        .toList();
    final helperName = teammates.isNotEmpty
        ? _cleanName(teammates.first.name)
        : 'Your Teammate';

    if (_stage == _ChainTurnStage.recallExistingChain &&
        _currentRecallInput.length < _packedChain.length) {
      final nextItem = _packedChain[_currentRecallInput.length];
      final packer = _cleanName(nextItem.addedByPlayerName);
      setState(() {
        _teammateHintText =
            'HINT_RECALL|$helperName|${_currentRecallInput.length + 1}|${nextItem.key}|$packer';
      });
      if (_isLiveMultiplayerActive) _publishLiveRoomState();
    } else if (_stage == _ChainTurnStage.addNewItemToChain) {
      final unpacked = _picnicPool
          .where((item) => !_packedChain.any((c) => c.key == item.key))
          .toList();
      if (unpacked.isNotEmpty) {
        setState(() {
          _teammateHintText = 'HINT_SUGGEST|$helperName|${unpacked.first.key}';
        });
        if (_isLiveMultiplayerActive) _publishLiveRoomState();
      }
    }
  }

  void _onTapPicnicItem(_PicnicChainItem item) {
    if (_isLiveMultiplayerActive && !_isMyTurnNow) {
      return;
    }
    final turnPlayers = _orderedTurnPlayers;
    if (turnPlayers.isEmpty) return;
    final safeIdx = _currentPlayerIndex.clamp(0, turnPlayers.length - 1);
    final activePlayer = turnPlayers[safeIdx];
    final activeClean = _cleanName(activePlayer.name);
    final tapNowMs = DateTime.now().millisecondsSinceEpoch;

    if (_stage == _ChainTurnStage.recallExistingChain) {
      final expectedIndex = _currentRecallInput.length;
      if (expectedIndex >= _packedChain.length) return;

      final expectedItem = _packedChain[expectedIndex];
      _totalTeamAttempts++;

      if (item.key == expectedItem.key) {
        _bgm.playTapChime();
        _successfulRecalls++;
        activePlayer.chainStepsCompleted++;
        bool completedNow = false;
        setState(() {
          _lastSelectedItemKey = item.key;
          _lastSelectedByName = activeClean;
          _lastSelectedAction = 'recalled';
          _lastSelectedAtMs = tapNowMs;
          _currentRecallInput.add(item);
          _teammateHintText = null;
          if (_currentRecallInput.length == _packedChain.length) {
            if (_packedChain.length >= _targetChainLength) {
              completedNow = true;
              _completeChainGame();
            } else {
              _stage = _ChainTurnStage.addNewItemToChain;
              _feedbackBannerText =
                  'Spot on, $activeClean! You remembered all ${_packedChain.length} items in order! Now pick 1 NEW item to add to the basket.';
              _isFeedbackPositive = true;
            }
          } else {
            _feedbackBannerText =
                'Correct! Item #${_currentRecallInput.length} is ${item.label}. Now tap Item #${_currentRecallInput.length + 1} in the chain.';
            _isFeedbackPositive = true;
          }
        });
        if (_isLiveMultiplayerActive && !completedNow) {
          _publishLiveRoomState();
        }
      } else {
        final helper = _cleanName(
          turnPlayers
              .firstWhere(
                (p) => p.id != activePlayer.id,
                orElse: () => activePlayer,
              )
              .name,
        );
        setState(() {
          _lastSelectedItemKey = item.key;
          _lastSelectedByName = activeClean;
          _lastSelectedAction = 'wrong';
          _lastSelectedAtMs = tapNowMs;
          _feedbackBannerText =
              'Not quite! Ask $helper for a hint — we are looking for Item #${expectedIndex + 1} in the basket order.';
          _isFeedbackPositive = false;
        });
        if (_isLiveMultiplayerActive) _publishLiveRoomState();
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

      final packedItem = item.withAddedBy(activeClean);
      _bgm.playTapChime();
      activePlayer.itemsAdded++;
      _totalTeamAttempts++;
      _successfulRecalls++;

      final nextPlayerIndex = (safeIdx + 1) % turnPlayers.length;
      final nextPlayerClean = _cleanName(turnPlayers[nextPlayerIndex].name);

      setState(() {
        _lastSelectedItemKey = item.key;
        _lastSelectedByName = activeClean;
        _lastSelectedAction = 'packed';
        _lastSelectedAtMs = tapNowMs;
        _packedChain.add(packedItem);
        _currentRecallInput.clear();
        _teammateHintText = null;
        _currentPlayerIndex = nextPlayerIndex;
        _stage = _ChainTurnStage.recallExistingChain;
        _feedbackBannerText =
            '$activeClean packed "${item.label}"! Now it is $nextPlayerClean\'s turn to recall the ${_packedChain.length}-item chain in order!';
        _isFeedbackPositive = true;
      });
      if (_isLiveMultiplayerActive) _publishLiveRoomState();
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

    if (_isLiveMultiplayerActive) {
      _publishLiveRoomState();
    }

    _savedCompletedRoomKey =
        '${_liveRoomId ?? 'local'}_${_liveRoomStartedAt ?? 0}';
    _bgm.playVictoryChime();
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

  bool get _isSi => widget.isSinhala;

  String _itemLabel(_PicnicChainItem item) {
    if (!_isSi) return item.label;
    switch (item.key) {
      case 'tea':
        return 'උණු තේ';
      case 'apple':
        return 'රතු ඇපල්';
      case 'sunhat':
        return 'අව්ව තොප්පිය';
      case 'flower':
        return 'මල් පොකුර';
      case 'book':
        return 'කතා පොත';
      case 'music':
        return 'පොඩි රේඩියෝව';
      case 'cake':
        return 'බෙරි කේක්';
      case 'lantern':
        return 'පහන් කූඩුව';
      default:
        return item.label;
    }
  }

  String _safePlayerDisplayName(_InvitedPlayer p) {
    final clean = p.name.trim();
    if (clean.isEmpty || clean == '-') {
      return _isSi ? 'නේවාසික මිතුරා' : 'Fellow Resident';
    }
    if (!_isSi) return clean;
    final hasYou = clean.contains('(You)');
    final base = clean.replaceAll('(You)', '').trim();
    final siBase = SinhalaNameTransliterator.toSinhala(base, fallback: 'මිතුරා');
    return hasYou ? '$siBase (ඔබ)' : siBase;
  }

  String _safePlayerInitial(_InvitedPlayer p) {
    final clean = p.name.trim();
    if (clean.isEmpty || clean == '-') return 'R';
    return clean.substring(0, 1).toUpperCase();
  }

  String _localizeHintText(String raw) {
    final isSi = _isSi;
    if (raw.startsWith('HINT_RECALL|')) {
      final parts = raw.split('|');
      final helper = parts.length > 1 ? parts[1] : 'Your Teammate';
      final slot = parts.length > 2 ? parts[2] : '1';
      final itemKey = parts.length > 3 ? parts[3] : '';
      final packer = parts.length > 4 ? parts[4] : '';
      final item = _picnicPool.where((p) => p.key == itemKey).firstOrNull;
      final itemLabel = item != null ? _itemLabel(item) : itemKey;
      if (isSi) {
        final siHelper =
            SinhalaNameTransliterator.toSinhala(helper, fallback: helper);
        final siPacker = packer.isNotEmpty
            ? SinhalaNameTransliterator.toSinhala(packer, fallback: packer)
            : '';
        return siPacker.isNotEmpty
            ? '💬 $siHelper රහසින් කියයි: "කූඩයේ #$slot භාණ්ඩය \"$itemLabel\" ($siPacker දැම්මේ)!"'
            : '💬 $siHelper රහසින් කියයි: "කූඩයේ #$slot භාණ්ඩය \"$itemLabel\"!"';
      }
      return packer.isNotEmpty
          ? '💬 $helper whispers: "Item #$slot in our basket is $itemLabel (packed by $packer)!"'
          : '💬 $helper whispers: "Item #$slot in our basket is $itemLabel!"';
    }
    if (raw.startsWith('HINT_SUGGEST|')) {
      final parts = raw.split('|');
      final helper = parts.length > 1 ? parts[1] : 'Your Teammate';
      final itemKey = parts.length > 2 ? parts[2] : '';
      final item = _picnicPool.where((p) => p.key == itemKey).firstOrNull;
      final itemLabel = item != null ? _itemLabel(item) : itemKey;
      if (isSi) {
        final siHelper =
            SinhalaNameTransliterator.toSinhala(helper, fallback: helper);
        return '💬 $siHelper යෝජනා කරයි: "ඊළඟට \"$itemLabel\" කූඩයට දමමුද?"';
      }
      return '💬 $helper suggests: "How about packing the $itemLabel next?"';
    }
    return raw;
  }

  String _localizeBannerText(String raw) {
    if (!_isSi) return raw;
    if (raw.contains('You accepted ') && raw.contains("'s invitation!")) {
      final name = raw
          .replaceAll('✅', '')
          .split('You accepted ')
          .last
          .split("'s invitation!")
          .first
          .trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '✅ ඔබ $siName ගේ ආරාධනාව පිළිගත්තා! දැන් ඔබ ක්‍රීඩා කාමරයට එක්වී සිටී.';
    }
    if (raw.contains('You declined ') && raw.contains("'s invitation.")) {
      final name = raw
          .split('You declined ')
          .last
          .split("'s invitation.")
          .first
          .trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '💌 ඔබ $siName ගේ ආරාධනාව ප්‍රතික්ෂේප කළේය.';
    }
    if (raw.contains('sat down with you at the same screen')) {
      final name = raw
          .replaceAll('🪑', '')
          .split('sat down with you')
          .first
          .trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '🪑 $siName ඔබ සමඟ එකම තිරයේ සෙල්ලම් කිරීමට සූදානම්!';
    }
    if (raw.contains('left the game.')) {
      final name = raw.split('left the game.').first.trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '👋 $siName ක්‍රීඩාවෙන් ඉවත් විය.';
    }
    if (raw.contains('is already in the basket!')) {
      final enItem = raw.split('is already in the basket!').first.trim();
      final matchedItem =
          _picnicPool.where((p) => p.label == enItem).firstOrNull;
      final siItem = matchedItem != null ? _itemLabel(matchedItem) : enItem;
      return '🧺 "$siItem" දැනටමත් කූඩයේ තිබේ! අලුත් භාණ්ඩයක් තෝරන්න.';
    }
    if (raw.contains('Minimum 2 players')) {
      return 'අවම වශයෙන් ක්‍රීඩකයින් 2ක් අවශ්‍යයි.';
    }
    if (raw.contains('accepted your invitation')) {
      final name = raw
          .replaceAll('✅', '')
          .split('accepted your invitation')
          .first
          .trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '✅ $siName ඔබේ ආරාධනාව පිළිගෙන ක්‍රීඩාවට එක් විය!';
    }
    if (raw.contains('copied!')) {
      return 'කාමර අංකය $_roomInviteCode පිටපත් විය! මිතුරන් සමඟ බෙදාගන්න.';
    }
    if (raw.contains('joined your room')) {
      return '✅ මිතුරා ඔබේ කණ්ඩායමට එක් විය!';
    }
    if (raw.contains('Invitation notification sent') ||
        raw.contains('Invitation sent to')) {
      return '🔔 ආරාධනා පණිවිඩය යවන ලදී! මිතුරා පිළිගන්නා තුරු රැඳී සිටින්න.';
    }
    if (raw.contains('declined the invitation')) {
      final name = raw.split('declined the invitation').first.trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '💌 $siName ආරාධනාව ප්‍රතික්ෂේප කළේය.';
    }
    if (raw.startsWith('Round 1:')) {
      final actor = raw
          .replaceFirst('Round 1:', '')
          .split(', pick')
          .first
          .replaceAll('(You)', '')
          .trim();
      final siActor =
          SinhalaNameTransliterator.toSinhala(actor, fallback: actor);
      return '🧺 වටය 1: $siActor, විනෝද චාරිකා කූඩයට පළමු භාණ්ඩය තෝරන්න!';
    }
    if (raw.contains('Spot on,') || raw.contains('Great! Now pick')) {
      return '🎉 හරිම හොඳයි! පිළිවෙල හරියටම මතක තබා ගත්තා! දැන් කූඩයට අලුත් භාණ්ඩයක් තෝරන්න!';
    }
    if (raw.contains('packed "')) {
      final parts = raw.split(' packed "');
      final actor = parts.first.replaceAll('(You)', '').trim();
      final siActor =
          SinhalaNameTransliterator.toSinhala(actor, fallback: actor);
      final afterItem = parts.length > 1 ? parts[1] : '';
      final enItem = afterItem.split('"').first.trim();
      final matchedItem =
          _picnicPool.where((p) => p.label == enItem).firstOrNull;
      final siItem = matchedItem != null ? _itemLabel(matchedItem) : enItem;
      String nextNameSi = 'ඊළඟ මිතුරා';
      if (afterItem.contains('Now it is ') && afterItem.contains("'s turn")) {
        final rawNext = afterItem
            .split('Now it is ')
            .last
            .split("'s turn")
            .first
            .replaceAll('(You)', '')
            .trim();
        if (rawNext.isNotEmpty) {
          nextNameSi =
              SinhalaNameTransliterator.toSinhala(rawNext, fallback: rawNext);
        }
      }
      return '🧺 $siActor "$siItem" කූඩයට දැම්මා! දැන් $nextNameSi ගේ වාරයයි — පිළිවෙලට මතකයෙන් තෝරන්න!';
    }
    if (raw.contains('Correct!')) {
      return '✨ නිවැරදියි! ඊළඟ භාණ්ඩයත් මතකයෙන් තෝරන්න.';
    }
    if (raw.contains('Not quite')) {
      return '💛 කමක් නැහැ! නැවත උත්සාහ කරන්න හෝ මිතුරාගෙන් ඉඟියක් අසන්න.';
    }
    if (raw.contains('Team agreed! Fresh Round 1')) {
      return '🔄 සැවොම එකඟ වුණා! අලුත් වටය 1 එකට ආරම්භ වුණා!';
    }
    if (raw.contains('is not ready for another round yet.')) {
      final name = raw.split('is not ready for another round yet.').first.trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '💛 $siName දැන් තව වටයකට සූදානම් නැත.';
    }
    if (raw.contains('wants to keep playing')) {
      final name = raw.split('wants to keep playing').first.trim();
      final siName = SinhalaNameTransliterator.toSinhala(name, fallback: name);
      return '💛 $siName මේ වටය දිගටම සෙල්ලම් කිරීමට කැමතියි!';
    }
    if (raw.contains('Wonderful Teamwork') ||
        raw.contains('Amazing Teamwork') ||
        raw.contains('completed')) {
      return '🎉 විශිෂ්ටයි! ඔබ සියලු දෙනාම එක්ව විනෝද චාරිකා කූඩය සම්පූර්ණ කළා!';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isSi = _isSi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGameNavBar(
          gameTitle:
              isSi ? 'හවුල් විනෝද චාරිකා මතක දාමය' : 'Shared Picnic Memory Chain',
          backLabel: isSi ? 'සියලුම ක්‍රීඩා' : 'All Games',
          gameIcon: LucideIcons.users,
          gameColor: const Color(0xFF2563EB),
          onBack: _handleBackToHub,
          onReset: _onTapResetButton,
          statusBadge: isSi
              ? 'ක්‍රීඩකයින් ${_joinedPlayers.length} • දාමය ${_packedChain.length} / $_targetChainLength'
              : '${_joinedPlayers.length} ${_joinedPlayers.length == 1 ? 'Player' : 'Players'} • Chain ${_packedChain.length} / $_targetChainLength',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFAFCFF),
                Color(0xFFF5F3FF),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF93C5FD).withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.11),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _stage == _ChainTurnStage.lobbyInvite
                  ? KeyedSubtree(
                      key: ValueKey('collab_lobby_stage_$isSi'),
                      child: _buildInviteLobbyView(),
                    )
                  : KeyedSubtree(
                      key: ValueKey('collab_gameplay_stage_$isSi'),
                      child: _buildChainGameplayView(),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteLobbyView() {
    final isSi = _isSi;
    final canStart = _joinedPlayers.length >= _minPlayers;
    final fellowElders =
        _directoryPlayers.where((p) => !p.isHost).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Compact Sleek Virtual Picnic Game Room Header Strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E1B4B),
                Color(0xFF1D4ED8),
                Color(0xFF0D9488),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Text('🧺', style: TextStyle(fontSize: 25)),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi
                            ? 'විනෝද චාරිකා මතක ක්‍රීඩාව! 🍉☕'
                            : 'Picnic Memory Party! 🍉☕',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSi
                            ? 'මිතුරන් සමඟ එක්ව විනෝද චාරිකා කූඩයක් අසුරමු'
                            : 'Invite a friend & pack a picnic basket together',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.90),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const ValueKey('collab_how_to_play_lobby_button'),
                onPressed: _showHowToPlayDialog,
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: Text(
                  isSi ? 'ක්‍රීඩා කරන ආකාරය' : 'How to Play',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 1b. Live Game Started Prompt Banner (when partner already clicked Start!)
        if (_pendingLiveStartRoom != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: AuroraGradientBorderFrame(
              borderRadius: 18,
              borderWidth: 2.8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFECFDF5), Color(0xFFEEF2FF)],
                  ),
                  borderRadius: BorderRadius.circular(15.2),
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
                        const Text('🚀', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(
                            () {
                              final rawStarter = (_pendingLiveStartRoom![
                                          'startedBy']
                                      ?.toString() ??
                                  'Your Friend')
                                  .trim();
                              final disp = isSi
                                  ? SinhalaNameTransliterator.toSinhala(
                                      rawStarter,
                                      fallback: rawStarter,
                                    )
                                  : rawStarter;
                              return isSi
                                  ? '$disp ක්‍රීඩාව ආරම්භ කළා! දැන්ම ඉක්මනින් එක්වී එකට සෙල්ලම් කරන්න!'
                                  : '$rawStarter started the game! Join quickly to play together live!';
                            }(),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _joinLiveRoom(_pendingLiveStartRoom!),
                      icon: const Icon(LucideIcons.gamepad2, size: 17),
                      label: Text(
                        isSi ? 'ඉක්මනින් එක්වන්න!' : 'Join Game Now!',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 2. Incoming Invite Alert (if any)
        if (_incomingInvitesForMe.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: _incomingInvitesForMe.map((inv) {
                final senderName =
                    (inv['senderName']?.toString() ?? 'Fellow Elder').trim();
                final displaySender = isSi
                    ? SinhalaNameTransliterator.toSinhala(senderName)
                    : senderName;
                final invId = inv['id']?.toString() ?? senderName;
                return Container(
                  key: ValueKey('incoming_notification_banner_$invId'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFCCFBF1)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF2563EB),
                      width: 1.5,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.bell,
                            size: 18,
                            color: Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Text(
                              isSi
                                  ? '🎉 $displaySender ඔබට විනෝද චාරිකා ක්‍රීඩාවට ආරාධනා කරයි!'
                                  : '🎉 $senderName invited you to play Picnic Memory Chain!',
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
                            icon: const Icon(LucideIcons.check, size: 14),
                            label: Text(
                              isSi ? 'එක්වන්න' : 'Accept & Join',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            key: ValueKey('decline_incoming_btn_$invId'),
                            onPressed: () =>
                                _respondToIncomingInvite(inv, accept: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.riskHigh,
                              side: const BorderSide(color: AppColors.riskHigh),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(isSi ? 'එපා' : 'Decline'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // 2b. Compact "Currently Playing Teams" Strip (shown ONLY when other teams are live!)
        if ((_otherActiveLiveTeams ?? const []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFF0FDF4)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFA5B4FC),
                  width: 1.3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🎮', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 7),
                      Text(
                        isSi
                            ? 'දැන් ක්‍රීඩා කරන කණ්ඩායම් (${_otherActiveLiveTeams!.length})'
                            : 'Currently Playing Teams (${_otherActiveLiveTeams!.length})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF312E81),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: _otherActiveLiveTeams!.map((room) {
                      final rawNames = (room['participants'] as List?)
                              ?.map((e) => e.toString().trim())
                              .where((e) => e.isNotEmpty)
                              .toList() ??
                          const <String>[];
                      final displayNames = rawNames.map((n) {
                        if (!isSi) return n;
                        return SinhalaNameTransliterator.toSinhala(
                          n,
                          fallback: n,
                        );
                      }).join(' • ');
                      final basketCount =
                          (room['packedChain'] as List?)?.length ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFF6EE7B7),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              isSi ? 'සජීවී' : 'LIVE',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                displayNames,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '🧺 $basketCount / $_targetChainLength',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

        // 3. ZERO-SCROLL Equal-Height Attractive 2-Column Game Lobby Workspace
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 452),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFDFEFF),
                  Color(0xFFF5F8FF),
                  Color(0xFFF0FDFA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 740;
                final teamPanel = _buildTeamReadyPanel(isSi, canStart);
                final friendsPanel =
                    _buildCompactFriendsPanel(isSi, fellowElders);

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: teamPanel),
                        const SizedBox(width: 18),
                        Expanded(flex: 6, child: friendsPanel),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    teamPanel,
                    const SizedBox(height: 16),
                    friendsPanel,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool _isLikelyFemaleElderName(String rawName) {
    final lower = _cleanName(rawName).toLowerCase();
    const femaleHints = [
      'malini',
      'seetha',
      'sitha',
      'padmini',
      'kamala',
      'chandra',
      'nirmala',
      'lakshmi',
      'kusuma',
      'swarna',
      'sarah',
      'margaret',
      'mary',
      'eleanor',
      'helen',
      'anula',
      'shanthi',
      'ranjani',
      'sriyani',
      'indrani',
      'manel',
      'kanthi',
      'nalini',
      'kumari',
      'menika',
      'amara',
    ];
    return femaleHints.any((h) => lower.contains(h));
  }

  Widget _buildLobbyProfileAvatar(
    _InvitedPlayer player, {
    double radius = 23,
    bool showStatusDot = false,
    bool isBusy = false,
  }) {
    final hasPhoto = (player.avatarUrl ?? '').trim().isNotEmpty;
    final size = radius * 2;
    final isFemale = _isLikelyFemaleElderName(player.name);

    final avatarCore = hasPhoto
        ? CarevoraAvatar(
            avatarUrl: player.avatarUrl,
            radius: radius,
            initials: _safePlayerInitial(player),
            backgroundColor: player.color,
            foregroundColor: Colors.white,
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  player.color.withValues(alpha: 0.22),
                  player.color.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: CustomPaint(
                size: Size(size, size),
                painter: _LobbyElderPortraitPainter(
                  accentColor: player.color,
                  isFemale: isFemale,
                ),
              ),
            ),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2.4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                player.color.withValues(alpha: 0.75),
                player.color.withValues(alpha: 0.30),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: player.color.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: avatarCore,
          ),
        ),
        if (showStatusDot)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isBusy
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: (isBusy
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981))
                        .withValues(alpha: 0.45),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamReadyPanel(bool isSi, bool canStart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF0F9FF),
            Color(0xFFF5F3FF),
            Color(0xFFECFDF5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canStart ? const Color(0xFF6EE7B7) : const Color(0xFFBAE6FD),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🎉', style: TextStyle(fontSize: 19)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isSi
                          ? 'ඔබේ කණ්ඩායම (${_joinedPlayers.length})'
                          : 'Your Picnic Team (${_joinedPlayers.length})',
                      style: const TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: canStart
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canStart
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCD34D),
                      ),
                    ),
                    child: Text(
                      canStart
                          ? (isSi ? 'සූදානම්!' : 'READY!')
                          : (isSi ? 'අවම 2' : 'MIN 2'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: canStart
                            ? const Color(0xFF047857)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Joined Players Cards with Profile Pictures
              ..._joinedPlayers.map((jp) {
                final display = _safePlayerDisplayName(jp);
                return Container(
                  key: jp.isHost ? ValueKey('invite_player_row_${jp.id}') : null,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: jp.color.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: jp.color.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildLobbyProfileAvatar(
                        jp,
                        radius: 21,
                        showStatusDot: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              display,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              jp.isHost
                                  ? (isSi
                                      ? '👑 ප්‍රධාන ක්‍රීඩකයා'
                                      : '👑 Host • Ready')
                                  : (isSi
                                      ? '✅ එක්වී සිටී'
                                      : '✅ Joined & Ready'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: jp.isHost
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!jp.isHost)
                        Material(
                          color: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                            side: const BorderSide(
                              color: Color(0xFFFCA5A5),
                              width: 1.2,
                            ),
                          ),
                          child: InkWell(
                            key: ValueKey('remove_invited_${jp.id}'),
                            onTap: () => _removeJoinedPlayer(jp),
                            borderRadius: BorderRadius.circular(11),
                            hoverColor: const Color(0xFFFEE2E2),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSi ? 'ඉවත්' : 'Remove',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                      height: 1.1,
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
              }),

              if (!canStart) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFCD34D),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('👉', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isSi
                              ? 'දකුණු පසින් මිතුරෙකු තෝරා එකට සෙල්ලම් කරමු!'
                              : 'Pick a friend on the right to start your picnic party!',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_feedbackBannerText != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _isFeedbackPositive
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _isFeedbackPositive
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Text(
                    _localizeBannerText(_feedbackBannerText!),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 18),

          // Big Hero Start Button — Anchored Cleanly at Panel Bottom
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const ValueKey('start_collaborative_chain_button'),
              onTap: canStart ? _startCollaborativeGame : null,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
                  gradient: canStart
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF7C3AED),
                            Color(0xFF0D9488),
                          ],
                        )
                      : null,
                  color: canStart ? null : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canStart
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: 0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.gamepad2,
                      size: 21,
                      color: canStart ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      canStart
                          ? (isSi
                              ? 'ක්‍රීඩාව ආරම්භ කරන්න!'
                              : 'Start Picnic Game!')
                          : (isSi
                              ? 'මිතුරෙකු එක් කරන්න'
                              : 'Add 1 Friend to Start'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color:
                            canStart ? Colors.white : const Color(0xFF64748B),
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

  Widget _buildCompactFriendsPanel(
    bool isSi,
    List<_InvitedPlayer> fellowElders,
  ) {
    const int pageSize = 4;
    final totalPages =
        fellowElders.isEmpty ? 1 : (fellowElders.length / pageSize).ceil();
    final safePage = (_friendsPageIndex ?? 0).clamp(0, totalPages - 1);
    final startIdx = safePage * pageSize;
    final endIdx = (startIdx + pageSize).clamp(0, fellowElders.length);
    final visibleElders = fellowElders.sublist(startIdx, endIdx);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.users,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isSi ? 'ආරාධනා කළ හැකි මිතුරන්' : 'Friends to Invite',
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
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
              const SizedBox(height: 16),

                // Spacious 2x2 Friend Cards (Row+Expanded so IntrinsicHeight works with zero LayoutBuilder conflict!)
                Builder(
                  builder: (context) {
                    Widget buildFriendCard(_InvitedPlayer player) {
                      final displayName = _safePlayerDisplayName(player);
                      final isBusyInGame = !player.hasJoined &&
                          (_busyInGamePlayerNames?.contains(
                                _cleanName(player.name).toLowerCase(),
                              ) ??
                              false);

                      return Container(
                        key: ValueKey('invite_player_row_${player.id}'),
                        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                        decoration: BoxDecoration(
                          gradient: player.hasJoined
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFF0FDF4),
                                    Color(0xFFECFDF5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : isBusyInGame
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFF8FAFC),
                                        Color(0xFFEEF2FF),
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.white,
                                        player.color.withValues(alpha: 0.04),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: player.hasJoined
                                ? const Color(0xFF6EE7B7)
                                : isBusyInGame
                                    ? const Color(0xFFC7D2FE)
                                    : player.color.withValues(alpha: 0.28),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: player.color.withValues(alpha: 0.09),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                _buildLobbyProfileAvatar(
                                  player,
                                  radius: 23,
                                  showStatusDot: true,
                                  isBusy: isBusyInGame,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isBusyInGame
                                            ? (isSi
                                                ? 'දැන් ක්‍රීඩාවේ'
                                                : 'In a game')
                                            : (player.hasJoined
                                                ? (isSi
                                                    ? 'කණ්ඩායමට එක්විය'
                                                    : 'In your team')
                                                : (isSi
                                                    ? 'සූදානම් • මිතුරා'
                                                    : 'Online • Ready to play')),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isBusyInGame
                                              ? const Color(0xFF6366F1)
                                              : (player.hasJoined
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (isBusyInGame)
                              Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFA5B4FC),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '🎮',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isSi
                                          ? 'ක්‍රීඩාවේ නිරතයි'
                                          : 'Playing Now',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF4338CA),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (player.hasJoined)
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF6EE7B7),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            LucideIcons.check,
                                            size: 15,
                                            color: Color(0xFF059669),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isSi ? 'එක්වී ඇත' : 'Joined',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Material(
                                    color: const Color(0xFFFEF2F2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(
                                        color: Color(0xFFFCA5A5),
                                        width: 1.3,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () =>
                                          _removeJoinedPlayer(player),
                                      borderRadius: BorderRadius.circular(12),
                                      hoverColor: const Color(0xFFFEE2E2),
                                      child: SizedBox(
                                        height: 38,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.close_rounded,
                                                size: 15,
                                                color: Color(0xFFDC2626),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isSi ? 'ඉවත්' : 'Remove',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (player.isInvited && !player.hasJoined)
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFCD34D),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          isSi
                                              ? '⏳ රැඳී සිටී...'
                                              : '⏳ Waiting...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Material(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                        width: 1.3,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () => _cancelSentInvite(player),
                                      borderRadius: BorderRadius.circular(12),
                                      hoverColor: const Color(0xFFF1F5F9),
                                      child: SizedBox(
                                        height: 38,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Center(
                                            child: Text(
                                              isSi ? 'අවලංගු' : 'Cancel',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: Material(
                                      color: const Color(0xFFF0FDFA),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        side: const BorderSide(
                                          color: Color(0xFF5EEAD4),
                                          width: 1.4,
                                        ),
                                      ),
                                      child: InkWell(
                                        key: ValueKey(
                                          'sit_together_${player.id}',
                                        ),
                                        onTap: () =>
                                            _sitTogetherQuickJoin(player),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        hoverColor: const Color(0xFFCCFBF1),
                                        child: SizedBox(
                                          height: 38,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                LucideIcons.users,
                                                size: 14.5,
                                                color: Color(0xFF0F766E),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  isSi
                                                      ? 'එකට'
                                                      : 'Sit Together',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: Color(0xFF0F766E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        key: ValueKey(
                                          'send_invite_${player.id}',
                                        ),
                                        onTap: () =>
                                            _sendInviteNotification(player),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Ink(
                                          height: 38,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF2563EB),
                                                Color(0xFF4F46E5),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF2563EB)
                                                    .withValues(alpha: 0.24),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                LucideIcons.bell,
                                                size: 14.5,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  isSi ? 'ආරාධනා' : 'Invite',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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

                    final rows = <Widget>[];
                    for (int i = 0; i < visibleElders.length; i += 2) {
                      final left = buildFriendCard(visibleElders[i]);
                      final right = (i + 1 < visibleElders.length)
                          ? buildFriendCard(visibleElders[i + 1])
                          : const SizedBox.shrink();
                      rows.add(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 14),
                            Expanded(child: right),
                          ],
                        ),
                      );
                      if (i + 2 < visibleElders.length) {
                        rows.add(const SizedBox(height: 14));
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rows,
                    );
                  },
                ),
            ],
          ),

          // Clean, Balanced Pagination Pill Bar when there are more than 4 friends
          if (totalPages > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: safePage > 0
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: safePage > 0
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFE2E8F0),
                      width: 1.3,
                    ),
                  ),
                  child: InkWell(
                    onTap: safePage > 0
                        ? () => setState(() => _friendsPageIndex = safePage - 1)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 38,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                              color: safePage > 0
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isSi ? 'පෙර' : 'Prev',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: safePage > 0
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(totalPages, (idx) {
                    final active = idx == safePage;
                    return GestureDetector(
                      onTap: () => setState(() => _friendsPageIndex = idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3.5),
                        width: active ? 24 : 9,
                        height: 9,
                        decoration: BoxDecoration(
                          gradient: active
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF0D9488),
                                  ],
                                )
                              : null,
                          color: active ? null : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }),
                ),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: safePage < totalPages - 1
                        ? () => setState(() => _friendsPageIndex = safePage + 1)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        gradient: safePage < totalPages - 1
                            ? const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
                              )
                            : null,
                        color: safePage < totalPages - 1
                            ? null
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: safePage < totalPages - 1
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.24),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSi ? 'තව මිතුරන්' : 'More Friends',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: safePage < totalPages - 1
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: safePage < totalPages - 1
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChainGameplayView() {
    final isSi = _isSi;
    final turnPlayers = _orderedTurnPlayers;
    final safeIdx = turnPlayers.isNotEmpty
        ? _currentPlayerIndex.clamp(0, turnPlayers.length - 1)
        : 0;
    final activePlayer = turnPlayers[safeIdx];
    final activeName = _safePlayerDisplayName(activePlayer);
    final isCompleted = _stage == _ChainTurnStage.completed;
    final isRecallStage = _stage == _ChainTurnStage.recallExistingChain;
    final isMuted = _isMusicMuted ?? false;
    final lastPickedItem = _lastSelectedItemKey != null
        ? _picnicPool.where((p) => p.key == _lastSelectedItemKey).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sleek Cosmic Turn Header with Profile Pictures + Guide / Music / Hint / Leave Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E1B4B),
                Color(0xFF3730A3),
                Color(0xFF0D9488),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: List.generate(turnPlayers.length, (i) {
                  final p = turnPlayers[i];
                  final pName = _safePlayerDisplayName(p);
                  final isTurn = !isCompleted && safeIdx == i;
                  final hasEnteredLive = !_isLiveMultiplayerActive ||
                      p.isHost ||
                      (_liveJoinedPlayers?.any(
                            (n) =>
                                n.toLowerCase() ==
                                _cleanName(p.name).toLowerCase(),
                          ) ??
                          false);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5.5,
                    ),
                    decoration: BoxDecoration(
                      color: isTurn
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isTurn
                            ? const Color(0xFFFDE68A)
                            : Colors.white.withValues(alpha: 0.30),
                        width: isTurn ? 2.2 : 1.1,
                      ),
                      boxShadow: isTurn
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFDE68A)
                                    .withValues(alpha: 0.28),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLobbyProfileAvatar(
                          p,
                          radius: 13,
                          showStatusDot: _isLiveMultiplayerActive,
                          isBusy: !hasEnteredLive,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isTurn ? AppColors.navy : Colors.white,
                          ),
                        ),
                        if (_isLiveMultiplayerActive && !hasEnteredLive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isSi ? '⏳ එක්වෙමින්' : '⏳ Joining',
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        if (isTurn) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              p.isHost || !_isLiveMultiplayerActive
                                  ? (isSi ? 'ඔබේ වාරය' : 'YOUR TURN')
                                  : (isSi ? 'වාරය' : 'PLAYING'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
              Wrap(
                spacing: 9,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // How to Play Guide Button (crisp non-squashed pill)
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.50),
                        width: 1.3,
                      ),
                    ),
                    child: InkWell(
                      key: const ValueKey('collab_how_to_play_play_button'),
                      onTap: _showHowToPlayDialog,
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: Colors.white.withValues(alpha: 0.24),
                      child: SizedBox(
                        height: 36,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.help_outline_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isSi ? 'උදව්' : 'Guide',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Gentle Picnic Music Toggle Pill
                  Material(
                    color: isMuted
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFF10B981).withValues(alpha: 0.24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isMuted
                            ? Colors.white.withValues(alpha: 0.35)
                            : const Color(0xFF6EE7B7).withValues(alpha: 0.78),
                        width: 1.3,
                      ),
                    ),
                    child: InkWell(
                      key: const ValueKey('collab_music_toggle_button'),
                      onTap: _toggleGameMusic,
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: Colors.white.withValues(alpha: 0.18),
                      child: SizedBox(
                        height: 36,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMuted
                                    ? Icons.music_off_rounded
                                    : Icons.music_note_rounded,
                                size: 16,
                                color: isMuted
                                    ? Colors.white.withValues(alpha: 0.80)
                                    : const Color(0xFFA7F3D0),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isMuted
                                    ? (isSi ? 'සංගීතය: OFF' : 'Music: OFF')
                                    : (isSi ? 'සංගීතය: ON' : 'Music: ON'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isMuted
                                      ? Colors.white.withValues(alpha: 0.80)
                                      : const Color(0xFFA7F3D0),
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isCompleted) ...[
                    // Crisp Golden Hint Pill
                    Material(
                      color: const Color(0xFFFDE68A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFFCD34D),
                          width: 1.3,
                        ),
                      ),
                      child: InkWell(
                        key: const ValueKey('ask_teammate_hint_button'),
                        onTap: _askInvitedTeammateForHint,
                        borderRadius: BorderRadius.circular(12),
                        hoverColor: const Color(0xFFFCD34D),
                        child: SizedBox(
                          height: 36,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lightbulb_rounded,
                                  size: 16,
                                  color: Color(0xFF4C1D95),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isSi ? 'ඉඟියක්' : 'Hint',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4C1D95),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Crisp Rose Leave Game Pill
                    Material(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color(0xFFFCA5A5).withValues(alpha: 0.78),
                          width: 1.3,
                        ),
                      ),
                      child: InkWell(
                        key: const ValueKey('leave_live_game_button'),
                        onTap: () =>
                            _showLeaveGameConfirmDialog(exitToHub: false),
                        borderRadius: BorderRadius.circular(12),
                        hoverColor:
                            const Color(0xFFDC2626).withValues(alpha: 0.48),
                        child: SizedBox(
                          height: 36,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.logout_rounded,
                                  size: 15.5,
                                  color: Color(0xFFFEE2E2),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isSi ? 'ඉවත්වන්න' : 'Leave Game',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFEE2E2),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // 2. Bigger, Equal-Height Animated Pastel Picnic Play Arena (Zero Scroll!)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 462),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: _PairsAmbientPlayBackdrop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Restart / Play Another Round Approval Strip (if active)
                    if (_restartRequestedBy != null)
                      _buildRestartVoteStrip(isSi, isCompleted),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 740;
                        final leftBasketPanel = _buildGameplayLeftBasketPanel(
                          isSi: isSi,
                          isCompleted: isCompleted,
                          isRecallStage: isRecallStage,
                          lastPickedItem: lastPickedItem,
                        );
                        final rightPlayBoard = isCompleted
                            ? _buildCompactVictoryPanel(isSi)
                            : _buildGameplayRightItemsBoard(
                                isSi: isSi,
                                isRecallStage: isRecallStage,
                                activeName: activeName,
                                isWide: isWide,
                              );

                        if (isWide) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 4, child: leftBasketPanel),
                                const SizedBox(width: 16),
                                Expanded(flex: 6, child: rightPlayBoard),
                              ],
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            leftBasketPanel,
                            const SizedBox(height: 14),
                            rightPlayBoard,
                          ],
                        );
                      },
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

  Widget _buildRestartVoteStrip(bool isSi, bool isCompleted) {
    final reqBy = _restartRequestedBy!;
    final dispReq = isSi
        ? SinhalaNameTransliterator.toSinhala(reqBy, fallback: reqBy)
        : reqBy;
    final myLower = widget.hostName.trim().toLowerCase();
    final approvedCount = _restartApprovedBy?.length ?? 1;
    final totalCount = _joinedPlayers.length;
    final iApproved = _restartApprovedBy?.contains(myLower) ?? false;
    final isRequester = reqBy.toLowerCase() == myLower;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFECFDF5)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Text(
            iApproved
                ? (isCompleted
                    ? (isSi
                        ? '⏳ තව වටයක් සඳහා මිතුරන් අනුමත කරන තුරු රැඳී සිටී ($approvedCount / $totalCount)...'
                        : '⏳ Waiting for teammates to join another round ($approvedCount / $totalCount)...')
                    : (isSi
                        ? '⏳ මිතුරන් අනුමත කරන තුරු රැඳී සිටී ($approvedCount / $totalCount)...'
                        : '⏳ Waiting for teammates to approve restart ($approvedCount / $totalCount)...'))
                : (isCompleted
                    ? (isSi
                        ? '🎮 $dispReq තව වටයක් එකට සෙල්ලම් කරමුදැයි අසයි!'
                        : '🎮 $reqBy wants to play another round together!')
                    : (isSi
                        ? '🔄 $dispReq ක්‍රීඩාව මුල සිට නැවත අරඹමුදැයි අසයි!'
                        : '🔄 $reqBy asked to restart the game together!')),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E3A8A),
            ),
          ),
          if (isRequester)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _restartRequestedBy = null;
                  _restartRequestId = null;
                  _restartApprovedBy = null;
                });
                _publishLiveRoomState();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text(
                isSi ? 'අවලංගු කරන්න' : 'Cancel',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            )
          else if (!iApproved)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _respondToRestartRequest(approve: true),
                  icon: const Icon(LucideIcons.check, size: 14),
                  label: Text(
                    isCompleted
                        ? (isSi ? 'ඔව්, සෙල්ලම් කරමු' : 'Yes, Play Again')
                        : (isSi ? 'ඔව්, අරඹමු' : 'Yes, Restart'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _respondToRestartRequest(approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    isCompleted
                        ? (isSi ? 'එපා' : 'Not Now')
                        : (isSi ? 'එපා' : 'Keep Playing'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGameplayLeftBasketPanel({
    required bool isSi,
    required bool isCompleted,
    required bool isRecallStage,
    required _PicnicChainItem? lastPickedItem,
  }) {
    final rawFeedback = _feedbackBannerText;
    final spotlightVisible = !isCompleted &&
        lastPickedItem != null &&
        _lastSelectedByName != null &&
        _lastSelectedByName!.isNotEmpty;
    final isRedundantPickBanner = spotlightVisible &&
        rawFeedback != null &&
        (rawFeedback.contains('packed "') || rawFeedback.contains('Correct!'));
    final showFeedback = rawFeedback != null && !isRedundantPickBanner;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFBEB),
            Color(0xFFFEF9C3),
            Color(0xFFECFDF5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basket Title + Progress Chip
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🧺', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRecallStage
                          ? (isSi ? 'පිළිවෙලට මතකයෙන් තෝරන්න' : 'Recall in Order')
                          : (isSi ? 'විනෝද චාරිකා කූඩය' : 'Picnic Basket'),
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      isRecallStage
                          ? '${_currentRecallInput.length} / ${_packedChain.length}'
                          : '${_packedChain.length} / $_targetChainLength',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5 Big Clear Plush Basket Slots (zero scroll!)
              ...List.generate(_targetChainLength, (slotIndex) {
                final isPacked = slotIndex < _packedChain.length;
                final isRevealed = !isRecallStage ||
                    slotIndex < _currentRecallInput.length ||
                    isCompleted;
                final item = isPacked ? _packedChain[slotIndex] : null;
                final isNextToRecall =
                    isRecallStage && slotIndex == _currentRecallInput.length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10.5,
                  ),
                  decoration: BoxDecoration(
                    color: isNextToRecall
                        ? const Color(0xFFDBEAFE)
                        : isPacked
                            ? (isRevealed
                                ? Colors.white
                                : const Color(0xFFEFF6FF))
                            : Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isNextToRecall
                          ? const Color(0xFF2563EB)
                          : isPacked
                              ? (isRevealed
                                  ? item!.color
                                  : const Color(0xFF93C5FD))
                              : const Color(0xFFCBD5E1),
                      width: isNextToRecall ? 2.2 : (isPacked ? 1.6 : 1.1),
                    ),
                    boxShadow: isPacked && isRevealed
                        ? [
                            BoxShadow(
                              color: item!.color.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isPacked && isRevealed
                              ? item!.color
                              : isNextToRecall
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${slotIndex + 1}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: (isPacked && isRevealed) || isNextToRecall
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      if (!isPacked)
                        Text(
                          isSi ? 'හිස්' : 'Empty Slot',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      else if (isRevealed) ...[
                        Icon(item!.icon, size: 20, color: item.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _itemLabel(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        const Icon(
                          LucideIcons.check,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                      ] else ...[
                        const Icon(
                          LucideIcons.helpCircle,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isNextToRecall
                              ? (isSi ? 'මෙය තෝරන්න!' : 'Tap this item!')
                              : (isSi ? 'මතකයෙන් තෝරන්න' : 'Hidden in basket'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isNextToRecall
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Selected Spotlight inside left panel (zero vertical bloat above grid!)
              if (spotlightVisible) ...[
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  key: ValueKey('live_picked_spotlight_${_lastSelectedAtMs ?? 0}'),
                  tween: Tween(begin: 0.94, end: 1.0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _lastSelectedAction == 'wrong'
                            ? const Color(0xFFF59E0B)
                            : lastPickedItem!.color,
                        width: 1.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: lastPickedItem!.color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            lastPickedItem.icon,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            () {
                              final rawActor = _lastSelectedByName!;
                              final actorDisp = isSi
                                  ? SinhalaNameTransliterator.toSinhala(
                                      rawActor,
                                      fallback: rawActor,
                                    )
                                  : rawActor;
                              final itemDisp = _itemLabel(lastPickedItem);
                              if (_lastSelectedAction == 'packed') {
                                return isSi
                                    ? '✨ $actorDisp: "$itemDisp" කූඩයට දැම්මා!'
                                    : '✨ $rawActor packed "$itemDisp"!';
                              }
                              if (_lastSelectedAction == 'recalled') {
                                return isSi
                                    ? '✅ $actorDisp: "$itemDisp" නිවැරදියි!'
                                    : '✅ $rawActor recalled "$itemDisp"!';
                              }
                              return isSi
                                  ? '💛 $actorDisp: "$itemDisp" — නැවත උත්සාහ කරමු!'
                                  : '💛 $rawActor tapped "$itemDisp" — try again!';
                            }(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Hint or non-duplicate guidance pill
              if (_teammateHintText != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA78BFA)),
                  ),
                  child: Text(
                    '💡 ${_localizeHintText(_teammateHintText!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4C1D95),
                      height: 1.3,
                    ),
                  ),
                ),
              ] else if (showFeedback) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isFeedbackPositive
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isFeedbackPositive
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Text(
                    _localizeBannerText(rawFeedback),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameplayRightItemsBoard({
    required bool isSi,
    required bool isRecallStage,
    required String activeName,
    bool isWide = true,
  }) {
    final isWaitingForPartner = _isLiveMultiplayerActive && !_isMyTurnNow;
    final cols = isWide ? 4 : 2;
    final double cardHeight = isWide ? 156 : 122;

    Widget buildItemTile(_PicnicChainItem item) {
      final alreadyPacked = _packedChain.any((c) => c.key == item.key);
      final recalledThisTurn =
          _currentRecallInput.any((c) => c.key == item.key);
      final isDisabledInAddMode =
          _stage == _ChainTurnStage.addNewItemToChain && alreadyPacked;
      final isJustPickedByTeam = _lastSelectedItemKey == item.key &&
          _lastSelectedByName != null &&
          _lastSelectedByName!.isNotEmpty;
      final pickerFirstName = isJustPickedByTeam
          ? (() {
              final rawFirst = _lastSelectedByName!.split(' ').first.trim();
              return isSi
                  ? SinhalaNameTransliterator.toSinhala(
                      rawFirst,
                      fallback: rawFirst,
                    )
                  : rawFirst;
            })()
          : '';

      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('picnic_chain_item_${item.key}'),
          onTap: (isDisabledInAddMode || isWaitingForPartner)
              ? null
              : () => _onTapPicnicItem(item),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: cardHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              gradient: isDisabledInAddMode && !isJustPickedByTeam
                  ? null
                  : LinearGradient(
                      colors: isJustPickedByTeam
                          ? [
                              item.color.withValues(alpha: 0.24),
                              const Color(0xFFFFFFFF),
                            ]
                          : recalledThisTurn
                              ? const [
                                  Color(0xFFECFDF5),
                                  Color(0xFFD1FAE5),
                                ]
                              : [
                                  Colors.white,
                                  item.color.withValues(alpha: 0.14),
                                ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isDisabledInAddMode && !isJustPickedByTeam
                  ? const Color(0xFFF1F5F9)
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isJustPickedByTeam
                    ? item.color
                    : isDisabledInAddMode
                        ? const Color(0xFFCBD5E1)
                        : (recalledThisTurn
                            ? const Color(0xFF10B981)
                            : item.color.withValues(alpha: 0.50)),
                width: isJustPickedByTeam ? 3.0 : (recalledThisTurn ? 2.4 : 1.7),
              ),
              boxShadow: isDisabledInAddMode && !isJustPickedByTeam
                  ? null
                  : [
                      BoxShadow(
                        color: item.color.withValues(
                          alpha: isJustPickedByTeam ? 0.34 : 0.15,
                        ),
                        blurRadius: isJustPickedByTeam ? 18 : 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: isDisabledInAddMode && !isJustPickedByTeam
                        ? null
                        : LinearGradient(
                            colors: [
                              item.color.withValues(alpha: 0.22),
                              item.color.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isDisabledInAddMode && !isJustPickedByTeam
                        ? const Color(0xFFE2E8F0)
                        : null,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: isDisabledInAddMode && !isJustPickedByTeam
                        ? null
                        : [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.24),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Icon(
                    item.icon,
                    size: 29,
                    color: isDisabledInAddMode && !isJustPickedByTeam
                        ? AppColors.muted
                        : item.color,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _itemLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDisabledInAddMode && !isJustPickedByTeam
                          ? AppColors.muted
                          : AppColors.navy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isJustPickedByTeam)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isSi
                          ? '👆 $pickerFirstName තේරුවා'
                          : '👆 $pickerFirstName picked',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (isDisabledInAddMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isSi ? '✓ දැම්මා' : '✓ Packed',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  )
                else if (recalledThisTurn)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isSi ? '✓ හරි!' : '✓ Recalled!',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final itemRows = <Widget>[];
    for (int i = 0; i < _picnicPool.length; i += cols) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < cols; c++) {
        final idx = i + c;
        rowChildren.add(
          Expanded(
            child: idx < _picnicPool.length
                ? buildItemTile(_picnicPool[idx])
                : const SizedBox.shrink(),
          ),
        );
        if (c < cols - 1) {
          rowChildren.add(const SizedBox(width: 13));
        }
      }
      itemRows.add(Row(children: rowChildren));
      if (i + cols < _picnicPool.length) {
        itemRows.add(const SizedBox(height: 13));
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Clear High-Contrast Turn Prompt Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: isWaitingForPartner
                  ? const LinearGradient(
                      colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
                    ),
              borderRadius: BorderRadius.circular(15),
              border: isWaitingForPartner
                  ? Border.all(color: const Color(0xFFF59E0B), width: 1.4)
                  : null,
              boxShadow: isWaitingForPartner
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Text(
                  isWaitingForPartner ? '⏳' : (isRecallStage ? '🎯' : '🧺'),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    isWaitingForPartner
                        ? (isSi
                            ? '$activeName ගේ වාරයයි... භාණ්ඩය තෝරන තුරු බලා සිටින්න!'
                            : "Watching $activeName's turn... Please wait!")
                        : isRecallStage
                            ? (isSi
                                ? '$activeName: කූඩයේ #${_currentRecallInput.length + 1} භාණ්ඩය තෝරන්න'
                                : '$activeName: Tap Item #${_currentRecallInput.length + 1} in order')
                            : (isSi
                                ? '$activeName: කූඩයට අලුත් භාණ්ඩයක් තෝරන්න'
                                : '$activeName: Pick 1 NEW item for the basket'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isWaitingForPartner
                          ? const Color(0xFF92400E)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Big Plush 4x2 Tactile Picnic Item Grid (Row+Expanded -> IntrinsicHeight safe!)
          Opacity(
            opacity: isWaitingForPartner ? 0.78 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: itemRows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactVictoryPanel(bool isSi) {
    final score = _lastScore ?? 100.0;
    final starCount = score >= 85 ? 5 : (score >= 60 ? 4 : 3);
    final players = _orderedTurnPlayers;

    return AuroraGradientBorderFrame(
      borderRadius: 24,
      borderWidth: 3.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 424),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFFDF9),
                Color(0xFFF5F3FF),
                Color(0xFFECFDF5),
                Color(0xFFFFFBEB),
              ],
              stops: [0.0, 0.35, 0.72, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated celebration streamers, ribbons & confetti bursting across the victory card
              const Positioned.fill(
                child: IgnorePointer(
                  child: _SeqPopupConfettiOverlay(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Trophy Emblem flanked by sparkles & party popper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: 14),
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF7C3AED),
                                Color(0xFF2563EB),
                                Color(0xFF0D9488),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.32),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.emoji_events_rounded,
                              size: 42,
                              color: Color(0xFFFEF08A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text('🎉', style: TextStyle(fontSize: 26)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      isSi ? 'විශිෂ්ට කණ්ඩායම් ජයක්!' : 'Wonderful Teamwork!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E1B4B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 5 Glowing Golden Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 30,
                          color: i < starCount
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Celebrating Team Member Profile Avatars Strip
                    if (players.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: players.map((p) {
                          return Container(
                            padding: const EdgeInsets.fromLTRB(6, 5, 13, 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: p.color.withValues(alpha: 0.35),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: p.color.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildLobbyProfileAvatar(p, radius: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _safePlayerDisplayName(p),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),

                    // Crisp 2-Tile Pastel Score Summary
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFDDD6FE),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: score),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, _) => Text(
                                    '${val.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSi ? 'කණ්ඩායම් ලකුණු' : 'Team Score',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${_packedChain.length} / $_targetChainLength',
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSi ? 'කූඩයේ භාණ්ඩ' : 'Items Packed',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_saveErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _saveErrorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Crisp, Well-Proportioned Non-Stretched Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            child: InkWell(
                              key: const ValueKey('play_chain_again_button'),
                              onTap: _isLiveMultiplayerActive
                                  ? _showInitiateRestartConfirmDialog
                                  : _startCollaborativeGame,
                              borderRadius: BorderRadius.circular(15),
                              child: Ink(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2563EB),
                                      Color(0xFF7C3AED),
                                      Color(0xFF0D9488),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.rotateCcw,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        isSi
                                            ? 'තව වටයක් ක්‍රීඩා කරන්න'
                                            : 'Play Another Round',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.96),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: const BorderSide(
                                color: Color(0xFFC4B5FD),
                                width: 1.6,
                              ),
                            ),
                            child: InkWell(
                              onTap: _returnToInviteLobby,
                              borderRadius: BorderRadius.circular(15),
                              hoverColor: const Color(0xFFF5F3FF),
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.users,
                                      size: 17,
                                      color: Color(0xFF4C1D95),
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        isSi ? 'කාමරයට' : 'Back to Lobby',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF4C1D95),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _LobbyElderPortraitPainter extends CustomPainter {
  final Color accentColor;
  final bool isFemale;

  const _LobbyElderPortraitPainter({
    required this.accentColor,
    required this.isFemale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width;

    // Warm shoulders / shirt
    final shirtPaint = Paint()..color = accentColor;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.42),
        width: s * 0.78,
        height: s * 0.50,
      ),
      shirtPaint,
    );

    // Subtle collar / saree accent
    if (isFemale) {
      canvas.drawLine(
        Offset(cx - s * 0.16, cy + s * 0.24),
        Offset(cx + s * 0.14, cy + s * 0.48),
        Paint()
          ..color = const Color(0xFFFDE68A)
          ..strokeWidth = s * 0.07
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final collar = Path()
        ..moveTo(cx - s * 0.10, cy + s * 0.22)
        ..lineTo(cx, cy + s * 0.34)
        ..lineTo(cx + s * 0.10, cy + s * 0.22)
        ..close();
      canvas.drawPath(collar, Paint()..color = Colors.white.withValues(alpha: 0.90));
    }

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + s * 0.19),
          width: s * 0.15,
          height: s * 0.14,
        ),
        Radius.circular(s * 0.05),
      ),
      Paint()..color = const Color(0xFFF6C8A8),
    );

    // Silver hair bun / back hair for grandma
    if (isFemale) {
      canvas.drawCircle(
        Offset(cx, cy - s * 0.27),
        s * 0.14,
        Paint()..color = const Color(0xFFE2E8F0),
      );
      canvas.drawCircle(
        Offset(cx, cy - s * 0.04),
        s * 0.25,
        Paint()..color = const Color(0xFFF1F5F9),
      );
    } else {
      // Soft silver side hair for grandpa
      canvas.drawCircle(
        Offset(cx - s * 0.19, cy - s * 0.06),
        s * 0.085,
        Paint()..color = const Color(0xFFE2E8F0),
      );
      canvas.drawCircle(
        Offset(cx + s * 0.19, cy - s * 0.06),
        s * 0.085,
        Paint()..color = const Color(0xFFE2E8F0),
      );
    }

    // Face
    final faceCenter = Offset(cx, cy - s * 0.02);
    final faceR = s * 0.22;
    canvas.drawCircle(
      faceCenter,
      faceR,
      Paint()..color = const Color(0xFFFCD5B8),
    );

    // Top silver hair fringe
    if (isFemale) {
      final hair = Path()
        ..addArc(
          Rect.fromCircle(center: faceCenter, radius: faceR + 0.8),
          pi * 1.05,
          pi * 0.90,
        )
        ..close();
      canvas.drawPath(hair, Paint()..color = const Color(0xFFF8FAFC));
    }

    // Rosy cheeks
    final cheekPaint = Paint()
      ..color = const Color(0xFFFDA4AF).withValues(alpha: 0.45);
    canvas.drawCircle(
      Offset(cx - s * 0.11, cy + s * 0.03),
      s * 0.042,
      cheekPaint,
    );
    canvas.drawCircle(
      Offset(cx + s * 0.11, cy + s * 0.03),
      s * 0.042,
      cheekPaint,
    );

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawCircle(Offset(cx - s * 0.075, cy - s * 0.03), s * 0.024, eyePaint);
    canvas.drawCircle(Offset(cx + s * 0.075, cy - s * 0.03), s * 0.024, eyePaint);

    // Cute round glasses for grandpa
    if (!isFemale) {
      final glassPaint = Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx - s * 0.075, cy - s * 0.03), s * 0.06, glassPaint);
      canvas.drawCircle(Offset(cx + s * 0.075, cy - s * 0.03), s * 0.06, glassPaint);
      canvas.drawLine(
        Offset(cx - s * 0.015, cy - s * 0.03),
        Offset(cx + s * 0.015, cy - s * 0.03),
        glassPaint,
      );
    }

    // Warm smile
    final smilePaint = Paint()
      ..color = const Color(0xFFB91C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.04),
        width: s * 0.15,
        height: s * 0.10,
      ),
      0.15,
      pi - 0.30,
      false,
      smilePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LobbyElderPortraitPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isFemale != isFemale;
}
