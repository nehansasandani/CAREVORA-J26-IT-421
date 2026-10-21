import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
    final width = isCollapsed ? 80.0 : 260.0;

    final userName = authState.userName ?? 'Care Specialist';
    final roleName = authState.role.name.toUpperCase();
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: isCollapsed
                ? const CarevoraLogo(variant: LogoVariant.iconOnly, size: 36)
                : const CarevoraLogo(variant: LogoVariant.full, size: 36),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                _buildNavItem(
                  context,
                  icon: LucideIcons.layoutDashboard,
                  label: 'Overview',
                  route: '/dashboard',
                ),
                if (!authState.isElder)
                  _buildNavItem(
                    context,
                    icon: LucideIcons.users,
                    label: authState.isElder ? 'My Health Record' : 'Resident Directory',
                    route: '/dashboard/residents',
                  ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.brain,
                  label: 'Cognitive Assessment',
                  route: '/dashboard/cognitive/session',
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.heartPulse,
                  label: 'Emotional Wellness',
                  route: '/dashboard/emotional',
                ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.activity,
                  label: 'Metabolic Health',
                  route: '/dashboard/metabolic',
                ),
                if (!authState.isElder)
                  _buildNavItem(
                    context,
                    icon: LucideIcons.bell,
                    label: 'Alerts & Notifications',
                    route: '/dashboard/alerts',
                  ),
                _buildNavItem(
                  context,
                  icon: LucideIcons.barChart3,
                  label: 'Reports & Analytics',
                  route: '/dashboard/reports',
                ),
                if (!authState.isElder)
                  _buildNavItem(
                    context,
                    icon: LucideIcons.clipboardList,
                    label: 'Care Plans',
                    route: '/dashboard/care-plans',
                  ),
                if (!authState.isElder) ...[
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
                ],
                if (authState.isElder) ...[
                  _buildNavItem(
                    context,
                    icon: LucideIcons.gamepad2,
                    label: 'Memory Games',
                    route: '/dashboard/memory-games',
                  ),
                ],
                _buildNavItem(
                  context,
                  icon: LucideIcons.settings,
                  label: 'Settings',
                  route: '/dashboard/settings',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // User Profile Card & Log Out
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
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Row(
                          children: [
                            CarevoraAvatar(
                              avatarUrl: authState.avatarUrl,
                              radius: 18,
                              initials: initials,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
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
                                      color: AppColors.primary,
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
                            children: const [
                              Icon(LucideIcons.logOut, size: 16, color: AppColors.riskHigh),
                              SizedBox(width: 8),
                              Text(
                                'Log Out',
                                style: TextStyle(
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
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppColors.primary : AppColors.muted,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? AppColors.primary : AppColors.body,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
