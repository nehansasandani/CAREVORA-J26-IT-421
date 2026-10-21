import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/carevora_avatar.dart';
import '../../../doctor/domain/models.dart';
import '../../../doctor/presentation/widgets/doctor_components.dart';

class DoseDetailSheet extends StatefulWidget {
  final Resident resident;
  final DoseSlot slot;
  final SlotWindow window;
  final List<DoseEvent> events;
  final List<Prescription> prescriptions;
  final String currentUser;
  final bool isReadOnly;
  final Function(DoseEvent event, DoseStatus newStatus, String? note) onMarkStatus;
  final VoidCallback onMarkAllGiven;

  const DoseDetailSheet({
    super.key,
    required this.resident,
    required this.slot,
    required this.window,
    required this.events,
    required this.prescriptions,
    required this.currentUser,
    required this.isReadOnly,
    required this.onMarkStatus,
    required this.onMarkAllGiven,
  });

  @override
  State<DoseDetailSheet> createState() => _DoseDetailSheetState();
}

class _DoseDetailSheetState extends State<DoseDetailSheet> {
  void _showNotGivenDialog(DoseEvent event) {
    String selectedReason = 'Refused';
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Dose as Not Given', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedReason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: ['Refused', 'Held by doctor', 'Vomited', 'Not available', 'Other']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => selectedReason = v ?? selectedReason,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Additional Clinical Note'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.riskHigh),
            onPressed: () {
              final status = selectedReason == 'Refused' ? DoseStatus.refused : DoseStatus.held;
              widget.onMarkStatus(event, status, '$selectedReason: ${noteCtrl.text.trim()}');
              Navigator.pop(ctx);
            },
            child: const Text('Confirm Status', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                CarevoraAvatar(
                  avatarUrl: widget.resident.avatarUrl,
                  radius: 24,
                  initials: widget.resident.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.resident.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      Text('ROOM ${widget.resident.roomNo} • ${widget.resident.age} yrs • ${widget.slot.name.toUpperCase()} SLOT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Allergy Chips
            if (widget.resident.allergies.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                children: widget.resident.allergies.map((a) => Chip(
                  backgroundColor: AppColors.riskHighBg,
                  label: Text('Allergy: $a', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.riskHigh)),
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],

            const Divider(),
            const SizedBox(height: 10),

            // Medicines List
            const Text('Slot Medications to Administer:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 15)),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.events.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (ctx, i) {
                final event = widget.events[i];
                final rx = widget.prescriptions.firstWhere((p) => p.id == event.prescriptionId, orElse: () => Prescription(
                  id: '', residentId: '', doctorId: '', medicineName: 'Unknown', strength: '', form: PrescriptionForm.tablet, doseAmount: '', pattern: const DosePattern(), mealTiming: MealTiming.anyTime, startDate: DateTime.now(), durationDays: 1, endDate: DateTime.now(), instructions: '', type: PrescriptionType.regular, status: PrescriptionStatus.active, createdAt: DateTime.now(),
                ));

                final isGiven = event.status == DoseStatus.given;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isGiven ? AppColors.riskLowBg.withValues(alpha: 0.3) : AppColors.dashboardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isGiven ? AppColors.riskLow : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${rx.medicineName} ${rx.strength}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                          MealTimingBadge(mealTiming: rx.mealTiming),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Dose: ${rx.doseAmount} • ${rx.instructions}', style: const TextStyle(fontSize: 12, color: AppColors.body)),
                      Text('Prescribed by ${rx.doctorId}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 10),

                      if (!widget.isReadOnly)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isGiven ? AppColors.riskLow : AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  widget.onMarkStatus(
                                    event,
                                    isGiven ? DoseStatus.pending : DoseStatus.given,
                                    isGiven ? 'Undone by caregiver' : 'Given at scheduled time',
                                  );
                                },
                                icon: Icon(isGiven ? Icons.check_circle : Icons.check, color: Colors.white, size: 16),
                                label: Text(isGiven ? 'Given (Tap to Undo)' : 'Mark as Given', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.riskHigh, side: const BorderSide(color: AppColors.riskHigh)),
                              onPressed: () => _showNotGivenDialog(event),
                              child: const Text('Not Given', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            if (!widget.isReadOnly)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.riskLow),
                  onPressed: () {
                    widget.onMarkAllGiven();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  label: const Text('Mark All Medications as Given', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
