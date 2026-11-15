import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';

class MobileBottomNav extends ConsumerWidget {
  final String currentRoute;
  final bool isElder;

  const MobileBottomNav({
    super.key,
    required this.currentRoute,
    this.isElder = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider).currentLanguage;
    final strings = AppStrings(lang);

    if (isElder) {
      int currentIndex = 0;
      if (currentRoute == '/dashboard') {
        currentIndex = 0;
      } else if (currentRoute.startsWith('/dashboard/cognitive')) {
        currentIndex = 1;
      } else if (currentRoute.startsWith('/dashboard/memory-games')) {
        currentIndex = 2;
      } else {
        currentIndex = 3;
      }

      return Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.muted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/dashboard');
                break;
              case 1:
                context.go('/dashboard/cognitive/session');
                break;
              case 2:
                context.go('/dashboard/memory-games');
                break;
              case 3:
                context.go('/dashboard/settings');
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.layoutDashboard, size: 20),
              label: strings.overview,
            ),
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.brain, size: 20),
              label: strings.isSinhala ? 'ඇගයීම' : 'Assess',
            ),
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.gamepad2, size: 20),
              label: strings.isSinhala ? 'ක්‍රීඩා' : 'Games',
            ),
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.settings, size: 20),
              label: strings.settings,
            ),
          ],
        ),
      );
    }

    int currentIndex = 0;
    if (currentRoute.startsWith('/dashboard/residents')) {
      currentIndex = 0;
    } else if (currentRoute.startsWith('/dashboard/alerts')) {
      currentIndex = 1;
    } else if (currentRoute.startsWith('/dashboard/settings')) {
      currentIndex = 2;
    } else {
      currentIndex = 0;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard/residents');
              break;
            case 1:
              context.go('/dashboard/alerts');
              break;
            case 2:
              context.go('/dashboard/settings');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.users, size: 20),
            label: strings.residentDirectory,
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.bell, size: 20),
            label: strings.alertsAndNotifications,
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.settings, size: 20),
            label: strings.settings,
          ),
        ],
      ),
    );
  }
}
