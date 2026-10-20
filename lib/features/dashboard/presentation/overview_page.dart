import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive/responsive_builder.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_carevora_data.dart';
import '../../../data/models/carevora_models.dart';
import '../../../shared/widgets/alerts_list_widget.dart';
import '../../../shared/widgets/component_donut_chart.dart';
import '../../../shared/widgets/recent_assessments_table.dart';
import '../../../shared/widgets/resident_header_card.dart';
import '../../../shared/widgets/risk_trend_chart.dart';
import '../../../shared/widgets/score_card.dart';
import '../../assessment/application/cognitive_assessment_service.dart';
import '../../auth/application/auth_controller.dart';

class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  Resident? _liveResident;
  final List<AssessmentRecord> _assessments = MockCarevoraData.recentAssessments;
  final List<AlertItem> _alerts = MockCarevoraData.alerts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadElderResident();
    });
  }

  Future<void> _loadElderResident() async {
    final authState = ref.read(authProvider).state;
    if (authState.isElder) {
      final resId = authState.residentId ?? 165;
      try {
        final profile = await CognitiveAssessmentService.fetchResident(
          residentId: resId,
          token: authState.token,
        );
        if (profile != null && mounted) {
          final cleanRoom = profile.roomNumber
              .replaceAll('Room No: ', '')
              .replaceAll('Room No ', '')
              .replaceAll('Room ', '')
              .replaceAll('Suite ', '')
              .trim();
          final isFemale = profile.name.contains('Mrs.') ||
              profile.name.contains('Malini') ||
              profile.name.contains('Sarah') ||
              profile.name.contains('Margaret') ||
              profile.name.contains('Seetha');
          final isMale = profile.name.contains('Mr.') ||
              profile.name.contains('Arthur') ||
              profile.name.contains('Kamal') ||
              profile.name.contains('James') ||
              profile.name.contains('Robert');
          final genderStr = (profile.gender != null && profile.gender!.isNotEmpty && profile.gender != 'Unknown')
              ? profile.gender!
              : (isFemale ? 'Female' : (isMale ? 'Male' : 'Senior Resident'));

          setState(() {
            _liveResident = Resident(
              id: profile.id.toString(),
              name: profile.name,
              age: profile.age ?? (profile.name.contains('Malini') ? 65 : 75),
              gender: genderStr,
              roomNo: cleanRoom.isNotEmpty ? cleanRoom : '30',
              lastAssessmentDate: 'Today, 10:30 AM',
              cognitiveScore: MockCarevoraData.defaultResident.cognitiveScore,
              cognitiveTrend: MockCarevoraData.defaultResident.cognitiveTrend,
              emotionalScore: MockCarevoraData.defaultResident.emotionalScore,
              emotionalTrend: MockCarevoraData.defaultResident.emotionalTrend,
              metabolicScore: MockCarevoraData.defaultResident.metabolicScore,
              metabolicTrend: MockCarevoraData.defaultResident.metabolicTrend,
              overallIndex: MockCarevoraData.defaultResident.overallIndex,
              overallTrend: MockCarevoraData.defaultResident.overallTrend,
              avatarUrl: profile.avatarUrl ?? authState.avatarUrl,
            );
          });
        }
      } catch (_) {}
    }
  }

  Resident _resolveResident(AuthState authState) {
    if (_liveResident != null) {
      return _liveResident!;
    }
    if (authState.isElder) {
      final bId = authState.residentId ?? 165;
      final userName = authState.userName?.trim();
      final isFemale = userName != null &&
          (userName.contains('Mrs.') ||
              userName.contains('Malini') ||
              userName.contains('Sarah') ||
              userName.contains('Margaret') ||
              userName.contains('Seetha') ||
              userName.contains('Nanda'));
      final isMale = userName != null &&
          (userName.contains('Mr.') ||
              userName.contains('Arthur') ||
              userName.contains('Kamal') ||
              userName.contains('James') ||
              userName.contains('Robert') ||
              userName.contains('Senarath'));
      final detectedGender = isFemale ? 'Female' : (isMale ? 'Male' : 'Senior Resident');
      final defaultAge = (bId == 165 || (userName != null && userName.contains('Malini')))
          ? 65
          : (bId == 1 || (userName != null && userName.contains('Sarah')) ? 78 : 75);
      final defaultRoom = (bId == 165 || (userName != null && userName.contains('Malini')))
          ? '30'
          : (bId == 1 || (userName != null && userName.contains('Sarah')) ? '204' : '101');

      return Resident(
        id: bId.toString(),
        name: (userName != null && userName.isNotEmpty)
            ? userName
            : (bId == 165 ? 'Malini Bandara' : 'Senior Resident'),
        age: defaultAge,
        gender: detectedGender,
        roomNo: defaultRoom,
        lastAssessmentDate: 'Today, 10:30 AM',
        cognitiveScore: MockCarevoraData.defaultResident.cognitiveScore,
        cognitiveTrend: MockCarevoraData.defaultResident.cognitiveTrend,
        emotionalScore: MockCarevoraData.defaultResident.emotionalScore,
        emotionalTrend: MockCarevoraData.defaultResident.emotionalTrend,
        metabolicScore: MockCarevoraData.defaultResident.metabolicScore,
        metabolicTrend: MockCarevoraData.defaultResident.metabolicTrend,
        overallIndex: MockCarevoraData.defaultResident.overallIndex,
        overallTrend: MockCarevoraData.defaultResident.overallTrend,
        avatarUrl: authState.avatarUrl,
      );
    }
    return MockCarevoraData.defaultResident;
  }

  void _showRecordDetails(AssessmentRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetailDrawer(record),
    );
  }

  Widget _buildDetailDrawer(AssessmentRecord record) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assessment Inspection Report',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('ID: ${record.id} • ${record.dateTime}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.border),
          Expanded(
            child: ListView(
              children: [
                _buildDrawerScoreRow('Cognitive Assessment Score', record.cognitiveScore),
                _buildDrawerScoreRow('Emotional Wellness Score', record.emotionalScore),
                _buildDrawerScoreRow('Metabolic Vitals Score', record.metabolicScore),
                _buildDrawerScoreRow('Overall Multimodal Risk', record.overallRiskScore),
                const SizedBox(height: 20),
                Text('Clinical Notes & Observations',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Assessment completed by ${record.assessedBy}. The resident demonstrated sustained engagement with minor hesitation during 3-step delayed retrieval. No critical motor distress noted. Follow-up assessment recommended in 14 days.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerScoreRow(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            score.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final isElder = authState.isElder;
    final resident = _resolveResident(authState);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Resident Identity Top Card
          ResidentHeaderCard(
            resident: resident,
            showViewProfile: false,
            showLastAssessment: false,
            onViewDetailedReport: () => context.go('/dashboard/reports'),
          ),
          const SizedBox(height: 16),

          // 1.5 Today's Medicine Summary Card
          Material(
            color: AppColors.primarySoft.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => context.go('/dashboard/medicine'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lilac),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.medication, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Today\'s Live Medicine Board', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                          Text('18/24 Doses Given • 2 Overdue Alerts Active', style: TextStyle(fontSize: 12, color: AppColors.body)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.riskHighBg, borderRadius: BorderRadius.circular(8)),
                      child: const Text('2 OVERDUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.riskHigh)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. 4 Multimodal Score Cards
          ResponsiveBuilder(
            mobile: (context) => SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(
                    width: 260,
                    child: ScoreCard(
                      title: 'Cognitive Health',
                      score: resident.cognitiveScore,
                      delta: resident.cognitiveTrend,
                      onTap: () => context.go('/dashboard/cognitive/session'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 260,
                    child: ScoreCard(
                      title: 'Emotional Wellness',
                      score: resident.emotionalScore,
                      delta: resident.emotionalTrend,
                      onTap: () => context.go('/dashboard/emotional'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 260,
                    child: ScoreCard(
                      title: 'Metabolic Health',
                      score: resident.metabolicScore,
                      delta: resident.metabolicTrend,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 260,
                    child: ScoreCard(
                      title: 'Overall Wellness Index',
                      score: resident.overallIndex,
                      delta: resident.overallTrend,
                      isGauge: true,
                    ),
                  ),
                ],
              ),
            ),
            desktop: (context) => LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: ScoreCard(
                        title: 'Cognitive Health',
                        score: resident.cognitiveScore,
                        delta: resident.cognitiveTrend,
                        onTap: () => context.go('/dashboard/cognitive/session'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ScoreCard(
                        title: 'Emotional Wellness',
                        score: resident.emotionalScore,
                        delta: resident.emotionalTrend,
                        onTap: () => context.go('/dashboard/emotional'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ScoreCard(
                        title: 'Metabolic Health',
                        score: resident.metabolicScore,
                        delta: resident.metabolicTrend,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ScoreCard(
                        title: 'Overall Wellness Index',
                        score: resident.overallIndex,
                        delta: resident.overallTrend,
                        isGauge: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 3. Middle Analytics Row (Risk Trend, Donut, Alerts)
          ResponsiveBuilder(
            mobile: (context) => Column(
              children: [
                const SizedBox(height: 340, child: RiskTrendChart()),
                const SizedBox(height: 16),
                const SizedBox(height: 340, child: ComponentDonutChart()),
                if (!isElder) ...[
                  const SizedBox(height: 16),
                  AlertsListWidget(
                    alerts: _alerts,
                    onViewAll: () => context.go('/dashboard/alerts'),
                  ),
                ],
              ],
            ),
            desktop: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isElder ? 5 : 4,
                  child: const SizedBox(height: 360, child: RiskTrendChart()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: isElder ? 5 : 3,
                  child: const SizedBox(height: 360, child: ComponentDonutChart()),
                ),
                if (!isElder) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 360,
                      child: AlertsListWidget(
                        alerts: _alerts,
                        onViewAll: () => context.go('/dashboard/alerts'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Recent Assessments Table
          RecentAssessmentsTable(
            records: _assessments,
            onSelectRecord: _showRecordDetails,
            onViewAll: () => context.go('/dashboard/cognitive/session'),
          ),
        ],
      ),
    );
  }
}
