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
import 'carevora_logo.dart';

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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6D28D9), // Rich royal violet
            Color(0xFF7C3AED), // Cheerful vibrant purple
            Color(0xFF8B5CF6), // Radiant violet
            Color(0xFF9333EA), // Deep purple
            Color(0xFFA855F7), // Soft purple
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x334C1D95),
            blurRadius: 16,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Logo & Brand Header with Glowing White Heart
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
                    showDivider: true,
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.brain,
                    label: strings.isSinhala ? 'මානසික ක්‍රියාකාරකම්' : strings.emotionalWellness,
                    route: '/dashboard/emotional',
                    showDivider: true,
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.puzzle,
                    label: strings.isSinhala ? 'මනස පරීක්ෂණ' : strings.memoryGames,
                    route: '/dashboard/memory-games',
                    showDivider: true,
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.calendar,
                    label: strings.isSinhala ? 'මගේ ඇවතුම්' : 'Appointments & Calls',
                    route: '/dashboard/station-help',
                    showDivider: true,
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.barChart3,
                    label: strings.isSinhala ? 'ප්‍රගති වාර්තා' : strings.reportsAndAnalytics,
                    route: '/dashboard/reports',
                    showDivider: true,
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.user,
                    label: strings.isSinhala ? 'මගේ ගිණුම' : 'My Account',
                    route: '/dashboard/residents',
                    showDivider: true,
                  ),
                  _buildNavItem(
                    context,
                    icon: LucideIcons.settings,
                    label: strings.isSinhala ? 'සැකසුම්' : strings.settings,
                    route: '/dashboard/settings',
                    showDivider: false,
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
                    icon: const Icon(LucideIcons.logOut, color: Colors.white),
                    onPressed: () async {
                      await ref.read(authProvider).logout();
                      if (context.mounted) context.go('/login');
                    },
                  )
                : Column(
                    children: [
                      // User Profile Capsule Card (Translucent Glass)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
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
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Color(0xFF6D28D9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
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
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    roleName,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE9D5FF),
                                    ),
                                  ),
                                  Text(
                                    (elderHomeName != null && elderHomeName.isNotEmpty)
                                        ? elderHomeName
                                        : 'Serene Valley Senior Living',
                                    style: TextStyle(
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.80),
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
                              color: Colors.white70,
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
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.logOut, size: 17, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                strings.isSinhala ? 'ඉවත්වන්න' : strings.logOut,
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
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Brand Header with Carevora Heart Logo (Exact Mockup Design)
  Widget _buildBrandHeader(bool isCollapsed) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.20),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(LucideIcons.heartHandshake, color: Colors.white, size: 22),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 16),
      child: Column(
        children: [
          // Glowing Heart Logo Badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.heartHandshake,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),

          // CAREVORA brand title
          const Text(
            'CAREVORA',
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2.6,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),

          // Tagline
          Text(
            'Compassionate Care,\nSmarter Tomorrow',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.90),
              height: 1.25,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // Pastoral Country Cottage Landscape Trim (Seamlessly blending with purple gradient)
  Widget _buildSidebarLandscapeTrim() {
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Rolling Hills (Lavender/Soft Purple)
          Positioned(
            left: -15,
            right: -15,
            bottom: 24,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFC4B5FD).withValues(alpha: 0.55),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(100),
                  topRight: Radius.circular(80),
                ),
              ),
            ),
          ),
          Positioned(
            left: 30,
            right: -30,
            bottom: 20,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFA78BFA).withValues(alpha: 0.65),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(90),
                  topRight: Radius.circular(110),
                ),
              ),
            ),
          ),

          // Foreground Lush Green Meadow Lawn
          Positioned(
            left: -10,
            right: -10,
            bottom: -15,
            child: Container(
              height: 48,
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
            child: Text('🏡', style: TextStyle(fontSize: 36)),
          ),

          // Green Shade Tree next to Cottage
          const Positioned(
            right: 24,
            bottom: 6,
            child: Text('🌳', style: TextStyle(fontSize: 40)),
          ),

          // Lavender flower stalks & shrubs
          const Positioned(
            left: 14,
            bottom: 4,
            child: Text('🪻', style: TextStyle(fontSize: 22)),
          ),
          const Positioned(
            left: 30,
            bottom: 6,
            child: Text('🪻', style: TextStyle(fontSize: 18)),
          ),
          const Positioned(
            left: 58,
            bottom: 8,
            child: Text('🌿', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // Navigation Pill Item (Matching Mockup with Active Solid White Pill & Inactive White Text)
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    String? badge,
    bool showDivider = false,
  }) {
    final isActive = currentRoute == route ||
        (route == '/dashboard/elder-home' && (currentRoute == '/dashboard' || currentRoute == '/dashboard/')) ||
        (route != '/dashboard' && route != '/dashboard/elder-home' && currentRoute.startsWith(route));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 6 : 10,
            vertical: 2.5,
          ),
          child: InkWell(
            onTap: () => context.go(route),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 10 : 16,
                vertical: isCollapsed ? 10 : 10,
              ),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment:
                    isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: isActive ? const Color(0xFF6D28D9) : Colors.white,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                          color: isActive ? const Color(0xFF6D28D9) : Colors.white,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF7C3AED) : Colors.white,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider && !isCollapsed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 1.5),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.15),
              height: 1,
              thickness: 0.75,
            ),
          ),
      ],
    );
  }
}
