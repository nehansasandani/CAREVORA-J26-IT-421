import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_colors.dart';

class LanguageSelectorButton extends ConsumerWidget {
  final bool compact;

  const LanguageSelectorButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageNotifier = ref.watch(languageProvider);
    final isSinhala = languageNotifier.isSinhala;

    if (compact) {
      return InkWell(
        onTap: () => languageNotifier.toggleLanguage(),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSinhala ? '🇱🇰 සිංහල' : '🇬🇧 EN',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageOption(
            title: 'English',
            flag: '🇬🇧',
            isSelected: !isSinhala,
            onTap: () => languageNotifier.setLanguage(AppLanguage.english),
          ),
          const SizedBox(width: 5),
          _buildLanguageOption(
            title: 'සිංහල',
            flag: '🇱🇰',
            isSelected: isSinhala,
            onTap: () => languageNotifier.setLanguage(AppLanguage.sinhala),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
