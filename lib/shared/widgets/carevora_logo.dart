import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum LogoVariant {
  full,
  iconOnly,
  wordmarkOnly,
}

class CarevoraLogo extends StatelessWidget {
  final LogoVariant variant;
  final double size;
  final bool isDark;

  const CarevoraLogo({
    super.key,
    this.variant = LogoVariant.full,
    this.size = 40,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case LogoVariant.iconOnly:
        return _buildIcon();
      case LogoVariant.wordmarkOnly:
        return _buildWordmark();
      case LogoVariant.full:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CAREVORA',
                    style: AppTextStyles.wordmarkSmall.copyWith(
                      fontSize: size * 0.55,
                      color: isDark ? Colors.white : AppColors.navy,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Compassionate Care, Smarter Tomorrow',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: (size * 0.24).clamp(9.5, 12.0),
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildIcon() {
    final logoImage = Image.asset(
      'assets/images/carevora_logo_official.png',
      width: size * 1.18,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (isDark) {
      final badgeSize = size * 1.24;
      return Container(
        width: badgeSize,
        height: badgeSize,
        padding: EdgeInsets.all(size * 0.14),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF3EEFF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA78BFA).withValues(alpha: 0.34),
              blurRadius: size * 0.38,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: logoImage,
      );
    }

    return SizedBox(
      width: size * 1.18,
      height: size,
      child: Center(child: logoImage),
    );
  }

  Widget _buildWordmark() {
    return Text(
      'CAREVORA',
      style: AppTextStyles.wordmark.copyWith(
        fontSize: size * 0.8,
        color: isDark ? Colors.white : AppColors.navy,
      ),
    );
  }
}
