import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/risk_utils.dart';
import 'risk_badge.dart';

class ScoreCard extends StatelessWidget {
  final String title;
  final double score;
  final double delta;
  final bool isGauge;
  final VoidCallback? onTap;
  final String? customBadgeLabel;
  final Color? customBadgeColor;
  final Color? customBadgeBgColor;
  final Color? customDeltaColor;

  const ScoreCard({
    super.key,
    required this.title,
    required this.score,
    required this.delta,
    this.isGauge = false,
    this.onTap,
    this.customBadgeLabel,
    this.customBadgeColor,
    this.customBadgeBgColor,
    this.customDeltaColor,
  });

  @override
  Widget build(BuildContext context) {
    final tier = RiskUtils.getTier(score);

    Widget content = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.h4.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              RiskBadge(
                score: score,
                customLabel: customBadgeLabel,
                customColor: customBadgeColor,
                customBgColor: customBadgeBgColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isGauge)
            Center(
              child: SizedBox(
                width: 140,
                height: 75,
                child: CustomPaint(
                  painter: _SemicircleGaugePainter(score: score, color: tier.color),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      RiskUtils.formatScore(score),
                      style: AppTextStyles.h2.copyWith(fontSize: 22),
                    ),
                  ),
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  RiskUtils.formatScore(score),
                  style: AppTextStyles.h1.copyWith(fontSize: 28),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ 1.00',
                  style: AppTextStyles.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 14,
                color: customDeltaColor ?? (delta >= 0 ? AppColors.riskHigh : AppColors.riskLow),
              ),
              const SizedBox(width: 4),
              Text(
                '${(delta.abs()).toStringAsFixed(2)} vs previous test',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: customDeltaColor ?? (delta >= 0 ? AppColors.riskHigh : AppColors.riskLow),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      );
    }

    return content;
  }
}

class _SemicircleGaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _SemicircleGaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 8;

    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    final sweep = math.pi * score.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SemicircleGaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
