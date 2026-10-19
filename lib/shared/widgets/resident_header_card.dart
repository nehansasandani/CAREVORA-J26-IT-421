import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/carevora_models.dart';
import 'carevora_avatar.dart';

class ResidentHeaderCard extends StatelessWidget {
  final Resident resident;
  final VoidCallback? onViewProfile;
  final VoidCallback? onViewDetailedReport;

  const ResidentHeaderCard({
    super.key,
    required this.resident,
    this.onViewProfile,
    this.onViewDetailedReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CarevoraAvatar(
                avatarUrl: resident.avatarUrl,
                radius: 26,
                initials: resident.name.isNotEmpty
                    ? resident.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                    : 'R',
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(resident.name, style: AppTextStyles.h3),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          'ID: ${resident.id}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Age: ${resident.age} • ${resident.gender} • Room No: ${resident.roomNo}',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onViewProfile,
                        child: Text(
                          'View Profile →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Last Assessment', style: AppTextStyles.caption),
                  Text(resident.lastAssessmentDate,
                      style: AppTextStyles.bodyMedium),
                ],
              ),
              ElevatedButton(
                onPressed: onViewDetailedReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('View Detailed Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
