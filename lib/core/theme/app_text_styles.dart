import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Cached GoogleFonts styles so widget rebuilds do not re-trigger font
  // resolution calls on every frame or section build.
  static final TextStyle h1 = GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        letterSpacing: -0.5,
      );

  static final TextStyle h2 = GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        letterSpacing: -0.3,
      );

  static final TextStyle h3 = GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      );

  static final TextStyle h4 = GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      );

  // Body & UI (Inter)
  static final TextStyle body = GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.body,
        height: 1.5,
      );

  static final TextStyle bodyMedium = GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.navy,
      );

  static final TextStyle bodySmall = GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.body,
      );

  static final TextStyle caption = GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      );

  static final TextStyle button = GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  // Brand Serif Wordmark (Cormorant SC)
  static final TextStyle wordmark = GoogleFonts.cormorantSc(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        letterSpacing: 4.0,
      );

  static final TextStyle wordmarkSmall = GoogleFonts.cormorantSc(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
        letterSpacing: 2.0,
      );
}
