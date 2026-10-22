import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/carevora_models.dart';
import '../../auth/application/auth_controller.dart';
import '../application/social_audit_service.dart';
import 'widgets/caregiver_social_audit_dialog.dart';

class CaregiverSocialAuditDashboardPage extends ConsumerStatefulWidget {
  const CaregiverSocialAuditDashboardPage({super.key});

  @override
  ConsumerState<CaregiverSocialAuditDashboardPage> createState() =>
      _CaregiverSocialAuditDashboardPageState();
}

class _CaregiverSocialAuditDashboardPageState
    extends ConsumerState<CaregiverSocialAuditDashboardPage> {
  final TextEditingController _searchController = TextEditingController();

  SocialAuditDashboardSummary? _summary;
  List<ResidentAuditDirectoryItem> _allResidents = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter: 0 = All, 1 = Awaiting Audit, 2 = Completed Audit
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authState = ref.read(authProvider).state;
    final token = authState.token;

    try {
      final summaryFuture = SocialAuditService.fetchDashboardSummary(token);
      final residentsFuture = SocialAuditService.fetchResidentAuditDirectory(
        search: _searchController.text.trim(),
        token: token,
      );

      final results = await Future.wait([summaryFuture, residentsFuture]);
      if (mounted) {
        setState(() {
          _summary = results[0] as SocialAuditDashboardSummary?;
          _allResidents = results[1] as List<ResidentAuditDirectoryItem>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load social audit dashboard: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<ResidentAuditDirectoryItem> get _filteredResidents {
    if (_selectedFilter == 1) {
      return _allResidents.where((r) => !r.hasCompletedAudit).toList();
    } else if (_selectedFilter == 2) {
      return _allResidents.where((r) => r.hasCompletedAudit).toList();
    }
    return _allResidents;
  }

  void _openAuditDialogForResident(ResidentAuditDirectoryItem item) {
    final authState = ref.read(authProvider).state;
    final staffName = authState.userName ?? 'Caregiver Specialist';

    final residentObj = Resident(
      id: item.residentId.toString(),
      name: item.name,
      roomNo: item.roomNumber ?? '101',
      age: item.age ?? 75,
      gender: 'Resident',
      lastAssessmentDate: item.latestAuditDate != null
          ? _formatDateTime(item.latestAuditDate!)
          : 'Awaiting Audit',
      cognitiveScore: 0.70,
      cognitiveTrend: 0.0,
      emotionalScore: 0.75,
      emotionalTrend: 0.0,
      metabolicScore: 0.70,
      metabolicTrend: 0.0,
      overallIndex: 0.72,
      overallTrend: 0.0,
      socialScore: item.latestSocialScore,
    );

    showDialog<SocialAuditRecord>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CaregiverSocialAuditDialog(
        resident: residentObj,
        backendResidentId: item.residentId,
        caregiverName: staffName,
        authToken: authState.token,
        onAuditSaved: (record) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Social audit recorded successfully for ${item.name}! Verified Score: ${record.socialScore != null ? "${record.socialScore!.toStringAsFixed(1)}%" : "Unassessed"}',
              ),
              backgroundColor: const Color(0xFF166534),
            ),
          );
          _loadDashboardData();
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dt.month - 1];
    final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $m ${dt.year}, $hr:$min $ampm';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Never';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dt.month - 1];
    return '${dt.day} $m ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;

    // Role Guard: if an Elder somehow navigates here, show friendly guidance
    if (authState.isElder) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.shieldAlert, size: 48, color: AppColors.riskModerate),
              const SizedBox(height: 16),
              const Text(
                'Care Staff Authorization Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              const Text(
                'The Caregiver Social Audit Dashboard is reserved for authorized care specialists conducting observational assessments. You can view your personal health records and daily wellness check-ins.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/dashboard/residents'),
                icon: const Icon(LucideIcons.user, size: 16),
                label: const Text('Go to My Health Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildHeaderBar(authState),
          const SizedBox(height: 20),

          // Real KPI Statistics
          _buildSummaryCards(),
          const SizedBox(height: 24),

          // Search & Filter Bar
          _buildSearchAndFilterBar(),
          const SizedBox(height: 20),

          // Main Resident Directory with Audit Status
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            _buildErrorCard()
          else
            _buildResidentCardsGrid(),

          const SizedBox(height: 28),

          // Recent Audit Activity Feed
          if (_summary != null && _summary!.recentAudits.isNotEmpty)
            _buildRecentActivitySection(),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(AuthState authState) {
    final staffName = authState.userName ?? 'Caregiver Specialist';
    final homeName = authState.elderHomeName ?? 'Care Home Facility';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.clipboardCheck, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Caregiver Social Audit Command Center',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Observational 7-day social isolation audits, peer contact tracking, and RALPA longitudinal verification',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.userCheck, size: 15, color: AppColors.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staffName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  Text(
                    homeName,
                    style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final total = _summary?.totalResidents ?? _allResidents.length;
    final completed = _summary?.residentsWithCompletedAudit ??
        _allResidents.where((r) => r.hasCompletedAudit).length;
    final awaiting = _summary?.residentsAwaitingAudit ??
        _allResidents.where((r) => !r.hasCompletedAudit).length;
    final today = _summary?.auditsCompletedToday ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              title: 'Assigned Residents',
              value: total.toString(),
              subtitle: 'Active care home residents',
              icon: LucideIcons.users,
              iconColor: AppColors.primary,
              bgColor: AppColors.primarySoft,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Audits Completed',
              value: completed.toString(),
              subtitle: 'Verified social audit on file',
              icon: LucideIcons.shieldCheck,
              iconColor: const Color(0xFF166534),
              bgColor: const Color(0xFFDCFCE7),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Awaiting Staff Audit',
              value: awaiting.toString(),
              subtitle: 'Requires 7-day observational audit',
              icon: LucideIcons.clock,
              iconColor: const Color(0xFF92400E),
              bgColor: const Color(0xFFFEF3C7),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Audits Completed Today',
              value: today.toString(),
              subtitle: 'Fresh observations logged',
              icon: LucideIcons.calendarCheck,
              iconColor: const Color(0xFF4F46E5),
              bgColor: const Color(0xFFEEF2FF),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    final awaitingCount = _allResidents.where((r) => !r.hasCompletedAudit).length;
    final completedCount = _allResidents.where((r) => r.hasCompletedAudit).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadDashboardData(),
                  decoration: InputDecoration(
                    hintText: 'Search residents by name, room number, or ID...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(LucideIcons.search, size: 16),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  _loadDashboardData();
                },
                icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.primary),
                tooltip: 'Refresh Directory',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFilterChip(
                label: 'All Residents (${_allResidents.length})',
                index: 0,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Awaiting Audit ($awaitingCount)',
                index: 1,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Completed Audit ($completedCount)',
                index: 2,
                color: const Color(0xFF16A34A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required int index, Color? color}) {
    final isSelected = _selectedFilter == index;
    final activeColor = color ?? AppColors.primary;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }

  Widget _buildResidentCardsGrid() {
    final list = _filteredResidents;
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: const [
            Icon(LucideIcons.userX, size: 40, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'No residents found matching criteria',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            SizedBox(height: 4),
            Text(
              'Try adjusting your search query or switching filters.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600;
        final columns = isDesktop ? 3 : (isTablet ? 2 : 1);
        final spacing = 16.0;
        final itemWidth = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: list.map((item) => _buildResidentCard(item, itemWidth)).toList(),
        );
      },
    );
  }

  Widget _buildResidentCard(ResidentAuditDirectoryItem item, double width) {
    final initials = item.name
        .split(' ')
        .where((w) => !w.startsWith('Mr.') && !w.startsWith('Mrs.') && !w.startsWith('Dr.'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join();

    final hasAudit = item.hasCompletedAudit;
    final score = item.latestSocialScore;

    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resident Header (clickable to open resident audit file)
          InkWell(
            onTap: () => context.go('/dashboard/social-audit/resident/${item.residentId}'),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials.isNotEmpty ? initials : 'R',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Room: ${item.roomNumber ?? "101"} • Age: ${item.age ?? 75} • ID: ${item.residentId}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Audit Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasAudit ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasAudit ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasAudit ? LucideIcons.shieldCheck : LucideIcons.alertCircle,
                  size: 14,
                  color: hasAudit ? const Color(0xFF166534) : const Color(0xFF92400E),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasAudit
                        ? 'Verified Audit • ${score != null ? "${score.toStringAsFixed(1)}%" : "Recorded"}'
                        : 'Awaiting Staff Observational Audit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasAudit ? const Color(0xFF166534) : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Audit Date & Peer Interaction details
          if (hasAudit) ...[
            Text(
              'Last audited: ${_formatDate(item.latestAuditDate)} (${item.auditCount} total records)',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            if (item.latestPeerInteractionLevel != null) ...[
              const SizedBox(height: 2),
              Text(
                'Peer Contact: ${item.latestPeerInteractionLevel!.label.split("(")[0].trim()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy),
              ),
            ],
          ] else ...[
            const Text(
              'Unassessed — No Caregiver Social Audit On File',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 8),
          // Weekly Music Therapy & Emotional Wellness Schedule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF2F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCE7F3)),
            ),
            child: Row(
              children: const [
                Icon(LucideIcons.music, size: 12, color: Color(0xFFDB2777)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Weekly Music Therapy: Mon, Wed, Fri (10:00 AM • 10 Mins)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9D174D)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAuditDialogForResident(item),
                  icon: const Icon(LucideIcons.clipboardPlus, size: 14),
                  label: Text(
                    hasAudit ? 'Re-Audit' : 'Record Audit',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => context.go('/dashboard/social-audit/resident/${item.residentId}'),
                icon: const Icon(LucideIcons.history, size: 18, color: AppColors.primary),
                tooltip: 'View Audit History & Details',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final recent = _summary!.recentAudits;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Caregiver Social Audit Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              Text(
                'Showing ${recent.length} latest entries',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceSecondary),
              columns: const [
                DataColumn(label: Text('Resident', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Audit Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Caregiver / Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Social Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Peer Interaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Reporting Window', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: recent.map((audit) {
                return DataRow(
                  cells: [
                    DataCell(Text(audit.residentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Text(_formatDateTime(audit.auditDate), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(audit.caregiverName, style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          audit.socialScore != null ? '${audit.socialScore!.toStringAsFixed(1)}%' : 'N/A',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ),
                    ),
                    DataCell(Text(audit.peerInteractionLevel.label.split('(')[0].trim(), style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${audit.reportingPeriodDays} Days', style: const TextStyle(fontSize: 12))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.alertTriangle, size: 36, color: AppColors.riskHigh),
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 13, color: AppColors.riskHigh, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadDashboardData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.riskHigh,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
