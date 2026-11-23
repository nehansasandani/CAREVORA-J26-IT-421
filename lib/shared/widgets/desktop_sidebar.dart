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
    final width = isCollapsed ? 80.0 : 260.0;

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
        color: AppColors.card,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo & Brand Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: isCollapsed
                ? const CarevoraLogo(variant: LogoVariant.iconOnly, size: 36)
                : const CarevoraLogo(variant: LogoVariant.full, size: 36),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                    icon: LucideIcons.barChart3,
                    label: strings.isSinhala ? 'ප්‍රගතිය සහ වාර්තා' : strings.reportsAndAnalytics,
                    route: '/dashboard/reports',
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
          const Divider(height: 1, color: AppColors.border),
          // User Profile Card & Log Out
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFDDD6FE)),
                                  ),
                                  child: CarevoraAvatar(
                                    avatarUrl: authState.avatarUrl,
                                    radius: 18,
                                    initials: initials,
                                    backgroundColor: const Color(0xFFEDE9FE),
                                    foregroundColor: const Color(0xFF7C3AED),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayUserName,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        roleName,
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ),
                                      if (elderHomeName != null && elderHomeName.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          elderHomeName,
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 9.5,
                                            color: AppColors.muted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              await ref.read(authProvider).logout();
                              if (context.mounted) context.go('/login');
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(LucideIcons.logOut, size: 16, color: AppColors.riskHigh),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.logOut,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.riskHigh,
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
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    String? badge,
  }) {
    final isActive = currentRoute == route ||
        (route != '/dashboard' && currentRoute.startsWith(route));

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF7C3AED) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : AppColors.muted,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : AppColors.body,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : AppColors.primary,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
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
}
