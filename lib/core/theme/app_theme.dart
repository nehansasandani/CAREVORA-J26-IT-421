import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

@immutable
class CarevoraThemeExtension extends ThemeExtension<CarevoraThemeExtension> {
  final Color primary;
  final Color primaryDeep;
  final Color primarySoft;
  final Color navy;
  final Color lavenderBg;
  final Color card;
  final Color border;

  const CarevoraThemeExtension({
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.navy,
    required this.lavenderBg,
    required this.card,
    required this.border,
  });

  @override
  CarevoraThemeExtension copyWith({
    Color? primary,
    Color? primaryDeep,
    Color? primarySoft,
    Color? navy,
    Color? lavenderBg,
    Color? card,
    Color? border,
  }) {
    return CarevoraThemeExtension(
      primary: primary ?? this.primary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      primarySoft: primarySoft ?? this.primarySoft,
      navy: navy ?? this.navy,
      lavenderBg: lavenderBg ?? this.lavenderBg,
      card: card ?? this.card,
      border: border ?? this.border,
    );
  }

  @override
  CarevoraThemeExtension lerp(ThemeExtension<CarevoraThemeExtension>? other, double t) {
    if (other is! CarevoraThemeExtension) return this;
    return CarevoraThemeExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      navy: Color.lerp(navy, other.navy, t)!,
      lavenderBg: Color.lerp(lavenderBg, other.lavenderBg, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accentPink,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.dashboardBg,
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        titleLarge: AppTextStyles.h3,
        titleMedium: AppTextStyles.h4,
        bodyLarge: AppTextStyles.bodyMedium,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
        ),
      ),
      extensions: const [
        CarevoraThemeExtension(
          primary: AppColors.primary,
          primaryDeep: AppColors.primaryDeep,
          primarySoft: AppColors.primarySoft,
          navy: AppColors.navy,
          lavenderBg: AppColors.lavenderBg,
          card: AppColors.card,
          border: AppColors.border,
        ),
      ],
    );
  }
}
