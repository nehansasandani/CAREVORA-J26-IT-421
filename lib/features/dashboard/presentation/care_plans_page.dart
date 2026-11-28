import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/carevora_avatar.dart';
import '../../../shared/widgets/cognitive_shap_explanation_card.dart';
import '../../../shared/widgets/emotional_shap_explanation_card.dart';
import '../../assessment/application/care_plans_service.dart';
import '../../assessment/application/cognitive_assessment_service.dart';
import '../../assessment/application/memory_game_service.dart';
import '../../auth/application/auth_controller.dart';

class CarePlansPage extends ConsumerStatefulWidget {
  final int? initialResidentId;
  final int? initialDomain;

  const CarePlansPage({
    super.key,
    this.initialResidentId,
    this.initialDomain,
  });

  @override
  ConsumerState<CarePlansPage> createState() => _CarePlansPageState();
}

class _CarePlansPageState extends ConsumerState<CarePlansPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _riskFilter;
  String get _activeRiskFilter => _riskFilter ?? 'All';

  List<CarePlanResident> _allResidents = [];
  bool _isLoadingResidents = false;
  String? _residentLoadError;

  CarePlanResident? _selectedResident;

  // Wellness Data State
  CarePlanCognitiveData? _cognitiveData;
  CarePlanEmotionalData? _emotionalData;
  CarePlanMetabolicData? _metabolicData;
  MemoryGameProgressSummary? _memoryGameProgress;
  bool _isLoadingWellness = false;
  String? _wellnessError;

  // Active domain selector: 0 = Cognitive, 1 = Emotional, 2 = Metabolic
  int _selectedDomainIndex = 0;

  // Cognitive history view state
  bool _showCognitiveHistory = false;
  bool _showSessionHistory = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDomain != null) {
      _selectedDomainIndex = widget.initialDomain!;
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final auth = ref.read(authProvider).state;

    // 1. If Elder role: directly load own profile
    if (auth.isElder) {
      final elderId = auth.residentId ?? 1;
      final elderResident = CarePlanResident(
        id: elderId,
        name: auth.userName ?? 'Sarah Jenkins',
        roomNumber: 'Room 204',
        elderHomeName: auth.elderHomeName ?? 'Serene Valley Senior Living',
        elderHomeId: auth.elderHomeId ?? 1,
        avatarUrl: auth.avatarUrl,
      );
      setState(() {
        _selectedResident = elderResident;
        if (widget.initialDomain != null) {
          _selectedDomainIndex = widget.initialDomain!;
        }
      });
      await _loadResidentWellness(elderResident);
      return;
    }

    // 2. Caregiver / Doctor: fetch residents list
    setState(() {
      _isLoadingResidents = true;
      _residentLoadError = null;
    });

    try {
      final token = auth.token;
      final facilityId = auth.isCaregiver ? auth.elderHomeId : null;
      final residents = await CarePlansService.fetchResidents(
        token: token,
        facilityId: facilityId,
      );

      if (mounted) {
        setState(() {
          _allResidents = residents;
          _isLoadingResidents = false;
        });

        // Check if an initial residentId was provided
        if (widget.initialResidentId != null) {
          final target = residents.firstWhere(
            (r) => r.id == widget.initialResidentId,
            orElse: () => CarePlanResident(
              id: widget.initialResidentId!,
              name: 'Resident #${widget.initialResidentId}',
              roomNumber: 'Room',
              elderHomeName: auth.elderHomeName ?? 'Assigned Facility',
              elderHomeId: auth.elderHomeId ?? 1,
            ),
          );
          await _selectResident(target, domainIndex: widget.initialDomain);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingResidents = false;
          _residentLoadError = 'Failed to load residents. Please check connection.';
        });
      }
    }
  }

  Future<void> _selectResident(CarePlanResident resident, {int? domainIndex}) async {
    setState(() {
      _selectedResident = resident;
      _selectedDomainIndex = domainIndex ?? (widget.initialDomain ?? 0);
      _showCognitiveHistory = false;
      _showSessionHistory = false;
    });
    await _loadResidentWellness(resident);
  }

  Future<void> _loadResidentWellness(CarePlanResident resident) async {
    setState(() {
      _isLoadingWellness = true;
      _wellnessError = null;
    });

    final token = ref.read(authProvider).state.token;

    try {
      final cognitiveFuture = CarePlansService.loadCognitiveData(resident.id, token: token);
      final emotionalFuture = CarePlansService.loadEmotionalData(
        resident.id,
        residentName: resident.name,
        token: token,
      );
      final metabolicFuture = CarePlansService.loadMetabolicData(resident.id, token: token);

      final results = await Future.wait([cognitiveFuture, emotionalFuture, metabolicFuture]);

      MemoryGameProgressSummary? memoryGames;
      try {
        memoryGames = await MemoryGameService.fetchResidentProgress(resident.id, token: token);
      } catch (_) {
        memoryGames = MemoryGameProgressSummary.empty(resident.id, resident.name);
      }

      if (mounted && _selectedResident?.id == resident.id) {
        setState(() {
          _cognitiveData = results[0] as CarePlanCognitiveData;
          _emotionalData = results[1] as CarePlanEmotionalData;
          _metabolicData = results[2] as CarePlanMetabolicData;
          _memoryGameProgress = memoryGames;
          _isLoadingWellness = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWellness = false;
          _wellnessError = 'Failed to load resident care plan records: $e';
        });
      }
    }
  }

  void _clearSelectedResident() {
    setState(() {
      _selectedResident = null;
      _selectedDomainIndex = 0;
      _cognitiveData = null;
      _emotionalData = null;
      _metabolicData = null;
      _memoryGameProgress = null;
      _showCognitiveHistory = false;
      _showSessionHistory = false;
    });
  }

  String _localizeResidentName(String name, bool isSi) {
    if (!isSi) return name;
    return SinhalaNameTransliterator.toSinhala(name, fallback: name);
  }

  String _localizeGender(String? gender, bool isSi) {
    final raw = (gender ?? '').trim();
    if (!isSi) return raw.isNotEmpty ? raw : 'Senior Resident';
    final lower = raw.toLowerCase();
    if (lower == 'female' || lower == 'f') return 'ස්ත්‍රී';
    if (lower == 'male' || lower == 'm') return 'පුරුෂ';
    return 'වැඩිහිටි';
  }

  String _classifyResidentRisk(CarePlanResident r) {
    final rl = (r.riskLevel ?? '').trim().toUpperCase();
    if (rl.contains('HIGH')) return 'High';
    if (rl.contains('MOD') || rl.contains('MED') || rl.contains('WATCH')) {
      return 'Moderate';
    }
    if (rl.contains('LOW') || rl.contains('STABLE')) return 'Stable';

    final cs = (r.currentStatus ?? '').trim().toUpperCase();
    if (cs.contains('CHECK_IN') || cs.contains('HIGH') || cs.contains('URGENT')) {
      return 'High';
    }
    if (cs.contains('ATTENTION') || cs.contains('MOD')) {
      return 'Moderate';
    }
    return 'Stable';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).state;
    final isSi = ref.watch(languageProvider).isSinhala;
    final bool showForegroundAccents = _selectedResident == null;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: _CarePlansAmbientBackdrop(isForeground: false),
            ),
          ),
          if (!showForegroundAccents)
            const Positioned.fill(
              child: IgnorePointer(
                child: _CarePlansAmbientBackdrop(isForeground: true),
              ),
            ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(auth, isSi),
                  const SizedBox(height: 20),

                  // Content body: Selected Resident Plan OR Resident Directory-Style Cards Grid
                  if (_selectedResident != null) ...[
                    _buildSelectedResidentPlan(),
                  ] else if (_isLoadingResidents) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                  ] else if (_residentLoadError != null) ...[
                    _buildErrorBanner(_residentLoadError!, () => _loadInitialData()),
                  ] else ...[
                    _buildCarePlansDirectorySection(auth, isSi),
                  ],
                ],
              ),
            ),
          ),
          if (showForegroundAccents)
            const Positioned.fill(
              child: IgnorePointer(
                child: _CarePlansAmbientBackdrop(isForeground: true),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // AURORA GRADIENT HEADER (Matching Resident Directory UI)
  // ----------------------------------------------------
  Widget _buildHeader(AuthState auth, bool isSi) {
    final homeName = auth.elderHomeName ?? (isSi ? 'ඔබේ සත්කාර නිවස' : 'Assigned Facility');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF312E81),
            Color(0xFF6D28D9),
            Color(0xFF0D9488),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          final leftSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.sparkles, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isSi
                            ? 'සායනික සත්කාර මඟපෙන්වීම • $homeName'
                            : 'MULTIMODAL CLINICAL GUIDANCE • $homeName',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(
                      LucideIcons.clipboardList,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      isSi ? 'සත්කාර සැලසුම්' : 'Care Plans Management',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                auth.isElder
                    ? (isSi
                        ? 'ඔබේ දෛනික සුවතා සැලසුම සහ සෞඛ්‍ය නිර්දේශ මෙහිදී බලන්න.'
                        : 'Your personalized holistic wellness plan and daily care recommendations.')
                    : (isSi
                        ? 'නේවාසිකයෙකු තෝරා මතක, මානසික සහ ශරීර සෞඛ්‍ය සඳහා සැකසූ සත්කාර සැලසුම් පරීක්ෂා කරන්න.'
                        : 'Select a resident to review structured, risk-based care plans across Cognitive, Emotional, and Metabolic wellness domains.'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
            ],
          );

          final rightActions = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!auth.isElder)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSi
                            ? 'නේවාසිකයින් ${_allResidents.length}'
                            : '${_allResidents.length} Residents',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                    ],
                  ),
                ),
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _isLoadingResidents ? null : _loadInitialData,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoadingResidents)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          isSi ? 'නැවුම් කරන්න' : 'Refresh',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftSection,
                const SizedBox(height: 14),
                rightActions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: leftSection),
              const SizedBox(width: 20),
              rightActions,
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // RESIDENT DIRECTORY-STYLE CARE PLANS SELECTOR (KPI + SEARCH + FILTERS + FLOATING CARDS)
  // ----------------------------------------------------
  Widget _buildCarePlansDirectorySection(AuthState auth, bool isSi) {
    int highCount = 0;
    int moderateCount = 0;
    int stableCount = 0;
    for (final r in _allResidents) {
      final tier = _classifyResidentRisk(r);
      if (tier == 'High') {
        highCount++;
      } else if (tier == 'Moderate') {
        moderateCount++;
      } else {
        stableCount++;
      }
    }

    final activeFilter = _activeRiskFilter;
    final q = _searchQuery.trim().toLowerCase();
    final filteredResidents = _allResidents.where((r) {
      if (activeFilter != 'All' && _classifyResidentRisk(r) != activeFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final enName = r.name.toLowerCase();
      final siName = SinhalaNameTransliterator.toSinhala(r.name, fallback: r.name).toLowerCase();
      final idStr = r.id.toString();
      final roomStr = r.roomNumber.toLowerCase();
      return enName.contains(q) ||
          siName.contains(q) ||
          idStr == q ||
          idStr.contains(q) ||
          roomStr.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Live KPI Summary Strip
        _buildCarePlanKpiStrip(
          total: _allResidents.length,
          highCount: highCount,
          moderateCount: moderateCount,
          stableCount: stableCount,
          facilityName: auth.elderHomeName ?? (isSi ? 'ඔබේ සත්කාර නිවස' : 'Assigned Facility'),
          isSi: isSi,
        ),
        const SizedBox(height: 18),

        // 2. Search Bar + Quick Risk Filter Pills
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEDE9FE), Color(0xFFE0E7FF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.search,
                        size: 16,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.navy,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: isSi
                              ? 'නම, කාමර අංකය හෝ හැඳුනුම්පත අනුව සොයන්න...'
                              : 'Search residents by name, room number, or ID...',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.muted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 17, color: AppColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        tooltip: isSi ? 'මකන්න' : 'Clear search',
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.7)),
                      ),
                      child: Text(
                        isSi
                            ? '${filteredResidents.length} / ${_allResidents.length}'
                            : '${filteredResidents.length} of ${_allResidents.length}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRiskFilterPill(
                    filterKey: 'All',
                    label: isSi ? 'සියල්ල' : 'All Residents',
                    count: _allResidents.length,
                    activeColor: const Color(0xFF4F46E5),
                    activeBg: const Color(0xFF4F46E5),
                  ),
                  _buildRiskFilterPill(
                    filterKey: 'High',
                    label: isSi ? 'ඉහළ අවදානම්' : 'High Risk',
                    count: highCount,
                    activeColor: const Color(0xFFDC2626),
                    activeBg: const Color(0xFFDC2626),
                  ),
                  _buildRiskFilterPill(
                    filterKey: 'Moderate',
                    label: isSi ? 'මධ්‍යම අවධානය' : 'Moderate',
                    count: moderateCount,
                    activeColor: const Color(0xFFD97706),
                    activeBg: const Color(0xFFD97706),
                  ),
                  _buildRiskFilterPill(
                    filterKey: 'Stable',
                    label: isSi ? 'ස්ථාවරයි' : 'Stable',
                    count: stableCount,
                    activeColor: const Color(0xFF059669),
                    activeBg: const Color(0xFF059669),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Responsive Floating Resident Cards Grid
        _buildResidentsGrid(filteredResidents, isSi),
      ],
    );
  }

  Widget _buildCarePlanKpiStrip({
    required int total,
    required int highCount,
    required int moderateCount,
    required int stableCount,
    required String facilityName,
    required bool isSi,
  }) {
    final attentionCount = highCount + moderateCount;
    final attentionSubtitle = attentionCount == 0
        ? (isSi ? 'සියලු දෙනා ස්ථාවරයි' : 'All residents stable')
        : (isSi
            ? 'ඉහළ $highCount • මධ්‍යම $moderateCount'
            : '$highCount High • $moderateCount Moderate');

    final card1 = _buildKpiCard(
      title: isSi ? 'මුළු නේවාසිකයින්' : 'Total Residents',
      value: '$total',
      subtitle: facilityName,
      icon: Icons.groups_rounded,
      accentColor: const Color(0xFF4F46E5),
      gradientColors: const [Color(0xFFF5F3FF), Color(0xFFEEF2FF)],
      borderColor: const Color(0xFFDDD6FE),
      isActive: _activeRiskFilter == 'All',
      onTap: () => setState(() => _riskFilter = 'All'),
    );

    final card2 = _buildKpiCard(
      title: isSi ? 'අවධානය අවශ්‍යයි' : 'Needs Attention',
      value: '$attentionCount',
      subtitle: attentionSubtitle,
      icon: attentionCount > 0 ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
      accentColor: attentionCount > 0 ? const Color(0xFFEA580C) : const Color(0xFF0D9488),
      gradientColors: attentionCount > 0
          ? const [Color(0xFFFFF7ED), Color(0xFFFEF2F2)]
          : const [Color(0xFFF0FDFA), Color(0xFFECFDF5)],
      borderColor: attentionCount > 0
          ? const Color(0xFFFED7AA)
          : const Color(0xFFA7F3D0),
      isActive: _activeRiskFilter == 'High' || _activeRiskFilter == 'Moderate',
      onTap: () => setState(() {
        if (highCount > 0) {
          _riskFilter = 'High';
        } else if (moderateCount > 0) {
          _riskFilter = 'Moderate';
        } else {
          _riskFilter = 'All';
        }
      }),
    );

    final card3 = _buildKpiCard(
      title: isSi ? 'ස්ථාවර මට්ටමේ' : 'Stable Residents',
      value: '$stableCount',
      subtitle: isSi ? 'සත්කාර සැලසුම් ක්‍රියාත්මකයි' : 'Active care plans on track',
      icon: Icons.favorite_rounded,
      accentColor: const Color(0xFF059669),
      gradientColors: const [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
      borderColor: const Color(0xFFA7F3D0),
      isActive: _activeRiskFilter == 'Stable',
      onTap: () => setState(() => _riskFilter = 'Stable'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              card1,
              const SizedBox(height: 12),
              card2,
              const SizedBox(height: 12),
              card3,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 14),
            Expanded(child: card2),
            const SizedBox(width: 14),
            Expanded(child: card3),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
    required Color borderColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive ? accentColor.withValues(alpha: 0.65) : borderColor,
              width: isActive ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isActive ? 0.12 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, size: 22, color: accentColor),
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
                        color: AppColors.body,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildRiskFilterPill({
    required String filterKey,
    required String label,
    required int count,
    required Color activeColor,
    required Color activeBg,
  }) {
    final isSelected = _activeRiskFilter == filterKey;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => setState(() => _riskFilter = filterKey),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isSelected ? activeBg : AppColors.border),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBg.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.24)
                      : activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : activeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResidentsGrid(List<CarePlanResident> residents, bool isSi) {
    if (residents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lilac),
              ),
              child: const Icon(LucideIcons.search, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              _allResidents.isEmpty
                  ? (isSi ? 'තවම නේවාසිකයින් ලියාපදිංචි වී නැත' : 'No Residents Available Yet')
                  : (isSi ? 'ගැලපෙන නේවාසිකයින් හමු නොවීය' : 'No Matching Residents Found'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _allResidents.isEmpty
                  ? (isSi
                      ? 'ඔබේ සත්කාර නිවසේ නේවාසිකයින් මෙහි දිස්වනු ඇත.'
                      : 'Residents assigned to your care home will appear here automatically.')
                  : (isSi
                      ? 'වෙනත් නමක් හෝ කාමර අංකයක් සොයා බලන්න, නැතහොත් පෙරහන් ඉවත් කරන්න.'
                      : 'Try another name, room number, or clear your active filters.'),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _activeRiskFilter != 'All') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _riskFilter = 'All';
                  });
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: Text(isSi ? 'පෙරහන් ඉවත් කරන්න' : 'Clear Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDeep,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int cols = constraints.maxWidth >= 1060
            ? 3
            : (constraints.maxWidth >= 660 ? 2 : 1);

        final List<Widget> rows = [];
        for (int i = 0; i < residents.length; i += cols) {
          final rowChildren = <Widget>[];
          for (int j = 0; j < cols; j++) {
            final idx = i + j;
            if (j > 0) rowChildren.add(const SizedBox(width: 16));
            if (idx < residents.length) {
              final rItem = residents[idx];
              final tier = _classifyResidentRisk(rItem);
              final glowColor = tier == 'High'
                  ? const Color(0xFFEF4444)
                  : (tier == 'Moderate'
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF0D9488));
              rowChildren.add(
                Expanded(
                  child: _FloatingCarePlanCardWrapper(
                    key: ValueKey('care_plan_elder_card_${rItem.id}'),
                    index: idx,
                    glowColor: glowColor,
                    child: _buildResidentCarePlanCard(rItem, isSi),
                  ),
                ),
              );
            } else {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (i > 0) rows.add(const SizedBox(height: 18));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        );
      },
    );
  }

  Widget _buildResidentCarePlanCard(CarePlanResident r, bool isSi) {
    final riskTier = _classifyResidentRisk(r);
    final Color riskColor;
    final Color riskBg;
    final Color riskBorder;
    final String riskLabel;
    final List<Color> topBarColors;
    final List<Color> cardTintColors;

    if (riskTier == 'High') {
      riskColor = const Color(0xFFDC2626);
      riskBg = const Color(0xFFFEF2F2);
      riskBorder = const Color(0xFFFECACA);
      riskLabel = isSi ? 'ඉහළ අවදානම්' : 'High Risk';
      topBarColors = const [Color(0xFFEF4444), Color(0xFFF97316)];
      cardTintColors = const [Colors.white, Color(0xFFFFF7F7)];
    } else if (riskTier == 'Moderate') {
      riskColor = const Color(0xFFD97706);
      riskBg = const Color(0xFFFFFBEB);
      riskBorder = const Color(0xFFFDE68A);
      riskLabel = isSi ? 'මධ්‍යම අවධානය' : 'Moderate';
      topBarColors = const [Color(0xFFF59E0B), Color(0xFFFB923C)];
      cardTintColors = const [Colors.white, Color(0xFFFFFCF3)];
    } else {
      riskColor = const Color(0xFF059669);
      riskBg = const Color(0xFFECFDF5);
      riskBorder = const Color(0xFFA7F3D0);
      riskLabel = isSi ? 'ස්ථාවරයි' : 'Stable';
      topBarColors = const [Color(0xFF4F46E5), Color(0xFF0D9488)];
      cardTintColors = const [Colors.white, Color(0xFFF8F7FF)];
    }

    final displayName = _localizeResidentName(r.name, isSi);
    final genderText = _localizeGender(r.gender, isSi);
    final cleanRoom = r.roomNumber.replaceFirst(RegExp(r'^Room\s*', caseSensitive: false), '').trim();
    final roomDisplay = isSi
        ? 'කාමරය ${cleanRoom.isNotEmpty ? cleanRoom : r.roomNumber}'
        : 'Room ${cleanRoom.isNotEmpty ? cleanRoom : r.roomNumber}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardTintColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: riskTier == 'High'
              ? const Color(0xFFFECACA)
              : (riskTier == 'Moderate'
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFE2E0F8)),
          width: 1.25,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectResident(r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: topBarColors),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Avatar + Name + Risk Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: topBarColors),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CarevoraAvatar(
                                avatarUrl: r.avatarUrl,
                                radius: 24,
                                initials: r.name,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                    height: 1.25,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: riskBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: riskBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: riskColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            riskLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: riskColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '#${r.id}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Info Chips (Room, Age, Gender)
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _buildCardMetaChip(
                            icon: Icons.meeting_room_outlined,
                            label: roomDisplay,
                            bg: const Color(0xFFEEF2FF),
                            fg: const Color(0xFF4338CA),
                          ),
                          if (r.age != null)
                            _buildCardMetaChip(
                              icon: Icons.cake_outlined,
                              label: isSi ? 'වයස ${r.age}' : 'Age ${r.age}',
                              bg: const Color(0xFFF0FDFA),
                              fg: const Color(0xFF0F766E),
                            ),
                          _buildCardMetaChip(
                            icon: Icons.person_outline_rounded,
                            label: genderText,
                            bg: const Color(0xFFF8FAFC),
                            fg: AppColors.body,
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),

                      // Care Plan Domain Preview Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildCardMetaChip(
                            icon: LucideIcons.brain,
                            label: isSi ? 'මතකය' : 'Cognitive',
                            bg: const Color(0xFFF5F3FF),
                            fg: const Color(0xFF6D28D9),
                          ),
                          _buildCardMetaChip(
                            icon: LucideIcons.heartHandshake,
                            label: isSi ? 'මානසික' : 'Emotional',
                            bg: const Color(0xFFFDF2F8),
                            fg: const Color(0xFFBE185D),
                          ),
                          _buildCardMetaChip(
                            icon: LucideIcons.activity,
                            label: isSi ? 'ශරීර සෞඛ්‍යය' : 'Metabolic',
                            bg: const Color(0xFFECFDF5),
                            fg: const Color(0xFF047857),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
                      const SizedBox(height: 11),

                      // Footer: Facility / Last check + Open Care Plan CTA
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.lastAssessmentDate != null &&
                                      r.lastAssessmentDate!.trim().isNotEmpty
                                  ? (isSi
                                      ? 'අවසන් පරීක්ෂාව: ${_formatDate(r.lastAssessmentDate)}'
                                      : 'Last check: ${_formatDate(r.lastAssessmentDate)}')
                                  : r.elderHomeName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isSi ? 'සත්කාර සැලසුම' : 'Care Plan',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  LucideIcons.arrowRight,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardMetaChip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: fg.withValues(alpha: 0.14)),
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

  // ----------------------------------------------------
  // SELECTED RESIDENT CARE PLAN VIEW
  // ----------------------------------------------------
  Widget _buildSelectedResidentPlan() {
    final resident = _selectedResident!;
    final auth = ref.watch(authProvider).state;
    final isSi = ref.watch(languageProvider).isSinhala;
    final displayName = _localizeResidentName(resident.name, isSi);
    final genderText = _localizeGender(resident.gender, isSi);
    final riskTier = _classifyResidentRisk(resident);
    final List<Color> ribbonColors = riskTier == 'High'
        ? const [Color(0xFFEF4444), Color(0xFFF97316)]
        : (riskTier == 'Moderate'
            ? const [Color(0xFFF59E0B), Color(0xFFFB923C)]
            : const [Color(0xFF4F46E5), Color(0xFF0D9488)]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upgraded Resident Profile Header Banner
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.22), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: ribbonColors),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: ribbonColors),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: CarevoraAvatar(
                            avatarUrl: resident.avatarUrl ?? (auth.isElder ? auth.avatarUrl : null),
                            radius: 26,
                            initials: resident.name,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isSi ? 'හැඳුනුම්පත: #${resident.id}' : 'ID: #${resident.id}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDeep,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 7,
                              runSpacing: 6,
                              children: [
                                _buildCardMetaChip(
                                  icon: Icons.meeting_room_outlined,
                                  label: isSi
                                      ? 'කාමරය ${resident.roomNumber.replaceFirst(RegExp(r'^Room\s*', caseSensitive: false), '').trim()}'
                                      : 'Room ${resident.roomNumber.replaceFirst(RegExp(r'^Room\s*', caseSensitive: false), '').trim()}',
                                  bg: const Color(0xFFEEF2FF),
                                  fg: const Color(0xFF4338CA),
                                ),
                                if (resident.age != null)
                                  _buildCardMetaChip(
                                    icon: Icons.cake_outlined,
                                    label: isSi ? 'වයස ${resident.age}' : 'Age ${resident.age}',
                                    bg: const Color(0xFFF0FDFA),
                                    fg: const Color(0xFF0F766E),
                                  ),
                                if (resident.educationYears != null)
                                  _buildCardMetaChip(
                                    icon: Icons.school_outlined,
                                    label: isSi
                                        ? 'අධ්‍යාපනය: වසර ${resident.educationYears}'
                                        : 'Edu: ${resident.educationYears} yrs',
                                    bg: const Color(0xFFF5F3FF),
                                    fg: const Color(0xFF6D28D9),
                                  ),
                                _buildCardMetaChip(
                                  icon: Icons.person_outline_rounded,
                                  label: genderText,
                                  bg: const Color(0xFFF8FAFC),
                                  fg: AppColors.body,
                                ),
                                _buildCardMetaChip(
                                  icon: Icons.home_work_outlined,
                                  label: resident.elderHomeName,
                                  bg: const Color(0xFFFDF2F8),
                                  fg: const Color(0xFF9D174D),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!auth.isElder) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _clearSelectedResident,
                          icon: const Icon(LucideIcons.arrowLeft, size: 15),
                          label: Text(isSi ? 'නේවාසික ලැයිස්තුවට' : 'Back to Residents'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDeep,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Clinical Support Guidance Notice
        _buildClinicalNoticeBanner(),
        const SizedBox(height: 20),

        if (_isLoadingWellness) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ] else if (_wellnessError != null) ...[
          _buildErrorBanner(_wellnessError!, () => _loadResidentWellness(resident)),
        ] else ...[
          // THREE INTERACTIVE DOMAIN SELECTOR CARDS
          _buildDomainSelectorCards(resident),
          const SizedBox(height: 14),

          // ACTIVE FOCUS DOMAIN BANNER
          _buildActiveDomainBanner(),
          const SizedBox(height: 16),

          // ACTIVE DOMAIN DETAIL CARD (IndexedStack preserves state & tests)
          IndexedStack(
            index: _selectedDomainIndex,
            children: [
              _buildCognitiveWellnessCard(resident),
              _buildEmotionalWellnessCard(),
              _buildMetabolicWellnessCard(),
            ],
          ),
        ],
      ],
    );
  }

  String _localizeRiskLabel(String raw, bool isSi) {
    if (!isSi) return raw;
    final up = raw.toUpperCase();
    if (up.contains('HIGH')) return 'ඉහළ අවදානම්';
    if (up.contains('MOD')) return 'මධ්‍යම අවදානම්';
    if (up.contains('LOW')) return 'අඩු අවදානම්';
    if (up.contains('STABLE')) return 'ස්ථාවරයි';
    if (up.contains('AWAITING') || up.contains('NONE') || up.contains('PENDING')) {
      return 'පරීක්ෂාවට ඇත';
    }
    if (up.contains('UNAVAILABLE') || up.contains('UNKNOWN')) return 'ලබා ගත නොහැක';
    return raw;
  }

  String _localizeTrajectory(String? raw, bool isSi) {
    if (!isSi) return raw ?? 'Stable';
    final up = (raw ?? '').toUpperCase();
    if (up.contains('IMPROV')) return 'දියුණු වෙමින්';
    if (up.contains('DECLIN') || up.contains('WORS')) return 'පහළ යමින්';
    return 'ස්ථාවරයි';
  }

  // ----------------------------------------------------
  // INTERACTIVE DOMAIN SELECTOR CARDS
  // ----------------------------------------------------
  Widget _buildDomainSelectorCards(CarePlanResident resident) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCognitiveDomainCard(resident)),
              const SizedBox(width: 14),
              Expanded(child: _buildEmotionalDomainCard()),
              const SizedBox(width: 14),
              Expanded(child: _buildMetabolicDomainCard()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildCognitiveDomainCard(resident),
              const SizedBox(height: 12),
              _buildEmotionalDomainCard(),
              const SizedBox(height: 12),
              _buildMetabolicDomainCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildCognitiveDomainCard(CarePlanResident resident) {
    final isSi = ref.watch(languageProvider).isSinhala;
    final isSelected = _selectedDomainIndex == 0;
    final cog = _cognitiveData;
    final hasCog = cog != null && cog.hasAssessment;
    final rec = cog?.recommendation;
    final accuracyStr = hasCog ? CarePlansService.formatTaskAccuracyScore(cog.taskAccuracyScore) : null;
    final dateStr = hasCog ? _formatDate(cog.assessmentDate) : null;

    final badgeLabel = hasCog && rec != null
        ? _localizeRiskLabel(rec.categoryLabel, isSi)
        : (isSi ? 'පරීක්ෂාවට ඇත' : 'AWAITING EVAL');
    final badgeBg = hasCog && rec != null ? rec.badgeBg : const Color(0xFFF3F4F6);
    final badgeColor = hasCog && rec != null ? rec.badgeColor : AppColors.muted;

    return _buildDomainCardContainer(
      index: 0,
      isSelected: isSelected,
      isSi: isSi,
      accentColor: AppColors.primary,
      selectedBgColor: const Color(0xFFFAF7FF),
      iconBgColor: AppColors.primarySoft,
      iconColor: AppColors.primary,
      icon: LucideIcons.brain,
      title: isSi ? 'මතක පරීක්ෂාව' : 'Cognitive Wellness',
      badgeLabel: badgeLabel,
      badgeBg: badgeBg,
      badgeColor: badgeColor,
      subtitle: hasCog
          ? (isSi
              ? 'මතක නිරවද්‍යතාව: $accuracyStr • $dateStr'
              : 'Task Accuracy: $accuracyStr • $dateStr')
          : (isSi ? 'මූලික මතක පරීක්ෂාව සිදු කිරීමට ඇත' : 'Baseline clinical assessment pending'),
      tagText: isSi ? 'මතක පුහුණුව සහ ක්‍රීඩා' : 'Practice & Memory Games',
    );
  }

  Widget _buildEmotionalDomainCard() {
    final isSi = ref.watch(languageProvider).isSinhala;
    final isSelected = _selectedDomainIndex == 1;
    final emo = _emotionalData;
    final hasEmo = emo != null && emo.hasData;

    final String badgeLabel;
    final Color badgeBg;
    final Color badgeColor;

    if (hasEmo && emo.riskLevel != null) {
      badgeLabel = _localizeRiskLabel('${emo.riskLevel} RISK', isSi);
      badgeColor = _getRiskBadgeColor(emo.riskLevel!);
      badgeBg = badgeColor.withValues(alpha: 0.12);
    } else {
      badgeLabel = isSi ? 'ස්ථාවරයි' : 'STABLE';
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
    }

    return _buildDomainCardContainer(
      index: 1,
      isSelected: isSelected,
      isSi: isSi,
      accentColor: const Color(0xFFDB2777),
      selectedBgColor: const Color(0xFFFDF2F8),
      iconBgColor: const Color(0xFFFCE7F3),
      iconColor: const Color(0xFFDB2777),
      icon: LucideIcons.heartHandshake,
      title: isSi ? 'මානසික සුවතාවය' : 'Emotional Wellness',
      badgeLabel: badgeLabel,
      badgeBg: badgeBg,
      badgeColor: badgeColor,
      subtitle: hasEmo && emo.socialScore != null
          ? (isSi
              ? 'සමාජ ලකුණු: ${emo.socialScore!.toStringAsFixed(0)}% • ${_localizeTrajectory(emo.trajectory, true)}'
              : 'Social Score: ${emo.socialScore!.toStringAsFixed(0)}% • ${emo.trajectory ?? 'Stable'}')
          : (isSi ? 'සමාජ සබඳතා සහ හැඟීම් නිරීක්ෂණය' : 'Social connectedness & affect monitoring'),
      tagText: isSi ? 'සංගීත හා ක්‍රියාකාරකම් සැලසුම්' : 'Music & Activity Plans',
    );
  }

  Widget _buildMetabolicDomainCard() {
    final isSi = ref.watch(languageProvider).isSinhala;
    final isSelected = _selectedDomainIndex == 2;

    return _buildDomainCardContainer(
      index: 2,
      isSelected: isSelected,
      isSi: isSi,
      accentColor: const Color(0xFFD97706),
      selectedBgColor: const Color(0xFFFFFBEB),
      iconBgColor: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFD97706),
      icon: LucideIcons.activity,
      title: isSi ? 'ශරීර සෞඛ්‍යය' : 'Metabolic Wellness',
      badgeLabel: isSi ? 'සම්බන්ධ වීමට ඇත' : 'Sync Pending',
      badgeBg: const Color(0xFFFEF3C7),
      badgeColor: const Color(0xFFD97706),
      subtitle: isSi
          ? 'ජීව දත්ත, රුධිර සීනි සහ නින්ද නිරීක්ෂණය'
          : 'Vitals tracking, glucose & sleep telemetry',
      tagText: isSi ? 'සංවේදක සම්බන්ධතාව' : 'Non-invasive Sync',
    );
  }

  Widget _buildDomainCardContainer({
    required int index,
    required bool isSelected,
    required bool isSi,
    required Color accentColor,
    required Color selectedBgColor,
    required Color iconBgColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String badgeLabel,
    required Color badgeBg,
    required Color badgeColor,
    required String subtitle,
    required String tagText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDomainIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: accentColor.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? selectedBgColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.border,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: isSelected ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tagText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.body,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.check, size: 11, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            isSi ? 'දැනට පෙන්වන' : 'Active View',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSi ? 'බලන්න' : 'View',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(LucideIcons.arrowRight, size: 12, color: AppColors.muted),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDomainBanner() {
    final isSi = ref.watch(languageProvider).isSinhala;
    final String domainName;
    final Color domainColor;
    final IconData domainIcon;

    if (_selectedDomainIndex == 0) {
      domainName = isSi
          ? 'මතක පරීක්ෂණ සහ සත්කාර සැලසුම'
          : 'Cognitive Clinical Protocol & Care Plan';
      domainColor = AppColors.primary;
      domainIcon = LucideIcons.brain;
    } else if (_selectedDomainIndex == 1) {
      domainName = isSi
          ? 'මානසික සුවතා සැලසුම සහ ක්‍රියාකාරකම්'
          : 'Emotional Care Protocol & Interventions';
      domainColor = const Color(0xFFDB2777);
      domainIcon = LucideIcons.heartHandshake;
    } else {
      domainName = isSi
          ? 'ශරීර සෞඛ්‍ය නිරීක්ෂණ සැලසුම'
          : 'Metabolic Health Telemetry Protocol';
      domainColor = const Color(0xFFD97706);
      domainIcon = LucideIcons.activity;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: domainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: domainColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(domainIcon, size: 15, color: domainColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSi ? 'දැනට තෝරා ඇත්තේ: $domainName' : 'Active Focus: $domainName',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: domainColor,
              ),
            ),
          ),
          Text(
            isSi ? 'මාරු වීමට ඉහත කාඩ්පත් ඔබන්න' : 'Click cards above to switch',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CLINICAL NOTICE BANNER
  // ----------------------------------------------------
  Widget _buildClinicalNoticeBanner() {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 18, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSi
                  ? 'සත්කාර උපදෙස් දැන්වීම: පහත සඳහන් සත්කාර සැලසුම් උපදෙස් දෛනික සුවතා සහාය සඳහා පමණි. මේවා වෛද්‍ය රෝග විනිශ්චයන් හෝ බෙහෙත් නියම කිරීම් නොවේ. සෞඛ්‍ය සැලසුම් වෙනස් කිරීමට පෙර වෛද්‍යවරයාගේ උපදෙස් ලබා ගන්න.'
                  : 'Caregiver Guidance Notice: Care plan recommendations provided below are supportive wellness suggestions and non-pharmacological interventions. They are not diagnoses or medical prescriptions. Consult the attending physician or clinical lead before modifying clinical protocols.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E40AF),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // 1. COGNITIVE WELLNESS CARD
  // ----------------------------------------------------
  Widget _buildCognitiveWellnessCard(CarePlanResident resident) {
    final isSi = ref.watch(languageProvider).isSinhala;
    final cog = _cognitiveData;
    if (cog == null || !cog.hasAssessment) {
      return _buildEmptyCognitiveCard(resident);
    }

    final latest = cog.latestAssessment!;
    final rec = cog.recommendation;
    final accuracyStr = CarePlansService.formatTaskAccuracyScore(cog.taskAccuracyScore);
    final dateStr = _formatDate(cog.assessmentDate);
    final priorRecords = _getPriorRecords(cog);

    // Localized care recommendation content for Sinhala
    final String recTitle;
    final String recSummary;
    final List<String> recActions;
    if (isSi) {
      switch (rec.category) {
        case CognitiveRiskCategory.high:
          recTitle = 'ඉහළ මතක අවදානම් සත්කාර සැලසුම';
          recSummary =
              'නේවාසිකයාට වැඩි සත්කාර සහායක් අවශ්‍ය බව පෙනේ. දෛනික කටයුතු පහසු කිරීමට සෙමින් මඟපෙන්වන්න සහ වෛද්‍ය උපදෙස් ලබා ගන්න.';
          recActions = const [
            'දිනය, වේලාව සහ අවට පරිසරය සෙමින් සිහිපත් කර දෙන්න.',
            'දෛනික ඖෂධ සහ ආහාර වේල් සඳහා සමීපව උදව් කරන්න.',
            'මතක තත්ත්වය පිළිබඳව වෛද්‍යවරයා දැනුවත් කර නැවත පරීක්ෂාවක් සැලසුම් කරන්න.',
            'සැහැල්ලු හා සන්සුන් පරිසරයක් පවත්වා ගන්න.',
          ];
          break;
        case CognitiveRiskCategory.moderate:
          recTitle = 'මධ්‍යම මතක අවදානම් සත්කාර සැලසුම';
          recSummary =
              'සුළු මතක වෙනස්කම් දක්නට ලැබේ. මොළය සක්‍රීයව තබා ගැනීමට දිනපතා මතක ක්‍රීඩා සහ නිතිපතා නිරීක්ෂණය නිර්දේශ කරයි.';
          recActions = const [
            'දිනපතා මිනිත්තු 10–15ක් සැහැල්ලු මතක ක්‍රීඩා සහ කතාබහ සිදු කරන්න.',
            'දෛනික කාලසටහන පිළිවෙළකට පවත්වා ගෙන යන්න.',
            'සති 2කින් නැවත මතක පරීක්ෂාවක් සිදු කර ප්‍රගතිය සසඳන්න.',
            'ප්‍රමාණවත් නින්ද සහ ජලය පානය තහවුරු කරන්න.',
          ];
          break;
        case CognitiveRiskCategory.low:
        default:
          recTitle = 'ස්ථාවර මතක සුවතා සැලසුම';
          recSummary =
              'නේවාසිකයාගේ මතක ශක්තිය යහපත් මට්ටමක පවතී! මෙම ශක්තිය දිගටම පවත්වා ගැනීමට දෛනික ක්‍රියාකාරකම් දිරිමත් කරන්න.';
          recActions = const [
            'දිනපතා කියවීම, සංගීතය සහ මිතුරන් සමඟ කතාබහ දිගටම කරගෙන යන්න.',
            'සතියකට කිහිප වතාවක් මතක ක්‍රීඩා සඳහා එක් කරන්න.',
            'මාසිකව නිතිපතා මතක පරීක්ෂා කර සුවතාවය සටහන් කරන්න.',
          ];
          break;
      }
    } else {
      recTitle = rec.title;
      recSummary = rec.summary;
      recActions = rec.actionItems;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.brain, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi
                            ? 'මතක පරීක්ෂණ සහ සත්කාර සැලසුම'
                            : 'Cognitive Clinical Protocol & Care Plan',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSi ? 'අවසන් පරීක්ෂාව: $dateStr' : 'Latest Assessment: $dateStr',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                // Risk Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rec.badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rec.badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(rec.icon, size: 14, color: rec.badgeColor),
                      const SizedBox(width: 6),
                      Text(
                        _localizeRiskLabel(rec.categoryLabel, isSi),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rec.badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Key Metrics Row: Task Accuracy Score vs AI Risk Level
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Task Accuracy Score Tile
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.target, size: 14, color: AppColors.muted),
                                const SizedBox(width: 6),
                                Text(
                                  isSi ? 'මතක නිරවද්‍යතා ලකුණු' : 'Task Accuracy Score',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              accuracyStr,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cog.taskAccuracyScore != null &&
                                      ((cog.taskAccuracyScore! <= 1.0 && cog.taskAccuracyScore! > 0.0)
                                          ? cog.taskAccuracyScore! * 100.0 >= 80.0
                                          : cog.taskAccuracyScore! >= 80.0)
                                  ? (isSi ? 'ඉහළ නිරවද්‍යතාවයකින් පිළිතුරු දී ඇත' : 'High task execution accuracy')
                                  : (isSi ? 'මධ්‍යම මට්ටමේ කාර්ය සාධනය' : 'Moderate or partial task execution'),
                              style: const TextStyle(fontSize: 11, color: AppColors.body),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // AI-Predicted Risk Level Tile
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: rec.badgeBg.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: rec.badgeColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.sparkles, size: 14, color: rec.badgeColor),
                                const SizedBox(width: 6),
                                Text(
                                  isSi ? 'AI අවදානම් තත්ත්වය' : 'Actual AI-Predicted Risk',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _localizeRiskLabel(rec.categoryLabel, isSi),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: rec.badgeColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cog.mlAvailable
                                  ? (isSi ? 'AI ආකෘති විශ්ලේෂණය මත පදනම්ව' : '31-feature ML model prediction')
                                  : (cog.actualRiskLevel != null
                                      ? (isSi ? 'ලකුණු මත පදනම් වූ අවදානම් මට්ටම' : 'Score-based clinical risk tier')
                                      : (isSi ? 'AI විශ්ලේෂණය ලබා ගත නොහැක' : 'Model prediction unavailable')),
                              style: const TextStyle(fontSize: 11, color: AppColors.body),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_memoryGameProgress != null &&
                    _memoryGameProgress!.totalCompletedSessions > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderBg.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.gamepad2, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          isSi ? 'මතක ක්‍රීඩා තත්ත්වය: ' : 'Memory Games Status: ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_memoryGameProgress!.averageScore ?? 0) >= 80.0 &&
                                    !_memoryGameProgress!.hasRepeatedDecline
                                ? AppColors.riskLowBg
                                : (_memoryGameProgress!.hasRepeatedDecline
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFEFF6FF)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (_memoryGameProgress!.averageScore ?? 0) >= 80.0 &&
                                    !_memoryGameProgress!.hasRepeatedDecline
                                ? (isSi ? 'හොඳ මට්ටමේ' : 'Good Condition')
                                : (_memoryGameProgress!.hasRepeatedDecline
                                    ? (isSi ? 'නිරීක්ෂණය අවශ්‍යයි' : 'Needs Observation')
                                    : (isSi ? 'ස්ථාවර මට්ටමේ' : 'Stable Condition')),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (_memoryGameProgress!.averageScore ?? 0) >= 80.0 &&
                                      !_memoryGameProgress!.hasRepeatedDecline
                                  ? AppColors.riskLow
                                  : (_memoryGameProgress!.hasRepeatedDecline
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF1D4ED8)),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isSi
                              ? 'වාර ${_memoryGameProgress!.totalCompletedSessions} (සාමාන්‍යය ${_memoryGameProgress!.averageScore?.toStringAsFixed(1) ?? "--"}%)'
                              : '${_memoryGameProgress!.totalCompletedSessions} sessions (${_memoryGameProgress!.averageScore?.toStringAsFixed(1) ?? "--"}% avg)',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Sub-Domain Accuracy Bar
                _buildDomainScoresRow(latest),
                const SizedBox(height: 18),

                // Explainable AI: SHAP Feature Attribution
                CognitiveShapExplanationCard(
                  riskLevel: rec.categoryLabel,
                  acrfScore: cog.taskAccuracyScore,
                  isCompact: false,
                  isSinhala: isSi,
                ),
                const SizedBox(height: 18),

                // Risk-Based Recommendations Block
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: rec.badgeBg.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: rec.badgeColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(rec.icon, color: rec.badgeColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              recTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: rec.badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recSummary,
                        style: const TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isSi ? 'සත්කාරක ක්‍රියාමාර්ග:' : 'Caregiver Action Protocol:',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...recActions.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: rec.badgeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.navy,
                                    height: 1.4,
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
                const SizedBox(height: 16),

                // Previous Assessment History Toggle
                if (priorRecords.isNotEmpty) ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showCognitiveHistory = !_showCognitiveHistory;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _showCognitiveHistory ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSi
                                ? 'පෙර පරීක්ෂණ ඉතිහාසය (වාර්තා ${priorRecords.length})'
                                : 'Previous Assessment History (${priorRecords.length} prior records)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showCognitiveHistory) ...[
                    const SizedBox(height: 10),
                    _buildCognitiveHistoryList(priorRecords),
                  ],
                ],
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 24),

                // Integrated Memory Games Progress Sub-Section
                _buildMemoryGamesProgressSection(resident),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCognitiveCard(CarePlanResident resident) {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Icon(LucideIcons.brain, size: 40, color: AppColors.muted),
                const SizedBox(height: 12),
                Text(
                  isSi ? 'මතක පරීක්ෂණයක් තවම නොමැත' : 'No Cognitive Assessment Recorded',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  isSi
                      ? 'මෙම නේවාසිකයා තවම මතක පරීක්ෂණයක් සම්පූර්ණ කර නැත. සත්කාර සැලසුම් ලබා ගැනීමට පරීක්ෂණයක් ආරම්භ කරන්න.'
                      : 'This resident has not completed a cognitive evaluation yet. Start an assessment to generate risk-based care plans.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/dashboard/assessment'),
                  icon: const Icon(LucideIcons.play, size: 16),
                  label: Text(isSi ? 'මතක පරීක්ෂාව ආරම්භ කරන්න' : 'Start Cognitive Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 24),
          _buildMemoryGamesProgressSection(resident),
        ],
      ),
    );
  }

  Widget _buildDomainScoresRow(CognitiveSubmissionResult result) {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSi ? 'මතක අංශ ලකුණු' : 'Cognitive Domain Scores',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDomainScoreItem(isSi ? 'දිශානතිය' : 'Orientation', result.orientation)),
              Expanded(child: _buildDomainScoreItem(isSi ? 'මතකය' : 'Memory', result.memory)),
              Expanded(child: _buildDomainScoreItem(isSi ? 'අවධානය' : 'Attention', result.attention)),
              Expanded(child: _buildDomainScoreItem(isSi ? 'සිහිපත් කිරීම' : 'Recall', result.recall)),
              Expanded(child: _buildDomainScoreItem(isSi ? 'තර්කනය' : 'Reasoning', result.reasoning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDomainScoreItem(String label, double? score) {
    final pct = CarePlansService.formatDomainScore(score);
    return Column(
      children: [
        Text(
          pct,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }

  List<CognitiveSubmissionResult> _getPriorRecords(CarePlanCognitiveData cog) {
    final latest = cog.latestAssessment;
    if (latest == null) return cog.history;
    return cog.history.where((item) {
      if (identical(item, latest)) return false;
      if (latest.id > 0 && item.id > 0 && item.id == latest.id) return false;
      if (latest.sessionId != null &&
          latest.sessionId!.isNotEmpty &&
          item.sessionId != null &&
          item.sessionId!.isNotEmpty &&
          item.sessionId == latest.sessionId) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildCognitiveHistoryList(List<CognitiveSubmissionResult> priorRecords) {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: priorRecords.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final item = priorRecords[index];
          final date = _formatDate(item.createdAt);
          final accuracy = CarePlansService.formatTaskAccuracyScore(item.acrfScore);
          String risk = item.riskLevel ?? item.mlPrediction ?? '';
          if (risk.isEmpty ||
              risk == 'UNKNOWN' ||
              risk == 'Not Available' ||
              risk == 'Risk Level Not Available' ||
              risk == 'Prediction Unavailable') {
            if (item.acrfScore != null) {
              final s = (item.acrfScore! <= 1.0 && item.acrfScore! > 0.0)
                  ? item.acrfScore! * 100.0
                  : item.acrfScore!;
              if (s >= 70.0) {
                risk = 'LOW';
              } else if (s >= 50.0) {
                risk = 'MODERATE';
              } else {
                risk = 'HIGH';
              }
            } else {
              risk = 'UNKNOWN';
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSi
                            ? 'පරීක්ෂා කළේ: ${item.assessedBy}'
                            : 'Assessed by ${item.assessedBy}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  isSi ? 'නිරවද්‍යතාව: $accuracy' : 'Accuracy: $accuracy',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.body),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getRiskBadgeColor(risk).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _localizeRiskLabel(risk, isSi),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getRiskBadgeColor(risk),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // 2. EMOTIONAL WELLNESS CARD
  // ----------------------------------------------------
  Widget _buildEmotionalWellnessCard() {
    final isSi = ref.watch(languageProvider).isSinhala;
    final emo = _emotionalData;
    final hasData = emo != null && emo.hasData;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.heartHandshake, color: Color(0xFFDB2777), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi
                            ? 'මානසික සුවතා සත්කාර සැලැස්ම සහ ක්‍රියාකාරකම්'
                            : 'Emotional Care Protocol & Interventions',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? (isSi
                                ? 'සමාජ සම්බන්ධතා සහ මානසික ස්ථාවරත්වය • තත්ත්වය: ${_localizeRiskLabel(emo.status ?? 'STABLE', isSi)}'
                                : 'Social connectedness and affect stability • Status: ${emo.status ?? 'STABLE'}')
                            : (isSi
                                ? 'පෞද්ගලික ක්‍රියාකාරකම්, කියවීම, සංගීතය සහ සමාජ සම්බන්ධතා'
                                : 'Personalized activities, literature, music & social engagement'),
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (hasData && emo.riskLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRiskBadgeColor(emo.riskLevel!).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSi
                          ? _localizeRiskLabel(emo.riskLevel!, true)
                          : '${emo.riskLevel} RISK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getRiskBadgeColor(emo.riskLevel!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasData && emo.overallScore != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSi ? 'මානසික සුවතා ලකුණු' : 'Emotional Wellness Score',
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${emo.overallScore!.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSi ? 'සමාජ සම්බන්ධතා ප්‍රවණතාව' : 'Social Connection Trend',
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isSi
                                    ? _localizeTrajectory(emo.trajectory, true)
                                    : (emo.trajectory ?? 'Stable Trajectory'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Explainable AI: SHAP Feature Attribution for Loneliness & Emotional Wellness
                EmotionalShapExplanationCard(
                  riskLevel: emo?.riskLevel ?? 'LOW',
                  wellnessScore: emo?.overallScore,
                  lonelinessScore: emo?.overallScore != null ? (100.0 - emo!.overallScore!).clamp(0.0, 100.0) : null,
                  isSinhala: isSi,
                ),
                const SizedBox(height: 18),

                // Weekly Schedule & Music Therapy Routine Overview
                if (hasData) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF472B6).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDB2777),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.calendarCheck, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isSi
                                    ? 'සතිපතා මානසික සුවතා සහ සංගීත ප්‍රතිකාර කාලසටහන'
                                    : 'Weekly Emotional Wellness & Music Therapy Schedule',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF831843),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDB2777),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isSi ? 'සක්‍රීය කාලසටහන' : 'Active Routine',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildSchedulePill(
                              LucideIcons.calendar,
                              isSi ? 'සතිපතා දින' : 'Weekly Days',
                              emo.weeklyScheduleSummary,
                            ),
                            _buildSchedulePill(
                              LucideIcons.clock,
                              isSi ? 'වේලාවන්' : 'Session Times',
                              emo.scheduledTimeRange,
                            ),
                            _buildSchedulePill(
                              LucideIcons.timer,
                              isSi ? 'කාලසීමාව' : 'Duration',
                              emo.sessionDuration,
                            ),
                            _buildSchedulePill(
                              LucideIcons.checkCircle2,
                              isSi ? 'අවසන් වරට සම්පූර්ණ කළ' : 'Latest Completed',
                              '${emo.lastActivityDate} • "${emo.completedSongTitle ?? "රන්කෙන්දෙන් බැඳි අතැඟිලි"}"',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFFBCFE8)),
                        const SizedBox(height: 12),

                        // Listened / Scheduled Music Therapy Songs section
                        Row(
                          children: [
                            const Icon(LucideIcons.music, size: 15, color: Color(0xFFDB2777)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isSi
                                    ? 'සංගීත ප්‍රතිකාර සහ අසන ලද ගීත ලැයිස්තුව'
                                    : 'Music Therapy Songs & Listened Tracks (අසන ලද ගීත ලැයිස්තුව)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF831843),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF472B6)),
                              ),
                              child: Text(
                                isSi ? 'විනාඩි 10 වාර' : '10-Minute Sessions',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDB2777)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...emo.therapySongs.map((track) => _buildTherapySongRow(track)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Personalized Activities, Games, Books, Songs, Social Engagement
                if (hasData && emo.recommendations.isNotEmpty) ...[
                  Text(
                    isSi
                        ? 'පෞද්ගලික සුවතා ක්‍රියාකාරකම් සහ නිර්දේශ'
                        : 'Personalized Therapeutic Activities & Recommendations',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 10),
                  ...emo.recommendations.map((item) => _buildEmotionalRecommendationTile(item)),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(LucideIcons.heart, size: 28, color: AppColors.muted),
                        const SizedBox(height: 8),
                        Text(
                          isSi
                              ? 'මානසික සුවතා පරීක්ෂණයක් තවම නොමැත'
                              : 'No Emotional Assessment Available',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSi
                              ? 'මෙම නේවාසිකයා සඳහා සංගීතය, කියවීම සහ සමාජ ක්‍රියාකාරකම් නිර්දේශ ලබා ගැනීමට මානසික සුවතා ප්‍රශ්නාවලිය සම්පූර්ණ කරන්න.'
                              : 'Conduct an emotional wellness questionnaire to generate personalized music, literature, and social engagement recommendations for this resident.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBCFE8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFDB2777)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTherapySongRow(CarePlanMusicTrackItem track) {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: track.isListened ? const Color(0xFF86EFAC) : const Color(0xFFFBCFE8),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: track.isListened ? const Color(0xFFDCFCE7) : const Color(0xFFFCE7F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              track.isListened ? LucideIcons.disc : LucideIcons.music2,
              size: 15,
              color: track.isListened ? const Color(0xFF166534) : const Color(0xFFDB2777),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '"${track.title}"',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '• ${track.artist}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isSi
                      ? 'වර්ගය: ${track.genre} • කාලය: ${track.durationText}'
                      : 'Genre: ${track.genre} • Duration: ${track.durationText}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: track.isListened ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: track.isListened ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  track.isListened ? LucideIcons.checkCheck : LucideIcons.calendarClock,
                  size: 12,
                  color: track.isListened ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 4),
                Text(
                  track.listenedDate ??
                      (track.isListened
                          ? (isSi ? 'සවන් දී ඇත ✓' : 'Listened ✓')
                          : (isSi ? 'සැලසුම් කර ඇත' : 'Scheduled')),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: track.isListened ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _localizeEmotionalCategory(String raw, bool isSi) {
    if (!isSi) return raw;
    final low = raw.toLowerCase();
    if (low.contains('music') || low.contains('song')) return 'සංගීත ප්‍රතිකාරය';
    if (low.contains('social')) return 'සමාජ සම්බන්ධතා';
    if (low.contains('book') || low.contains('read') || low.contains('liter')) return 'කියවීම';
    if (low.contains('game') || low.contains('memory')) return 'මතක ක්‍රීඩා';
    if (low.contains('mindful') || low.contains('relax') || low.contains('breath')) return 'මනස සැහැල්ලු කිරීම';
    if (low.contains('walk') || low.contains('physical') || low.contains('exercise')) return 'ශාරීරික ක්‍රියාකාරකම්';
    if (low.contains('family') || low.contains('call')) return 'පවුලේ සම්බන්ධතා';
    return raw;
  }

  String _localizeEmotionalPriority(String raw, bool isSi) {
    if (!isSi) return raw;
    final low = raw.toLowerCase();
    if (low.contains('essential') || low.contains('high')) return 'අත්‍යවශ්‍යයි';
    if (low.contains('recommend')) return 'නිර්දේශිතයි';
    if (low.contains('optional')) return 'අමතර';
    return raw;
  }

  Widget _buildEmotionalRecommendationTile(EmotionalRecommendationItem item) {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(item.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        if (item.category.trim().toLowerCase() != item.priority.trim().toLowerCase())
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.lavenderBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _localizeEmotionalCategory(item.category, isSi),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDeep,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.priority == 'Essential'
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _localizeEmotionalPriority(item.priority, isSi),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.priority == 'Essential'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.body, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.calendar, size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    item.weeklySchedule,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.clock, size: 13, color: Color(0xFFDB2777)),
                  const SizedBox(width: 4),
                  Text(
                    '${item.scheduledTime} (${item.sessionDuration})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9D174D)),
                  ),
                ],
              ),
              if (item.lastSessionDate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.checkCheck, size: 13, color: Color(0xFF166534)),
                    const SizedBox(width: 4),
                    Text(
                      isSi ? 'අවසන් වාරය: ${item.lastSessionDate}' : 'Last: ${item.lastSessionDate}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF166534)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // 3. METABOLIC WELLNESS CARD (Strictly Honest Pending Status)
  // ----------------------------------------------------
  Widget _buildMetabolicWellnessCard() {
    final isSi = ref.watch(languageProvider).isSinhala;
    final meta = _metabolicData ?? const CarePlanMetabolicData();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.activity, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'ශරීර සෞඛ්‍ය නිරීක්ෂණ සැලැස්ම' : 'Metabolic Health Telemetry Protocol',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSi
                            ? 'ශරීර සෞඛ්‍යය, රුධිර සීනි සහ නින්දේ රටාව නිරීක්ෂණය'
                            : 'Vitals tracking, glucose regularity, and sleep rhythm',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                // Pending Integration Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.clock, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        isSi ? 'සම්බන්ධ වෙමින් පවතී' : meta.statusMessage,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Content Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.layers, size: 16, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Text(
                        isSi ? 'ශරීර සෞඛ්‍ය වාර්තා තවම නොමැත' : 'No Metabolic Assessment Available',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSi
                        ? 'ශරීර සෞඛ්‍ය උපකරණ තවම සම්බන්ධ කර නොමැති බැවින් සජීවී දත්ත පසුව යාවත්කාලීන වේ.'
                        : meta.integrationNote,
                    style: const TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isSi
                        ? '• ශරීර සෞඛ්‍යය සහ රුධිර සීනි මැනීමේ සංවේදක උපකරණ තවමත් පරීක්ෂාවේ පවතී.\n• වෛද්‍ය වාර්තාවල නිරවද්‍යතාවය රැක ගැනීමට ව්‍යාජ දත්ත කිසිවක් පෙන්වන්නේ නැත.'
                        : '• Hardware sensors for continuous vital signs and glucose monitoring are pending facility hardware validation.\n• No simulated or fabricated measurements are shown to maintain clinical record integrity.',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ERROR BANNER
  // ----------------------------------------------------
  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.riskHighBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.riskHigh.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: AppColors.riskHigh, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              isSi ? 'නැවත උත්සාහ කරන්න' : 'Retry',
              style: const TextStyle(color: AppColors.riskHigh, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SECTION 4: MEMORY GAMES PROGRESS
  // ----------------------------------------------------
  Widget _buildMemoryGamesProgressSection(CarePlanResident resident) {
    final isSi = ref.watch(languageProvider).isSinhala;
    final displayResidentName = isSi ? SinhalaNameTransliterator.toSinhala(resident.name) : resident.name;
    final progress = _memoryGameProgress;
    final totalSessions = progress?.totalCompletedSessions ?? 0;
    final sessions = progress?.sessions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.gamepad2, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSi ? 'මතක ක්‍රීඩා ප්‍රගතිය' : 'Memory Games Progress',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSi
                          ? 'මතක පුහුණු ක්‍රීඩා වාර සහ ලකුණු ප්‍රගතිය'
                          : 'Longitudinal cognitive practice sessions and game performance',
                      style: const TextStyle(fontSize: 13, color: AppColors.body),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: totalSessions > 0 ? AppColors.riskLowBg : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSi
                      ? 'වාර $totalSessions ක් සම්පූර්ණයි'
                      : '$totalSessions ${totalSessions == 1 ? 'Session' : 'Sessions'} Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: totalSessions > 0 ? AppColors.riskLow : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Non-Clinical Assessment Separation Disclaimer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSi
                        ? 'පුහුණු ක්‍රීඩා දැනුම්දීම: මතක ක්‍රීඩා යනු මනස සක්‍රීයව තබා ගැනීමේ අමතර පුහුණු ක්‍රියාකාරකම් වේ. මෙම ලකුණු මඟින් වෛද්‍ය අවදානම් මට්ටම හෝ ප්‍රතිකාර සැලසුම් වෙනස් නොවේ.'
                        : 'Practice Activity Disclaimer: Memory Games are optional cognitive practice exercises. Performance scores reflect mental recreation and do not alter clinical AI risk level, ACRF scores, or formal medical care plans.',
                    style: const TextStyle(fontSize: 12, color: AppColors.body, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Neutral Caregiver Notice if repeated decline is observed
          if (progress?.hasRepeatedDecline == true) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 20, color: Color(0xFFB45309)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSi
                              ? 'සත්කාරක නිරීක්ෂණය: ක්‍රීඩා ලකුණු වෙනස්වීමක්'
                              : 'Caregiver Observation: Noticeable Practice Variation',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSi
                              ? 'මෑත ක්‍රීඩා වාරවලදී ලකුණු සුළු වශයෙන් අඩුවීමක් පෙනේ. නේවාසිකයාට වෙහෙසක් තිබේදැයි බලා විවේකී වේලාවක නැවත පුහුණු වීමට උදව් කරන්න.'
                              : (progress?.caregiverNotice ??
                                  'A gentle decline in recent game scores has been observed across recent sessions. Consider scheduling a relaxed practice session or checking if the resident was fatigued during play.'),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Friendly Empty State when 0 sessions exist
          if (totalSessions == 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.gamepad2, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isSi ? 'සම්පූර්ණ කළ ක්‍රීඩා වාර තවම නොමැත' : 'No Completed Game Sessions Yet',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      isSi
                          ? '$displayResidentName අනුපිළිවෙල මතක තබා ගැනීම, යුගල ගැලපීම, භාණ්ඩ මතක තබා ගැනීම හෝ විනෝද චාරිකා මතක දාමය ක්‍රීඩා කළ පසු, ඔවුන්ගේ ලකුණු හා ප්‍රගතිය මෙහි පෙන්වයි.'
                          : 'When ${resident.name} plays Remember the Sequence, Matching Pairs, Remember the Items, or Shared Picnic Memory Chain, their practice accuracy, trends, and session records will be displayed here.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Orderly Caregiver Memory Condition Overview Card
            _buildCaregiverMemoryConditionCard(resident, progress!),
            const SizedBox(height: 20),

            // 1. Separate Progress Summaries for All 4 Games (3 Individual + Collaborative)
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = constraints.maxWidth < 680
                    ? constraints.maxWidth
                    : (constraints.maxWidth < 1040
                        ? (constraints.maxWidth - 16) / 2
                        : (constraints.maxWidth - 48) / 4);

                // Group sessions per game
                final seqSessions = sessions.where((s) => s.gameType == 'SEQUENCE').toList();
                final pairsSessions = sessions.where((s) => s.gameType == 'PAIRS').toList();
                final itemsSessions = sessions.where((s) => s.gameType == 'ITEMS').toList();
                final collabSessions = sessions
                    .where((s) => s.gameType.contains('COLLABORATIVE'))
                    .toList();

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildGameSummaryCard(
                      title: isSi ? 'අනුපිළිවෙල මතක තබා ගැනීම' : 'Remember the Sequence',
                      icon: LucideIcons.sparkles,
                      color: const Color(0xFF7C3AED),
                      latestScore: seqSessions.isNotEmpty ? seqSessions.first.scorePercentage : null,
                      previousScore: seqSessions.length > 1 ? seqSessions[1].scorePercentage : null,
                      totalSessions: seqSessions.length,
                      progressStatus: progress.sequenceProgress,
                      width: cardWidth,
                    ),
                    _buildGameSummaryCard(
                      title: isSi ? 'යුගල ගැලපීම' : 'Matching Pairs',
                      icon: LucideIcons.puzzle,
                      color: const Color(0xFF2563EB),
                      latestScore: pairsSessions.isNotEmpty ? pairsSessions.first.scorePercentage : null,
                      previousScore: pairsSessions.length > 1 ? pairsSessions[1].scorePercentage : null,
                      totalSessions: pairsSessions.length,
                      progressStatus: progress.pairsProgress,
                      width: cardWidth,
                    ),
                    _buildGameSummaryCard(
                      title: isSi ? 'භාණ්ඩ මතක තබා ගැනීම' : 'Remember the Items',
                      icon: LucideIcons.bookOpen,
                      color: const Color(0xFF16A34A),
                      latestScore: itemsSessions.isNotEmpty ? itemsSessions.first.scorePercentage : null,
                      previousScore: itemsSessions.length > 1 ? itemsSessions[1].scorePercentage : null,
                      totalSessions: itemsSessions.length,
                      progressStatus: progress.itemsProgress,
                      width: cardWidth,
                    ),
                    _buildGameSummaryCard(
                      title: isSi ? 'විනෝද චාරිකා මතක දාමය' : 'Shared Picnic Chain',
                      icon: LucideIcons.users,
                      color: const Color(0xFF0D9488),
                      latestScore: collabSessions.isNotEmpty ? collabSessions.first.scorePercentage : null,
                      previousScore: collabSessions.length > 1 ? collabSessions[1].scorePercentage : null,
                      totalSessions: collabSessions.length,
                      progressStatus: progress.collaborativeProgress,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 2. Simple Progress Chart (Visual score bars of recent sessions)
            _buildProgressScoreChart(sessions),
            const SizedBox(height: 24),

            // 3. Session History
            _buildSessionHistoryList(sessions),
          ],
        ],
      );
  }

  Widget _buildCaregiverMemoryConditionCard(
    CarePlanResident resident,
    MemoryGameProgressSummary progress,
  ) {
    final isSi = ref.watch(languageProvider).isSinhala;
    final displayResidentName = isSi ? SinhalaNameTransliterator.toSinhala(resident.name) : resident.name;
    final avgScore = progress.averageScore;
    final isDecline = progress.hasRepeatedDecline || (avgScore != null && avgScore < 60.0);
    final isGood = !isDecline && avgScore != null && avgScore >= 80.0;

    final String conditionTitle = isSi
        ? (isGood
            ? 'මතක තත්ත්වය: ඉතා හොඳයි'
            : (isDecline
                ? 'මතක තත්ත්වය: නිරීක්ෂණය අවශ්‍යයි'
                : 'මතක තත්ත්වය: සාමාන්‍ය (ස්ථාවරයි)'))
        : (isGood
            ? 'Memory Condition: Good (Healthy Recall)'
            : (isDecline
                ? 'Memory Condition: Needs Observation'
                : 'Memory Condition: Fair (Stable Baseline)'));

    final String conditionBadge = isSi
        ? (isGood
            ? 'හොඳ තත්ත්වය'
            : (isDecline ? 'අවධානය අවශ්‍යයි' : 'ස්ථාවර තත්ත්වය'))
        : (isGood
            ? 'Good Condition'
            : (isDecline ? 'Needs Attention' : 'Stable Condition'));

    final Color primaryColor = isGood
        ? const Color(0xFF047857)
        : (isDecline ? const Color(0xFFB45309) : const Color(0xFF1D4ED8));

    final Color bgColor = isGood
        ? const Color(0xFFF0FDF4)
        : (isDecline ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF));

    final Color borderColor = isGood
        ? const Color(0xFFA7F3D0)
        : (isDecline ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE));

    final IconData icon = isGood
        ? LucideIcons.checkCircle2
        : (isDecline ? LucideIcons.alertTriangle : LucideIcons.activity);

    final String evaluationText = isSi
        ? (isGood
            ? 'අනුපිළිවෙල මතක තබා ගැනීම, යුගල ගැලපීම, භාණ්ඩ මතක තබා ගැනීම සහ විනෝද චාරිකා මතක දාමය යන ක්‍රීඩා වාර අනුව, $displayResidentName හොඳ කෙටිකාලීන මතකයක්, රටා හඳුනාගැනීමේ හැකියාවක් සහ සමූහ මතක හැකියාවක් පෙන්වයි. මතක තත්ත්වය ඉතා හොඳ මට්ටමක පවතී.'
            : (isDecline
                ? 'මෑත මතක ක්‍රීඩා වාරවලදී ලකුණු අඩුවීමක් වාර්තා වී ඇත. නැවත පුහුණු වීමට පෙර නේවාසිකයාට වෙහෙසක්, නින්දේ වෙනසක් හෝ අවධානය බිඳීමක් තිබේදැයි සත්කාරක විසින් නිරීක්ෂණය කළ යුතුය.'
                : 'පුහුණු වාර හරහා මතක ක්‍රීඩා නිරවද්‍යතාවය සහ මතක තබා ගැනීම ස්ථාවරව පවතී. මනස සක්‍රීයව තබා ගැනීමට නිතිපතා මතක ක්‍රීඩා දිගටම කරගෙන යන්න.'))
        : (isGood
            ? 'Based on completed practice sessions across Remember the Sequence, Matching Pairs, Remember the Items, and Shared Picnic Memory Chain, ${resident.name} demonstrates strong short-term memory recall, sequence tracking, visual association, and collaborative recall. Memory function is in a good, healthy condition.'
            : (isDecline
                ? 'A downward variation in memory game scores has been recorded across recent practice sessions. The caregiver should observe whether the resident is experiencing fatigue, changes in sleep, or temporary distractions before scheduling a relaxed retry.'
                : 'Memory game accuracy and recall performance remain consistent and steady across practice rounds. Continue regular cognitive exercises to maintain active mental wellness.'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conditionTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSi
                          ? 'සත්කාරක මතක ඇගයීම • මතක ක්‍රීඩා 4ක පුහුණුව'
                          : 'Caregiver Memory Assessment • 4 Cognitive Games Practice',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      conditionBadge,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            evaluationText,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.navy,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSi ? 'සමස්ත පුහුණු නිරවද්‍යතාව: ' : 'Overall Practice Accuracy: ',
                    style: const TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                  Text(
                    avgScore != null ? '${avgScore.toStringAsFixed(1)}%' : '--',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSi ? 'පරීක්ෂා කළ වාර: ' : 'Sessions Analyzed: ',
                    style: const TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                  Text(
                    '${progress.totalCompletedSessions}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSi ? 'මතක මට්ටම: ' : 'Game Recall Tier: ',
                    style: const TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                  Text(
                    isSi
                        ? (isGood ? 'ඉතා හොඳයි' : (isDecline ? 'නිරීක්ෂණය අවශ්‍යයි' : 'සාමාන්‍යයි'))
                        : (isGood ? 'Optimal' : (isDecline ? 'Observation Needed' : 'Baseline')),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameSummaryCard({
    required String title,
    required IconData icon,
    required Color color,
    required double? latestScore,
    required double? previousScore,
    required int totalSessions,
    required String progressStatus,
    required double width,
  }) {
    final isSi = ref.watch(languageProvider).isSinhala;
    String trendText;
    Color trendBg;
    Color trendColor;

    if (latestScore == null) {
      trendText = isSi ? 'තවම ක්‍රීඩා කර නැත' : 'No Plays Yet';
      trendBg = AppColors.surfaceSecondary;
      trendColor = AppColors.muted;
    } else if (previousScore == null) {
      trendText = isSi ? 'වාර 1ක් සම්පූර්ණයි' : '1 Round Completed';
      trendBg = AppColors.lavenderBg;
      trendColor = AppColors.primary;
    } else {
      final diff = latestScore - previousScore;
      if (diff > 0) {
        trendText = isSi
            ? '+${diff.toStringAsFixed(1)}% දියුණුවක්'
            : '+${diff.toStringAsFixed(1)}% Improvement';
        trendBg = AppColors.riskLowBg;
        trendColor = AppColors.riskLow;
      } else if (diff < 0) {
        trendText = isSi
            ? '${diff.toStringAsFixed(1)}% වෙනසක්'
            : '${diff.toStringAsFixed(1)}% Variation';
        trendBg = const Color(0xFFFEF3C7);
        trendColor = const Color(0xFFB45309);
      } else {
        trendText = isSi ? 'ස්ථාවරයි (0.0%)' : 'Steady (0.0%)';
        trendBg = AppColors.lavenderBg;
        trendColor = AppColors.primary;
      }
    }

    final String recallCondition = isSi
        ? (latestScore == null
            ? 'දත්ත නැත'
            : (latestScore >= 80.0
                ? 'හොඳ මතකයක්'
                : (latestScore >= 60.0 ? 'සාමාන්‍ය මතකයක්' : 'පුහුණුව අවශ්‍යයි')))
        : (latestScore == null
            ? 'No Data'
            : (latestScore >= 80.0
                ? 'Good Recall'
                : (latestScore >= 60.0 ? 'Fair Recall' : 'Needs Practice')));
    final Color conditionColor = latestScore == null
        ? AppColors.muted
        : (latestScore >= 80.0
            ? const Color(0xFF047857)
            : (latestScore >= 60.0 ? const Color(0xFF1D4ED8) : const Color(0xFFB45309)));
    final Color conditionBg = latestScore == null
        ? AppColors.surfaceSecondary
        : (latestScore >= 80.0
            ? const Color(0xFFECFDF5)
            : (latestScore >= 60.0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7)));

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                MemoryGameService.formatScore(latestScore),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: latestScore != null ? AppColors.navy : AppColors.muted,
                ),
              ),
              const SizedBox(width: 8),
              if (previousScore != null)
                Text(
                  isSi
                      ? 'පෙර: ${MemoryGameService.formatScore(previousScore)}'
                      : 'Prev: ${MemoryGameService.formatScore(previousScore)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: conditionBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSi ? 'තත්ත්වය: $recallCondition' : 'Condition: $recallCondition',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: conditionColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trendText,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: trendColor),
                ),
              ),
              Text(
                isSi
                    ? 'වාර $totalSessions'
                    : '$totalSessions ${totalSessions == 1 ? 'play' : 'plays'}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressScoreChart(List<MemoryGameSessionRecord> sessions) {
    final isSi = ref.watch(languageProvider).isSinhala;
    final recent = sessions.take(6).toList().reversed.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.barChart2, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                isSi ? 'මෑත ප්‍රගති ප්‍රස්ථාරය' : 'Recent Performance Chart',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const Spacer(),
              Text(
                isSi ? 'වාර අනුව නිරවද්‍යතාව %' : 'Accuracy % by session',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: recent.map((s) {
              final gameName = s.gameType == 'SEQUENCE'
                  ? (isSi ? 'අනුපිළිවෙල' : 'Sequence')
                  : (s.gameType == 'PAIRS'
                      ? (isSi ? 'යුගල ගැලපීම' : 'Pairs')
                      : (s.gameType.contains('COLLABORATIVE')
                          ? (isSi ? 'මතක දාමය' : 'Picnic Chain')
                          : (isSi ? 'භාණ්ඩ මතකය' : 'Items')));
              final pct = (s.scorePercentage.clamp(0.0, 100.0)) / 100.0;
              final Color barColor = s.scorePercentage >= 80
                  ? AppColors.riskLow
                  : (s.scorePercentage >= 60 ? AppColors.primary : AppColors.riskModerate);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: isSi ? 104 : 88,
                      child: Text(
                        gameName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          minHeight: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${s.scorePercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHistoryList(List<MemoryGameSessionRecord> sessions) {
    final isSi = ref.watch(languageProvider).isSinhala;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _showSessionHistory = !_showSessionHistory;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showSessionHistory ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.history, size: 18, color: AppColors.navy),
                const SizedBox(width: 8),
                Text(
                  isSi
                      ? 'ක්‍රීඩා වාර ඉතිහාසය (${sessions.length})'
                      : 'Session History (${sessions.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showSessionHistory ? AppColors.primarySoft : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showSessionHistory
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSi
                            ? (_showSessionHistory ? 'සඟවන්න' : 'ඉතිහාසය බලන්න')
                            : (_showSessionHistory ? 'Collapse' : 'Expand History'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _showSessionHistory ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showSessionHistory ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 14,
                        color: _showSessionHistory ? AppColors.primary : AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showSessionHistory) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final s = sessions[index];
              final isCollaborative = s.gameType.contains('COLLABORATIVE');
              final gameTitle = s.gameType == 'SEQUENCE'
                  ? (isSi ? 'අනුපිළිවෙල මතක තබා ගැනීම' : 'Remember the Sequence')
                  : (s.gameType == 'PAIRS'
                      ? (isSi ? 'යුගල ගැලපීම' : 'Matching Pairs')
                      : (isCollaborative
                          ? (isSi ? 'විනෝද චාරිකා මතක දාමය' : 'Shared Picnic Memory Chain')
                          : (isSi ? 'භාණ්ඩ මතක තබා ගැනීම' : 'Remember the Items')));
              final dateStr = s.completedAt != null
                  ? _formatDate(s.completedAt!.toIso8601String())
                  : (isSi ? 'මෑත වාරය' : 'Recent session');

              String metrics;
              if (s.gameType == 'SEQUENCE') {
                metrics = isSi
                    ? 'මට්ටම: කොටු ${s.totalItems} • උත්සාහ: ${s.attempts} • නිවැරදි: ${s.correctAnswers}'
                    : 'Level: ${s.totalItems} Tiles • Attempts: ${s.attempts} • Correct: ${s.correctAnswers}';
              } else if (s.gameType == 'PAIRS') {
                metrics = isSi
                    ? 'වාර: ${s.attempts} • සොයාගත් යුගල: ${s.correctAnswers} / ${s.totalItems}'
                    : 'Turns Taken: ${s.attempts} • Pairs Found: ${s.correctAnswers} / ${s.totalItems}';
              } else if (isCollaborative) {
                metrics = isSi
                    ? 'සමූහ දාමය: භාණ්ඩ ${s.totalItems} • මතක තබා ගත්: ${s.correctAnswers} • උත්සාහ: ${s.attempts}'
                    : 'Collaborative Chain: ${s.totalItems} Items • Recalled: ${s.correctAnswers} • Team Attempts: ${s.attempts}';
              } else {
                metrics = isSi
                    ? 'උත්සාහ: ${s.attempts} • මතක තබා ගත්: ${s.correctAnswers} / ${s.totalItems}'
                    : 'Attempts: ${s.attempts} • Recalled: ${s.correctAnswers} / ${s.totalItems} Items';
              }

              final statusText = isSi
                  ? (s.status.toUpperCase() == 'COMPLETED' ? 'සම්පූර්ණයි' : s.status)
                  : s.status;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isCollaborative
                          ? const Color(0xFFCCFBF1)
                          : AppColors.primarySoft,
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCollaborative
                              ? const Color(0xFF0F766E)
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                gameTitle,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                              ),
                              if (isCollaborative)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF99F6E4)),
                                  ),
                                  child: Text(
                                    isSi ? 'සමූහ ක්‍රීඩාව' : 'COLLABORATIVE',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusText,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.muted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            metrics,
                            style: const TextStyle(fontSize: 12, color: AppColors.body),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: s.scorePercentage >= 80
                                ? AppColors.riskLowBg
                                : (s.scorePercentage >= 60 ? AppColors.lavenderBg : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${s.scorePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: s.scorePercentage >= 80
                                  ? AppColors.riskLow
                                  : (s.scorePercentage >= 60 ? AppColors.primary : const Color(0xFFB45309)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        ],
      ],
    );
  }

  // ----------------------------------------------------
  // HELPERS
  // ----------------------------------------------------
  Color _getRiskBadgeColor(String risk) {
    final norm = risk.toUpperCase();
    if (norm.contains('LOW')) return AppColors.riskLow;
    if (norm.contains('MODERATE')) return AppColors.riskModerate;
    if (norm.contains('HIGH')) return AppColors.riskHigh;
    return AppColors.muted;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final parsed = DateTime.parse(raw).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final m = months[parsed.month - 1];
      final day = parsed.day.toString().padLeft(2, '0');
      final year = parsed.year;
      final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
      final min = parsed.minute.toString().padLeft(2, '0');
      final amPm = parsed.hour >= 12 ? 'PM' : 'AM';
      return '$day $m $year, $hour12:$min $amPm';
    } catch (_) {
      return raw;
    }
  }
}

/// Smooth, staggered floating + hover-lift wrapper for Care Plans resident cards.
class _FloatingCarePlanCardWrapper extends StatefulWidget {
  final int index;
  final Color glowColor;
  final Widget child;

  const _FloatingCarePlanCardWrapper({
    super.key,
    required this.index,
    required this.glowColor,
    required this.child,
  });

  @override
  State<_FloatingCarePlanCardWrapper> createState() =>
      _FloatingCarePlanCardWrapperState();
}

class _FloatingCarePlanCardWrapperState
    extends State<_FloatingCarePlanCardWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    final durationMs = 3500 + (widget.index % 3) * 460;
    _floatCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.index * 0.95;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 280 + (widget.index % 6) * 55),
          curve: Curves.easeOutCubic,
          builder: (context, entrance, child) {
            return Opacity(
              opacity: entrance.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1.0 - entrance) * 14.0),
                child: child,
              ),
            );
          },
          child: AnimatedBuilder(
            animation: _floatCtrl,
            builder: (context, child) {
              final wave = math.sin(_floatCtrl.value * 2 * math.pi + phase);
              final floatY = _isHovered ? 0.0 : wave * 4.5;
              return Transform.translate(
                offset: Offset(0, floatY),
                child: child,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _isHovered ? -7.0 : 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.glowColor.withValues(alpha: 0.24),
                          blurRadius: 24,
                          spreadRadius: 1,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: widget.glowColor.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Unique Care Plans ambient animation:
/// Botanical healing leaves, rotating dotted care-compass arcs,
/// soft watercolor corner mists, and floating wellness crosses.
class _CarePlansAmbientBackdrop extends StatefulWidget {
  final bool isForeground;

  const _CarePlansAmbientBackdrop({this.isForeground = false});

  @override
  State<_CarePlansAmbientBackdrop> createState() =>
      _CarePlansAmbientBackdropState();
}

class _CarePlansAmbientBackdropState extends State<_CarePlansAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
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
            painter: _CarePlansAmbientPainter(
              t: _controller.value,
              isForeground: widget.isForeground,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CarePlansAmbientPainter extends CustomPainter {
  final double t;
  final bool isForeground;

  const _CarePlansAmbientPainter({
    required this.t,
    this.isForeground = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final double angle = t * 2 * math.pi;

    if (!isForeground) {
      // Background layer: Botanical emerald-mint, sky, violet & warm peach watercolor mists
      _drawMist(
        canvas,
        Offset(
          size.width * 0.05 + math.sin(angle) * 26,
          size.height * 0.16 + math.cos(angle * 0.8) * 20,
        ),
        220,
        const Color(0xFF10B981).withValues(alpha: 0.11),
      );
      _drawMist(
        canvas,
        Offset(
          size.width * 0.95 + math.cos(angle * 0.9) * 26,
          size.height * 0.20 + math.sin(angle) * 22,
        ),
        225,
        const Color(0xFF6366F1).withValues(alpha: 0.10),
      );
      _drawMist(
        canvas,
        Offset(
          size.width * 0.07 + math.cos(angle * 0.7) * 24,
          size.height * 0.85 + math.sin(angle * 0.9) * 22,
        ),
        220,
        const Color(0xFF0EA5E9).withValues(alpha: 0.10),
      );
      _drawMist(
        canvas,
        Offset(
          size.width * 0.94 + math.sin(angle * 0.85) * 24,
          size.height * 0.84 + math.cos(angle) * 24,
        ),
        230,
        const Color(0xFFF59E0B).withValues(alpha: 0.09),
      );

      // Rotating dotted care-compass rings framing the left & right edges
      _drawCareCompassRing(
        canvas,
        Offset(16, size.height * 0.30),
        46,
        angle,
        const Color(0xFF0D9488).withValues(alpha: 0.22),
      );
      _drawCareCompassRing(
        canvas,
        Offset(size.width - 16, size.height * 0.68),
        52,
        -angle * 0.85,
        const Color(0xFF6366F1).withValues(alpha: 0.20),
      );
      _drawCareCompassRing(
        canvas,
        Offset(22, size.height * 0.76),
        34,
        -angle * 1.2,
        const Color(0xFFEC4899).withValues(alpha: 0.18),
      );
      return;
    }

    // Foreground translucent layer: drifting botanical healing leaves & soft wellness pluses
    const leaves = [
      (0.025, 0.10, 0.00, 1.0, Color(0xFF10B981)),
      (0.975, 0.22, 0.20, 0.95, Color(0xFF0D9488)),
      (0.180, 0.35, 0.38, 0.82, Color(0xFF6366F1)),
      (0.840, 0.48, 0.56, 0.88, Color(0xFF14B8A6)),
      (0.030, 0.64, 0.72, 0.92, Color(0xFF8B5CF6)),
      (0.968, 0.78, 0.86, 1.0, Color(0xFF10B981)),
      (0.460, 0.16, 0.14, 0.76, Color(0xFF0EA5E9)),
      (0.640, 0.86, 0.44, 0.80, Color(0xFF10B981)),
    ];

    for (final lf in leaves) {
      final (rx, startY, shift, scale, color) = lf;
      final lt = (t + shift) % 1.0;
      final yPos = ((startY + lt * 0.50) % 1.0);
      final swayX = math.sin(lt * 2 * math.pi + rx * 7.0) * 18.0;
      final rot = math.sin(lt * 2 * math.pi + rx * 4.0) * 0.75 + 0.4;
      final edgeFade = (yPos < 0.08)
          ? (yPos / 0.08)
          : (yPos > 0.92 ? ((1.0 - yPos) / 0.08) : 1.0);
      _drawHealingLeaf(
        canvas,
        Offset(size.width * rx + swayX, size.height * yPos),
        10.5 * scale,
        rot,
        color.withValues(alpha: 0.24 * edgeFade),
      );
    }

    // Soft rising wellness plus / checklist diamond accents
    const badges = [
      (0.018, 0.42, 0.10, Color(0xFF0D9488), true),
      (0.982, 0.36, 0.32, Color(0xFF6366F1), false),
      (0.280, 0.82, 0.54, Color(0xFFEC4899), true),
      (0.740, 0.24, 0.76, Color(0xFFF59E0B), false),
      (0.022, 0.88, 0.66, Color(0xFF0EA5E9), false),
      (0.978, 0.58, 0.88, Color(0xFF10B981), true),
    ];

    for (final b in badges) {
      final (rx, startY, shift, color, isCross) = b;
      final lt = (t + shift) % 1.0;
      final yPos = ((startY - lt * 0.35) % 1.0 + 1.0) % 1.0;
      final sway = math.cos(lt * 2 * math.pi + rx * 5.0) * 12.0;
      final pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(lt * 4 * math.pi));
      final edgeFade = (yPos < 0.08)
          ? (yPos / 0.08)
          : (yPos > 0.92 ? ((1.0 - yPos) / 0.08) : 1.0);
      final c = Offset(size.width * rx + sway, size.height * yPos);
      final col = color.withValues(alpha: (0.18 + pulse * 0.18) * edgeFade);

      if (isCross) {
        final p = Paint()
          ..color = col
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        final arm = 5.0 + pulse * 2.0;
        canvas.drawLine(Offset(c.dx - arm, c.dy), Offset(c.dx + arm, c.dy), p);
        canvas.drawLine(Offset(c.dx, c.dy - arm), Offset(c.dx, c.dy + arm), p);
      } else {
        final r = 5.5 + pulse * 2.5;
        final diamond = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
        canvas.drawPath(
          diamond,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = col,
        );
      }
    }
  }

  void _drawMist(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawCareCompassRing(
    Canvas canvas,
    Offset center,
    double radius,
    double rot,
    Color color,
  ) {
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;

    final rect = Rect.fromCircle(center: center, radius: radius);
    const segments = 6;
    const sweep = (2 * math.pi / segments) * 0.55;
    for (int i = 0; i < segments; i++) {
      final start = rot + i * (2 * math.pi / segments);
      canvas.drawArc(rect, start, sweep, false, arcPaint);
    }

    // Inner subtle ring
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withValues(alpha: color.a * 0.6),
    );
  }

  void _drawHealingLeaf(
    Canvas canvas,
    Offset center,
    double size,
    double rotation,
    Color color,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final leaf = Path()
      ..moveTo(0, -size)
      ..quadraticBezierTo(size * 0.95, -size * 0.15, 0, size)
      ..quadraticBezierTo(-size * 0.95, -size * 0.15, 0, -size)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color);

    // Delicate center vein
    canvas.drawLine(
      Offset(0, -size * 0.72),
      Offset(0, size * 0.72),
      Paint()
        ..color = Colors.white.withValues(alpha: color.a * 1.1)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarePlansAmbientPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.isForeground != isForeground;
  }
}
