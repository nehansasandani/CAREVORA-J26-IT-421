import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/carevora_avatar.dart';
import '../../assessment/application/care_plans_service.dart';
import '../../assessment/application/cognitive_assessment_service.dart';
import '../../assessment/application/memory_game_service.dart';
import '../../auth/application/auth_controller.dart';

class CarePlansPage extends ConsumerStatefulWidget {
  final int? initialResidentId;

  const CarePlansPage({super.key, this.initialResidentId});

  @override
  ConsumerState<CarePlansPage> createState() => _CarePlansPageState();
}

class _CarePlansPageState extends ConsumerState<CarePlansPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
          await _selectResident(target);
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

  Future<void> _selectResident(CarePlanResident resident) async {
    setState(() {
      _selectedResident = resident;
      _selectedDomainIndex = 0;
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).state;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(auth),
            const SizedBox(height: 20),

            // If not an Elder, render the Search UI
            if (!auth.isElder) ...[
              _buildSearchBar(),
              const SizedBox(height: 20),
            ],

            // Content body: either Search Results, Empty State, or Selected Resident Care Plan
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
            ] else if (_searchQuery.trim().isEmpty) ...[
              _buildEmptySearchPrompt(auth),
            ] else ...[
              _buildSearchResultsList(),
            ],
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // HEADER
  // ----------------------------------------------------
  Widget _buildHeader(AuthState auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.clipboardList, size: 28, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Care Plans Management',
                      style: AppTextStyles.h2.copyWith(fontSize: 22, color: AppColors.navy),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        'Multimodal Clinical Guidance',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  auth.isElder
                      ? 'Your personalized holistic wellness plan and daily care recommendations.'
                      : 'Search any resident by name or resident ID to view structured, risk-based care plans across Cognitive, Emotional, and Metabolic wellness domains.',
                  style: const TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SEARCH BAR (Consistent with Resident Directory UI)
  // ----------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lilac),
            ),
            child: const Center(
              child: Text('🔍', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
              decoration: const InputDecoration(
                hintText: 'Search residents by name or resident ID...  📋',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18, color: AppColors.muted),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              tooltip: 'Clear search',
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF4F0FF), Color(0xFFEDE9FE)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lilac.withValues(alpha: 0.8)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📋', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 5),
                  Text(
                    'Care Plans',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDeep,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // EMPTY SEARCH PROMPT
  // ----------------------------------------------------
  Widget _buildEmptySearchPrompt(AuthState auth) {
    final facilityName = auth.elderHomeName ?? 'Your Facility';
    final count = _allResidents.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('📋', style: TextStyle(fontSize: 40)),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.lilac, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🔍', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              Positioned(
                left: -6,
                top: -2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.lilac, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('✨', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Search to Select a Resident',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(width: 6),
              Text('✨', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const Text(
              'Type a resident name or resident ID above to review their latest assessment results and personalized Care Plans.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildCarePlanPill('🧠', 'Cognitive Wellness', const Color(0xFFEEF2FF), const Color(0xFF4338CA)),
              _buildCarePlanPill('💖', 'Emotional State', const Color(0xFFFFF1F2), const Color(0xFFBE123C)),
              _buildCarePlanPill('🥗', 'Metabolic Care', const Color(0xFFECFDF5), const Color(0xFF047857)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.lavenderBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.lilac),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '$facilityName ($count residents available)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💡', style: TextStyle(fontSize: 13)),
              SizedBox(width: 6),
              Text(
                'Tip: Search by resident name or assigned room number',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarePlanPill(String emoji, String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SEARCH RESULTS LIST
  // ----------------------------------------------------
  Widget _buildSearchResultsList() {
    final q = _searchQuery.trim().toLowerCase();
    final matches = _allResidents.where((r) {
      final nameMatch = r.name.toLowerCase().contains(q);
      final idMatch = r.id.toString() == q;
      final roomMatch = r.roomNumber.toLowerCase().contains(q);
      return nameMatch || idMatch || roomMatch;
    }).toList();

    if (matches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Center(
                child: Text('🧐', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No residents found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                SizedBox(width: 6),
                Text('🔍', style: TextStyle(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'No resident matches "$_searchQuery". Please check the spelling or resident ID.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Matching Residents (${matches.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.muted),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final r = matches[index];
              return InkWell(
                onTap: () => _selectResident(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      CarevoraAvatar(
                        avatarUrl: r.avatarUrl,
                        radius: 20,
                        initials: r.name,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.lavenderBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ID: #${r.id}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.roomNumber} • ${r.elderHomeName}${r.age != null ? ' • Age ${r.age}' : ''}${r.educationYears != null ? ' • Edu: ${r.educationYears} yrs' : ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.body),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
                    ],
                  ),
                ),
              );
            },
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resident Profile Header Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
          child: Row(
            children: [
              CarevoraAvatar(
                avatarUrl: resident.avatarUrl ?? (auth.isElder ? auth.avatarUrl : null),
                radius: 26,
                initials: resident.name,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          resident.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.lavenderBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ID: #${resident.id}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${resident.roomNumber} • ${resident.elderHomeName}${resident.age != null ? ' • Age ${resident.age}' : ''}${resident.educationYears != null ? ' • Education: ${resident.educationYears} yrs' : ''}${resident.gender != null ? ' • ${resident.gender}' : ''}',
                      style: const TextStyle(fontSize: 13, color: AppColors.body),
                    ),
                  ],
                ),
              ),
              if (!auth.isElder)
                OutlinedButton.icon(
                  onPressed: _clearSelectedResident,
                  icon: const Icon(LucideIcons.userCheck, size: 16),
                  label: const Text('Change Resident'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primarySoft, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
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
    final isSelected = _selectedDomainIndex == 0;
    final cog = _cognitiveData;
    final hasCog = cog != null && cog.hasAssessment;
    final rec = cog?.recommendation;
    final accuracyStr = hasCog ? CarePlansService.formatTaskAccuracyScore(cog.taskAccuracyScore) : null;
    final dateStr = hasCog ? _formatDate(cog.assessmentDate) : null;

    final badgeLabel = hasCog && rec != null ? rec.categoryLabel : 'AWAITING EVAL';
    final badgeBg = hasCog && rec != null ? rec.badgeBg : const Color(0xFFF3F4F6);
    final badgeColor = hasCog && rec != null ? rec.badgeColor : AppColors.muted;

    return _buildDomainCardContainer(
      index: 0,
      isSelected: isSelected,
      accentColor: AppColors.primary,
      selectedBgColor: const Color(0xFFFAF7FF),
      iconBgColor: AppColors.primarySoft,
      iconColor: AppColors.primary,
      icon: LucideIcons.brain,
      title: 'Cognitive Wellness',
      badgeLabel: badgeLabel,
      badgeBg: badgeBg,
      badgeColor: badgeColor,
      subtitle: hasCog
          ? 'Task Accuracy: $accuracyStr • $dateStr'
          : 'Baseline clinical assessment pending',
      tagText: 'Practice & Memory Games',
    );
  }

  Widget _buildEmotionalDomainCard() {
    final isSelected = _selectedDomainIndex == 1;
    final emo = _emotionalData;
    final hasEmo = emo != null && emo.hasData;

    final String badgeLabel;
    final Color badgeBg;
    final Color badgeColor;

    if (hasEmo && emo.riskLevel != null) {
      badgeLabel = '${emo.riskLevel} RISK';
      badgeColor = _getRiskBadgeColor(emo.riskLevel!);
      badgeBg = badgeColor.withValues(alpha: 0.12);
    } else {
      badgeLabel = 'STABLE';
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
    }

    return _buildDomainCardContainer(
      index: 1,
      isSelected: isSelected,
      accentColor: const Color(0xFFDB2777),
      selectedBgColor: const Color(0xFFFDF2F8),
      iconBgColor: const Color(0xFFFCE7F3),
      iconColor: const Color(0xFFDB2777),
      icon: LucideIcons.heartHandshake,
      title: 'Emotional Wellness',
      badgeLabel: badgeLabel,
      badgeBg: badgeBg,
      badgeColor: badgeColor,
      subtitle: hasEmo && emo.socialScore != null
          ? 'Social Score: ${emo.socialScore!.toStringAsFixed(0)}% • ${emo.trajectory ?? 'Stable'}'
          : 'Social connectedness & affect monitoring',
      tagText: 'Music & Activity Plans',
    );
  }

  Widget _buildMetabolicDomainCard() {
    final isSelected = _selectedDomainIndex == 2;

    return _buildDomainCardContainer(
      index: 2,
      isSelected: isSelected,
      accentColor: const Color(0xFFD97706),
      selectedBgColor: const Color(0xFFFFFBEB),
      iconBgColor: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFD97706),
      icon: LucideIcons.activity,
      title: 'Metabolic Wellness',
      badgeLabel: 'Sync Pending',
      badgeBg: const Color(0xFFFEF3C7),
      badgeColor: const Color(0xFFD97706),
      subtitle: 'Vitals tracking, glucose & sleep telemetry',
      tagText: 'Non-invasive Sync',
    );
  }

  Widget _buildDomainCardContainer({
    required int index,
    required bool isSelected,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tagText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.body,
                      ),
                    ),
                  ),
                  const Spacer(),
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
                            'Active View',
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
                      children: const [
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(LucideIcons.arrowRight, size: 12, color: AppColors.muted),
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
    final String domainName;
    final Color domainColor;
    final IconData domainIcon;

    if (_selectedDomainIndex == 0) {
      domainName = 'Cognitive Clinical Protocol & Care Plan';
      domainColor = AppColors.primary;
      domainIcon = LucideIcons.brain;
    } else if (_selectedDomainIndex == 1) {
      domainName = 'Emotional Care Protocol & Interventions';
      domainColor = const Color(0xFFDB2777);
      domainIcon = LucideIcons.heartHandshake;
    } else {
      domainName = 'Metabolic Health Telemetry Protocol';
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
              'Active Focus: $domainName',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: domainColor,
              ),
            ),
          ),
          const Text(
            'Click cards above to switch',
            style: TextStyle(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(LucideIcons.info, size: 18, color: Color(0xFF2563EB)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Caregiver Guidance Notice: Care plan recommendations provided below are supportive wellness suggestions and non-pharmacological interventions. They are not diagnoses or medical prescriptions. Consult the attending physician or clinical lead before modifying clinical protocols.',
              style: TextStyle(
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
    final cog = _cognitiveData;
    if (cog == null || !cog.hasAssessment) {
      return _buildEmptyCognitiveCard(resident);
    }

    final latest = cog.latestAssessment!;
    final rec = cog.recommendation;
    final accuracyStr = CarePlansService.formatTaskAccuracyScore(cog.taskAccuracyScore);
    final dateStr = _formatDate(cog.assessmentDate);
    final priorRecords = _getPriorRecords(cog);

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
                      const Text(
                        'Cognitive Clinical Protocol & Care Plan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Latest Assessment: $dateStr',
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
                        rec.categoryLabel,
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
                            const Row(
                              children: [
                                Icon(LucideIcons.target, size: 14, color: AppColors.muted),
                                SizedBox(width: 6),
                                Text(
                                  'Task Accuracy Score',
                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
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
                                  ? 'High task execution accuracy'
                                  : 'Moderate or partial task execution',
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
                                const Text(
                                  'Actual AI-Predicted Risk',
                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rec.categoryLabel,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: rec.badgeColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cog.mlAvailable
                                  ? '31-feature ML model prediction'
                                  : (cog.actualRiskLevel != null
                                      ? 'Score-based clinical risk tier'
                                      : 'Model prediction unavailable'),
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
                        const Text(
                          'Memory Games Status: ',
                          style: TextStyle(
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
                                ? 'Good Condition'
                                : (_memoryGameProgress!.hasRepeatedDecline
                                    ? 'Needs Observation'
                                    : 'Stable Condition'),
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
                          '${_memoryGameProgress!.totalCompletedSessions} sessions (${_memoryGameProgress!.averageScore?.toStringAsFixed(1) ?? "--"}% avg)',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Sub-Domain Accuracy Bar
                _buildDomainScoresRow(latest),
                const SizedBox(height: 20),

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
                          Text(
                            rec.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: rec.badgeColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rec.summary,
                        style: const TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Caregiver Action Protocol:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...rec.actionItems.map(
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
                            'Previous Assessment History (${priorRecords.length} prior records)',
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
                const Text(
                  'No Cognitive Assessment Recorded',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This resident has not completed a cognitive evaluation yet. Start an assessment to generate risk-based care plans.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/dashboard/assessment'),
                  icon: const Icon(LucideIcons.play, size: 16),
                  label: const Text('Start Cognitive Assessment'),
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
          const Text(
            'Cognitive Domain Scores',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDomainScoreItem('Orientation', result.orientation)),
              Expanded(child: _buildDomainScoreItem('Memory', result.memory)),
              Expanded(child: _buildDomainScoreItem('Attention', result.attention)),
              Expanded(child: _buildDomainScoreItem('Recall', result.recall)),
              Expanded(child: _buildDomainScoreItem('Reasoning', result.reasoning)),
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
                        'Assessed by ${item.assessedBy}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Accuracy: $accuracy',
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
                    risk,
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
                      const Text(
                        'Emotional Care Protocol & Interventions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? 'Social connectedness and affect stability • Status: ${emo.status ?? 'STABLE'}'
                            : 'Personalized activities, literature, music & social engagement',
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
                      '${emo.riskLevel} RISK',
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
                              const Text('Emotional Wellness Score', style: TextStyle(fontSize: 11, color: AppColors.muted)),
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
                              const Text('Social Connection Trend', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              const SizedBox(height: 6),
                              Text(
                                emo.trajectory ?? 'Stable Trajectory',
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

                // Personalized Activities, Games, Books, Songs, Social Engagement
                if (hasData && emo.recommendations.isNotEmpty) ...[
                  const Text(
                    'Personalized Therapeutic Activities & Recommendations',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
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
                      children: const [
                        Icon(LucideIcons.heart, size: 28, color: AppColors.muted),
                        SizedBox(height: 8),
                        Text(
                          'No Emotional Assessment Available',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Conduct an emotional wellness questionnaire to generate personalized music, literature, and social engagement recommendations for this resident.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
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

  Widget _buildEmotionalRecommendationTile(EmotionalRecommendationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDeep,
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
    );
  }

  // ----------------------------------------------------
  // 3. METABOLIC WELLNESS CARD (Strictly Honest Pending Status)
  // ----------------------------------------------------
  Widget _buildMetabolicWellnessCard() {
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metabolic Health Telemetry Protocol',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Vitals tracking, glucose regularity, and sleep rhythm',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
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
                        meta.statusMessage,
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
                    children: const [
                      Icon(LucideIcons.layers, size: 16, color: AppColors.muted),
                      SizedBox(width: 8),
                      Text(
                        'No Metabolic Assessment Available',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta.integrationNote,
                    style: const TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Hardware sensors for continuous vital signs and glucose monitoring are pending facility hardware validation.\n• No simulated or fabricated measurements are shown to maintain clinical record integrity.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
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
            child: const Text('Retry', style: TextStyle(color: AppColors.riskHigh, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SECTION 4: MEMORY GAMES PROGRESS
  // ----------------------------------------------------
  Widget _buildMemoryGamesProgressSection(CarePlanResident resident) {
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
                      'Memory Games Progress',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Longitudinal cognitive practice sessions and game performance',
                      style: TextStyle(fontSize: 13, color: AppColors.body),
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
                  '$totalSessions ${totalSessions == 1 ? 'Session' : 'Sessions'} Completed',
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
              children: const [
                Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Practice Activity Disclaimer: Memory Games are optional cognitive practice exercises. Performance scores reflect mental recreation and do not alter clinical AI risk level, ACRF scores, or formal medical care plans.',
                    style: TextStyle(fontSize: 12, color: AppColors.body, height: 1.35),
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
                        const Text(
                          'Caregiver Observation: Noticeable Practice Variation',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          progress?.caregiverNotice ??
                              'A gentle decline in recent game scores has been observed across recent sessions. Consider scheduling a relaxed practice session or checking if the resident was fatigued during play.',
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
                  const Text(
                    'No Completed Game Sessions Yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      'When ${resident.name} plays Remember the Sequence, Matching Pairs, or Remember the Items, their practice accuracy, trends, and session records will be displayed here.',
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

            // 1. Separate Progress Summaries for All 3 Games
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = constraints.maxWidth < 680
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 32) / 3;

                // Group sessions per game
                final seqSessions = sessions.where((s) => s.gameType == 'SEQUENCE').toList();
                final pairsSessions = sessions.where((s) => s.gameType == 'PAIRS').toList();
                final itemsSessions = sessions.where((s) => s.gameType == 'ITEMS').toList();

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildGameSummaryCard(
                      title: 'Remember the Sequence',
                      icon: LucideIcons.sparkles,
                      color: const Color(0xFF7C3AED),
                      latestScore: seqSessions.isNotEmpty ? seqSessions.first.scorePercentage : null,
                      previousScore: seqSessions.length > 1 ? seqSessions[1].scorePercentage : null,
                      totalSessions: seqSessions.length,
                      progressStatus: progress.sequenceProgress,
                      width: cardWidth,
                    ),
                    _buildGameSummaryCard(
                      title: 'Matching Pairs',
                      icon: LucideIcons.puzzle,
                      color: const Color(0xFF2563EB),
                      latestScore: pairsSessions.isNotEmpty ? pairsSessions.first.scorePercentage : null,
                      previousScore: pairsSessions.length > 1 ? pairsSessions[1].scorePercentage : null,
                      totalSessions: pairsSessions.length,
                      progressStatus: progress.pairsProgress,
                      width: cardWidth,
                    ),
                    _buildGameSummaryCard(
                      title: 'Remember the Items',
                      icon: LucideIcons.bookOpen,
                      color: const Color(0xFF16A34A),
                      latestScore: itemsSessions.isNotEmpty ? itemsSessions.first.scorePercentage : null,
                      previousScore: itemsSessions.length > 1 ? itemsSessions[1].scorePercentage : null,
                      totalSessions: itemsSessions.length,
                      progressStatus: progress.itemsProgress,
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
    final avgScore = progress.averageScore;
    final isDecline = progress.hasRepeatedDecline || (avgScore != null && avgScore < 60.0);
    final isGood = !isDecline && avgScore != null && avgScore >= 80.0;

    final String conditionTitle = isGood
        ? 'Memory Condition: Good (Healthy Recall)'
        : (isDecline
            ? 'Memory Condition: Needs Observation'
            : 'Memory Condition: Fair (Stable Baseline)');

    final String conditionBadge = isGood
        ? 'Good Condition'
        : (isDecline ? 'Needs Attention' : 'Stable Condition');

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

    final String evaluationText = isGood
        ? 'Based on completed practice sessions across Remember the Sequence, Matching Pairs, and Remember the Items, ${resident.name} demonstrates strong short-term memory recall, sequence tracking, and visual association. Memory function is in a good, healthy condition.'
        : (isDecline
            ? 'A downward variation in memory game scores has been recorded across recent practice sessions. The caregiver should observe whether the resident is experiencing fatigue, changes in sleep, or temporary distractions before scheduling a relaxed retry.'
            : 'Memory game accuracy and recall performance remain consistent and steady across practice rounds. Continue regular cognitive exercises to maintain active mental wellness.');

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
                      'Caregiver Memory Assessment • 3 Cognitive Games Practice',
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
                  const Text(
                    'Overall Practice Accuracy: ',
                    style: TextStyle(fontSize: 12, color: AppColors.body),
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
                  const Text(
                    'Sessions Analyzed: ',
                    style: TextStyle(fontSize: 12, color: AppColors.body),
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
                  const Text(
                    'Game Recall Tier: ',
                    style: TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                  Text(
                    isGood ? 'Optimal' : (isDecline ? 'Observation Needed' : 'Baseline'),
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
    String trendText;
    Color trendBg;
    Color trendColor;

    if (latestScore == null) {
      trendText = 'No Plays Yet';
      trendBg = AppColors.surfaceSecondary;
      trendColor = AppColors.muted;
    } else if (previousScore == null) {
      trendText = '1 Round Completed';
      trendBg = AppColors.lavenderBg;
      trendColor = AppColors.primary;
    } else {
      final diff = latestScore - previousScore;
      if (diff > 0) {
        trendText = '+${diff.toStringAsFixed(1)}% Improvement';
        trendBg = AppColors.riskLowBg;
        trendColor = AppColors.riskLow;
      } else if (diff < 0) {
        trendText = '${diff.toStringAsFixed(1)}% Variation';
        trendBg = const Color(0xFFFEF3C7);
        trendColor = const Color(0xFFB45309);
      } else {
        trendText = 'Steady (0.0%)';
        trendBg = AppColors.lavenderBg;
        trendColor = AppColors.primary;
      }
    }

    final String recallCondition = latestScore == null
        ? 'No Data'
        : (latestScore >= 80.0
            ? 'Good Recall'
            : (latestScore >= 60.0 ? 'Fair Recall' : 'Needs Practice'));
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
                  'Prev: ${MemoryGameService.formatScore(previousScore)}',
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
                  'Condition: $recallCondition',
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
                '$totalSessions ${totalSessions == 1 ? 'play' : 'plays'}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressScoreChart(List<MemoryGameSessionRecord> sessions) {
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
            children: const [
              Icon(LucideIcons.barChart2, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Recent Performance Chart',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              Spacer(),
              Text(
                'Accuracy % by session',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: recent.map((s) {
              final gameName = s.gameType == 'SEQUENCE'
                  ? 'Sequence'
                  : (s.gameType == 'PAIRS' ? 'Pairs' : 'Items');
              final pct = (s.scorePercentage.clamp(0.0, 100.0)) / 100.0;
              final Color barColor = s.scorePercentage >= 80
                  ? AppColors.riskLow
                  : (s.scorePercentage >= 60 ? AppColors.primary : AppColors.riskModerate);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 75,
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
                  'Session History (${sessions.length})',
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
                        _showSessionHistory ? 'Collapse' : 'Expand History',
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
              final gameTitle = s.gameType == 'SEQUENCE'
                  ? 'Remember the Sequence'
                  : (s.gameType == 'PAIRS' ? 'Matching Pairs' : 'Remember the Items');
              final dateStr = s.completedAt != null
                  ? _formatDate(s.completedAt!.toIso8601String())
                  : 'Recent session';

              String metrics;
              if (s.gameType == 'SEQUENCE') {
                metrics = 'Level: ${s.totalItems} Tiles • Attempts: ${s.attempts} • Correct: ${s.correctAnswers}';
              } else if (s.gameType == 'PAIRS') {
                metrics = 'Turns Taken: ${s.attempts} • Pairs Found: ${s.correctAnswers} / ${s.totalItems}';
              } else {
                metrics = 'Attempts: ${s.attempts} • Recalled: ${s.correctAnswers} / ${s.totalItems} Items';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                gameTitle,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s.status,
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
