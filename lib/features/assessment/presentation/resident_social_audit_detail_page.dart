import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/carevora_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/social_audit_service.dart';
import 'widgets/caregiver_social_audit_dialog.dart';

String _formatAuditDate(DateTime dt, {bool fullMonth = false}) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const fullMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final m = fullMonth ? fullMonths[dt.month - 1] : months[dt.month - 1];
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  return '$day $m ${dt.year}, ${hour.toString().padLeft(2, '0')}:$min $period';
}

class ResidentSocialAuditDetailPage extends ConsumerStatefulWidget {
  final String residentId;

  const ResidentSocialAuditDetailPage({
    super.key,
    required this.residentId,
  });

  @override
  ConsumerState<ResidentSocialAuditDetailPage> createState() =>
      _ResidentSocialAuditDetailPageState();
}

class _ResidentSocialAuditDetailPageState
    extends ConsumerState<ResidentSocialAuditDetailPage> {
  bool _isLoading = true;
  String? _errorMessage;

  ResidentAuditDirectoryItem? _residentSummary;
  List<SocialAuditRecord> _auditHistory = [];
  SocialAuditRecord? get _latestAudit {
    if (_auditHistory.isNotEmpty) return _auditHistory.first;
    final parsedId = int.tryParse(widget.residentId) ?? 1;
    return SocialAuditService.getLiveAudit(parsedId);
  }

  @override
  void initState() {
    super.initState();
    _loadResidentAuditDetails();
  }

  Future<void> _loadResidentAuditDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authState = ref.read(authProvider).state;
    final token = authState.token;
    final parsedId = int.tryParse(widget.residentId) ?? 1;

    try {
      // 1. Fetch resident metadata via directory search or fallback
      final directory = await SocialAuditService.fetchResidentAuditDirectory(
        token: token,
      );
      ResidentAuditDirectoryItem? matched = directory.firstWhere(
        (r) => r.residentId == parsedId,
        orElse: () => ResidentAuditDirectoryItem(
          residentId: parsedId,
          name: 'Resident #$parsedId',
          roomNumber: '101',
          age: 75,
          hasCompletedAudit: false,
          auditCount: 0,
        ),
      );

      // 2. Fetch full historical audits for this specific resident
      var history = await SocialAuditService.fetchAuditHistory(
        residentId: parsedId,
        token: token,
      );

      final liveAudit = SocialAuditService.getLiveAudit(parsedId);
      if (liveAudit != null) {
        if (!history.any((a) => a.id == liveAudit.id)) {
          history = [liveAudit, ...history];
        }
        if (matched.name.startsWith('Resident #') || !matched.hasCompletedAudit) {
          matched = ResidentAuditDirectoryItem(
            residentId: parsedId,
            name: liveAudit.residentName,
            roomNumber: matched.roomNumber ?? '102',
            age: matched.age ?? 74,
            elderHomeName: matched.elderHomeName ?? 'Serene Valley Senior Living',
            hasCompletedAudit: true,
            latestAuditDate: liveAudit.auditDate,
            latestSocialScore: liveAudit.socialScore,
            auditCount: history.length,
          );
        }
      }

      if (mounted) {
        setState(() {
          _residentSummary = matched;
          _auditHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load resident audit records: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openRecordAuditDialog() {
    final authState = ref.read(authProvider).state;
    if (authState.isElder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only authorized caregivers and staff can record social audits.'),
          backgroundColor: AppColors.riskHigh,
        ),
      );
      return;
    }

    final residentObj = Resident(
      id: widget.residentId,
      name: _residentSummary?.name ?? 'Resident #${widget.residentId}',
      roomNo: _residentSummary?.roomNumber ?? '101',
      age: _residentSummary?.age ?? 75,
      gender: 'Resident',
      lastAssessmentDate: _latestAudit != null
          ? _formatAuditDate(_latestAudit!.auditDate)
          : 'Awaiting Audit',
      cognitiveScore: 0.70,
      cognitiveTrend: 0.0,
      emotionalScore: 0.75,
      emotionalTrend: 0.0,
      metabolicScore: 0.70,
      metabolicTrend: 0.0,
      overallIndex: 0.72,
      overallTrend: 0.0,
      socialScore: _latestAudit?.socialScore,
    );

    showDialog<SocialAuditRecord>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CaregiverSocialAuditDialog(
        resident: residentObj,
        backendResidentId: int.tryParse(widget.residentId) ?? 1,
        caregiverName: authState.userName ?? 'Caregiver Specialist',
        authToken: authState.token,
        onAuditSaved: (savedRecord) {
          _loadResidentAuditDetails();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Caregiver Social Audit recorded for ${residentObj.name}! (Score: ${savedRecord.socialScore != null ? "${savedRecord.socialScore!.toStringAsFixed(1)}%" : "Unassessed"})',
              ),
              backgroundColor: const Color(0xFF166534),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSecondary,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _errorMessage != null
                ? _buildErrorView()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopBreadcrumb(),
                            const SizedBox(height: 16),
                            _buildResidentProfileBanner(),
                            const SizedBox(height: 20),
                            _buildActionHeader(),
                            const SizedBox(height: 20),
                            if (_latestAudit != null) ...[
                              _buildLatestAuditBreakdown(),
                              const SizedBox(height: 24),
                            ] else ...[
                              _buildUnassessedCard(),
                              const SizedBox(height: 24),
                            ],
                            _buildAuditHistorySection(),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildTopBreadcrumb() {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/dashboard/social-audit'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(LucideIcons.arrowLeft, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Back to Social Audit Hub',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('/', style: TextStyle(color: AppColors.muted)),
        const SizedBox(width: 8),
        Text(
          _residentSummary?.name ?? 'Resident #${widget.residentId}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildResidentProfileBanner() {
    final name = _residentSummary?.name ?? 'Resident #${widget.residentId}';
    final room = _residentSummary?.roomNumber ?? '101';
    final age = _residentSummary?.age ?? 75;
    final home = _residentSummary?.elderHomeName ?? 'Serene Valley Senior Living';
    final hasAudit = _latestAudit != null;

    final initials = name
        .split(' ')
        .where((w) => !w.startsWith('Mr.') && !w.startsWith('Mrs.') && !w.startsWith('Dr.'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials.isNotEmpty ? initials : 'R',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasAudit ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasAudit ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasAudit ? LucideIcons.shieldCheck : LucideIcons.alertCircle,
                            size: 13,
                            color: hasAudit ? const Color(0xFF166534) : const Color(0xFF92400E),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasAudit
                                ? 'Verified Caregiver Audit (${_latestAudit!.socialScore != null ? "${_latestAudit!.socialScore!.toStringAsFixed(1)}%" : "Recorded"})'
                                : 'Awaiting Staff Observational Audit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasAudit ? const Color(0xFF166534) : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  children: [
                    _buildMetaTag(LucideIcons.home, 'Room $room'),
                    _buildMetaTag(LucideIcons.user, 'Age $age'),
                    _buildMetaTag(LucideIcons.building, home),
                    _buildMetaTag(
                      LucideIcons.clock,
                      hasAudit
                          ? 'Latest Audit: ${_formatAuditDate(_latestAudit!.auditDate)}'
                          : 'No Prior Audit',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }

  Widget _buildActionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Social Isolation & Engagement Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            SizedBox(height: 2),
            Text(
              'Observational social telemetry evaluated across visits, peers, activities, and solitude context.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/dashboard/emotional?residentId=${widget.residentId}'),
              icon: const Icon(LucideIcons.heartHandshake, size: 16),
              label: const Text('View Emotional Wellness'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.lilac),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _openRecordAuditDialog,
              icon: const Icon(LucideIcons.clipboardPlus, size: 16),
              label: const Text('Record Social Audit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLatestAuditBreakdown() {
    final audit = _latestAudit!;
    final score = audit.socialScore;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Latest Observational Assessment (${audit.reportingPeriodDays}-Day Window)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                ],
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lilac),
                  ),
                  child: Text(
                    'Social Score: ${score.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 700;
              return GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _buildDomainMetricCard(
                    title: '1. Family & Friends',
                    icon: LucideIcons.users,
                    primaryText: audit.externalContactUnknown
                        ? 'Unknown / Not Logged'
                        : '${audit.totalExternalContacts ?? (audit.familyInPersonVisits ?? 0) + (audit.familyPhoneVideoContacts ?? 0)} Contacts',
                    subText: audit.externalContactUnknown
                        ? 'Staff had no visitor contact'
                        : '${audit.familyInPersonVisits ?? 0} visits • ${audit.familyPhoneVideoContacts ?? 0} calls',
                    color: AppColors.primary,
                  ),
                  _buildDomainMetricCard(
                    title: '2. Peer Interaction',
                    icon: LucideIcons.messageCircle,
                    primaryText: audit.peerInteractionLevel.label.split('(')[0].trim(),
                    subText: audit.peerInteractionLevel.label.contains('(')
                        ? audit.peerInteractionLevel.label.split('(')[1].replaceAll(')', '')
                        : 'Dining / Lounging interaction',
                    color: Colors.blueAccent,
                  ),
                  _buildDomainMetricCard(
                    title: '3. Group Activities',
                    icon: LucideIcons.calendarCheck,
                    primaryText: audit.activitiesAttended != null && audit.activitiesAvailable != null
                        ? '${audit.activitiesAttended}/${audit.activitiesAvailable} Attended'
                        : audit.activityParticipationLevel.label.split('(')[0].trim(),
                    subText: audit.activityParticipationLevel.label.split('(')[0].trim(),
                    color: const Color(0xFF16A34A),
                  ),
                  _buildDomainMetricCard(
                    title: '4. Solitude Context',
                    icon: LucideIcons.userMinus,
                    primaryText: audit.aloneTimeContext.label.split('(')[0].trim(),
                    subText: audit.estimatedHoursAlonePerDay != null
                        ? '~${audit.estimatedHoursAlonePerDay!.toStringAsFixed(1)} hrs/day in room'
                        : 'Autonomous vs. involuntary',
                    color: const Color(0xFFD97706),
                  ),
                ],
              );
            },
          ),
          if (audit.caregiverNotes != null && audit.caregiverNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caregiver Observational Clinical Notes:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    audit.caregiverNotes!,
                    style: const TextStyle(fontSize: 12, color: AppColors.body, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recorded by: ${audit.caregiverName}${audit.caregiverStaffCode != null ? " (${audit.caregiverStaffCode})" : ""}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                'Algorithm: ${audit.scoreProvenance ?? "CAREVORA-OBS-SOC-V1"} (Observational Scale)',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDomainMetricCard({
    required String title,
    required IconData icon,
    required String primaryText,
    required String subText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            primaryText,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUnassessedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.clipboardX, size: 44, color: AppColors.muted),
          const SizedBox(height: 14),
          const Text(
            'Unassessed — No Caregiver Social Audit On File',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 6),
          const Text(
            'This resident has not yet undergone an observational social assessment.\nClick "Record Social Audit" above to log external visits, peer interaction, and group participation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _openRecordAuditDialog,
            icon: const Icon(LucideIcons.plusCircle, size: 16),
            label: const Text('Record First Social Audit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historical Observational Audit Timeline (${_auditHistory.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              IconButton(
                onPressed: _loadResidentAuditDetails,
                icon: const Icon(LucideIcons.refreshCw, size: 16, color: AppColors.primary),
                tooltip: 'Refresh Timeline',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_auditHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No historical audit logs recorded for this resident yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _auditHistory.length,
              separatorBuilder: (context, index) => const Divider(height: 24, color: AppColors.border),
              itemBuilder: (context, idx) {
                final item = _auditHistory[idx];
                final isLatest = idx == 0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isLatest ? AppColors.primarySoft : AppColors.surfaceSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLatest ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isLatest ? LucideIcons.badgeCheck : LucideIcons.history,
                        size: 16,
                        color: isLatest ? AppColors.primary : AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatAuditDate(item.auditDate, fullMonth: true),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                ),
                              ),
                              if (item.socialScore != null)
                                Text(
                                  'Score: ${item.socialScore!.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Logged by: ${item.caregiverName} • Reporting period: ${item.reportingPeriodDays} days',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Peer: ${item.peerInteractionLevel.label.split("(")[0].trim()} | Activities: ${item.activityParticipationLevel.label.split("(")[0].trim()} | Solitude: ${item.aloneTimeContext.label.split("(")[0].trim()}',
                            style: const TextStyle(fontSize: 12, color: AppColors.body),
                          ),
                          if (item.caregiverNotes != null && item.caregiverNotes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Notes: "${item.caregiverNotes}"',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 40, color: AppColors.riskHigh),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.riskHigh),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadResidentAuditDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
