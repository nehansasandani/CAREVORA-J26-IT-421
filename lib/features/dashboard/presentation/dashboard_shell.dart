import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/responsive/responsive_builder.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/desktop_sidebar.dart';
import '../../../shared/widgets/mobile_bottom_nav.dart';
import '../../../shared/widgets/language_selector_button.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../data/mock/mock_carevora_data.dart';
import '../../auth/application/auth_controller.dart';
import 'widgets/elder_game_invite_notifications.dart';

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final authState = ref.watch(authProvider).state;
    final lang = ref.watch(languageProvider).currentLanguage;
    final strings = AppStrings(lang);

    return ElderInviteNotificationHost(
      enabled: authState.isElder,
      elderName: authState.userName,
      elderHomeId: authState.elderHomeId ?? 1,
      token: authState.token,
      isSinhala: strings.isSinhala,
      builder: (ctx, elderBellButton) => Scaffold(
        backgroundColor: AppColors.dashboardBg,
        drawer: Drawer(
          backgroundColor: AppColors.card,
          child: SafeArea(
            child: DesktopSidebar(currentRoute: location, isCollapsed: false),
          ),
        ),
        body: ResponsiveBuilder(
          mobile: (context) => Column(
            children: [
              _buildTopBar(
                context,
                authState,
                strings: strings,
                isMobile: true,
                elderBellButton: elderBellButton,
              ),
              Expanded(child: child),
              MobileBottomNav(
                currentRoute: location,
                isElder: authState.isElder,
              ),
            ],
          ),
          tablet: (context) => Row(
            children: [
              DesktopSidebar(currentRoute: location, isCollapsed: true),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(
                      context,
                      authState,
                      strings: strings,
                      isMobile: false,
                      elderBellButton: elderBellButton,
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
          desktop: (context) => Row(
            children: [
              DesktopSidebar(currentRoute: location, isCollapsed: false),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(
                      context,
                      authState,
                      strings: strings,
                      isMobile: false,
                      elderBellButton: elderBellButton,
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AuthState authState, {
    required AppStrings strings,
    required bool isMobile,
    Widget? elderBellButton,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF5F0FF), // Soft lilac matching sidebar
            Color(0xFFFAF7FF), // Airy pastel lavender
            Color(0xFFF3F8FF), // Soft sky mist
            Color(0xFFECFDF9), // Gentle Carevora mint-teal tint
          ],
          stops: [0.0, 0.36, 0.72, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE4DCFA), width: 1.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.055),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft decorative pastel accents harmonized with sidebar & cards
            Positioned(
              left: -24,
              top: -28,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFA78BFA).withValues(alpha: 0.16),
                        const Color(0xFFA78BFA).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 80,
              bottom: -36,
              child: IgnorePointer(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2DD4BF).withValues(alpha: 0.14),
                        const Color(0xFF2DD4BF).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 340,
              top: -32,
              child: IgnorePointer(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF472B6).withValues(alpha: 0.11),
                        const Color(0xFFF472B6).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: isMobile ? 10 : 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
          if (isMobile) ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(LucideIcons.menu, color: AppColors.navy, size: 22),
                tooltip: 'Open Navigation Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Builder(
              builder: (context) {
                final hour = DateTime.now().hour;
                String timeGreetingSi = 'සුබ සවසක්';
                String timeGreetingEn = 'Good evening';
                if (hour < 12) {
                  timeGreetingSi = 'සුබ උදෑසනක්';
                  timeGreetingEn = 'Good morning';
                } else if (hour < 16) {
                  timeGreetingSi = 'සුබ දහවලක්';
                  timeGreetingEn = 'Good afternoon';
                } else if (hour < 21) {
                  timeGreetingSi = 'සුබ සවසක්';
                  timeGreetingEn = 'Good evening';
                } else {
                  timeGreetingSi = 'සුබ රාත්‍රියක්';
                  timeGreetingEn = 'Good night';
                }

                final rawName = authState.userName ?? 'Kumara';
                final displayName = strings.isSinhala ? _toSinhalaName(rawName) : rawName;
                final honorificName = strings.isSinhala
                    ? (displayName.contains('මහත්මිය') || displayName.contains('මහතා') ? displayName : '$displayName මහත්මිය')
                    : rawName;
                final elderGreeting = strings.isSinhala
                    ? '$timeGreetingSi, $honorificName!'
                    : '$timeGreetingEn, $rawName!';
                final elderSubtitle = strings.isSinhala
                    ? 'ඔබගේ සම්පූර්ණ දිනක් සඳහා අප සමග සිටියයුතු අපි සතුටුයි.'
                    : 'We are with you for your mental health and wellness.';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (authState.isElder && strings.isSinhala) ...[
                          const Text('🌱', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            authState.isElder ? elderGreeting : strings.welcomeBack,
                            style: AppTextStyles.h4.copyWith(
                              fontSize: isMobile ? 14 : 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('👋', style: TextStyle(fontSize: 15)),
                      ],
                    ),
                    if (!isMobile)
                      Text(
                        authState.isElder
                            ? elderSubtitle
                            : strings.residentsWellnessOverview,
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accessible Language Switcher (English / සිංහල)
              LanguageSelectorButton(compact: isMobile),
              const SizedBox(width: 10),
              // Live Date and Time Chip
              if (!isMobile) _LiveDateTimeChip(isSinhala: strings.isSinhala),
              if (!isMobile) const SizedBox(width: 10),
              // Bell Notification Icon with Badge (Elder gets live game invite notifications; Staff keeps clinical alerts)
              if (authState.isElder && elderBellButton != null)
                elderBellButton
              else
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      constraints: const BoxConstraints(),
                      icon: const Icon(LucideIcons.bell, size: 24, color: AppColors.navy),
                      onPressed: () => context.go('/dashboard/alerts'),
                    ),
                    Positioned(
                      top: isMobile ? 2 : 4,
                      right: isMobile ? 2 : 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.riskHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${MockCarevoraData.alerts.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

  String _toSinhalaName(String name) {
    return SinhalaNameTransliterator.toSinhala(name);
  }
}

class _LiveDateTimeChip extends StatefulWidget {
  final bool isSinhala;

  const _LiveDateTimeChip({required this.isSinhala});

  @override
  State<_LiveDateTimeChip> createState() => _LiveDateTimeChipState();
}

class _LiveDateTimeChipState extends State<_LiveDateTimeChip> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const _monthsSi = [
    'ජනවාරි', 'පෙබරවාරි', 'මාර්තු', 'අප්‍රේල්', 'මැයි', 'ජූනි',
    'ජූලි', 'අගෝස්තු', 'සැප්තැම්බර්', 'ඔක්තෝබර්', 'නොවැම්බර්', 'දෙසැම්බර්'
  ];

  String _formatDate(DateTime dt) {
    if (widget.isSinhala) {
      return 'අද, ${dt.year} ${_monthsSi[dt.month - 1]} ${dt.day}';
    }
    return 'Today, ${dt.day} ${_monthsEn[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    if (widget.isSinhala) {
      final period = dt.hour >= 12 ? 'ප.ව.' : 'පෙ.ව.';
      return '$period ${hour.toString().padLeft(2, '0')}:$minute';
    }
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(_now);
    final timeStr = _formatTime(_now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.calendar,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          Container(
            width: 1.2,
            height: 15,
            margin: const EdgeInsets.symmetric(horizontal: 11),
            color: AppColors.border,
          ),
          const Icon(
            LucideIcons.clock,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

