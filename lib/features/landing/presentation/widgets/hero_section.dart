import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/landing_content.dart';
import 'common/photo_frame.dart';

class HeroSection extends StatefulWidget {
  final GlobalKey heroKey;
  final VoidCallback onLearnMore;

  const HeroSection({
    super.key,
    required this.heroKey,
    required this.onLearnMore,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      key: widget.heroKey,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.pageGradient,
      ),
      padding: EdgeInsets.only(
        top: isMobile ? 36 : 64,
        bottom: isMobile ? 80 : 120,
        left: isMobile ? 20 : 40,
        right: isMobile ? 20 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ResponsiveBuilder(
            mobile: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTextColumn(context, isCentered: true),
                const SizedBox(height: 48),
                _buildPhotoWithFloatingCards(isMobile: true),
              ],
            ),
            desktop: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: _buildTextColumn(context, isCentered: false)),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: _buildPhotoWithFloatingCards(isMobile: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextColumn(BuildContext context, {required bool isCentered}) {
    return Column(
      crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                LandingContent.heroPill,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Headline
        Text.rich(
          TextSpan(
            style: AppTextStyles.h1.copyWith(
              fontSize: isCentered ? 40 : 56,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -1.0,
            ),
            children: const [
              TextSpan(text: LandingContent.heroTitleNavy, style: TextStyle(color: AppColors.navy)),
              TextSpan(text: LandingContent.heroTitlePurple, style: TextStyle(color: AppColors.primary)),
            ],
          ),
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 20),
        // Paragraph
        Text(
          LandingContent.heroParagraph,
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: AppTextStyles.body.copyWith(
            fontSize: 16,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        // Buttons Row
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: isCentered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.go('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Get Started', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            OutlinedButton.icon(
              onPressed: widget.onLearnMore,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18, color: AppColors.primary),
              label: const Text('Learn More', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Trust Row (3 tiny check items)
        Wrap(
          spacing: 20,
          runSpacing: 8,
          alignment: isCentered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            _buildTrustCheck('Privacy-first'),
            _buildTrustCheck('Explainable AI'),
            _buildTrustCheck('Built for care homes'),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustCheck(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.riskLow),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.body,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoWithFloatingCards({required bool isMobile}) {
    final frameWidth = isMobile ? 300.0 : 420.0;
    final frameHeight = isMobile ? 360.0 : 480.0;

    return Center(
      child: SizedBox(
        width: frameWidth + 40,
        height: frameHeight + 40,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Arch Photo Frame
            PhotoFrame(
              assetPath: 'assets/images/landing/hero_caregiver_hug.jpg',
              width: frameWidth,
              height: frameHeight,
              isArch: true,
            ),
            // Floating Glass Card 1 (Top Left: Wellness Index)
            Positioned(
              top: 20,
              left: -20,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: _buildGlassCard(
                    icon: Icons.speed_rounded,
                    iconColor: AppColors.riskModerate,
                    title: 'Wellness Index: 0.62',
                    subtitle: 'Moderate Risk Zone',
                  ),
                ),
              ),
            ),
            // Floating Glass Card 2 (Bottom Right: Early Alert)
            Positioned(
              bottom: 30,
              right: -20,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -_floatAnimation.value),
                      child: child,
                    );
                  },
                  child: _buildGlassCard(
                    icon: Icons.notifications_active_rounded,
                    iconColor: AppColors.riskHigh,
                    title: 'Early Clinical Alert',
                    subtitle: 'Affect shift detected',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
