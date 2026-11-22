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

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final authState = ref.watch(authProvider).state;
    final lang = ref.watch(languageProvider).currentLanguage;
    final strings = AppStrings(lang);

    return Scaffold(
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
            _buildTopBar(context, authState, strings: strings, isMobile: true),
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
                  _buildTopBar(context, authState, strings: strings, isMobile: false),
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
                  _buildTopBar(context, authState, strings: strings, isMobile: false),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AuthState authState, {
    required AppStrings strings,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 10 : 0,
      ),
      constraints: const BoxConstraints(minHeight: 70),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
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
                if (hour >= 5 && hour < 12) {
                  timeGreetingSi = 'සුබ උදෑසනක්';
                  timeGreetingEn = 'Good morning';
                } else if (hour >= 12 && hour < 16) {
                  timeGreetingSi = 'සුබ දහවලක්';
                  timeGreetingEn = 'Good afternoon';
                } else if (hour >= 16 && hour < 21) {
                  timeGreetingSi = 'සුබ සවසක්';
                  timeGreetingEn = 'Good evening';
                } else {
                  timeGreetingSi = 'සුබ රාත්‍රියක්';
                  timeGreetingEn = 'Good night';
                }

                final rawName = authState.userName ?? 'Kumara';
                final displayName = strings.isSinhala ? _toSinhalaName(rawName) : rawName;
                final elderGreeting = strings.isSinhala
                    ? '$timeGreetingSi, $displayName!'
                    : '$timeGreetingEn, $rawName!';
                final elderSubtitle = strings.isSinhala
                    ? 'ඔබේ මනෝසෞඛ්‍ය හා සුවසාධනය වෙනුවෙන් අපි ඔබ සමඟයි.'
                    : 'We are with you for your mental health and wellness.';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
              const SizedBox(width: 8),
              // Live Date and Time Chip
              if (!isMobile) _LiveDateTimeChip(isSinhala: strings.isSinhala),
              if (!isMobile) const SizedBox(width: 8),
              // Bell Notification Icon with Badge
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    constraints: const BoxConstraints(),
                    icon: const Icon(LucideIcons.bell, size: 20, color: AppColors.navy),
                    onPressed: () => context.go('/dashboard/alerts'),
                  ),
                    Positioned(
                      top: isMobile ? 2 : 4,
                      right: isMobile ? 2 : 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.riskHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${MockCarevoraData.alerts.length}',
                            style: const TextStyle(
                              fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
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
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Text(
            dateStr,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          Container(
            width: 1,
            height: 13,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.border,
          ),
          const Icon(
            LucideIcons.clock,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

