import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class PhotoFrame extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final double borderRadius;
  final bool isArch;
  final Widget? overlayWidget;

  const PhotoFrame({
    super.key,
    required this.assetPath,
    this.width = 420,
    this.height = 480,
    this.borderRadius = 28,
    this.isArch = false,
    this.overlayWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Lavender decorative offset ring/shape
        Positioned(
          top: -12,
          right: -12,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.lilac.withValues(alpha: 0.45),
              borderRadius: isArch
                  ? BorderRadius.vertical(
                      top: Radius.circular(width / 2),
                      bottom: Radius.circular(borderRadius),
                    )
                  : BorderRadius.circular(borderRadius),
            ),
          ),
        ),
        // Main Photo with graceful fallback
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: isArch
                ? BorderRadius.vertical(
                    top: Radius.circular(width / 2),
                    bottom: Radius.circular(borderRadius),
                  )
                : BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: isArch
                ? BorderRadius.vertical(
                    top: Radius.circular(width / 2),
                    bottom: Radius.circular(borderRadius),
                  )
                : BorderRadius.circular(borderRadius),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            ),
          ),
        ),
        ?overlayWidget,
      ],
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.lavenderBg, Color(0xFFF0EBF8), AppColors.lilac],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.health_and_safety_rounded,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Carevora Clinical Photo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Compassionate Eldercare',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
