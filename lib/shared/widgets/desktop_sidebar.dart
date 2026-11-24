import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/sinhala_name_transliterator.dart';
import '../../features/auth/application/auth_controller.dart';
import 'carevora_avatar.dart';

class DesktopSidebar extends ConsumerWidget {
  final String currentRoute;
  final bool isCollapsed;

  const DesktopSidebar({
    super.key,
    required this.currentRoute,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider).state;
    final lang = ref.watch(languageProvider).currentLanguage;
    final strings = AppStrings(lang);
    final width = isCollapsed ? 80.0 : 265.0;

    final userName = authState.userName ?? (strings.isSinhala ? 'නේවාසිකයා' : 'Care Specialist');
    final displayUserName = strings.isSinhala
        ? SinhalaNameTransliterator.toSinhala(userName, fallback: 'නේවාසිකයා')
        : userName;
    final roleName = authState.role == UserRole.elder
        ? (strings.isSinhala ? 'වැඩිහිටියා' : 'ELDER')
        : (authState.role == UserRole.doctor
            ? (strings.isSinhala ? 'වෛද්‍යවරයා' : 'DOCTOR')
            : (strings.isSinhala ? 'භාරකරු' : 'CAREGIVER'));
    final elderHomeName = authState.elderHomeName;

    String initials = 'CV';
    final parts = userName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7FF), // Soft lavender pastel sidebar background
        border: Border(right: BorderSide(color: Color(0xFFEDE9FE), width: 1.5)),
      ),
      child: Column(
        children: [
          // 1. Logo & Brand Header with Top Leaf Accents
          _buildBrandHeader(isCollapsed),

          // 2. Navigation Items List (Scrollable Pill Capsules)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: [
                if (authState.isElder) ...[
                  _buildNavItem(
                    context,
                    icon: LucideIcons.home,
                    label: strings.isSinhala ? 'මුල් පිටුව' : strings.overview,
                    route: '/dashboard/elder-home',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.brain,
                    label: strings.isSinhala ? 'මතක පරීක්ෂාව' : strings.cognitiveAssessment,
                    route: '/dashboard/cognitive/session',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.heart,
                    label: strings.isSinhala ? 'මානසික සුවතාවය' : strings.emotionalWellness,
                    route: '/dashboard/emotional',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.calendar,
                    label: strings.isSinhala ? 'මගේ ඇමතුම්' : 'Appointments & Calls',
                    route: '/dashboard/station-help',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.activity,
                    label: strings.isSinhala ? 'සෞඛ්‍ය තොරතුරු' : strings.metabolicHealth,
                    route: '/dashboard/metabolic',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.gamepad2,
                    label: strings.isSinhala ? 'මතක ක්‍රීඩා' : strings.memoryGames,
                    route: '/dashboard/memory-games',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.users,
                    label: strings.isSinhala ? 'සහය ලබා ගැනීම' : strings.stationHelpAndCalls,
                    route: '/dashboard/station-help',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.settings,
                    label: strings.isSinhala ? 'සැකසුම්' : strings.settings,
                    route: '/dashboard/settings',
                  ),
                ] else ...[
                  _buildNavItem(
                    context,
                    icon: LucideIcons.users,
                    label: strings.residentDirectory,
                    route: '/dashboard/residents',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.brain,
                    label: strings.cognitiveAssessment,
                    route: '/dashboard/cognitive/session',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.heart,
                    label: strings.isSinhala ? 'මානසික සුවතාවය' : strings.emotionalWellness,
                    route: '/dashboard/emotional',
                  ),
                  if (authState.isCaregiver)
                    _buildNavItem(
                      context,
                      icon: LucideIcons.activity,
                      label: 'Metabolic Health',
                      route: '/dashboard/metabolic',
                    ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.bell,
                    label: strings.alertsAndNotifications,
                    route: '/dashboard/alerts',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.barChart3,
                    label: strings.reportsAndAnalytics,
                    route: '/dashboard/reports',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.clipboardList,
                    label: strings.carePlans,
                    route: '/dashboard/care-plans',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.stethoscope,
                    label: 'Doctor Prescribing',
                    route: '/dashboard/doctor',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.pill,
                    label: 'Live Medicine Board',
                    route: '/dashboard/medicine',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.clipboardCheck,
                    label: 'Social Audit Hub',
                    route: '/dashboard/social-audit',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.trendingUp,
                    label: 'Emotional RALPA Trajectory',
                    route: '/dashboard/emotional-ralpa-trajectory',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.phoneCall,
                    label: strings.stationHelpAndCalls,
                    route: '/dashboard/station-help',
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.settings,
                    label: strings.settings,
                    route: '/dashboard/settings',
                  ),
                ],
              ],
            ),
          ),

          // 3. Pastoral Country Cottage Landscape (Shown in expanded mode)
          if (!isCollapsed) _buildSidebarLandscapeTrim(),

          // 4. User Profile Card & Log Out Button
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 8 : 12,
              vertical: 8,
            ),
            child: isCollapsed
                ? IconButton(
                    icon: const Icon(LucideIcons.logOut, color: AppColors.riskHigh),
                    onPressed: () async {
                      await ref.read(authProvider).logout();
                      if (context.mounted) context.go('/login');
                    },
                  )
                : Column(
                    children: [
                      // User Profile Capsule Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFDDD6FE),
                                  width: 1.5,
                                ),
                              ),
                              child: CarevoraAvatar(
                                avatarUrl: authState.avatarUrl,
                                radius: 19,
                                initials: initials,
                                backgroundColor: const Color(0xFFEDE9FE),
                                foregroundColor: const Color(0xFF6D28D9),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayUserName,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    roleName,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                  Text(
                                    (elderHomeName != null && elderHomeName.isNotEmpty)
                                        ? elderHomeName
                                        : 'Serene Valley Senior Living',
                                    style: const TextStyle(
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 19,
                              color: Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Log Out Capsule Button
                      InkWell(
                        onTap: () async {
                          await ref.read(authProvider).logout();
                          if (context.mounted) context.go('/login');
                        },
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.logOut, size: 17, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Text(
                                strings.isSinhala ? 'ඉවත්වන්න' : strings.logOut,
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
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Brand Header with Official Transparent Carevora Logo & Top Corner Leaves
  Widget _buildBrandHeader(bool isCollapsed) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Image.asset(
          'assets/images/carevora_logo_official.png',
          width: 44,
          height: 36,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Top left leaves
        const Positioned(
          top: -2,
          left: 2,
          child: Text('🌿', style: TextStyle(fontSize: 22)),
        ),
        // Top right leaves
        const Positioned(
          top: -2,
          right: 2,
          child: Text('🌿', style: TextStyle(fontSize: 22)),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            children: [
              // Official Transparent Carevora Logo blended seamlessly onto the soft lavender sidebar
              Container(
                width: 82,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEDE9FE).withValues(alpha: 0.72),
                      const Color(0xFFFAF7FF).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/carevora_logo_official.png',
                  width: 72,
                  height: 60,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 4),

              // CAREVORA brand text
              const Text(
                'CAREVORA',
                style: TextStyle(
                  fontFamily: 'Serif',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: 2.8,
                ),
              ),
              const SizedBox(height: 1),

              // Tagline
              const Text(
                'Compassionate Care, Smarter Tomorrow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Pastoral Country Cottage Landscape Trim
  Widget _buildSidebarLandscapeTrim() {
    return Container(
      height: 84,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFAF7FF),
            Color(0xFFF3E8FF),
            Color(0xFFE9D5FF),
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Purple Mountain Hills
          Positioned(
            left: -15,
            right: -15,
            bottom: 20,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDDD6FE).withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(100),
                  topRight: Radius.circular(80),
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: -30,
            bottom: 18,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFC4B5FD).withValues(alpha: 0.75),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(90),
                  topRight: Radius.circular(110),
                ),
              ),
            ),
          ),

          // Foreground Green Lawn
          Positioned(
            left: -10,
            right: -10,
            bottom: -15,
            child: Container(
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF86EFAC),
                    Color(0xFF22C55E),
                    Color(0xFF16A34A),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(140),
                  topRight: Radius.circular(120),
                ),
              ),
            ),
          ),

          // Country Cottage with Purple Roof
          const Positioned(
            left: 82,
            bottom: 8,
            child: Text('🏡', style: TextStyle(fontSize: 38)),
          ),

          // Green Shade Tree next to Cottage
          const Positioned(
            right: 24,
            bottom: 6,
            child: Text('🌳', style: TextStyle(fontSize: 42)),
          ),

          // Small shrubs & daisy
          const Positioned(
            left: 60,
            bottom: 10,
            child: Text('🌿', style: TextStyle(fontSize: 16)),
          ),
          const Positioned(
            left: 18,
            bottom: 6,
            child: Text('🌼', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // Navigation Pill Item (Matching Mockup with Vivid Theme Icons)
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    String? badge,
  }) {
    final isActive = currentRoute == route ||
        (route != '/dashboard' && currentRoute.startsWith(route));

    final effectiveIconColor = _resolveIconColor(icon);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 10 : 13,
            vertical: isCollapsed ? 10 : 8.5,
          ),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
                  )
                : null,
            color: isActive ? null : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive ? const Color(0xFF6D28D9) : const Color(0xFFF3E8FF),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: isActive ? 10 : 4,
                offset: Offset(0, isActive ? 3 : 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 19,
                color: isActive ? Colors.white : effectiveIconColor,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                      color: isActive ? Colors.white : const Color(0xFF1E1B4B),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isActive ? const Color(0xFF7C3AED) : Colors.white,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Theme-specific vibrant icon colors matching the mockup
  Color _resolveIconColor(IconData icon) {
    if (icon == LucideIcons.home) return const Color(0xFF7C3AED);
    if (icon == LucideIcons.user || icon == LucideIcons.users) return const Color(0xFF8B5CF6);
    if (icon == LucideIcons.heart) return const Color(0xFFF43F5E); // vivid pink heart
    if (icon == LucideIcons.brain || icon == LucideIcons.gamepad2) return const Color(0xFFF59E0B); // golden puzzle/game
    if (icon == LucideIcons.activity) return const Color(0xFFE11D48); // magenta pulse wave
    if (icon == LucideIcons.barChart3 || icon == LucideIcons.trendingUp) return const Color(0xFF6366F1); // indigo bar chart
    if (icon == LucideIcons.calendar || icon == LucideIcons.phoneCall) return const Color(0xFF8B5CF6);
    if (icon == LucideIcons.bookOpen || icon == LucideIcons.helpCircle || icon == LucideIcons.stethoscope) return const Color(0xFF3B82F6);
    if (icon == LucideIcons.settings) return const Color(0xFF7C3AED);
    return const Color(0xFF7C3AED);
  }
}
