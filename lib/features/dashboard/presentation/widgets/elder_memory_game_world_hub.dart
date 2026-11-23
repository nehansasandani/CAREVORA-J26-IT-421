import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/localization/sinhala_name_transliterator.dart';
import '../../../../core/theme/app_colors.dart';

enum _GameCategoryTab { all, individual, collaborative }

class ElderMemoryGameWorldHub extends StatefulWidget {
  final bool isSinhala;
  final String userName;
  final List<Map<String, dynamic>> incomingInvites;
  final VoidCallback onPlaySequence;
  final VoidCallback onPlayPairs;
  final VoidCallback onPlayItems;
  final VoidCallback onPlayCollaborative;

  const ElderMemoryGameWorldHub({
    super.key,
    required this.isSinhala,
    required this.userName,
    required this.incomingInvites,
    required this.onPlaySequence,
    required this.onPlayPairs,
    required this.onPlayItems,
    required this.onPlayCollaborative,
  });

  @override
  State<ElderMemoryGameWorldHub> createState() =>
      _ElderMemoryGameWorldHubState();
}

class _ElderMemoryGameWorldHubState extends State<ElderMemoryGameWorldHub>
    with SingleTickerProviderStateMixin {
  _GameCategoryTab _selectedTab = _GameCategoryTab.all;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    final isTestEnv =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnv) {
      _ambientController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.isSinhala;
    final rawName =
        widget.userName.trim().isNotEmpty ? widget.userName.trim() : 'Friend';
    final displayName =
        isSi ? SinhalaNameTransliterator.toSinhala(rawName) : rawName;

    return Column(
      key: const ValueKey('elder_game_world_hub'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Smart Virtual Game World Hero Portal (Minimal Words, High Visual Delight)
        _buildVirtualPortalHero(isSi, displayName),

        // 2. Incoming Collaborative Invite Banner (compact, if waiting)
        if (widget.incomingInvites.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...widget.incomingInvites.map((inv) => _buildInviteBanner(inv, isSi)),
        ],

        const SizedBox(height: 20),

        // 3. Clean Individual vs Collaborative Virtual Mode Bar
        _buildVirtualModeBar(isSi),

        const SizedBox(height: 20),

        // 4. Individual & Collaborative Virtual Game Zones
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey('${_selectedTab.name}_$isSi'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedTab == _GameCategoryTab.all ||
                    _selectedTab == _GameCategoryTab.individual)
                  _buildIndividualZone(isSi),
                if (_selectedTab == _GameCategoryTab.all)
                  const SizedBox(height: 24),
                if (_selectedTab == _GameCategoryTab.all ||
                    _selectedTab == _GameCategoryTab.collaborative)
                  _buildCollaborativeZone(isSi),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVirtualPortalHero(bool isSi, String displayName) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF4C1D95),
            Color(0xFF6D28D9),
            Color(0xFF0F766E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFA78BFA).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.30),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            // Animated subtle virtual holographic grid & glowing aurora particles
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ambientController,
                  builder: (context, _) => CustomPaint(
                    painter: _VirtualWorldBackdropPainter(
                      progress: _ambientController.value,
                    ),
                  ),
                ),
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final showPortalOrb = constraints.maxWidth >= 660;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Glowing Smart Virtual Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF5EEAD4)
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 13.5,
                                    color: Color(0xFF5EEAD4),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isSi
                                        ? 'ස්මාර්ට් ක්‍රීඩා ලෝකය'
                                        : 'SMART GAME WORLD',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Short, Warm Headline
                            Text(
                              isSi
                                  ? 'ක්‍රීඩා කරමු, $displayName! 🎮'
                                  : "Let's Play, $displayName! 🎮",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.4,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Ultra-short 1-line prompt
                            Text(
                              isSi
                                  ? 'කැමති ක්‍රීඩාව තෝරා සතුටින් ආරම්භ කරන්න'
                                  : 'Pick a game below and enjoy at your own pace',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Minimal visual pills (no wordy sentences)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildGlassChip(
                                  icon: LucideIcons.smile,
                                  label: isSi ? 'නිදහසේ' : 'Relaxed',
                                  glowColor: const Color(0xFFFDE68A),
                                ),
                                _buildGlassChip(
                                  icon: LucideIcons.user,
                                  label: isSi ? 'තනි • 3' : 'Solo • 3',
                                  glowColor: const Color(0xFFC4B5FD),
                                ),
                                _buildGlassChip(
                                  icon: LucideIcons.users,
                                  label: isSi ? 'එක්ව • 1' : 'Together • 1',
                                  glowColor: const Color(0xFF5EEAD4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (showPortalOrb) ...[
                        const SizedBox(width: 20),
                        _buildHolographicPortalOrb(),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassChip({
    required IconData icon,
    required String label,
    required Color glowColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: glowColor.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: glowColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolographicPortalOrb() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final t = _ambientController.value;
        final floatY = math.sin(t * math.pi) * 7.0 - 3.5;
        final pulse = 0.94 + 0.08 * math.sin(t * math.pi);

        return SizedBox(
          width: 170,
          height: 144,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer holographic aura ring
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF5EEAD4).withValues(alpha: 0.22),
                        const Color(0xFFA78BFA).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF5EEAD4).withValues(alpha: 0.35),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              // Inner portal ring
              Container(
                width: 102,
                height: 102,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                ),
              ),
              // Floating central glowing gamepad crystal
              Transform.translate(
                offset: Offset(0, floatY),
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF5EEAD4),
                        Color(0xFF38BDF8),
                        Color(0xFFA78BFA),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.50),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.gamepad2,
                      size: 38,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
              ),
              // Orbiting mini virtual game gems
              Positioned(
                top: 4,
                left: 10,
                child: Transform.translate(
                  offset: Offset(0, -floatY * 0.8),
                  child: _buildOrbitGem('🧩', const Color(0xFF99F6E4)),
                ),
              ),
              Positioned(
                top: 6,
                right: 8,
                child: Transform.translate(
                  offset: Offset(0, floatY * 0.7),
                  child: _buildOrbitGem('⭐', const Color(0xFFFDE68A)),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 14,
                child: Transform.translate(
                  offset: Offset(0, floatY * 0.6),
                  child: _buildOrbitGem('🌸', const Color(0xFFFBCFE8)),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 10,
                child: Transform.translate(
                  offset: Offset(0, -floatY * 0.75),
                  child: _buildOrbitGem('🧺', const Color(0xFFBFDBFE)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrbitGem(String emoji, Color borderTint) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        border: Border.all(color: borderTint, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: borderTint.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
    );
  }

  Widget _buildInviteBanner(Map<String, dynamic> inv, bool isSi) {
    final senderName =
        (inv['senderName']?.toString() ?? 'Fellow Elder').trim();
    final displaySender =
        isSi ? SinhalaNameTransliterator.toSinhala(senderName) : senderName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFCCFBF1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.6),
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
              const Icon(LucideIcons.bell, size: 20, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(
                  isSi
                      ? '$displaySender ඔබට ක්‍රීඩාවට ආරාධනා කරයි!'
                      : '$senderName invited you to play!',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: widget.onPlayCollaborative,
            icon: const Icon(LucideIcons.play, size: 15),
            label: Text(
              isSi ? 'එක්වන්න' : 'Join Now',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualModeBar(bool isSi) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final tabs = [
            _buildModePill(
              tab: _GameCategoryTab.all,
              icon: LucideIcons.sparkles,
              label: isSi ? 'සියල්ල' : 'All Games',
              count: '4',
              activeGradient: const [Color(0xFF4C1D95), Color(0xFF7C3AED)],
              compact: compact,
            ),
            _buildModePill(
              tab: _GameCategoryTab.individual,
              icon: LucideIcons.user,
              label: isSi ? 'තනි ක්‍රීඩා' : 'Individual',
              count: '3',
              activeGradient: const [Color(0xFF7C3AED), Color(0xFFDB2777)],
              compact: compact,
            ),
            _buildModePill(
              tab: _GameCategoryTab.collaborative,
              icon: LucideIcons.users,
              label: isSi ? 'සාමූහික' : 'Collaborative',
              count: '1',
              activeGradient: const [Color(0xFF0284C7), Color(0xFF0D9488)],
              hasDot: widget.incomingInvites.isNotEmpty,
              compact: compact,
            ),
          ];

          if (compact) {
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: tabs,
            );
          }

          return Row(
            children: [
              Expanded(child: tabs[0]),
              const SizedBox(width: 6),
              Expanded(child: tabs[1]),
              const SizedBox(width: 6),
              Expanded(child: tabs[2]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModePill({
    required _GameCategoryTab tab,
    required IconData icon,
    required String label,
    required String count,
    required List<Color> activeGradient,
    bool hasDot = false,
    bool compact = false,
  }) {
    final isActive = _selectedTab == tab;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tab),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            gradient: isActive ? LinearGradient(colors: activeGradient) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeGradient.first.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : const Color(0xFF5B4E7A),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.24)
                      : const Color(0xFFF3EEFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : const Color(0xFF6C3FC5),
                  ),
                ),
              ),
              if (hasDot) ...[
                const SizedBox(width: 6),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneLabel({
    required IconData icon,
    required String title,
    required String pillText,
    required List<Color> gradient,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: gradient.first.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gradient.first.withValues(alpha: 0.25)),
          ),
          child: Text(
            pillText,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: gradient.first,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualZone(bool isSi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildZoneLabel(
          icon: LucideIcons.user,
          title: isSi ? 'තනි ක්‍රීඩා' : 'Individual Games',
          pillText: isSi ? 'තනිවම • 3' : 'SOLO • 3',
          gradient: const [Color(0xFF7C3AED), Color(0xFFDB2777)],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            final cards = [
              _SmartVirtualGameCard(
                title: isSi ? 'අනුපිළිවෙල' : 'Sequence Tiles',
                shortCue: isSi ? 'පිළිවෙලින් ඔබන්න' : 'Tap in order',
                tag: isSi ? 'තනි ක්‍රීඩාව' : 'SOLO',
                buttonLabel: isSi ? 'ක්‍රීඩා කරන්න' : 'Play',
                stageColors: const [
                  Color(0xFF2E1065),
                  Color(0xFF6D28D9),
                  Color(0xFF8B5CF6),
                ],
                glowColor: const Color(0xFF8B5CF6),
                animation: _ambientController,
                stageBuilder: (t) => _buildSequenceVirtualStage(t),
                onPlay: widget.onPlaySequence,
              ),
              _SmartVirtualGameCard(
                title: isSi ? 'ගැලපෙන යුගල' : 'Matching Pairs',
                shortCue: isSi ? 'කාඩ්පත් ගලපන්න' : 'Flip & match',
                tag: isSi ? 'තනි ක්‍රීඩාව' : 'SOLO',
                buttonLabel: isSi ? 'ක්‍රීඩා කරන්න' : 'Play',
                stageColors: const [
                  Color(0xFF064E3B),
                  Color(0xFF0D9488),
                  Color(0xFF2DD4BF),
                ],
                glowColor: const Color(0xFF14B8A6),
                animation: _ambientController,
                stageBuilder: (t) => _buildPairsVirtualStage(t),
                onPlay: widget.onPlayPairs,
              ),
              _SmartVirtualGameCard(
                title: isSi ? 'භාණ්ඩ මතකය' : 'Memory Items',
                shortCue: isSi ? 'භාණ්ඩ හඳුනාගන්න' : 'Spot the items',
                tag: isSi ? 'තනි ක්‍රීඩාව' : 'SOLO',
                buttonLabel: isSi ? 'ක්‍රීඩා කරන්න' : 'Play',
                stageColors: const [
                  Color(0xFF831843),
                  Color(0xFFDB2777),
                  Color(0xFFFB7185),
                ],
                glowColor: const Color(0xFFEC4899),
                animation: _ambientController,
                stageBuilder: (t) => _buildItemsVirtualStage(t),
                onPlay: widget.onPlayItems,
              ),
            ];

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 18),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 18),
                  Expanded(child: cards[2]),
                ],
              );
            }

            return Column(
              children: [
                cards[0],
                const SizedBox(height: 16),
                cards[1],
                const SizedBox(height: 16),
                cards[2],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCollaborativeZone(bool isSi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildZoneLabel(
          icon: LucideIcons.users,
          title: isSi ? 'සාමූහික ක්‍රීඩා' : 'Collaborative Games',
          pillText: isSi ? 'මිතුරන් 2+' : '2+ PLAYERS',
          gradient: const [Color(0xFF0284C7), Color(0xFF0D9488)],
        ),
        const SizedBox(height: 14),
        _VirtualMultiplayerArenaCard(
          isSinhala: isSi,
          hasInviteWaiting: widget.incomingInvites.isNotEmpty,
          animation: _ambientController,
          onPlay: widget.onPlayCollaborative,
        ),
      ],
    );
  }

  Widget _buildSequenceVirtualStage(double t) {
    final wave1 = math.sin(t * math.pi) * 5.0;
    final wave2 = math.sin((t + 0.35) * math.pi) * 6.0;
    final wave3 = math.sin((t + 0.7) * math.pi) * 5.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, -wave1),
          child: Transform.rotate(
            angle: -0.08,
            child: _buildHoloTile('1', const Color(0xFFFDE68A), const Color(0xFF78350F)),
          ),
        ),
        const SizedBox(width: 12),
        Transform.translate(
          offset: Offset(0, -6 - wave2),
          child: _buildHoloTile('2', const Color(0xFF99F6E4), const Color(0xFF134E4A)),
        ),
        const SizedBox(width: 12),
        Transform.translate(
          offset: Offset(0, -wave3),
          child: Transform.rotate(
            angle: 0.08,
            child: _buildHoloTile('3', const Color(0xFFFBCFE8), const Color(0xFF831843)),
          ),
        ),
      ],
    );
  }

  Widget _buildHoloTile(String label, Color bg, Color fg) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _buildPairsVirtualStage(double t) {
    final lift = math.sin(t * math.pi) * 5.5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, -lift),
          child: Transform.rotate(
            angle: -0.10,
            child: _buildVirtualCard('🌸', false),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            LucideIcons.sparkles,
            size: 20,
            color: const Color(0xFFFDE68A).withValues(alpha: 0.9),
          ),
        ),
        Transform.translate(
          offset: Offset(0, lift - 4),
          child: Transform.rotate(
            angle: 0.10,
            child: _buildVirtualCard('🌸', true),
          ),
        ),
      ],
    );
  }

  Widget _buildVirtualCard(String emoji, bool glow) {
    return Container(
      width: 60,
      height: 74,
      decoration: BoxDecoration(
        color: glow ? const Color(0xFFFEF9C3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glow ? const Color(0xFFFBBF24) : Colors.white,
          width: 2.6,
        ),
        boxShadow: [
          BoxShadow(
            color: (glow ? const Color(0xFFFBBF24) : Colors.black)
                .withValues(alpha: glow ? 0.45 : 0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
    );
  }

  Widget _buildItemsVirtualStage(double t) {
    final floatA = math.sin(t * math.pi) * 5.0;
    final floatB = math.sin((t + 0.5) * math.pi) * 6.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, floatA),
          child: _buildVirtualSphere('🍎'),
        ),
        const SizedBox(width: 12),
        Transform.translate(
          offset: Offset(0, -8 - floatB),
          child: _buildVirtualSphere('🫖', large: true),
        ),
        const SizedBox(width: 12),
        Transform.translate(
          offset: Offset(0, floatA),
          child: _buildVirtualSphere('📖'),
        ),
      ],
    );
  }

  Widget _buildVirtualSphere(String emoji, {bool large = false}) {
    final size = large ? 60.0 : 52.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFDE68A), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDE68A).withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: large ? 28 : 23)),
      ),
    );
  }
}

class _SmartVirtualGameCard extends StatefulWidget {
  final String title;
  final String shortCue;
  final String tag;
  final String buttonLabel;
  final List<Color> stageColors;
  final Color glowColor;
  final Animation<double> animation;
  final Widget Function(double t) stageBuilder;
  final VoidCallback onPlay;

  const _SmartVirtualGameCard({
    required this.title,
    required this.shortCue,
    required this.tag,
    required this.buttonLabel,
    required this.stageColors,
    required this.glowColor,
    required this.animation,
    required this.stageBuilder,
    required this.onPlay,
  });

  @override
  State<_SmartVirtualGameCard> createState() => _SmartVirtualGameCardState();
}

class _SmartVirtualGameCardState extends State<_SmartVirtualGameCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -7 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _hovered
                  ? widget.glowColor
                  : widget.glowColor.withValues(alpha: 0.25),
              width: _hovered ? 2.2 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor
                    .withValues(alpha: _hovered ? 0.26 : 0.10),
                blurRadius: _hovered ? 30 : 18,
                offset: Offset(0, _hovered ? 14 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tall Interactive Virtual Stage
                Container(
                  height: 162,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.stageColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle concentric virtual portal rings
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 1.2,
                          ),
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      // Minimal corner tag
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            widget.tag,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      // Floating animated game objects
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: AnimatedBuilder(
                          animation: widget.animation,
                          builder: (context, _) =>
                              widget.stageBuilder(widget.animation.value),
                        ),
                      ),
                    ],
                  ),
                ),

                // Ultra-clean minimal body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.shortCue,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B608A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.stageColors[1],
                              widget.stageColors[2],
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: widget.glowColor.withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onPlay,
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    LucideIcons.play,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.buttonLabel,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VirtualMultiplayerArenaCard extends StatefulWidget {
  final bool isSinhala;
  final bool hasInviteWaiting;
  final Animation<double> animation;
  final VoidCallback onPlay;

  const _VirtualMultiplayerArenaCard({
    required this.isSinhala,
    required this.hasInviteWaiting,
    required this.animation,
    required this.onPlay,
  });

  @override
  State<_VirtualMultiplayerArenaCard> createState() =>
      _VirtualMultiplayerArenaCardState();
}

class _VirtualMultiplayerArenaCardState
    extends State<_VirtualMultiplayerArenaCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isSi = widget.isSinhala;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF7DD3FC),
              width: _hovered ? 2.2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7)
                    .withValues(alpha: _hovered ? 0.24 : 0.11),
                blurRadius: _hovered ? 30 : 18,
                offset: Offset(0, _hovered ? 12 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 680;
                final stage = _buildVirtualPicnicStage(isSi);
                final info = _buildMinimalMultiplayerInfo(isSi, isWide);

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 320, child: stage),
                        Expanded(child: info),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 170, child: stage),
                    info,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualPicnicStage(bool isSi) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0C4A6E),
            Color(0xFF0284C7),
            Color(0xFF0D9488),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.3,
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34D399),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSi ? 'මිතුරන් 2+' : '2+ LIVE',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: widget.animation,
            builder: (context, _) {
              final dy = math.sin(widget.animation.value * math.pi) * 5.0;
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, dy),
                      child: _buildAvatarOrb('👵', const Color(0xFFFCE7F3)),
                    ),
                    const SizedBox(width: 10),
                    Transform.translate(
                      offset: Offset(0, -6 - dy),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFDE68A)
                                  .withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🧺', style: TextStyle(fontSize: 34)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Transform.translate(
                      offset: Offset(0, dy),
                      child: _buildAvatarOrb('👴', const Color(0xFFCCFBF1)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOrb(String emoji, Color bg) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
    );
  }

  Widget _buildMinimalMultiplayerInfo(bool isSi, bool isWide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      child: Column(
        crossAxisAlignment:
            isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
            children: [
              _buildMiniBadge(
                isSi ? '🤝 මිතුරන් සමඟ' : '🤝 Play With Friends',
                const Color(0xFFE0F2FE),
                const Color(0xFF0369A1),
              ),
              if (widget.hasInviteWaiting)
                _buildMiniBadge(
                  isSi ? '🔔 නව ආරාධනාවක්!' : '🔔 Invite Waiting!',
                  const Color(0xFFFEF2F2),
                  const Color(0xFFDC2626),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isSi ? 'හවුල් විනෝද චාරිකාව' : 'Shared Picnic Chain',
            textAlign: isWide ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSi
                ? 'මිතුරන් සමඟ එක්ව මතකය බෙදාගෙන සෙල්ලම් කරන්න'
                : 'Invite friends & build a picnic basket together',
            textAlign: isWide ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF534873),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPlay,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.users,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isSi ? 'එක්ව ක්‍රීඩා කරන්න' : 'Play Together',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        LucideIcons.arrowRight,
                        size: 18,
                        color: Colors.white,
                      ),
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

  Widget _buildMiniBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _VirtualWorldBackdropPainter extends CustomPainter {
  final double progress;

  _VirtualWorldBackdropPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle perspective virtual grid lines at bottom
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    const double step = 36;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Soft glowing floating virtual light orbs
    final glowA = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF5EEAD4).withValues(alpha: 0.24),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * (0.25 + 0.1 * progress)),
          radius: 130,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * (0.25 + 0.1 * progress)),
      130,
      glowA,
    );

    final glowB = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF472B6).withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.12, size.height * (0.85 - 0.1 * progress)),
          radius: 120,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * (0.85 - 0.1 * progress)),
      120,
      glowB,
    );
  }

  @override
  bool shouldRepaint(covariant _VirtualWorldBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
