import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_carevora_data.dart';
import '../../../data/models/carevora_models.dart';
import '../../assessment/application/cognitive_assessment_service.dart';
import '../../auth/application/auth_controller.dart';

/// Shared real-time clinical alert synchronizer used by both the top-bar bell
/// badge (DashboardShell) and AlertsNotificationsPage so counts always match 100%.
class ClinicalAlertsSync {
  ClinicalAlertsSync._();

  static bool _isSyncing = false;
  static bool _hasSyncedOnce = false;
  static int? _lastSyncedHomeId;

  static bool get isSyncing => _isSyncing;

  static Future<void> sync(
    AuthState authState, {
    bool force = false,
  }) async {
    if (authState.isElder) return;
    if (_isSyncing) return;

    final caregiverHomeId = authState.elderHomeId;
    if (_hasSyncedOnce && !force && _lastSyncedHomeId == caregiverHomeId) {
      return;
    }

    _isSyncing = true;
    try {
      await MockCarevoraData.loadAttendanceLog();

      // Remove any legacy hardcoded dummy alerts (ALT-1 / ALT-3) if still in memory after hot reload
      MockCarevoraData.alerts.removeWhere(
        (a) => a.id == 'ALT-1' || a.id == 'ALT-3',
      );

      String? token = authState.token;
      if (token == null || token.isEmpty) {
        if (authState.email != null && authState.email!.isNotEmpty) {
          token = await CognitiveAssessmentService.getCaregiverToken(
            email: authState.email!,
          );
        }
      }

      List<CognitiveResidentProfile> residents = [];
      try {
        residents = await CognitiveAssessmentService.fetchResidents(token: token);
      } catch (_) {}

      if (residents.isNotEmpty) {
        // Rebuild the real cognitive alerts list cleanly for this care home
        MockCarevoraData.alerts.removeWhere((a) => a.id.startsWith('ALT-COG'));

        for (final res in residents) {
          // Scope strictly to the signed-in staff member's elder home when known
          if (caregiverHomeId != null &&
              res.elderHomeId != null &&
              res.elderHomeId != caregiverHomeId) {
            continue;
          }

          List<CognitiveSubmissionResult> history = [];
          try {
            history = await CognitiveAssessmentService.fetchHistory(
              residentId: res.id,
              token: token,
            );
          } catch (_) {}
          if (history.isEmpty) continue;

          // Skip in-progress or pending review sessions without finalized clinical scores
          final evaluatedAssessments = history
              .where(
                (h) =>
                    h.acrfScore != null ||
                    (h.status != null &&
                        h.status != 'IN_PROGRESS' &&
                        h.status != 'PENDING_CAREGIVER_REVIEW'),
              )
              .toList();

          final latest = evaluatedAssessments.isNotEmpty
              ? evaluatedAssessments.first
              : history.first;

          final bool isHighRisk =
              (latest.riskLevel?.toLowerCase().contains('high') ?? false) ||
              (latest.mlPrediction?.toLowerCase().contains('high') ?? false) ||
              (latest.alertTriggered == true) ||
              (latest.acrfScore != null && latest.acrfScore! < 50.0);

          if (!isHighRisk) continue;

          final resName = (res.name.trim().isNotEmpty
                  ? res.name
                  : latest.residentName)
              .trim();
          final scoreVal = latest.acrfScore ?? 0.0;
          final scoreText = '${scoreVal.toStringAsFixed(1)}/100';
          final roomNo = res.roomNumber.trim();

          String formattedTime = 'Recent Assessment';
          if (latest.createdAt != null && latest.createdAt!.isNotEmpty) {
            try {
              final parsedDate = DateTime.parse(latest.createdAt!).toLocal();
              final now = DateTime.now();
              final isToday = parsedDate.year == now.year &&
                  parsedDate.month == now.month &&
                  parsedDate.day == now.day;
              final hh = parsedDate.hour.toString().padLeft(2, '0');
              final mm = parsedDate.minute.toString().padLeft(2, '0');
              formattedTime = isToday
                  ? 'Today, $hh:$mm'
                  : '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}, $hh:$mm';
            } catch (_) {
              formattedTime = latest.createdAt!;
            }
          }

          MockCarevoraData.alerts.insert(
            0,
            AlertItem(
              id: 'ALT-COG-REAL-${res.id}-${latest.id ?? 'latest'}',
              title: 'High Cognitive Impairment Risk: $resName',
              description: roomNo.isNotEmpty
                  ? 'Cognitive assessment score ($scoreText) indicates acute cognitive decline risk for $resName in Room $roomNo. Prompt caregiver review and clinical attention recommended.'
                  : 'Cognitive assessment score ($scoreText) indicates acute cognitive decline risk for $resName. Prompt caregiver review and clinical attention recommended.',
              severity: 'High',
              timestamp: formattedTime,
              residentName: resName,
              roomNo: roomNo.isNotEmpty ? roomNo : null,
              residentAge: (res.age != null && res.age! > 0) ? res.age : null,
              residentGender: (res.gender != null && res.gender!.trim().isNotEmpty)
                  ? res.gender!.trim()
                  : null,
              currentStatus: 'High Cognitive Risk',
              cognitiveScore: scoreVal,
            ),
          );
        }
      }

      _hasSyncedOnce = true;
      _lastSyncedHomeId = caregiverHomeId;
      MockCarevoraData.notifyAlertsChanged();
    } catch (_) {
      MockCarevoraData.notifyAlertsChanged();
    } finally {
      _isSyncing = false;
    }
  }
}

class AlertsNotificationsPage extends ConsumerStatefulWidget {
  const AlertsNotificationsPage({super.key});

  @override
  ConsumerState<AlertsNotificationsPage> createState() =>
      _AlertsNotificationsPageState();
}

class _AlertsNotificationsPageState
    extends ConsumerState<AlertsNotificationsPage> {
  String _selectedFilter = 'Pending';
  bool? _isRefreshing;

  bool get _refreshing => _isRefreshing ?? false;

  String get _effectiveFilter {
    if (_selectedFilter == 'Pending' ||
        _selectedFilter == 'Urgent' ||
        _selectedFilter == 'Attended') {
      return _selectedFilter;
    }
    return 'Pending';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAlerts(force: false);
    });
  }

  Future<void> _refreshAlerts({bool force = false}) async {
    if (_refreshing) return;
    final authState = ref.read(authProvider).state;
    if (authState.isElder) return;

    if (mounted) setState(() => _isRefreshing = true);
    await ClinicalAlertsSync.sync(authState, force: force);
    if (mounted) setState(() => _isRefreshing = false);
  }

  String _nowFormattedDateTime() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = now.day.toString().padLeft(2, '0');
    final mon = months[now.month - 1];
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$day $mon ${now.year}, $hh:$mm';
  }

  void _toggleAcknowledge(String alertId, String staffName) {
    setState(() {
      if (MockCarevoraData.acknowledgedAlertIds.contains(alertId)) {
        MockCarevoraData.acknowledgedAlertIds.remove(alertId);
        MockCarevoraData.alertAttendanceLog.remove(alertId);
      } else {
        MockCarevoraData.acknowledgedAlertIds.add(alertId);
        MockCarevoraData.alertAttendanceLog[alertId] = {
          'by': staffName,
          'time': _nowFormattedDateTime(),
        };
      }
    });
    MockCarevoraData.saveAttendanceLog();
    MockCarevoraData.notifyAlertsChanged();
  }

  void _markAllAttended(List<AlertItem> alerts, String staffName) {
    final nowStr = _nowFormattedDateTime();
    setState(() {
      for (final a in alerts) {
        MockCarevoraData.acknowledgedAlertIds.add(a.id);
        final existing = MockCarevoraData.alertAttendanceLog[a.id];
        if (existing == null || (existing['by']?.trim().isEmpty ?? true)) {
          MockCarevoraData.alertAttendanceLog[a.id] = {
            'by': staffName,
            'time': nowStr,
          };
        }
      }
    });
    MockCarevoraData.saveAttendanceLog();
    MockCarevoraData.notifyAlertsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final isSi = ref.watch(languageProvider).isSinhala;

    // Clinical alerts and facility notifications are restricted to caregivers and staff
    if (authState.isElder) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isSi
                    ? 'සායනික දැනුම්දීම් කාර්ය මණ්ඩලයට පමණයි'
                    : 'Clinical Alerts are Staff-Only',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSi
                    ? 'සායනික දැනුම්දීම් කළමනාකරණය කරන්නේ සත්කාරක නිලධාරීන් සහ වෛද්‍යවරුන් විසිනි.'
                    : 'Alerts and clinical notifications are managed by caregivers and medical attendants.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/dashboard/elder-home'),
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: Text(isSi ? 'මුල් පිටුවට යන්න' : 'Return to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rawCaregiverName =
        (authState.userName != null && authState.userName!.trim().isNotEmpty)
            ? authState.userName!.trim()
            : (isSi ? 'සත්කාරක නිලධාරී' : 'Caregiver');
    final careHomeName = (authState.elderHomeName != null &&
            authState.elderHomeName!.trim().isNotEmpty)
        ? authState.elderHomeName!.trim()
        : (isSi ? 'රැකවරණ මධ්‍යස්ථානය' : 'Care Facility');

    return ValueListenableBuilder<int>(
      valueListenable: MockCarevoraData.alertsVersion,
      builder: (context, _, __) {
        // Ensure zero dummy alerts ever appear
        final alerts = MockCarevoraData.alerts
            .where((a) => a.id != 'ALT-1' && a.id != 'ALT-3')
            .toList();

        final unattendedCount = alerts
            .where((a) => !MockCarevoraData.acknowledgedAlertIds.contains(a.id))
            .length;
        final attendedCount = alerts.length - unattendedCount;
        final urgentUnattendedCount = alerts
            .where(
              (a) =>
                  !MockCarevoraData.acknowledgedAlertIds.contains(a.id) &&
                  (a.severity.toLowerCase() == 'high' ||
                      a.title.contains('Urgent')),
            )
            .length;
        final totalUrgentCount = alerts
            .where(
              (a) =>
                  a.severity.toLowerCase() == 'high' ||
                  a.title.contains('Urgent'),
            )
            .length;

        final activeTab = _effectiveFilter;
        final filteredAlerts = alerts.where((a) {
          final isAck = MockCarevoraData.acknowledgedAlertIds.contains(a.id);
          if (activeTab == 'Pending') return !isAck;
          if (activeTab == 'Urgent') {
            return !isAck &&
                (a.severity.toLowerCase() == 'high' ||
                    a.title.contains('Urgent') ||
                    a.title.contains('Doctor'));
          }
          if (activeTab == 'Attended') return isAck;
          return !isAck;
        }).toList();

        // Find most recent staff member who attended an alert in this list
        String? lastAttendedBy;
        for (final a in alerts) {
          final log = MockCarevoraData.alertAttendanceLog[a.id];
          final by = log?['by']?.trim() ?? '';
          if (by.isNotEmpty) {
            lastAttendedBy = isSi
                ? SinhalaNameTransliterator.toSinhala(by, fallback: by)
                : by;
            break;
          }
        }

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _AlertsClinicalBackdrop(
                  hasUrgent: urgentUnattendedCount > 0,
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Sleek Gradient Header Banner
                      _buildHeaderBanner(
                        isSi: isSi,
                        unattendedCount: unattendedCount,
                        urgentUnattendedCount: urgentUnattendedCount,
                        careHomeName: careHomeName,
                      ),
                      const SizedBox(height: 20),

                      // 2. Clean 3-Card Metrics Row
                      Row(
                        children: [
                          _buildMetricCard(
                            title: isSi
                                ? 'නොවිසඳුණු දැනුම්දීම්'
                                : 'Unattended Alerts',
                            value: '$unattendedCount',
                            subtitle: isSi
                                ? 'මුළු සක්‍රීය දැනුම්දීම්: ${alerts.length}'
                                : 'Out of ${alerts.length} real active alerts',
                            icon: LucideIcons.bellRing,
                            accent: unattendedCount > 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669),
                            gradient: unattendedCount > 0
                                ? const [Color(0xFFFFFFFF), Color(0xFFFFF1F2)]
                                : const [Color(0xFFFFFFFF), Color(0xFFECFDF5)],
                            borderColor: unattendedCount > 0
                                ? const Color(0xFFFECDD3)
                                : const Color(0xFFA7F3D0),
                          ),
                          const SizedBox(width: 16),
                          _buildMetricCard(
                            title: isSi ? 'ඉහළ අවදානම්' : 'High-Risk Priority',
                            value: '$totalUrgentCount',
                            subtitle: isSi
                                ? 'සලකා බැලූ ප්‍රමාණය: $attendedCount'
                                : '$attendedCount attended by staff',
                            icon: LucideIcons.heartPulse,
                            accent: const Color(0xFF7C3AED),
                            gradient: const [
                              Color(0xFFFFFFFF),
                              Color(0xFFF5F3FF),
                            ],
                            borderColor: const Color(0xFFDDD6FE),
                          ),
                          const SizedBox(width: 16),
                          _buildMetricCard(
                            title: isSi
                                ? 'සලකා බැලූ දැනුම්දීම්'
                                : 'Attended & Resolved',
                            value: '$attendedCount / ${alerts.length}',
                            subtitle: lastAttendedBy != null
                                ? (isSi
                                    ? 'අවසන් වරට: $lastAttendedBy'
                                    : 'Last attended by $lastAttendedBy')
                                : (isSi
                                    ? 'තවම සලකා බැලීම් නැත'
                                    : 'No alerts attended yet'),
                            icon: LucideIcons.checkCheck,
                            accent: const Color(0xFF0D9488),
                            gradient: const [
                              Color(0xFFFFFFFF),
                              Color(0xFFF0FDFA),
                            ],
                            borderColor: const Color(0xFF99F6E4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // 3. Clean 3-Tab Clinical Inbox Bar (No mixed 'All' clutter!)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterPill(
                                keyVal: 'Pending',
                                label: isSi ? 'නොවිසඳුණු' : 'Pending',
                                count: unattendedCount,
                                accent: const Color(0xFF6D28D9),
                              ),
                              _buildFilterPill(
                                keyVal: 'Urgent',
                                label: isSi ? 'හදිසි පමණයි' : 'Urgent Only',
                                count: urgentUnattendedCount,
                                accent: const Color(0xFFDC2626),
                              ),
                              _buildFilterPill(
                                keyVal: 'Attended',
                                label: isSi
                                    ? 'සලකා බැලූ ඉතිහාසය'
                                    : 'Attended History',
                                count: attendedCount,
                                accent: const Color(0xFF059669),
                              ),
                            ],
                          ),
                          if (unattendedCount > 0)
                            Material(
                              color: const Color(0xFFECFDF5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFF6EE7B7),
                                  width: 1.3,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _markAllAttended(
                                  alerts,
                                  rawCaregiverName,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.checkCheck,
                                        size: 15,
                                        color: Color(0xFF047857),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        isSi
                                            ? 'සියල්ල සලකා බැලූ ලෙස සලකුණු කරන්න'
                                            : 'Mark All Attended',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 4. Alerts Feed or Clean Empty State
                      if (_refreshing && alerts.isEmpty)
                        _buildLoadingState(isSi)
                      else if (filteredAlerts.isEmpty)
                        _buildEmptyState(
                          isSi: isSi,
                          activeTab: activeTab,
                          attendedCount: attendedCount,
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredAlerts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) => _buildAlertCard(
                            alert: filteredAlerts[index],
                            currentStaffName: rawCaregiverName,
                            isSi: isSi,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderBanner({
    required bool isSi,
    required int unattendedCount,
    required int urgentUnattendedCount,
    required String careHomeName,
  }) {
    final bool hasUrgent = urgentUnattendedCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasUrgent
              ? const [Color(0xFF312E81), Color(0xFF6D28D9), Color(0xFFBE123C)]
              : const [Color(0xFF312E81), Color(0xFF6D28D9), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  hasUrgent ? LucideIcons.bellRing : LucideIcons.shieldCheck,
                  color: hasUrgent
                      ? const Color(0xFFBE123C)
                      : const Color(0xFF0D9488),
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSi
                        ? 'සායනික දැනුම්දීම් සහ අනතුරු ඇඟවීම්'
                        : 'Alerts & Clinical Notifications',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSi
                        ? '$careHomeName — සජීවී නේවාසික අවදානම් දැනුම්දීම්'
                        : 'Real-time resident clinical risk alerts for $careHomeName',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: InkWell(
                  onTap: _refreshing
                      ? null
                      : () => _refreshAlerts(force: true),
                  borderRadius: BorderRadius.circular(13),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_refreshing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            LucideIcons.refreshCw,
                            size: 14,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          isSi ? 'යාවත්කාලීන' : 'Refresh',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hasUrgent
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasUrgent
                          ? LucideIcons.alertTriangle
                          : LucideIcons.shieldCheck,
                      size: 15,
                      color: hasUrgent
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      hasUrgent
                          ? (isSi
                              ? 'හදිසි අවධානය අවශ්‍යයි: $urgentUnattendedCount'
                              : '$urgentUnattendedCount Urgent Attention Required')
                          : (unattendedCount > 0
                              ? (isSi
                                  ? 'සක්‍රීය දැනුම්දීම්: $unattendedCount'
                                  : '$unattendedCount Active Notifications')
                              : (isSi
                                  ? 'සියලු නේවාසිකයින් ස්ථාවරයි'
                                  : 'All Residents Stable')),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: hasUrgent
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _localizeAlertTitle(AlertItem alert, bool isSi) {
    if (!isSi) return alert.title;
    final rawName = (alert.residentName ?? '').trim();
    final siName = rawName.isNotEmpty
        ? SinhalaNameTransliterator.toSinhala(rawName, fallback: rawName)
        : '';

    final lower = alert.title.toLowerCase();
    if (lower.contains('high cognitive impairment risk') ||
        lower.contains('cognitive')) {
      return siName.isNotEmpty
          ? 'ඉහළ මතක අවදානම: $siName'
          : 'ඉහළ මතක අවදානම';
    }
    if (lower.contains('emotional') || lower.contains('distress')) {
      return siName.isNotEmpty
          ? 'මානසික අවදානම් දැනුම්දීම: $siName'
          : 'මානසික අවදානම් දැනුම්දීම';
    }
    if (lower.contains('doctor') || lower.contains('emergency')) {
      return siName.isNotEmpty
          ? 'හදිසි වෛද්‍ය අවධානය: $siName'
          : 'හදිසි වෛද්‍ය අවධානය';
    }
    return alert.title;
  }

  String _localizeAlertDescription(AlertItem alert, bool isSi) {
    if (!isSi) return alert.description;
    final rawName = (alert.residentName ?? '').trim();
    final siName = rawName.isNotEmpty
        ? SinhalaNameTransliterator.toSinhala(rawName, fallback: rawName)
        : 'නේවාසිකයා';
    final roomText =
        (alert.roomNo != null && alert.roomNo!.trim().isNotEmpty)
            ? ' (කාමරය ${alert.roomNo!.trim()})'
            : '';

    if (alert.cognitiveScore != null) {
      final scoreStr = '${alert.cognitiveScore!.toStringAsFixed(1)}/100';
      return '$siName$roomText ගේ මතක පරීක්ෂණ ලකුණු ($scoreStr) ඉහළ අවදානම් මට්ටමක් පෙන්වයි. ඉක්මන් භාරකරු පරීක්ෂාව සහ වෛද්‍ය අවධානය නිර්දේශ කෙරේ.';
    }
    final lower = alert.description.toLowerCase();
    if (lower.contains('emotional') || lower.contains('affect')) {
      return '$siName$roomText සඳහා මානසික සුවතා අවදානමක් හඳුනාගෙන ඇත. ඉක්මන් භාරකරු අවධානය නිර්දේශ කෙරේ.';
    }
    return alert.description;
  }

  String _localizeSeverity(String severity, bool isSi) {
    if (!isSi) return severity.toUpperCase();
    switch (severity.trim().toLowerCase()) {
      case 'high':
      case 'urgent':
        return 'ඉහළ';
      case 'moderate':
      case 'medium':
        return 'මධ්‍යම';
      case 'low':
        return 'අඩු';
      case 'reminder':
        return 'මතක් කිරීම';
      default:
        return severity;
    }
  }

  String _localizeTimestamp(String ts, bool isSi) {
    if (!isSi) return ts;
    if (ts.startsWith('Today,')) {
      return ts.replaceFirst('Today,', 'අද,');
    }
    if (ts == 'Recent Assessment') {
      return 'මෑත පරීක්ෂාව';
    }
    return ts;
  }

  Widget _buildAlertCard({
    required AlertItem alert,
    required String currentStaffName,
    required bool isSi,
  }) {
    final isUrgent =
        alert.severity.toLowerCase() == 'high' || alert.title.contains('Urgent');
    final isAcknowledged =
        MockCarevoraData.acknowledgedAlertIds.contains(alert.id);
    final attendanceEntry = MockCarevoraData.alertAttendanceLog[alert.id];
    final rawAttendedBy = (attendanceEntry?['by'] ?? '').trim();
    final attendedByDisplay = rawAttendedBy.isNotEmpty
        ? (isSi
            ? SinhalaNameTransliterator.toSinhala(
                rawAttendedBy,
                fallback: rawAttendedBy,
              )
            : rawAttendedBy)
        : null;
    final attendedAt = (attendanceEntry?['time'] ?? '').trim();
    final displayTitle = _localizeAlertTitle(alert, isSi);
    final displayDesc = _localizeAlertDescription(alert, isSi);
    final displaySeverity = _localizeSeverity(alert.severity, isSi);
    final displayTimestamp = _localizeTimestamp(alert.timestamp, isSi);
    final displayResidentName = alert.residentName != null
        ? (isSi
            ? SinhalaNameTransliterator.toSinhala(
                alert.residentName!,
                fallback: alert.residentName!,
              )
            : alert.residentName!)
        : null;

    final Color stripColor = isAcknowledged
        ? const Color(0xFF10B981)
        : (isUrgent ? const Color(0xFFE11D48) : const Color(0xFF7C3AED));
    final Color cardBg = isAcknowledged
        ? const Color(0xFFF8FFFC)
        : (isUrgent ? const Color(0xFFFFF8F9) : Colors.white);
    final Color cardBorder = isAcknowledged
        ? const Color(0xFFA7F3D0)
        : (isUrgent ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0));

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: stripColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left severity indicator strip
              Container(width: 5.5, color: stripColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: stripColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isAcknowledged
                              ? LucideIcons.checkCheck
                              : (isUrgent
                                  ? LucideIcons.bellRing
                                  : LucideIcons.info),
                          color: stripColor,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  displayTitle,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    color: isAcknowledged
                                        ? const Color(0xFF065F46)
                                        : (isUrgent
                                            ? const Color(0xFF881337)
                                            : const Color(0xFF1E1B4B)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stripColor,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    isAcknowledged
                                        ? (isSi ? 'සලකා බැලුණි' : 'ATTENDED')
                                        : displaySeverity,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.clock,
                                        size: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        displayTimestamp,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              displayDesc,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF475569),
                                height: 1.45,
                              ),
                            ),
                            if (displayResidentName != null ||
                                alert.roomNo != null ||
                                alert.cognitiveScore != null) ...[
                              const SizedBox(height: 11),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (displayResidentName != null)
                                    _buildDetailTag(
                                      icon: LucideIcons.user,
                                      label: displayResidentName,
                                      fg: const Color(0xFF4338CA),
                                      bg: const Color(0xFFEEF2FF),
                                    ),
                                  if (alert.roomNo != null)
                                    _buildDetailTag(
                                      icon: LucideIcons.doorClosed,
                                      label: isSi
                                          ? 'කාමරය ${alert.roomNo}'
                                          : 'Room ${alert.roomNo}',
                                      fg: const Color(0xFF0F766E),
                                      bg: const Color(0xFFCCFBF1),
                                    ),
                                  if (alert.residentAge != null)
                                    _buildDetailTag(
                                      icon: LucideIcons.calendar,
                                      label: isSi
                                          ? 'වයස ${alert.residentAge}'
                                          : 'Age ${alert.residentAge}${alert.residentGender != null ? ' • ${alert.residentGender}' : ''}',
                                      fg: const Color(0xFF475569),
                                      bg: const Color(0xFFF1F5F9),
                                    ),
                                  if (alert.cognitiveScore != null)
                                    _buildDetailTag(
                                      icon: LucideIcons.brain,
                                      label: isSi
                                          ? 'මතක ලකුණු: ${alert.cognitiveScore!.toStringAsFixed(1)} / 100'
                                          : 'Cognitive Score: ${alert.cognitiveScore!.toStringAsFixed(1)} / 100',
                                      fg: const Color(0xFF6D28D9),
                                      bg: const Color(0xFFEDE9FE),
                                    ),
                                  if (isAcknowledged)
                                    _buildDetailTag(
                                      icon: LucideIcons.userCheck,
                                      label: attendedByDisplay != null
                                          ? (isSi
                                              ? 'සලකා බැලුවේ: $attendedByDisplay${attendedAt.isNotEmpty ? ' • $attendedAt' : ''}'
                                              : 'Attended by $attendedByDisplay${attendedAt.isNotEmpty ? ' • $attendedAt' : ''}')
                                          : (isSi
                                              ? 'නිලධාරියෙකු විසින් සලකා බැලුණි'
                                              : 'Attended by Staff'),
                                      fg: const Color(0xFF047857),
                                      bg: const Color(0xFFD1FAE5),
                                    )
                                  else
                                    _buildDetailTag(
                                      icon: LucideIcons.clock,
                                      label: isSi
                                          ? 'භාරකරු අවධානය බලාපොරොත්තුවෙන්'
                                          : 'Awaiting Staff Response',
                                      fg: const Color(0xFFB45309),
                                      bg: const Color(0xFFFEF3C7),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Material(
                        color: isAcknowledged
                            ? Colors.white
                            : const Color(0xFF6D28D9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isAcknowledged
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF6D28D9),
                            width: 1.3,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _toggleAcknowledge(
                            alert.id,
                            currentStaffName,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAcknowledged
                                      ? LucideIcons.rotateCcw
                                      : LucideIcons.check,
                                  size: 14.5,
                                  color: isAcknowledged
                                      ? const Color(0xFF475569)
                                      : Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isAcknowledged
                                      ? (isSi ? 'නැවත ගන්න' : 'Reopen')
                                      : (isSi
                                          ? 'තහවුරු කරන්න'
                                          : 'Acknowledge'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: isAcknowledged
                                        ? const Color(0xFF334155)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTag({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isSi) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 14),
          Text(
            isSi
                ? 'සජීවී සායනික දැනුම්දීම් පරීක්ෂා කරමින්...'
                : 'Syncing live clinical notifications...',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isSi,
    required String activeTab,
    required int attendedCount,
  }) {
    final bool isAttendedTab = activeTab == 'Attended';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF99F6E4), width: 1.4),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              size: 30,
              color: Color(0xFF0D9488),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isAttendedTab
                ? (isSi
                    ? 'තවම සලකා බැලූ ඉතිහාසයක් නැත'
                    : 'No Attended Alerts in History Yet')
                : (isSi
                    ? 'සියලුම දැනුම්දීම් සලකා බලා අවසන්!'
                    : 'All Clear — No Pending Clinical Alerts'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isAttendedTab
                ? (isSi
                    ? 'නිලධාරීන් විසින් තහවුරු කරන දැනුම්දීම් දිනය හා වෙලාව සමඟ මෙහි සටහන් වේ.'
                    : 'Acknowledged resident alerts will appear here with staff name, date, and time.')
                : (isSi
                    ? 'දැනට හදිසි අවධානය අවශ්‍ය නොවිසඳුණු දැනුම්දීම් කිසිවක් නැත.'
                    : 'All active resident alerts have been attended or are currently stable.'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          if (!isAttendedTab && attendedCount > 0) ...[
            const SizedBox(height: 16),
            Material(
              color: const Color(0xFFECFDF5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF6EE7B7), width: 1.3),
              ),
              child: InkWell(
                onTap: () => setState(() => _selectedFilter = 'Attended'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Text(
                    isSi
                        ? 'සලකා බැලූ ඉතිහාසය බලන්න ($attendedCount)'
                        : 'View Attended History ($attendedCount)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<Color> gradient,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1B4B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String keyVal,
    required String label,
    required int count,
    required Color accent,
  }) {
    final isSelected = _effectiveFilter == keyVal;
    return Material(
      color: isSelected ? accent : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: isSelected ? accent : const Color(0xFFE2E8F0),
          width: 1.4,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = keyVal),
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bespoke clinical monitoring backdrop framing the Caregiver Alerts page:
/// soft expanding care-signal radar ripples, gentle travelling ECG pulse lines,
/// and subtle floating medical cross (+) motifs along the outer margins.
class _AlertsClinicalBackdrop extends StatefulWidget {
  final bool hasUrgent;

  const _AlertsClinicalBackdrop({required this.hasUrgent});

  @override
  State<_AlertsClinicalBackdrop> createState() =>
      _AlertsClinicalBackdropState();
}

class _AlertsClinicalBackdropState extends State<_AlertsClinicalBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _AlertsClinicalBackdropPainter(
              progress: _controller.value,
              hasUrgent: widget.hasUrgent,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _AlertsClinicalBackdropPainter extends CustomPainter {
  final double progress;
  final bool hasUrgent;

  const _AlertsClinicalBackdropPainter({
    required this.progress,
    required this.hasUrgent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;
    final primaryAccent =
        hasUrgent ? const Color(0xFFE11D48) : const Color(0xFF0D9488);
    const violetAccent = Color(0xFF7C3AED);
    const tealAccent = Color(0xFF0D9488);

    // 1. Soft atmospheric clinical corner glows
    _drawRadialWash(
      canvas,
      Offset(size.width * 0.03, size.height * 0.16),
      130,
      violetAccent.withValues(alpha: 0.09),
    );
    _drawRadialWash(
      canvas,
      Offset(size.width * 0.97, size.height * 0.18),
      140,
      primaryAccent.withValues(alpha: 0.10),
    );
    _drawRadialWash(
      canvas,
      Offset(size.width * 0.96, size.height * 0.82),
      130,
      tealAccent.withValues(alpha: 0.09),
    );

    // 2. Expanding care-signal radar pulse ripples on outer corners
    _drawRadarBeacon(
      canvas,
      Offset(size.width * 0.036, size.height * 0.24),
      maxRadius: 56,
      phase: progress,
      color: violetAccent,
    );
    _drawRadarBeacon(
      canvas,
      Offset(size.width * 0.962, size.height * 0.22),
      maxRadius: 62,
      phase: (progress + 0.35) % 1.0,
      color: primaryAccent,
    );
    _drawRadarBeacon(
      canvas,
      Offset(size.width * 0.958, size.height * 0.78),
      maxRadius: 52,
      phase: (progress + 0.70) % 1.0,
      color: tealAccent,
    );

    // 3. Delicate animated ECG heartbeat trace strips along bottom-left & top-right margins
    _drawEcgTrace(
      canvas,
      origin: Offset(size.width * 0.012, size.height * 0.56),
      width: math.min(96.0, size.width * 0.085),
      sweepProgress: (progress * 2.0) % 1.0,
      color: primaryAccent,
    );
    _drawEcgTrace(
      canvas,
      origin: Offset(
        size.width - math.min(104.0, size.width * 0.09) - 10,
        size.height * 0.50,
      ),
      width: math.min(96.0, size.width * 0.085),
      sweepProgress: (progress * 2.0 + 0.5) % 1.0,
      color: tealAccent,
    );

    // 4. Subtle floating clinical care-cross (+) emblems along outer margins
    const crosses = <(double, double, double, Color, double)>[
      (0.032, 0.12, 9.0, Color(0xFF7C3AED), 0.2),
      (0.045, 0.40, 7.5, Color(0xFF0D9488), 1.8),
      (0.028, 0.76, 8.5, Color(0xFFE11D48), 3.4),
      (0.968, 0.11, 8.5, Color(0xFFE11D48), 0.9),
      (0.952, 0.38, 7.5, Color(0xFF7C3AED), 2.5),
      (0.968, 0.64, 9.0, Color(0xFF0D9488), 4.1),
      (0.945, 0.90, 7.0, Color(0xFF6366F1), 5.3),
    ];

    for (final c in crosses) {
      final bobX = math.sin(t + c.$5) * 6.0;
      final bobY = math.cos(t * 1.2 + c.$5) * 10.0;
      final pulseAlpha = 0.16 + 0.14 * (0.5 + 0.5 * math.sin(t * 2 + c.$5));
      _drawCareCross(
        canvas,
        Offset(size.width * c.$1 + bobX, size.height * c.$2 + bobY),
        radius: c.$3,
        angle: math.sin(t * 0.6 + c.$5) * 0.18,
        color: c.$4.withValues(alpha: pulseAlpha),
      );
    }
  }

  void _drawRadialWash(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawRadarBeacon(
    Canvas canvas,
    Offset center, {
    required double maxRadius,
    required double phase,
    required Color color,
  }) {
    // Center dot
    canvas.drawCircle(
      center,
      3.5,
      Paint()..color = color.withValues(alpha: 0.34),
    );

    // Two staggered expanding sonar rings
    for (int i = 0; i < 2; i++) {
      final p = (phase + i * 0.5) % 1.0;
      final r = 8.0 + p * (maxRadius - 8.0);
      final alpha = (1.0 - p) * 0.24;
      if (alpha <= 0.01) continue;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  void _drawEcgTrace(
    Canvas canvas, {
    required Offset origin,
    required double width,
    required double sweepProgress,
    required Color color,
  }) {
    // Normalized ECG P-Q-R-S-T points (x in 0..1, y offset in px)
    const pts = <(double, double)>[
      (0.00, 0.0),
      (0.22, 0.0),
      (0.28, -4.5),
      (0.34, 0.0),
      (0.42, 0.0),
      (0.46, 5.0),
      (0.51, -18.0),
      (0.56, 9.0),
      (0.61, 0.0),
      (0.71, 0.0),
      (0.78, -6.5),
      (0.85, 0.0),
      (1.00, 0.0),
    ];

    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final px = origin.dx + pts[i].$1 * width;
      final py = origin.dy + pts[i].$2;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Glowing pulse bead gliding smoothly along the ECG waveform
    final sx = sweepProgress.clamp(0.0, 1.0);
    double sy = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      if (sx >= pts[i].$1 && sx <= pts[i + 1].$1) {
        final seg = (sx - pts[i].$1) / math.max(0.0001, pts[i + 1].$1 - pts[i].$1);
        sy = pts[i].$2 + (pts[i + 1].$2 - pts[i].$2) * seg;
        break;
      }
    }
    final dot = Offset(origin.dx + sx * width, origin.dy + sy);
    canvas.drawCircle(
      dot,
      7.0,
      Paint()..color = color.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      dot,
      3.0,
      Paint()..color = color.withValues(alpha: 0.55),
    );
  }

  void _drawCareCross(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double angle,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final armW = radius * 0.42;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: radius * 2, height: armW),
        Radius.circular(armW / 2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: armW, height: radius * 2),
        Radius.circular(armW / 2),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AlertsClinicalBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hasUrgent != hasUrgent;
  }
}
