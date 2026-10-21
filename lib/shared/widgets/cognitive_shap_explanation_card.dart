import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class ShapFeatureDriver {
  final String featureName;
  final String impactLabel;
  final double weight; // 0.0 - 1.0
  final bool isRiskDriver; // true: pushes risk higher, false: protective
  final String description;

  const ShapFeatureDriver({
    required this.featureName,
    required this.impactLabel,
    required this.weight,
    required this.isRiskDriver,
    required this.description,
  });
}

class CognitiveShapExplanationCard extends StatelessWidget {
  final String riskLevel;
  final double? acrfScore;
  final bool isCompact;

  const CognitiveShapExplanationCard({
    super.key,
    required this.riskLevel,
    this.acrfScore,
    this.isCompact = false,
  });

  String _normalizeTier(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('high')) return 'High';
    if (lower.contains('moderate') || lower.contains('medium')) return 'Moderate';
    if (lower.contains('low')) return 'Low';
    if (acrfScore != null) {
      final scoreVal = (acrfScore! <= 1.0 && acrfScore! > 0.0) ? acrfScore! * 100.0 : acrfScore!;
      if (scoreVal >= 70.0) return 'Low';
      if (scoreVal >= 50.0) return 'Moderate';
      return 'High';
    }
    return 'Moderate';
  }

  List<ShapFeatureDriver> _getDriversForTier(String tier) {
    switch (tier) {
      case 'High':
        return const [
          ShapFeatureDriver(
            featureName: 'Lower Overall Score',
            impactLabel: '38% Impact',
            weight: 0.38,
            isRiskDriver: true,
            description: 'Overall score dropped below the resident\'s normal baseline.',
          ),
          ShapFeatureDriver(
            featureName: 'Trouble Remembering Things',
            impactLabel: '29% Impact',
            weight: 0.29,
            isRiskDriver: true,
            description: 'Struggled with recalling words and remembering date or place.',
          ),
          ShapFeatureDriver(
            featureName: 'Takes Longer to Answer',
            impactLabel: '21% Impact',
            weight: 0.21,
            isRiskDriver: true,
            description: 'Noticeable pauses and hesitation when answering questions.',
          ),
        ];

      case 'Moderate':
        return const [
          ShapFeatureDriver(
            featureName: 'Occasional Memory Slips',
            impactLabel: '24% Impact',
            weight: 0.24,
            isRiskDriver: true,
            description: 'Minor forgetfulness on multi-step recall questions.',
          ),
          ShapFeatureDriver(
            featureName: 'Slight Hesitation in Tasks',
            impactLabel: '18% Impact',
            weight: 0.18,
            isRiskDriver: true,
            description: 'Brief pauses before answering some exercises.',
          ),
          ShapFeatureDriver(
            featureName: 'Good Sense of Direction',
            impactLabel: 'Protective (26%)',
            weight: 0.26,
            isRiskDriver: false,
            description: 'Knowing their surroundings helps keep overall risk down.',
          ),
        ];

      case 'Low':
      default:
        return const [
          ShapFeatureDriver(
            featureName: 'Steady High Accuracy',
            impactLabel: 'Protective (42%)',
            weight: 0.42,
            isRiskDriver: false,
            description: 'Consistently good scores across all tests.',
          ),
          ShapFeatureDriver(
            featureName: 'Quick & Confident Answers',
            impactLabel: 'Protective (28%)',
            weight: 0.28,
            isRiskDriver: false,
            description: 'Answers promptly with no signs of hesitation.',
          ),
          ShapFeatureDriver(
            featureName: 'Good Balance in All Tasks',
            impactLabel: 'Protective (18%)',
            weight: 0.18,
            isRiskDriver: false,
            description: 'Healthy performance in memory, focus, and thinking.',
          ),
        ];
    }
  }

  String _getCaregiverTakeaway(String tier) {
    switch (tier) {
      case 'High':
        return 'Caregiver Tip: Give gentle reminders for date and time, help with daily routines, and let the doctor know.';
      case 'Moderate':
        return 'Caregiver Tip: Play daily 10-minute memory games to keep the mind active, and recheck in two weeks.';
      case 'Low':
      default:
        return 'Caregiver Tip: Brain wellness is strong and steady! Keep up cheerful daily conversations and activities.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = _normalizeTier(riskLevel);
    final drivers = _getDriversForTier(tier);
    final takeaway = _getCaregiverTakeaway(tier);

    final Color primaryColor = tier == 'High'
        ? AppColors.riskHigh
        : (tier == 'Moderate' ? AppColors.riskModerate : AppColors.riskLow);

    final Color badgeBg = tier == 'High'
        ? AppColors.riskHighBg
        : (tier == 'Moderate' ? AppColors.riskModerateBg : AppColors.riskLowBg);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Why this Risk?',
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$tier Risk • SHAP AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Main reasons identified during the assessment:',
            style: TextStyle(
              fontSize: isCompact ? 11 : 11.5,
              color: AppColors.muted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Drivers List
          ...drivers.map((driver) {
            final Color barColor = driver.isRiskDriver
                ? (tier == 'High' ? AppColors.riskHigh : AppColors.riskModerate)
                : AppColors.riskLow;

            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          driver.featureName,
                          style: TextStyle(
                            fontSize: isCompact ? 11.5 : 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        driver.impactLabel,
                        style: TextStyle(
                          fontSize: isCompact ? 10.5 : 11,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: driver.weight.clamp(0.05, 1.0),
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE9E4F5),
                      color: barColor,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: 3),
                    Text(
                      driver.description,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.body,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 4),

          // Caregiver Action Takeaway
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: badgeBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lightbulb, size: 14, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    takeaway,
                    style: TextStyle(
                      fontSize: isCompact ? 11 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: tier == 'High'
                          ? const Color(0xFF991B1B)
                          : (tier == 'Moderate' ? const Color(0xFF92400E) : const Color(0xFF166534)),
                      height: 1.35,
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
}
