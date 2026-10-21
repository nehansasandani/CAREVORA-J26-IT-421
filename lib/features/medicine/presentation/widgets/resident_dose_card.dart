import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/carevora_avatar.dart';
import '../../../doctor/domain/models.dart';
import '../widgets/dose_status_chip.dart';

class ResidentDoseCard extends StatelessWidget {
  final Resident resident;
  final List<DoseEvent> slotEvents;
  final List<Prescription> prescriptions;
  final String status; // 'given', 'overdue', 'pending', 'upcoming'
  final String? lateLabel;
  final VoidCallback onTap;

  const ResidentDoseCard({
    super.key,
    required this.resident,
    required this.slotEvents,
    required this.prescriptions,
    required this.status,
    this.lateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color cardBg = Colors.white;
    Color borderColor = AppColors.border;

    if (status == 'given') {
      cardBg = AppColors.riskLowBg.withValues(alpha: 0.4);
      borderColor = AppColors.riskLow;
    } else if (status == 'overdue') {
      cardBg = AppColors.riskHighBg.withValues(alpha: 0.3);
      borderColor = AppColors.riskHigh;
    } else if (status == 'pending') {
      borderColor = AppColors.riskModerate;
    }

    final givenCount = slotEvents.where((e) => e.status == DoseStatus.given).length;
    final totalCount = slotEvents.length;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: status == 'given' || status == 'overdue' ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CarevoraAvatar(
                    avatarUrl: resident.avatarUrl,
                    radius: 18,
                    initials: resident.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                    backgroundColor: status == 'given' ? AppColors.riskLowBg : AppColors.primarySoft,
                    foregroundColor: status == 'given' ? AppColors.riskLow : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resident.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ROOM ${resident.roomNo} • $totalCount med(s)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  DoseStatusChip(status: status, lateLabel: lateLabel),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: $givenCount/$totalCount given',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.body),
                  ),
                  Icon(
                    status == 'given' ? Icons.check_circle : Icons.chevron_right,
                    size: 18,
                    color: status == 'given' ? AppColors.riskLow : AppColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
