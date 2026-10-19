import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/carevora_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../assessment/application/cognitive_assessment_service.dart';
import '../../assessment/application/memory_game_service.dart';
import '../../assessment/domain/cognitive_scoring.dart';

class ResidentItem {
  final int id;
  final String name;
  final int age;
  final String gender;
  final String roomNo;
  final String elderHomeName;
  final int elderHomeId;
  final String? avatarUrl;
  final int? educationYears;
  final double? cognitiveScore;
  final double? emotionalScore;
  final double? metabolicScore;
  final double riskScore;
  final String caregiverName;
  final String? lastAssessmentDate;
  final String? currentStatus;
  final String? riskLevel;

  const ResidentItem({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.roomNo,
    required this.elderHomeName,
    required this.elderHomeId,
    this.avatarUrl,
    this.educationYears,
    this.cognitiveScore,
    this.emotionalScore,
    this.metabolicScore,
    required this.riskScore,
    required this.caregiverName,
    this.lastAssessmentDate,
    this.currentStatus,
    this.riskLevel,
  });
}

class UserDirectoryItem {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? elderHomeName;
  final String? avatarUrl;
  final int? age;
  final int? educationYears;
  final String? roomNumber;

  const UserDirectoryItem({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.elderHomeName,
    this.avatarUrl,
    this.age,
    this.educationYears,
    this.roomNumber,
  });
}

class ResidentDirectoryPage extends ConsumerStatefulWidget {
  const ResidentDirectoryPage({super.key});

  @override
  ConsumerState<ResidentDirectoryPage> createState() => _ResidentDirectoryPageState();
}

class _ResidentDirectoryPageState extends ConsumerState<ResidentDirectoryPage> {
  int _selectedFilterHomeId = 0; // 0: All homes (Doctor view)
  int _doctorTabIndex = 0; // 0: Elders, 1: All System Users
  bool _isLoading = false;

  // Search-First State for Caregiver View
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ResidentItem? _selectedResident;
  List<CognitiveSubmissionResult> _residentCognitiveHistory = [];
  bool _isLoadingHistory = false;
  String? _historyError;
  bool _showHistoryView = false;
  int? _expandedHistoryIndex;
  MemoryGameProgressSummary? _memoryGameProgress;
  bool _isLoadingMemoryGames = false;
  String? _memoryGameError;

  final List<ResidentItem> _allEldersFallback = [
    const ResidentItem(
      id: 1,
      name: 'Sarah Jenkins',
      age: 78,
      gender: 'Female',
      roomNo: '101',
      elderHomeName: 'Serene Valley Senior Living',
      elderHomeId: 1,
      cognitiveScore: 85.0,
      emotionalScore: 88.0,
      metabolicScore: null,
      riskScore: 0.20,
      caregiverName: 'Eleanor Vance',
      currentStatus: 'LOOKING_GOOD',
      riskLevel: 'LOW',
    ),
    const ResidentItem(
      id: 2,
      name: 'Arthur Pendelton',
      age: 82,
      gender: 'Male',
      roomNo: '102',
      elderHomeName: 'Serene Valley Senior Living',
      elderHomeId: 1,
      cognitiveScore: 62.0,
      emotionalScore: 54.0,
      metabolicScore: null,
      riskScore: 0.45,
      caregiverName: 'Eleanor Vance',
      currentStatus: 'NEEDS_ATTENTION',
      riskLevel: 'MODERATE',
    ),
    const ResidentItem(
      id: 3,
      name: 'Margaret Chen',
      age: 79,
      gender: 'Female',
      roomNo: '201',
      elderHomeName: 'Golden Sunset Eldercare',
      elderHomeId: 2,
      cognitiveScore: 80.0,
      emotionalScore: 76.0,
      metabolicScore: null,
      riskScore: 0.18,
      caregiverName: 'David Silva',
      currentStatus: 'STABLE',
      riskLevel: 'LOW',
    ),
    const ResidentItem(
      id: 4,
      name: 'Robert Hastings',
      age: 84,
      gender: 'Male',
      roomNo: '202',
      elderHomeName: 'Golden Sunset Eldercare',
      elderHomeId: 2,
      cognitiveScore: 48.0,
      emotionalScore: 38.0,
      metabolicScore: null,
      riskScore: 0.75,
      caregiverName: 'David Silva',
      currentStatus: 'CHECK_IN_NEEDED',
      riskLevel: 'HIGH',
    ),
    const ResidentItem(
      id: 5,
      name: 'Simon Perera',
      age: 76,
      gender: 'Male',
      roomNo: '301',
      elderHomeName: 'Lotus Care Senior Home',
      elderHomeId: 3,
      cognitiveScore: 60.0,
      emotionalScore: 65.0,
      metabolicScore: null,
      riskScore: 0.35,
      caregiverName: 'Staff On Duty',
      currentStatus: 'STABLE',
      riskLevel: 'LOW',
    ),
  ];

  final List<UserDirectoryItem> _allUsersFallback = [
    const UserDirectoryItem(
      id: 1,
      name: 'Dr. Samantha Reed',
      email: 'dr.reed@carevora.com',
      role: 'DOCTOR',
      elderHomeName: 'Global Oversight (All Facilities)',
    ),
    const UserDirectoryItem(
      id: 2,
      name: 'Eleanor Vance',
      email: 'eleanor.vance@carevora.com',
      role: 'CAREGIVER',
      elderHomeName: 'Serene Valley Senior Living',
    ),
    const UserDirectoryItem(
      id: 3,
      name: 'David Silva',
      email: 'david.silva@carevora.com',
      role: 'CAREGIVER',
      elderHomeName: 'Golden Sunset Eldercare',
    ),
    const UserDirectoryItem(
      id: 4,
      name: 'Sarah Jenkins',
      email: 'sarah.jenkins@carevora.com',
      role: 'ELDER',
      elderHomeName: 'Serene Valley Senior Living',
    ),
    const UserDirectoryItem(
      id: 5,
      name: 'Arthur Pendelton',
      email: 'arthur.p@carevora.com',
      role: 'ELDER',
      elderHomeName: 'Serene Valley Senior Living',
    ),
  ];

  List<ResidentItem> _liveResidents = [];
  List<UserDirectoryItem> _liveUsers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final authState = ref.read(authProvider).state;
    final token = authState.token;

    if (token == null) {
      _applyFallback();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Residents scoped by backend role
      final res = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/residents'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data'] as List?;
        if (list != null && list.isNotEmpty) {
          _liveResidents = list.map((e) {
            final cogVal = (e['cognitiveScore'] as num?)?.toDouble();
            final emoVal = (e['emotionalScore'] as num?)?.toDouble();
            final riskStr = e['riskLevel'] as String?;
            final double riskScore = riskStr == 'HIGH' ? 0.75 : (riskStr == 'MODERATE' ? 0.45 : 0.20);

            return ResidentItem(
              id: (e['id'] as num).toInt(),
              name: e['name'] as String? ?? 'Resident',
              age: (e['age'] as num?)?.toInt() ?? 75,
              educationYears: (e['educationYears'] as num?)?.toInt(),
              gender: e['gender'] as String? ?? 'Unknown',
              roomNo: e['roomNumber'] as String? ?? 'Room',
              elderHomeName: e['elderHomeName'] as String? ?? 'Care Facility',
              elderHomeId: (e['elderHomeId'] as num?)?.toInt() ?? 1,
              avatarUrl: e['avatarUrl'] as String?,
              cognitiveScore: cogVal,
              emotionalScore: emoVal,
              metabolicScore: null, // Metabolic data not exposed on backend
              riskScore: riskScore,
              caregiverName: 'Assigned Care Team',
              lastAssessmentDate: e['lastAssessmentDate'] as String?,
              currentStatus: e['currentStatus'] as String?,
              riskLevel: riskStr,
            );
          }).toList();
        }
      }

      // 2. If Doctor, fetch all users
      if (authState.isDoctor) {
        final usersRes = await http.get(
          Uri.parse('${AppConfig.backendBaseUrl}/api/doctor/all-users'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 4));

        if (usersRes.statusCode == 200) {
          final decoded = jsonDecode(usersRes.body);
          final list = decoded['data'] as List?;
          if (list != null && list.isNotEmpty) {
            _liveUsers = list.map((u) {
              return UserDirectoryItem(
                id: (u['id'] as num).toInt(),
                name: u['name'] as String? ?? 'User',
                email: u['email'] as String? ?? '',
                role: u['role'] as String? ?? 'USER',
                elderHomeName: u['elderHomeName'] as String?,
                avatarUrl: u['avatarUrl'] as String?,
                age: (u['age'] as num?)?.toInt(),
                educationYears: (u['educationYears'] as num?)?.toInt(),
                roomNumber: u['roomNumber'] as String?,
              );
            }).toList();
          }
        }
      }
    } catch (_) {
      _applyFallback();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFallback() {
    _liveResidents = _allEldersFallback;
    _liveUsers = _allUsersFallback;
  }

  Future<void> _selectResident(ResidentItem resident) async {
    setState(() {
      _selectedResident = resident;
      _isLoadingHistory = true;
      _historyError = null;
      _residentCognitiveHistory = [];
      _showHistoryView = false;
      _expandedHistoryIndex = null;
      _memoryGameProgress = null;
      _isLoadingMemoryGames = true;
      _memoryGameError = null;
    });

    await Future.wait([
      _loadResidentHistory(resident.id),
      _loadResidentMemoryGameProgress(resident.id),
    ]);
  }

  Future<void> _loadResidentHistory(int residentId) async {
    final token = ref.read(authProvider).state.token;
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final history = await CognitiveAssessmentService.fetchHistory(
        residentId: residentId,
        token: token,
      );
      if (mounted && _selectedResident?.id == residentId) {
        setState(() {
          _residentCognitiveHistory = history;
          _isLoadingHistory = false;
          _historyError = null;
        });
      }
    } catch (err) {
      if (mounted && _selectedResident?.id == residentId) {
        setState(() {
          _isLoadingHistory = false;
          _historyError = err.toString();
        });
      }
    }
  }

  Future<void> _loadResidentMemoryGameProgress(int residentId) async {
    final token = ref.read(authProvider).state.token;
    setState(() {
      _isLoadingMemoryGames = true;
      _memoryGameError = null;
    });

    try {
      final summary = await MemoryGameService.fetchResidentProgress(
        residentId,
        token: token,
      );
      if (mounted && _selectedResident?.id == residentId) {
        setState(() {
          _memoryGameProgress = summary;
          _isLoadingMemoryGames = false;
          _memoryGameError = null;
        });
      }
    } catch (err) {
      if (mounted && _selectedResident?.id == residentId) {
        setState(() {
          _isLoadingMemoryGames = false;
          _memoryGameError = err.toString();
        });
      }
    }
  }

  void _clearSelectedResident() {
    setState(() {
      _selectedResident = null;
      _residentCognitiveHistory = [];
      _isLoadingHistory = false;
      _historyError = null;
      _showHistoryView = false;
      _expandedHistoryIndex = null;
      _memoryGameProgress = null;
      _isLoadingMemoryGames = false;
      _memoryGameError = null;
    });
  }

  Future<void> _startNewAssessmentForResident(ResidentItem resident) async {
    final token = ref.read(authProvider).state.token;
    try {
      await CognitiveAssessmentService.startSession(
        residentId: resident.id,
        token: token,
      );
    } catch (_) {}
    if (mounted) {
      context.go('/dashboard/cognitive/session');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRoleHeader(authState),
            const SizedBox(height: 20),
            if (authState.isDoctor)
              _buildDoctorView(authState)
            else if (authState.isCaregiver)
              _buildCaregiverView(authState)
            else
              _buildElderView(authState),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleHeader(AuthState auth) {
    String badgeText;
    Color badgeBg;
    Color badgeColor;
    IconData badgeIcon;

    if (auth.isDoctor) {
      badgeText = 'DOCTOR GLOBAL OVERSIGHT • All Facilities & All Users';
      badgeBg = const Color(0xFFCCFBF1);
      badgeColor = const Color(0xFF0F766E);
      badgeIcon = LucideIcons.stethoscope;
    } else if (auth.isCaregiver) {
      final home = auth.elderHomeName ?? 'Assigned Elder Home';
      badgeText = 'CAREGIVER SCOPED ACCESS • $home';
      badgeBg = AppColors.primarySoft;
      badgeColor = AppColors.primaryDeep;
      badgeIcon = LucideIcons.shieldCheck;
    } else {
      final home = auth.elderHomeName ?? 'Care Community';
      badgeText = 'ELDER PRIVACY PROTECTION • $home';
      badgeBg = const Color(0xFFFEF3C7);
      badgeColor = const Color(0xFF92400E);
      badgeIcon = LucideIcons.lock;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            auth.isElder
                ? 'My Confidential Health Record'
                : 'Resident Directory',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            auth.isDoctor
                ? 'Logged in as ${auth.userName}. You have clinical clearance to review all residents and registered staff across all elder homes.'
                : auth.isCaregiver
                    ? 'Search residents assigned to your care home to view longitudinal wellness metrics, review cognitive assessments, or initiate new evaluation sessions.'
                    : 'Logged in as ${auth.userName}. Under HIPAA and resident privacy standards, you cannot view other elders\' records.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.body,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CAREGIVER VIEW: Search-First Interface
  // ----------------------------------------------------
  Widget _buildCaregiverView(AuthState auth) {
    final allResidents = _liveResidents.isNotEmpty ? _liveResidents : _allEldersFallback;
    final assignedHomeId = auth.elderHomeId ?? 1;

    // Filter STRICTLY by caregiver's elder home
    final scopedResidents = allResidents.where((r) => r.elderHomeId == assignedHomeId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prominent Search Bar with Clear-Search Control
        Container(
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
                    hintText: 'Search residents by name or resident ID...  🧓',
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
                      Text('👥', style: TextStyle(fontSize: 13)),
                      SizedBox(width: 5),
                      Text(
                        'Directory',
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
        ),
        const SizedBox(height: 20),

        // Display states: If a resident is selected, show their 3 wellness cards.
        // Otherwise, show search results or empty state.
        if (_selectedResident != null) ...[
          _buildSelectedResidentOverview(auth),
        ] else if (_searchQuery.trim().isEmpty) ...[
          _buildEmptySearchState(scopedResidents.length, auth.elderHomeName ?? 'Your Facility'),
        ] else ...[
          _buildSearchResultsList(scopedResidents),
        ],
      ],
    );
  }

  /// Empty state displayed before any search query is entered or resident is selected
  Widget _buildEmptySearchState(int residentCount, String facilityName) {
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
        mainAxisSize: MainAxisSize.min,
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
                  child: Text('🧓', style: TextStyle(fontSize: 40)),
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
              'Type a resident name or resident ID in the search bar above to view their cognitive, emotional, and metabolic wellness cards.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.body,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildDirectoryTag('🧓', 'Senior Profiles', const Color(0xFFF3E8FF), const Color(0xFF6B21A8)),
              _buildDirectoryTag('📊', 'Wellness Tracking', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
              _buildDirectoryTag('🩺', 'Clinical History', const Color(0xFFECFDF5), const Color(0xFF047857)),
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
                Flexible(
                  child: Text(
                    '$facilityName ($residentCount residents assigned)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDeep,
                    ),
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildDirectoryTag(String emoji, String label, Color bg, Color textColor) {
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

  /// Search results list matching the caregiver's input
  Widget _buildSearchResultsList(List<ResidentItem> scopedResidents) {
    final q = _searchQuery.trim().toLowerCase();
    final matches = scopedResidents.where((r) {
      final nameMatch = r.name.toLowerCase().contains(q);
      final idMatch = r.id.toString() == q;
      final roomMatch = r.roomNo.toLowerCase().contains(q);
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
              'No resident matches "$_searchQuery" in your assigned facility. Please check the spelling or ID.',
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
                borderRadius: BorderRadius.circular(12),
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
                            Text(
                              r.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Room ${r.roomNo} • Age ${r.age}${r.educationYears != null ? ' • Edu: ${r.educationYears} yrs' : ''} • ${r.gender}',
                              style: const TextStyle(fontSize: 12, color: AppColors.body),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lavenderBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ID: #${r.id}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDeep),
                        ),
                      ),
                      const SizedBox(width: 12),
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

  /// Selected resident overview containing identification details and three individual wellness cards
  Widget _buildSelectedResidentOverview(AuthState auth) {
    final r = _selectedResident!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Resident Banner with Back to Search / Clear Control
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, bannerBox) {
              final isNarrow = bannerBox.maxWidth < 520;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CarevoraAvatar(
                          avatarUrl: r.avatarUrl,
                          radius: 22,
                          initials: r.name,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Resident ID: #${r.id}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Room ${r.roomNo} • Age ${r.age}${r.educationYears != null ? ' • Edu: ${r.educationYears} yrs' : ''} (${r.gender}) • Facility: ${r.elderHomeName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.body),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _clearSelectedResident,
                      icon: const Icon(LucideIcons.arrowLeft, size: 14),
                      label: const Text('Back to Search'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  CarevoraAvatar(
                    avatarUrl: r.avatarUrl,
                    radius: 26,
                    initials: r.name,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Resident ID: #${r.id}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Room ${r.roomNo} • Age ${r.age}${r.educationYears != null ? ' • Education: ${r.educationYears} yrs' : ''} (${r.gender}) • Facility: ${r.elderHomeName}',
                          style: const TextStyle(fontSize: 13, color: AppColors.body),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearSelectedResident,
                    icon: const Icon(LucideIcons.arrowLeft, size: 14),
                    label: const Text('Back to Search'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Three Individual Wellness Cards in Responsive Wrap to prevent RenderFlex overflow
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = constraints.maxWidth < 360
                ? constraints.maxWidth
                : constraints.maxWidth < 720
                    ? constraints.maxWidth
                    : (constraints.maxWidth < 1100 ? (constraints.maxWidth - 16) / 2 : 340.0);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildCognitiveWellnessCard(r, cardWidth),
                _buildEmotionalWellnessCard(r, cardWidth),
                _buildMetabolicWellnessCard(r, cardWidth),
                _buildMemoryGamesProgressCard(r, cardWidth),
              ],
            );
          },
        ),

        // Optional History View / Modal
        if (_showHistoryView) ...[
          const SizedBox(height: 24),
          _buildCognitiveHistorySection(r),
        ],
      ],
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    Color bg;
    Color text;
    IconData icon;

    final r = riskLevel.toLowerCase();
    if (r.contains('low')) {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
      icon = LucideIcons.shieldCheck;
    } else if (r.contains('mod')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
      icon = LucideIcons.alertTriangle;
    } else if (r.contains('high')) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFB91C1C);
      icon = LucideIcons.alertCircle;
    } else {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF64748B);
      icon = LucideIcons.helpCircle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              riskLevel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Card 1 — Cognitive Wellness
  Widget _buildCognitiveWellnessCard(ResidentItem r, [double? cardWidth]) {
    final completedAssessments = _residentCognitiveHistory
        .where((a) {
          final s = a.status.toUpperCase();
          return s == 'COMPLETED' || s == 'COMPLETED_PREDICTION_UNAVAILABLE';
        })
        .toList();
    final int completedCount = completedAssessments.length;

    final pendingAssessments = _residentCognitiveHistory
        .where((a) =>
            a.status.toUpperCase() == 'PENDING_CAREGIVER_REVIEW' ||
            a.status.toUpperCase() == 'PENDING_REVIEW')
        .toList();

    String scoreDisplay;
    String riskLevelDisplay;
    String statusDisplay;
    String dateDisplay;
    Color statusBg;
    Color statusColor;
    bool hasCompletedScore = false;

    if (_isLoadingHistory && _residentCognitiveHistory.isEmpty) {
      scoreDisplay = 'Loading...';
      riskLevelDisplay = 'Not Available';
      statusDisplay = 'Checking...';
      dateDisplay = 'Loading...';
      statusBg = AppColors.surfaceSecondary;
      statusColor = AppColors.muted;
    } else if (completedAssessments.isNotEmpty) {
      final latestRecord = completedAssessments.first;
      if (latestRecord.acrfScore != null) {
        scoreDisplay = '${latestRecord.acrfScore!.toStringAsFixed(1)}%';
        hasCompletedScore = true;
      } else {
        scoreDisplay = 'No cognitive assessments yet';
      }

      final hasPrediction = (latestRecord.riskLevel != null &&
              latestRecord.riskLevel!.isNotEmpty &&
              latestRecord.riskLevel != 'Not Available' &&
              latestRecord.riskLevel != 'Risk Level Not Available' &&
              latestRecord.riskLevel != 'Prediction Unavailable') ||
          (latestRecord.mlPrediction != null &&
              latestRecord.mlPrediction!.isNotEmpty &&
              latestRecord.mlPrediction != 'Not Available' &&
              latestRecord.mlPrediction != 'Risk Level Not Available' &&
              latestRecord.mlPrediction != 'Prediction Unavailable');

      if (hasPrediction &&
          latestRecord.status.toUpperCase() != 'COMPLETED_PREDICTION_UNAVAILABLE') {
        if (latestRecord.riskLevel != null &&
            latestRecord.riskLevel!.isNotEmpty &&
            latestRecord.riskLevel != 'Not Available' &&
            latestRecord.riskLevel != 'Risk Level Not Available' &&
            latestRecord.riskLevel != 'Prediction Unavailable') {
          riskLevelDisplay = latestRecord.riskLevel!;
        } else {
          riskLevelDisplay = latestRecord.mlPrediction!;
        }
      } else if (latestRecord.acrfScore != null) {
        final s = (latestRecord.acrfScore! <= 1.0 && latestRecord.acrfScore! > 0.0)
            ? latestRecord.acrfScore! * 100.0
            : latestRecord.acrfScore!;
        if (s >= 70.0) {
          riskLevelDisplay = 'Low Risk';
        } else if (s >= 50.0) {
          riskLevelDisplay = 'Moderate Risk';
        } else {
          riskLevelDisplay = 'High Risk';
        }
      } else {
        riskLevelDisplay = 'Risk Level Not Available';
      }

      if (latestRecord.status.toUpperCase() == 'COMPLETED_PREDICTION_UNAVAILABLE' ||
          latestRecord.status.toUpperCase() == 'COMPLETED') {
        statusDisplay = 'Completed';
        statusBg = const Color(0xFFDCFCE7);
        statusColor = const Color(0xFF15803D);
      } else {
        statusDisplay = latestRecord.status;
        statusBg = const Color(0xFFDBEAFE);
        statusColor = const Color(0xFF1D4ED8);
      }

      dateDisplay = latestRecord.createdAt != null
          ? _formatDate(latestRecord.createdAt!)
          : 'None recorded';
    } else if (pendingAssessments.isNotEmpty) {
      final latestPending = pendingAssessments.first;
      scoreDisplay = 'Pending Review';
      riskLevelDisplay = 'Not Available';
      statusDisplay = 'Pending Review';
      dateDisplay = latestPending.createdAt != null
          ? _formatDate(latestPending.createdAt!)
          : 'None recorded';
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFB45309);
    } else {
      scoreDisplay = 'No cognitive assessments yet';
      riskLevelDisplay = 'Not Available';
      statusDisplay = 'Not Assessed';
      dateDisplay = 'None recorded';
      statusBg = AppColors.surfaceSecondary;
      statusColor = AppColors.muted;
    }

    return Container(
      width: cardWidth ?? 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.brain, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cognitive Wellness',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Task Accuracy Score', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(
            scoreDisplay,
            style: TextStyle(
              fontSize: hasCompletedScore ? 24 : 15,
              fontWeight: FontWeight.w800,
              color: hasCompletedScore ? AppColors.navy : AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              const Text(
                'AI Risk Prediction:',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              _buildRiskBadge(riskLevelDisplay),
            ],
          ),
          if (completedAssessments.isNotEmpty &&
              completedAssessments.first.acrfScore != null &&
              completedAssessments.first.acrfScore! >= 85.0 &&
              (riskLevelDisplay.toLowerCase().contains('moderate') ||
                  riskLevelDisplay.toLowerCase().contains('high'))) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 14, color: Color(0xFFB45309)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI prediction also considers response latency, longitudinal features, and other model inputs alongside task accuracy.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Date: $dateDisplay',
                  style: const TextStyle(fontSize: 12, color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.history, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _isLoadingHistory
                      ? 'Loading history count...'
                      : '$completedCount assessment(s) completed',
                  style: const TextStyle(fontSize: 12, color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_memoryGameProgress != null && _memoryGameProgress!.totalCompletedSessions > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.gamepad2, size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Memory Practice: ${_memoryGameProgress!.hasRepeatedDecline ? "Needs Observation" : ((_memoryGameProgress!.averageScore ?? 0) >= 80.0 ? "Good Condition" : "Stable Condition")} (${_memoryGameProgress!.averageScore?.toStringAsFixed(1) ?? "--"}% avg)',
                    style: const TextStyle(fontSize: 12, color: AppColors.body, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'ACRF is a weighted wellness metric. Model trained on synthetic data. Non-diagnostic.',
            style: TextStyle(fontSize: 9, color: AppColors.muted, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startNewAssessmentForResident(r),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('New Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  setState(() => _showHistoryView = !_showHistoryView);
                  if (_showHistoryView && _residentCognitiveHistory.isEmpty && !_isLoadingHistory) {
                    _loadResidentHistory(r.id);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_showHistoryView ? LucideIcons.eyeOff : LucideIcons.history, size: 14),
                    const SizedBox(width: 4),
                    Text(_showHistoryView ? 'Hide' : 'History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card 2 — Emotional Wellness (Display-only integration)
  Widget _buildEmotionalWellnessCard(ResidentItem r, [double? cardWidth]) {
    final double? emoScore = r.emotionalScore;
    final String dateDisplay = r.lastAssessmentDate != null
        ? _formatDate(r.lastAssessmentDate!)
        : 'Latest Available';

    return Container(
      width: cardWidth ?? 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.heartHandshake, color: Color(0xFFDB2777), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Emotional Wellness',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.currentStatus ?? 'Stable',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Latest Score', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(
            emoScore != null
                ? '${emoScore.toStringAsFixed(1)}%'
                : 'No emotional wellness data available',
            style: TextStyle(
              fontSize: emoScore != null ? 24 : 15,
              fontWeight: FontWeight.w800,
              color: emoScore != null ? AppColors.navy : AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.calendar, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Date: $dateDisplay',
                  style: const TextStyle(fontSize: 12, color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.shieldAlert, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Risk Level: ${r.riskLevel ?? "Low"}',
                  style: const TextStyle(fontSize: 12, color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(LucideIcons.info, size: 14, color: AppColors.muted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Multimodal affective monitoring & sentiment telemetry.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 3 — Metabolic Wellness (Display-only integration; clear empty state when unexposed)
  Widget _buildMetabolicWellnessCard(ResidentItem r, [double? cardWidth]) {
    // Metabolic data is not exposed in the existing backend
    final double? metabolicScore = r.metabolicScore;

    return Container(
      width: cardWidth ?? 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.activity, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Metabolic Wellness',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Pending Integration',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Latest Score', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(
            metabolicScore != null
                ? '${metabolicScore.toStringAsFixed(1)}%'
                : 'No metabolic wellness data available',
            style: TextStyle(
              fontSize: metabolicScore != null ? 24 : 15,
              fontWeight: FontWeight.w800,
              color: metabolicScore != null ? AppColors.navy : AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(LucideIcons.calendar, size: 13, color: AppColors.muted),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Date: None recorded',
                  style: TextStyle(fontSize: 12, color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const [
              Icon(LucideIcons.activity, size: 13, color: AppColors.muted),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Telemetry: Vitals & Glycemic stability',
                  style: TextStyle(fontSize: 12, color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(LucideIcons.info, size: 14, color: AppColors.muted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Metabolic health monitoring stream is not yet active on backend.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 4 — Memory Games Progress (Quick Summary for Caregiver Directory)
  Widget _buildMemoryGamesProgressCard(ResidentItem r, [double? cardWidth]) {
    final progress = _memoryGameProgress;
    final totalSessions = progress?.totalCompletedSessions ?? 0;
    final latestDateStr = progress?.latestActivityDate != null
        ? _formatDate(progress!.latestActivityDate!.toIso8601String())
        : 'No sessions recorded';

    // Friendly progress indicator badge based on real saved records
    String progressText;
    Color progressBg;
    Color progressColor;
    IconData progressIcon;

    if (totalSessions == 0) {
      progressText = 'No practice yet';
      progressBg = AppColors.surfaceSecondary;
      progressColor = AppColors.muted;
      progressIcon = LucideIcons.circle;
    } else if (progress?.hasRepeatedDecline == true) {
      progressText = 'Decline Notice';
      progressBg = const Color(0xFFFEF3C7);
      progressColor = const Color(0xFFB45309);
      progressIcon = LucideIcons.alertTriangle;
    } else {
      progressText = progress?.overallProgress == 'IMPROVING'
          ? 'Improving (+)'
          : (progress?.overallProgress == 'STEADY' ? 'Steady Practice' : 'Practicing Regularly');
      progressBg = AppColors.riskLowBg;
      progressColor = AppColors.riskLow;
      progressIcon = LucideIcons.sparkles;
    }

    return Container(
      width: cardWidth ?? 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.gamepad2, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Memory Games',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(progressIcon, size: 11, color: progressColor),
                    const SizedBox(width: 4),
                    Text(
                      progressText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingMemoryGames) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            ),
          ] else if (_memoryGameError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.riskHigh),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _memoryGameError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.riskHigh),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Orderly Caregiver Memory Condition Banner
            if (totalSessions > 0) ...[
              Builder(
                builder: (context) {
                  final avgScore = progress?.averageScore;
                  final isDecline = progress?.hasRepeatedDecline == true || (avgScore != null && avgScore < 60.0);
                  final isGood = !isDecline && avgScore != null && avgScore >= 80.0;

                  final Color bannerColor = isGood
                      ? const Color(0xFF047857)
                      : (isDecline ? const Color(0xFFB45309) : const Color(0xFF1D4ED8));
                  final Color bannerBg = isGood
                      ? const Color(0xFFECFDF5)
                      : (isDecline ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF));
                  final Color bannerBorder = isGood
                      ? const Color(0xFFA7F3D0)
                      : (isDecline ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE));
                  final IconData bannerIcon = isGood
                      ? LucideIcons.checkCircle2
                      : (isDecline ? LucideIcons.alertTriangle : LucideIcons.activity);

                  final String conditionLabel = isGood
                      ? 'Memory Condition: Good (Healthy Recall)'
                      : (isDecline
                          ? 'Memory Condition: Needs Observation'
                          : 'Memory Condition: Fair (Stable)');

                  final String conditionNote = isGood
                      ? 'Strong cognitive recall across the 3 memory games'
                      : (isDecline
                          ? 'Recent game variation observed. Supportive practice advised'
                          : 'Consistent mental recall within expected baseline range');

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: bannerBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bannerBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(bannerIcon, size: 14, color: bannerColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                conditionLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: bannerColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          conditionNote,
                          style: TextStyle(
                            fontSize: 11,
                            color: bannerColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],

            // Sessions Completed Counter
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lavenderBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Completed Sessions',
                    style: TextStyle(fontSize: 13, color: AppColors.body, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$totalSessions',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Latest Scores per Game
            _buildGameScoreRow('Remember Sequence', progress?.latestSequenceScore),
            const SizedBox(height: 6),
            _buildGameScoreRow('Matching Pairs', progress?.latestPairsScore),
            const SizedBox(height: 6),
            _buildGameScoreRow('Remember Items', progress?.latestItemsScore),
            const SizedBox(height: 12),

            // Recent Activity Date
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 13, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Last Activity: $latestDateStr',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Open Memory Games in Care Plans
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('open_memory_games_care_plan_button'),
                onPressed: () {
                  context.go('/dashboard/care-plans?residentId=${r.id}');
                },
                icon: const Icon(LucideIcons.arrowUpRight, size: 14),
                label: const Text('View in Care Plans'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameScoreRow(String gameTitle, double? score) {
    String statusTag;
    Color tagColor;
    Color tagBg;

    if (score == null) {
      statusTag = 'Not Played';
      tagColor = AppColors.muted;
      tagBg = AppColors.surfaceSecondary;
    } else if (score >= 80.0) {
      statusTag = 'Good';
      tagColor = const Color(0xFF047857);
      tagBg = const Color(0xFFECFDF5);
    } else if (score >= 60.0) {
      statusTag = 'Fair';
      tagColor = const Color(0xFF1D4ED8);
      tagBg = const Color(0xFFEFF6FF);
    } else {
      statusTag = 'Needs Practice';
      tagColor = const Color(0xFFB45309);
      tagBg = const Color(0xFFFEF3C7);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  gameTitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.navy),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusTag,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: tagColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          MemoryGameService.formatScore(score),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: score != null ? AppColors.primary : AppColors.muted,
          ),
        ),
      ],
    );
  }

  /// Cognitive Assessment History Section: chronologically ordered newest first
  Widget _buildCognitiveHistorySection(ResidentItem r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.history, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cognitive Assessment History — ${r.name}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 14, color: AppColors.muted),
                tooltip: 'Refresh history',
                onPressed: () => _loadResidentHistory(r.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                '${_residentCognitiveHistory.length} record(s)',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          if (_isLoadingHistory) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Loading cognitive assessment history...',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_historyError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.alertCircle, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error loading cognitive history: $_historyError',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _loadResidentHistory(r.id),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_residentCognitiveHistory.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(LucideIcons.fileQuestion, size: 36, color: AppColors.muted),
                  SizedBox(height: 10),
                  Text(
                    'No cognitive assessments recorded yet.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Start a new assessment to establish the resident\'s cognitive wellness baseline.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _residentCognitiveHistory.length,
              separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.border),
              itemBuilder: (context, index) {
                final item = _residentCognitiveHistory[index];
                final dateStr = item.createdAt != null ? _formatDate(item.createdAt!) : 'Date N/A';
                final isCompleted = item.status.toUpperCase() == 'COMPLETED';
                final isCompletedNoMl = item.status.toUpperCase() == 'COMPLETED_PREDICTION_UNAVAILABLE';
                final isPending = item.status.toUpperCase().contains('PENDING');

                final String statusLabel = isCompleted
                    ? 'Completed'
                    : (isCompletedNoMl
                        ? 'Completed (No ML)'
                        : (isPending ? 'Pending Caregiver Review' : item.status));

                final Color statusBg = isCompleted
                    ? const Color(0xFFDCFCE7)
                    : (isCompletedNoMl
                        ? const Color(0xFFDBEAFE)
                        : (isPending ? const Color(0xFFFEF3C7) : AppColors.surfaceSecondary));

                final Color statusColor = isCompleted
                    ? const Color(0xFF15803D)
                    : (isCompletedNoMl
                        ? const Color(0xFF1D4ED8)
                        : (isPending ? const Color(0xFFB45309) : AppColors.body));

                final String sessionLabel = item.sessionId != null && item.sessionId!.isNotEmpty
                    ? item.sessionId!
                    : (item.id > 0 ? 'Assessment #${item.id}' : 'Assessment #${_residentCognitiveHistory.length - index}');

                final String scoreText = item.acrfScore != null
                    ? '${item.acrfScore!.toStringAsFixed(1)}%'
                    : (isPending ? 'Pending Review' : 'Not Available');

                final hasItemPrediction = (item.riskLevel != null &&
                        item.riskLevel!.isNotEmpty &&
                        item.riskLevel != 'Not Available' &&
                        item.riskLevel != 'Risk Level Not Available' &&
                        item.riskLevel != 'Prediction Unavailable') ||
                    (item.mlPrediction != null &&
                        item.mlPrediction!.isNotEmpty &&
                        item.mlPrediction != 'Not Available' &&
                        item.mlPrediction != 'Risk Level Not Available' &&
                        item.mlPrediction != 'Prediction Unavailable');

                final String riskLabel = isPending
                    ? 'Not Available'
                    : (hasItemPrediction && !isCompletedNoMl
                        ? (item.riskLevel != null &&
                                item.riskLevel!.isNotEmpty &&
                                item.riskLevel != 'Not Available' &&
                                item.riskLevel != 'Risk Level Not Available' &&
                                item.riskLevel != 'Prediction Unavailable'
                            ? item.riskLevel!
                            : item.mlPrediction!)
                        : (item.acrfScore != null
                            ? ((item.acrfScore! <= 1.0 && item.acrfScore! > 0.0
                                    ? item.acrfScore! * 100.0
                                    : item.acrfScore!) >= 70.0
                                ? 'Low Risk'
                                : ((item.acrfScore! <= 1.0 && item.acrfScore! > 0.0
                                        ? item.acrfScore! * 100.0
                                        : item.acrfScore!) >= 50.0
                                    ? 'Moderate Risk'
                                    : 'High Risk'))
                            : 'Risk Level Not Available'));

                final bool isExpanded = _expandedHistoryIndex == index;

                return Container(
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sessionLabel,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dateStr,
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Task Accuracy Score', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              const SizedBox(height: 2),
                              Text(
                                scoreText,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AI Risk Prediction', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              const SizedBox(height: 2),
                              _buildRiskBadge(riskLabel),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Assessed By', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              const SizedBox(height: 2),
                              Text(
                                item.assessedBy ?? 'Care Specialist',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.body),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildDomainChip('Memory', item.memory),
                          _buildDomainChip('Attention', item.attention),
                          _buildDomainChip('Orientation', item.orientation),
                          _buildDomainChip('Recall', item.recall),
                          _buildDomainChip('Reasoning', item.reasoning),
                        ],
                      ),
                      if (item.acrfScore != null &&
                          item.acrfScore! >= 85.0 &&
                          (riskLabel.toLowerCase().contains('moderate') ||
                              riskLabel.toLowerCase().contains('high'))) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.info, size: 13, color: Color(0xFFB45309)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'AI prediction also considers response latency, longitudinal features, and other model inputs alongside task accuracy.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(LucideIcons.sparkles, size: 12, color: AppColors.muted),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              isPending
                                  ? 'AI Inference: Pending completion'
                                  : (item.mlAvailable
                                      ? 'AI Prediction: ${item.mlModelType} (${item.mlStatusMessage})'
                                      : 'AI Inference: ${item.mlStatusMessage}'),
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Optional expandable section for question-by-question responses and clinical grades
                      if ((item.responses != null && item.responses!.isNotEmpty) ||
                          (item.grades != null && item.grades!.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _expandedHistoryIndex = isExpanded ? null : index;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isExpanded
                                      ? 'Hide Question Responses & Grades'
                                      : 'Inspect Responses & Auto-Grades (10 Questions)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (isExpanded) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int qId = 1; qId <= 10; qId++) ...[
                                  Builder(
                                    builder: (context) {
                                      final question = CognitiveScoring.questions.firstWhere(
                                        (q) => q.id == qId,
                                        orElse: () => CognitiveQuestionItem(
                                          id: qId,
                                          category: 'General',
                                          domain: 'general',
                                          prompt: 'Question $qId',
                                          aiTip: '',
                                          recommendedAnswerGuide: '',
                                        ),
                                      );
                                      final resp = item.responses?[qId] ?? 'No recorded response';
                                      final grade = item.grades?[qId];
                                      final gradeText = grade != null
                                          ? '${grade.toStringAsFixed(1)} / 1.0'
                                          : (isPending ? 'Pending review' : 'Ungraded');

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primarySoft,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Q$qId',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    question.prompt,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy),
                                                  ),
                                                  Text(
                                                    'Response: "$resp"',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.body),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              gradeText,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: grade != null && grade > 0 ? const Color(0xFF15803D) : AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  if (qId < 10) const Divider(height: 8, color: AppColors.border),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDomainChip(String domain, double? score) {
    final String scoreStr = score != null ? '${score.toStringAsFixed(0)}%' : 'N/A';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$domain: $scoreStr',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$month ${dt.day}, ${dt.year} • $hour:$minute $ampm';
    } catch (_) {
      return isoString;
    }
  }

  // ----------------------------------------------------
  // DOCTOR VIEW: Global access to all elders & all users
  // ----------------------------------------------------
  Widget _buildDoctorView(AuthState auth) {
    final allResidents = _liveResidents.isNotEmpty ? _liveResidents : _allEldersFallback;
    final allUsers = _liveUsers.isNotEmpty ? _liveUsers : _allUsersFallback;

    final filteredResidents = _selectedFilterHomeId == 0
        ? allResidents
        : allResidents.where((r) => r.elderHomeId == _selectedFilterHomeId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildTabButton('All Elders (${allResidents.length})', 0, LucideIcons.users),
            const SizedBox(width: 10),
            _buildTabButton('All System Users (${allUsers.length})', 1, LucideIcons.userCheck),
          ],
        ),
        const SizedBox(height: 16),

        if (_doctorTabIndex == 0) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFacilityChip('All Elder Homes (${allResidents.length})', 0),
              _buildFacilityChip('Serene Valley (2)', 1),
              _buildFacilityChip('Golden Sunset (2)', 2),
              _buildFacilityChip('Lotus Care (1)', 3),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: filteredResidents.map((r) => _buildResidentCard(r, isDoctor: true)).toList(),
          ),
        ] else ...[
          _buildAllUsersDirectory(allUsers),
        ],
      ],
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _doctorTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _doctorTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.navy : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.navy),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityChip(String label, int homeId) {
    final isSelected = _selectedFilterHomeId == homeId;
    return InkWell(
      onTap: () => setState(() => _selectedFilterHomeId = homeId),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.body,
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // ELDER VIEW: Confidential individual record ONLY
  // ----------------------------------------------------
  Widget _buildElderView(AuthState auth) {
    final allResidents = _liveResidents.isNotEmpty ? _liveResidents : _allEldersFallback;

    final myRecord = allResidents.firstWhere(
      (r) => auth.userName != null && r.name.toLowerCase().contains(auth.userName!.toLowerCase().split(' ')[0]),
      orElse: () => allResidents.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: const [
              Icon(LucideIcons.lock, color: Color(0xFFB45309), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elder Confidential Privacy Protocol Active',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Other resident records are confidential and hidden from view. You have exclusive private access to your own personalized health telemetry and cognitive wellness progress.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CarevoraAvatar(
                      avatarUrl: auth.avatarUrl ?? myRecord.avatarUrl,
                      radius: 30,
                      initials: auth.userName ?? myRecord.name,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.userName ?? myRecord.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            'Room ${myRecord.roomNo} • Age ${myRecord.age}${myRecord.educationYears != null ? ' • Education: ${myRecord.educationYears} Years' : ''} • ${myRecord.gender}',
                            style: const TextStyle(fontSize: 13, color: AppColors.body),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              auth.elderHomeName ?? myRecord.elderHomeName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, color: AppColors.border),
                const Text(
                  'Your Wellness Tracking Scores',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 12),
                _buildScoreBar('Cognitive Clarity', myRecord.cognitiveScore != null ? myRecord.cognitiveScore! / 100.0 : 0.0, const Color(0xFF6366F1)),
                const SizedBox(height: 10),
                _buildScoreBar('Emotional Wellness', myRecord.emotionalScore != null ? myRecord.emotionalScore! / 100.0 : 0.0, const Color(0xFFEC4899)),
                const SizedBox(height: 10),
                _buildScoreBar('Metabolic Stability', 0.70, const Color(0xFF10B981)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.heartHandshake, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned Primary Caregiver: ${myRecord.caregiverName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResidentCard(ResidentItem r, {required bool isDoctor}) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CarevoraAvatar(
                avatarUrl: r.avatarUrl,
                radius: 22,
                initials: r.name,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Room ${r.roomNo} • Age ${r.age}${r.educationYears != null ? ' • Edu: ${r.educationYears} yrs' : ''} (${r.gender})',
                      style: const TextStyle(fontSize: 12, color: AppColors.body),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: r.riskScore < 0.3 ? AppColors.riskLowBg : AppColors.riskModerateBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.riskScore < 0.3 ? 'Low Risk' : 'Moderate',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: r.riskScore < 0.3 ? AppColors.riskLow : AppColors.riskModerate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lavenderBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.building2, size: 12, color: AppColors.primary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    r.elderHomeName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDeep),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Cognitive', r.cognitiveScore != null ? '${r.cognitiveScore!.toStringAsFixed(0)}%' : 'N/A'),
              _buildMiniMetric('Emotional', r.emotionalScore != null ? '${r.emotionalScore!.toStringAsFixed(0)}%' : 'N/A'),
              _buildMiniMetric('Metabolic', 'N/A'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Caregiver: ${r.caregiverName}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              if (isDoctor)
                InkWell(
                  onTap: () => context.go('/dashboard/doctor'),
                  child: const Text(
                    'Prescribe Rx →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
      ],
    );
  }

  Widget _buildScoreBar(String label, double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.body)),
            Text('${(score * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            minHeight: 6,
            backgroundColor: AppColors.surfaceSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildAllUsersDirectory(List<UserDirectoryItem> users) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final u = users[index];
          Color roleColor = AppColors.primary;
          if (u.role == 'DOCTOR') roleColor = const Color(0xFF0D9488);
          if (u.role == 'ELDER') roleColor = const Color(0xFFD97706);

          return ListTile(
            leading: CarevoraAvatar(
              avatarUrl: u.avatarUrl,
              radius: 20,
              initials: u.name,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              foregroundColor: roleColor,
            ),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${u.email} • ${u.elderHomeName ?? "No Home"}${u.roomNumber != null ? " • Room ${u.roomNumber}" : ""}${u.age != null ? " • Age ${u.age}" : ""}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                u.role,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
              ),
            ),
          );
        },
      ),
    );
  }
}
