import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/sinhala_name_transliterator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/url_launcher_service.dart';
import '../../../shared/widgets/carevora_avatar.dart';
import '../../auth/application/auth_controller.dart';

class CallContactItem {
  final String id;
  final String name;
  final String roleOrRoom;
  final String? subtitle;
  final String phoneOrExt;
  final String? whatsappNumber;
  final String status;
  final Color statusColor;
  final IconData icon;
  final int? elderHomeId;
  final String? elderHomeName;
  final String? avatarUrl;

  const CallContactItem({
    required this.id,
    required this.name,
    required this.roleOrRoom,
    this.subtitle,
    required this.phoneOrExt,
    this.whatsappNumber,
    required this.status,
    required this.statusColor,
    required this.icon,
    this.elderHomeId,
    this.elderHomeName,
    this.avatarUrl,
  });
}

class CareStationHelpPage extends ConsumerStatefulWidget {
  const CareStationHelpPage({super.key});

  @override
  ConsumerState<CareStationHelpPage> createState() => _CareStationHelpPageState();
}

class _CareStationHelpPageState extends ConsumerState<CareStationHelpPage> {
  int _caregiverSelectedTab = 0; // 0: Elders (Residents), 1: Doctors, 2: Stations
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Live backend caregivers & residents (nullable for safe Hot Reload)
  List<CallContactItem>? _liveHomeCaregivers;
  List<CallContactItem>? _liveHomeResidents;
  Map<String, String>? _liveAvatarsByName;
  bool? _hasRequestedLiveSync;
  bool? _isLoadingLive;
  int? _loadedForHomeId;

  @override
  void initState() {
    super.initState();
    _hasRequestedLiveSync = true;
    _fetchLiveDirectoryAvatars();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Ensure Hot Reload immediately fetches live DB caregivers & real avatars
    _fetchLiveDirectoryAvatars(force: true);
  }

  Future<void> _fetchLiveDirectoryAvatars({bool force = false}) async {
    if (_isLoadingLive == true && !force) return;
    final authState = ref.read(authProvider).state;
    final homeId = _getResolvedElderHomeId(authState);
    final token = authState.token;
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    if (mounted) {
      setState(() {
        _isLoadingLive = true;
        _loadedForHomeId = homeId;
      });
    }

    final avatarMap = <String, String>{};
    List<CallContactItem>? fetchedCaregivers;
    List<CallContactItem>? fetchedResidents;

    // 1. Fetch live caregivers + ONLY real uploaded DB avatars for this elder home
    try {
      final res = await http
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/api/elder-homes/$homeId/caregivers'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data'] as List?;
        if (list != null && list.isNotEmpty) {
          final items = <CallContactItem>[];
          for (int i = 0; i < list.length; i++) {
            final row = list[i] as Map<String, dynamic>;
            final rawName = (row['name']?.toString() ?? '').trim();
            if (rawName.isEmpty) continue;
            final displayName = rawName.toLowerCase().startsWith('caregiver')
                ? rawName
                : 'Caregiver $rawName';
            final av = row['avatarUrl']?.toString().trim();
            final realAvatar = (av != null && av.isNotEmpty) ? av : null;
            if (realAvatar != null) {
              avatarMap[rawName.toLowerCase()] = realAvatar;
              avatarMap[displayName.toLowerCase()] = realAvatar;
            }
            final title = (row['title']?.toString().trim().isNotEmpty ?? false)
                ? row['title'].toString().trim()
                : 'Care Coordinator';
            final dept = (row['department']?.toString().trim().isNotEmpty ?? false)
                ? row['department'].toString().trim()
                : 'General Elderly Care • On Duty';
            items.add(
              CallContactItem(
                id: 'CG-${row['id'] ?? i}',
                name: displayName,
                roleOrRoom: title,
                subtitle: dept,
                phoneOrExt: '+94 76 037 6031',
                whatsappNumber: '94760376031',
                status: 'Available • On Duty',
                statusColor: AppColors.riskLow,
                icon: LucideIcons.userCheck,
                elderHomeId: homeId,
                elderHomeName: row['elderHomeName']?.toString() ?? authState.elderHomeName,
                avatarUrl: realAvatar,
              ),
            );
          }
          if (items.isNotEmpty) {
            fetchedCaregivers = items;
          }
        }
      }
    } catch (e) {
      debugPrint('CareStationHelpPage live caregivers fetch error: $e');
    }

    // 2. If logged in as caregiver/doctor, also fetch real residents + real avatars
    if (!authState.isElder && token != null && token.isNotEmpty) {
      try {
        final res = await http
            .get(
              Uri.parse('${AppConfig.backendBaseUrl}/api/residents'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final list = decoded['data'] as List?;
          if (list != null && list.isNotEmpty) {
            final items = <CallContactItem>[];
            for (final raw in list) {
              final e = raw as Map<String, dynamic>;
              final rHomeId = (e['elderHomeId'] as num?)?.toInt();
              if (rHomeId != null && rHomeId != homeId) continue;
              final name = (e['name']?.toString() ?? 'Resident').trim();
              final room = (e['roomNumber']?.toString() ?? '').trim();
              final age = (e['age'] as num?)?.toInt();
              final gender = (e['gender']?.toString() ?? '').trim();
              final av = e['avatarUrl']?.toString().trim();
              final realAvatar = (av != null && av.isNotEmpty) ? av : null;
              if (realAvatar != null) {
                avatarMap[name.toLowerCase()] = realAvatar;
              }
              items.add(
                CallContactItem(
                  id: 'RES-${e['id']}',
                  name: name,
                  roleOrRoom: room.isNotEmpty ? 'Room $room' : 'Resident',
                  subtitle: '${age != null ? 'Age: $age' : ''}${gender.isNotEmpty ? ' • $gender' : ''}'.trim(),
                  phoneOrExt: room.isNotEmpty ? 'Intercom #$room' : 'Intercom',
                  whatsappNumber: '94760376031',
                  status: 'In Room',
                  statusColor: AppColors.riskLow,
                  icon: LucideIcons.user,
                  elderHomeId: homeId,
                  elderHomeName: e['elderHomeName']?.toString() ?? authState.elderHomeName,
                  avatarUrl: realAvatar,
                ),
              );
            }
            if (items.isNotEmpty) {
              fetchedResidents = items;
            }
          }
        }
      } catch (e) {
        debugPrint('CareStationHelpPage live residents fetch error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingLive = false;
        if (fetchedCaregivers != null) _liveHomeCaregivers = fetchedCaregivers;
        if (fetchedResidents != null) _liveHomeResidents = fetchedResidents;
        if (avatarMap.isNotEmpty) _liveAvatarsByName = avatarMap;
      });
    }
  }

  /// Returns ONLY a real uploaded profile picture URL/base64 from the database,
  /// or null so CarevoraAvatar renders clean colorful initials (no fake stock photos).
  String? _resolveAvatarUrl(CallContactItem contact, int index) {
    if (contact.avatarUrl != null && contact.avatarUrl!.trim().isNotEmpty) {
      return contact.avatarUrl!.trim();
    }
    final map = _liveAvatarsByName;
    if (map != null) {
      final exact = map[contact.name.toLowerCase()];
      if (exact != null && exact.isNotEmpty) return exact;
      final stripped = contact.name
          .toLowerCase()
          .replaceFirst(RegExp(r'^caregiver\s+'), '')
          .trim();
      final byStripped = map[stripped];
      if (byStripped != null && byStripped.isNotEmpty) return byStripped;
    }
    return null;
  }

  // Preset facility caregivers categorized strictly by Elder Home (matching database records)
  final List<CallContactItem> _facilityCaregivers = const [
    // Serenity Elder Home Registered Caregivers (ID: 3)
    CallContactItem(
      id: 'CG-207',
      name: 'Caregiver Sarangi',
      roleOrRoom: 'Care Coordinator',
      subtitle: 'General Elderly Care • On Duty',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'CG-238',
      name: 'Caregiver Pasidi Sarangi',
      roleOrRoom: 'Assigned Primary Caregiver',
      subtitle: 'Care Coordinator • General Elderly Care',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'CG-369',
      name: 'Caregiver Maya Ekanayaka',
      roleOrRoom: 'Care Coordinator',
      subtitle: 'General Elderly Care • On Duty',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'CG-398',
      name: 'Caregiver Indika Perera',
      roleOrRoom: 'Care Coordinator',
      subtitle: 'General Elderly Care • Active',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • Active',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'CG-399',
      name: 'Caregiver Malini Silva',
      roleOrRoom: 'Care Coordinator',
      subtitle: 'General Elderly Care • On Duty',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),

    // Serene Valley Senior Living Registered Caregivers (ID: 1)
    CallContactItem(
      id: 'CG-101',
      name: 'Caregiver Eleanor Vance',
      roleOrRoom: 'Lead Care Coordinator',
      subtitle: 'Senior Behavioral Health • On Duty',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 1,
      elderHomeName: 'Serene Valley Senior Living',
    ),
    CallContactItem(
      id: 'CG-TEST-99',
      name: 'Caregiver Florence Nightingale',
      roleOrRoom: 'Senior Charge Nurse',
      subtitle: 'Palliative & Wellness Care • Active',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • Active',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 1,
      elderHomeName: 'Serene Valley Senior Living',
    ),
    CallContactItem(
      id: 'CG-CLARA-1',
      name: 'Caregiver Clara Barton',
      roleOrRoom: 'Staff Care Coordinator',
      subtitle: 'Elder Emotional Wellness • On Duty',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 1,
      elderHomeName: 'Serene Valley Senior Living',
    ),

    // Golden Sunset Eldercare Registered Caregivers (ID: 2)
    CallContactItem(
      id: 'CG-202',
      name: 'Caregiver David Silva',
      roleOrRoom: 'Senior Care Specialist',
      subtitle: 'Active Living Support • On Duty',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 2,
      elderHomeName: 'Golden Sunset Eldercare',
    ),
    CallContactItem(
      id: 'CG-203',
      name: 'Caregiver Kamala Jayawardena',
      roleOrRoom: 'Care Coordinator',
      subtitle: 'Resident Wellbeing Specialist • On Duty',
      phoneOrExt: '+94 76 037 6031',
      whatsappNumber: '94760376031',
      status: 'Available • On Duty',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.userCheck,
      elderHomeId: 2,
      elderHomeName: 'Golden Sunset Eldercare',
    ),
  ];

  int _getResolvedElderHomeId(AuthState authState) {
    int? resolvedHomeId = authState.elderHomeId;

    final homeName = authState.elderHomeName?.toLowerCase().trim() ?? '';
    if (homeName.isNotEmpty) {
      if (homeName.contains('serenity')) {
        resolvedHomeId = 3;
      } else if (homeName.contains('golden')) {
        resolvedHomeId = 2;
      } else if (homeName.contains('serene')) {
        resolvedHomeId = 1;
      }
    }

    if (resolvedHomeId == null) {
      final resId = authState.residentId;
      final userName = authState.userName?.toLowerCase().trim() ?? '';
      final email = authState.email?.toLowerCase().trim() ?? '';

      if (resId == 1 || resId == 2 || userName.contains('sarah') || userName.contains('arthur') || userName.contains('eleanor') || email.contains('sarah') || email.contains('eleanor')) {
        resolvedHomeId = 1;
      } else if (resId == 3 || resId == 4 || userName.contains('margaret') || userName.contains('david') || email.contains('margaret') || email.contains('david')) {
        resolvedHomeId = 2;
      } else if (resId == 5 || resId == 30 || resId == 165 || resId == 300 || userName.contains('malini') || userName.contains('pasidi') || userName.contains('sarangi') || email.contains('mb@') || email.contains('ps@') || email.contains('serenity')) {
        resolvedHomeId = 3;
      }
    }

    return resolvedHomeId ?? 3;
  }

  List<CallContactItem> _getElderCaregivers(AuthState authState) {
    if (_liveHomeCaregivers != null && _liveHomeCaregivers!.isNotEmpty) {
      return _liveHomeCaregivers!;
    }
    final finalHomeId = _getResolvedElderHomeId(authState);
    return _facilityCaregivers.where((cg) => cg.elderHomeId == finalHomeId).toList();
  }

  List<CallContactItem> _getOtherCaregivers(AuthState authState) {
    final homeId = _getResolvedElderHomeId(authState);
    final source = (_liveHomeCaregivers != null && _liveHomeCaregivers!.isNotEmpty)
        ? _liveHomeCaregivers!
        : _facilityCaregivers.where((cg) => cg.elderHomeId == homeId).toList();
    final currentUserName = authState.userName?.toLowerCase().trim() ?? '';
    final currentClean = currentUserName.replaceAll('caregiver', '').trim();

    final filtered = source.where((cg) {
      if (currentClean.isNotEmpty) {
        final cgNameClean = cg.name.toLowerCase().replaceAll('caregiver', '').trim();
        if (cgNameClean == currentClean) {
          return false;
        }
      }
      return true;
    }).toList();

    return filtered.isEmpty ? source : filtered;
  }

  final List<CallContactItem> _elderDoctors = const [
    CallContactItem(
      id: 'DOC-1',
      name: 'Dr. Nimal Fernando',
      roleOrRoom: 'Geriatric Specialist & Medical Lead',
      subtitle: 'Attending Physician • Weekly Review',
      phoneOrExt: '+94 77 123 4567',
      whatsappNumber: '94771234567',
      status: 'On Call Today',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.stethoscope,
    ),
    CallContactItem(
      id: 'DOC-2',
      name: 'Dr. Kasun Jayasinghe',
      roleOrRoom: 'Neurology Specialist',
      subtitle: 'Cognitive Health Consultant',
      phoneOrExt: '+94 71 987 6543',
      whatsappNumber: '94719876543',
      status: 'Available for Urgent Calls',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.brain,
    ),
    CallContactItem(
      id: 'DOC-3',
      name: 'Dr. Sanduni Wijesinghe',
      roleOrRoom: 'General Care Physician',
      subtitle: 'Resident Wellness Consultant',
      phoneOrExt: '+94 72 345 6789',
      whatsappNumber: '94723456789',
      status: 'Consulting Desk',
      statusColor: AppColors.primary,
      icon: LucideIcons.stethoscope,
    ),
  ];

  // Preset data for Caregivers to call Elders (Residents), strictly categorized by Elder Home
  final List<CallContactItem> _caregiverResidents = const [
    // Serene Valley Senior Living (ID: 1)
    CallContactItem(
      id: 'RES-101',
      name: 'Sarah Jenkins',
      roleOrRoom: 'Room 101 • Suite 204',
      subtitle: 'Age: 78 • Female',
      phoneOrExt: 'Intercom #101',
      whatsappNumber: '94760376031',
      status: 'In Room • Resting',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 1,
      elderHomeName: 'Serene Valley Senior Living',
    ),
    CallContactItem(
      id: 'RES-102',
      name: 'Arthur Pendelton',
      roleOrRoom: 'Room 102 • Suite 112',
      subtitle: 'Age: 82 • Male',
      phoneOrExt: 'Intercom #102',
      whatsappNumber: '94760376031',
      status: 'Activity Hall',
      statusColor: AppColors.primary,
      icon: LucideIcons.user,
      elderHomeId: 1,
      elderHomeName: 'Serene Valley Senior Living',
    ),
    CallContactItem(
      id: 'RES-106',
      name: 'Clara Oswald',
      roleOrRoom: 'Room 106 • Suite B',
      subtitle: 'Age: 78 • Female',
      phoneOrExt: 'Intercom #106',
      whatsappNumber: '94760376031',
      status: 'In Room',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 1,
      elderHomeName: 'Serene Valley Senior Living',
    ),

    // Golden Sunset Eldercare (ID: 2)
    CallContactItem(
      id: 'RES-201',
      name: 'Margaret Chen',
      roleOrRoom: 'Room 201 • Suite 305',
      subtitle: 'Age: 79 • Female',
      phoneOrExt: 'Intercom #201',
      whatsappNumber: '94760376031',
      status: 'Activity Lounge',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 2,
      elderHomeName: 'Golden Sunset Eldercare',
    ),
    CallContactItem(
      id: 'RES-202',
      name: 'Robert Hastings',
      roleOrRoom: 'Room 202 • Suite 108',
      subtitle: 'Age: 84 • Male',
      phoneOrExt: 'Intercom #202',
      whatsappNumber: '94760376031',
      status: 'Garden Walk',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 2,
      elderHomeName: 'Golden Sunset Eldercare',
    ),
    CallContactItem(
      id: 'RES-104',
      name: 'Robert Chen',
      roleOrRoom: 'Room 104 • Suite C',
      subtitle: 'Age: 75 • Male',
      phoneOrExt: 'Intercom #104',
      whatsappNumber: '94760376031',
      status: 'In Room',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 2,
      elderHomeName: 'Golden Sunset Eldercare',
    ),

    // Serenity Elder Home (ID: 3)
    CallContactItem(
      id: 'RES-105',
      name: 'James Perera',
      roleOrRoom: 'Room 105 • North Wing',
      subtitle: 'Age: 82 • Male',
      phoneOrExt: 'Intercom #105',
      whatsappNumber: '94760376031',
      status: 'In Room • Monitored',
      statusColor: AppColors.riskModerate,
      icon: LucideIcons.user,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'RES-30',
      name: 'Malini Bandara',
      roleOrRoom: 'Room 30 • East Wing',
      subtitle: 'Age: 65 • Female',
      phoneOrExt: 'Intercom #030',
      whatsappNumber: '94760376031',
      status: 'In Room • Relaxed',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'RES-107',
      name: 'Harold Finch',
      roleOrRoom: 'Room 107 • Suite D',
      subtitle: 'Age: 85 • Male',
      phoneOrExt: 'Intercom #107',
      whatsappNumber: '94760376031',
      status: 'Reading Lounge',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'RES-108',
      name: 'Beatrice Potter',
      roleOrRoom: 'Room 108 • South Wing',
      subtitle: 'Age: 91 • Female',
      phoneOrExt: 'Intercom #108',
      whatsappNumber: '94760376031',
      status: 'In Room • Vitals Due',
      statusColor: AppColors.riskModerate,
      icon: LucideIcons.user,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
    CallContactItem(
      id: 'RES-301',
      name: 'Simon Perera',
      roleOrRoom: 'Room 301 • Suite A',
      subtitle: 'Age: 76 • Male',
      phoneOrExt: 'Intercom #301',
      whatsappNumber: '94760376031',
      status: 'Garden Courtyard',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.user,
      elderHomeId: 3,
      elderHomeName: 'Serenity Elder Home',
    ),
  ];

  List<CallContactItem> _getCaregiverResidents(AuthState authState) {
    if (_liveHomeResidents != null && _liveHomeResidents!.isNotEmpty) {
      return _liveHomeResidents!;
    }
    final homeId = _getResolvedElderHomeId(authState);
    return _caregiverResidents.where((r) => r.elderHomeId == homeId).toList();
  }

  final List<CallContactItem> _caregiverStations = const [
    CallContactItem(
      id: 'ST-1',
      name: 'Nurse Station 1 (South Wing Desk)',
      roleOrRoom: 'Emergency Intercom',
      subtitle: 'Lead Nurse on duty: Dilani K. • Floor 1',
      phoneOrExt: 'Ext. 101',
      status: 'Active 24/7',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.radio,
    ),
    CallContactItem(
      id: 'ST-2',
      name: 'Nurse Station 2 (North Wing Central)',
      roleOrRoom: 'Emergency Intercom',
      subtitle: 'Central Medical Dispatch • Floor 2',
      phoneOrExt: 'Ext. 102',
      status: 'Active 24/7',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.radio,
    ),
    CallContactItem(
      id: 'ST-3',
      name: 'Critical Care & Clinic Room',
      roleOrRoom: 'Doctor Consultation Suite',
      subtitle: 'Emergency Resuscitation & Observation',
      phoneOrExt: 'Ext. 999',
      status: 'Emergency Standby',
      statusColor: AppColors.riskHigh,
      icon: LucideIcons.shieldAlert,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLaunchToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.phoneCall, size: 16, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF065F46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _extractInitials(String rawName) {
    final cleaned = rawName
        .replaceAll(RegExp(r'^(Caregiver|Dr\.|Nurse)\s+', caseSensitive: false), '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'CG';
    if (parts.length == 1) {
      return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  List<Color> _avatarGradientFor(int index) {
    const palettes = [
      [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      [Color(0xFF0D9488), Color(0xFF10B981)],
      [Color(0xFFDB2777), Color(0xFFF43F5E)],
      [Color(0xFF2563EB), Color(0xFF06B6D4)],
      [Color(0xFFD97706), Color(0xFFF97316)],
    ];
    return palettes[index % palettes.length];
  }

  String _localizeContactName(CallContactItem c, bool isSi) {
    if (!isSi) return c.name;
    final lower = c.name.toLowerCase();
    if (lower.startsWith('caregiver ')) {
      final rest = c.name.substring('caregiver '.length).trim();
      return 'සත්කාරක ${SinhalaNameTransliterator.toSinhala(rest, fallback: rest)}';
    }
    if (lower.startsWith('dr. ')) {
      final rest = c.name.substring('dr. '.length).trim();
      return 'වෛද්‍ය ${SinhalaNameTransliterator.toSinhala(rest, fallback: rest)}';
    }
    if (lower.contains('nurse station 1')) return 'හෙද මධ්‍යස්ථානය 1 (දකුණු අංශය)';
    if (lower.contains('nurse station 2')) return 'හෙද මධ්‍යස්ථානය 2 (උතුරු අංශය)';
    if (lower.contains('critical care')) return 'හදිසි ප්‍රතිකාර හා සායන කාමරය';
    return SinhalaNameTransliterator.toSinhala(c.name, fallback: c.name);
  }

  String _localizeRole(String role, bool isSi) {
    if (!isSi) return role;
    final lower = role.toLowerCase();
    if (lower.contains('primary caregiver') || lower.contains('care coordinator')) {
      return 'සත්කාර සම්බන්ධීකාරක';
    }
    if (lower.contains('charge nurse')) return 'ජ්‍යෙෂ්ඨ හෙද නිලධාරී';
    if (lower.contains('care specialist')) return 'වැඩිහිටි සත්කාර නිලධාරී';
    if (lower.contains('geriatric')) return 'වැඩිහිටි රෝග විශේෂඥ වෛද්‍ය';
    if (lower.contains('neurology')) return 'ස්නායු රෝග විශේෂඥ වෛද්‍ය';
    if (lower.contains('general care physician')) return 'සාමාන්‍ය වෛද්‍ය නිලධාරී';
    if (lower.contains('emergency intercom')) return 'හදිසි ඉන්ටර්කොම් සේවාව';
    if (lower.contains('doctor consultation')) return 'වෛද්‍ය උපදේශන අංශය';
    if (lower.startsWith('room ')) {
      return role.replaceFirst('Room ', 'කාමරය ');
    }
    return role;
  }

  String _localizeStatus(String status, bool isSi) {
    if (!isSi) return status;
    final lower = status.toLowerCase();
    if (lower.contains('on duty')) return 'සේවයේ ඇත';
    if (lower.contains('active 24/7')) return 'පැය 24ම සක්‍රීයයි';
    if (lower.contains('active')) return 'සක්‍රීයව සේවයේ';
    if (lower.contains('emergency')) return 'හදිසි සූදානම';
    if (lower.contains('urgent')) return 'හදිසි ඇමතුම් සඳහා';
    if (lower.contains('on call')) return 'අද සේවයේ';
    if (lower.contains('consulting')) return 'උපදේශන අංශය';
    if (lower.contains('resting')) return 'කාමරයේ විවේකයෙන්';
    if (lower.contains('relaxed')) return 'කාමරයේ සැහැල්ලුවෙන්';
    if (lower.contains('monitored')) return 'නිරීක්ෂණය යටතේ';
    if (lower.contains('vitals')) return 'පරීක්ෂාවට සූදානම්';
    if (lower.contains('garden')) return 'උද්‍යානයේ';
    if (lower.contains('reading')) return 'කියවීම් කාමරයේ';
    if (lower.contains('activity')) return 'ක්‍රියාකාරකම් ශාලාවේ';
    if (lower.contains('in room')) return 'කාමරයේ';
    return status;
  }

  String _localizeSubtitle(String subtitle, bool isSi) {
    if (!isSi) return subtitle;
    final lower = subtitle.toLowerCase();
    if (lower.contains('general elderly care')) return 'වැඩිහිටි සත්කාර සේවාව • සේවයේ ඇත';
    if (lower.contains('behavioral health')) return 'වැඩිහිටි මානසික සෞඛ්‍ය සත්කාර';
    if (lower.contains('palliative')) return 'සුවතා සහ හෙද සත්කාර';
    if (lower.contains('emotional wellness')) return 'මානසික සුවතා සහාය';
    if (lower.contains('active living')) return 'දෛනික සුවතා සහාය';
    if (lower.contains('wellbeing specialist')) return 'නේවාසික සුවතා සහාය';
    if (lower.contains('attending physician')) return 'වෛද්‍ය නිලධාරී • සතිපතා පරීක්ෂාව';
    if (lower.contains('cognitive health')) return 'මතක සෞඛ්‍ය උපදේශක';
    if (lower.contains('resident wellness')) return 'නේවාසික සුවතා වෛද්‍ය';
    if (lower.contains('lead nurse')) return 'ප්‍රධාන හෙද නිලධාරී • 1 වන මහල';
    if (lower.contains('central medical')) return 'මධ්‍යම වෛද්‍ය සම්බන්ධීකරණය • 2 වන මහල';
    if (lower.contains('resuscitation')) return 'හදිසි ප්‍රතිකාර හා නිරීක්ෂණ';
    if (lower.startsWith('age:')) {
      return subtitle
          .replaceFirst('Age:', 'වයස:')
          .replaceAll('Female', 'ස්ත්‍රී')
          .replaceAll('Male', 'පුරුෂ');
    }
    return subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final resolvedHomeId = _getResolvedElderHomeId(authState);
    if (_hasRequestedLiveSync != true ||
        (_loadedForHomeId != null && _loadedForHomeId != resolvedHomeId)) {
      _hasRequestedLiveSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchLiveDirectoryAvatars();
      });
    }
    final isSi = ref.watch(languageProvider).isSinhala;
    final isElder = authState.isElder;
    final elderCaregivers = _getElderCaregivers(authState);

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: _CareStationAmbientBackdrop(),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                        authState: authState,
                        isElder: isElder,
                        isSi: isSi,
                        onDutyCount: elderCaregivers.length,
                      ),
                      const SizedBox(height: 20),
                      if (isElder) ...[
                        _buildElderView(authState, elderCaregivers, isSi),
                      ] else ...[
                        _buildCaregiverView(authState, isSi),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required AuthState authState,
    required bool isElder,
    required bool isSi,
    required int onDutyCount,
  }) {
    final homeName = authState.elderHomeName ??
        (isSi ? 'සත්කාර නිවස' : 'Care Home');

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
          final isCompact = constraints.maxWidth < 680;

          final leftInfo = Column(
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
                    const Icon(LucideIcons.heartHandshake, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isSi
                            ? 'පැය 24 සත්කාර සහාය • $homeName'
                            : '24/7 CARE SUPPORT • $homeName',
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                    ),
                    child: const Icon(
                      LucideIcons.phoneCall,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      isElder
                          ? (isSi ? 'සහාය සහ ඇමතුම්' : 'Caregiver & Station Help')
                          : (isSi
                              ? 'සත්කාර මධ්‍යස්ථානය සහ ඇමතුම්'
                              : 'Care Station & Emergency Calls'),
                      style: const TextStyle(
                        fontSize: 23,
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
                isElder
                    ? (isSi
                        ? 'ඔබට උදව්වක් අවශ්‍ය ඕනෑම වෙලාවක ඔබේ සත්කාර නිවසේ සත්කාරකයින් අමතන්න.'
                        : 'Contact any caregiver at your care home whenever you need friendly assistance.')
                    : (isSi
                        ? 'නේවාසිකයින්, සත්කාර කණ්ඩායම සහ වෛද්‍යවරුන් වෙත ක්ෂණික හඬ ඇමතුම් ලබා ගන්න.'
                        : 'Immediate direct voice and WhatsApp calling to residents, fellow caregivers, and on-call doctors.'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
            ],
          );

          final statusPill = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingLive == true && _liveHomeCaregivers == null)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF059669),
                        ),
                      )
                    else
                      const _PulsingStatusDot(color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Text(
                      isSi
                          ? '$onDutyCount දෙනෙක් සේවයේ'
                          : '$onDutyCount Caregivers On Duty',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _isLoadingLive == true
                      ? null
                      : () => _fetchLiveDirectoryAvatars(force: true),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoadingLive == true)
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
                            Icons.refresh_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
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
                leftInfo,
                const SizedBox(height: 14),
                statusPill,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: leftInfo),
              const SizedBox(width: 18),
              statusPill,
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ELDER VIEW: All Caregivers in the Elder's Care Home (Equal 2-Column Grid)
  // --------------------------------------------------------------------------
  Widget _buildElderView(
    AuthState authState,
    List<CallContactItem> caregivers,
    bool isSi,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warm Reassurance / Quick Guide Strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFF5F3FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(
                  LucideIcons.phoneCall,
                  size: 19,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSi
                          ? 'උදව්වක් අවශ්‍යද? එක බොත්තමකින් අමතන්න'
                          : 'Need Help? Connect in One Tap',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSi
                          ? 'පහත සිටින ඕනෑම සත්කාරකයෙකුගේ "ඇමතුමක් ගන්න" බොත්තම ඔබා කෙලින්ම කතා කරන්න.'
                          : 'Tap "Start Voice Call" on any caregiver below — our team is always ready to assist you.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF047857),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Heading
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.users, color: AppColors.primaryDeep, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSi
                    ? 'ඔබේ සත්කාරකයින් (${caregivers.length})'
                    : (caregivers.length > 1
                        ? 'My Assigned Caregivers (${caregivers.length})'
                        : 'My Assigned Caregiver'),
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Responsive 2-Column Modern Caregiver Cards Grid (All Caregivers Equal)
        LayoutBuilder(
          builder: (context, constraints) {
            final int cols = constraints.maxWidth >= 720 ? 2 : 1;
            final List<Widget> rows = [];
            for (int i = 0; i < caregivers.length; i += cols) {
              final rowChildren = <Widget>[];
              for (int j = 0; j < cols; j++) {
                final idx = i + j;
                if (j > 0) rowChildren.add(const SizedBox(width: 16));
                if (idx < caregivers.length) {
                  rowChildren.add(
                    Expanded(
                      child: _buildElderCaregiverCard(
                        caregivers[idx],
                        index: idx,
                        isSi: isSi,
                      ),
                    ),
                  );
                } else {
                  rowChildren.add(const Expanded(child: SizedBox.shrink()));
                }
              }
              if (i > 0) rows.add(const SizedBox(height: 16));
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowChildren,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            );
          },
        ),
      ],
    );
  }

  Widget _buildElderCaregiverCard(
    CallContactItem contact, {
    required int index,
    required bool isSi,
  }) {
    final gradientColors = _avatarGradientFor(index);
    final initials = _extractInitials(contact.name);
    final avatarUrl = _resolveAvatarUrl(contact, index);
    final displayName = _localizeContactName(contact, isSi);
    final displayRole = _localizeRole(contact.roleOrRoom, isSi);
    final displayStatus = _localizeStatus(contact.status, isSi);
    final displaySubtitle =
        contact.subtitle != null ? _localizeSubtitle(contact.subtitle!, isSi) : null;

    return _HoverCareCard(
      accentColor: gradientColors.first,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFAF9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4E0F7), width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtle top gradient accent strip
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Real Caregiver Profile Photo inside glowing ring + Live Green Online Dot
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradientColors.first.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: CarevoraAvatar(
                                  avatarUrl: avatarUrl,
                                  radius: 26,
                                  initials: initials,
                                  backgroundColor: gradientColors.first,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: _PulsingStatusDot(color: contact.statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: contact.statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: contact.statusColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: contact.statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      displayStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: contact.statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                displayRole,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: gradientColors.first,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (displaySubtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  displaySubtitle,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Big, Clear Elder-Friendly Voice Call CTA (Direct WhatsApp Launch — No Fake Modal)
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          onTap: () {
                            final wpNumber = contact.whatsappNumber ?? contact.phoneOrExt;
                            final auth = ref.read(authProvider).state;
                            final rawElderName = auth.userName?.trim() ?? '';
                            final hasElderName =
                                rawElderName.isNotEmpty && rawElderName != '-';
                            final elderLabel = hasElderName
                                ? (isSi
                                    ? SinhalaNameTransliterator.toSinhala(
                                        rawElderName,
                                        fallback: rawElderName,
                                      )
                                    : rawElderName)
                                : '';
                            final homeLabel = (auth.elderHomeName ?? '').trim();
                            final homeSuffix =
                                homeLabel.isNotEmpty ? ' ($homeLabel)' : '';
                            final msg = isSi
                                ? (hasElderName
                                    ? 'ආයුබෝවන් $displayName, මම $elderLabel$homeSuffix. මට පොඩි උදව්වක් අවශ්‍යයි — පුළුවන් වෙලාවට මට කතා කරන්න හෝ මාව බලන්න පුළුවන්ද?'
                                    : 'ආයුබෝවන් $displayName, මට පොඩි උදව්වක් අවශ්‍යයි — පුළුවන් වෙලාවට මට කතා කරන්න පුළුවන්ද?')
                                : (hasElderName
                                    ? 'Hello ${contact.name}, this is $elderLabel$homeSuffix. I need a little help — could you please call me or check in when you can?'
                                    : 'Hello ${contact.name}, I need a little help — could you please call me or check in when you can?');
                            UrlLauncherService.launchWhatsApp(wpNumber, msg);
                            _showLaunchToast(
                              isSi
                                  ? '$displayName සඳහා WhatsApp විවෘත වෙමින්...'
                                  : 'Opening WhatsApp to call $displayName...',
                            );
                          },
                          borderRadius: BorderRadius.circular(13),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.phoneCall, size: 17, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  isSi ? 'ඇමතුමක් ගන්න' : 'Start Voice Call',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  // --------------------------------------------------------------------------
  // CAREGIVER VIEW: Call Elders & Other Caregivers in Assigned Elder Home
  // --------------------------------------------------------------------------
  Widget _buildCaregiverView(AuthState authState, bool isSi) {
    final residents = _getCaregiverResidents(authState);
    final otherCaregivers = _getOtherCaregivers(authState);

    final activeTab = _caregiverSelectedTab > 2 ? 0 : _caregiverSelectedTab;
    List<CallContactItem> currentList;
    if (activeTab == 0) {
      currentList = residents;
    } else if (activeTab == 1) {
      currentList = otherCaregivers;
    } else {
      currentList = _elderDoctors;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      currentList = currentList.where((item) {
        final siName = _localizeContactName(item, true).toLowerCase();
        return item.name.toLowerCase().contains(q) ||
            siName.contains(q) ||
            item.roleOrRoom.toLowerCase().contains(q) ||
            item.phoneOrExt.toLowerCase().contains(q) ||
            (item.subtitle != null && item.subtitle!.toLowerCase().contains(q));
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab selector (Residents, Team Caregivers, Doctors)
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
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
              Expanded(
                child: _buildSegmentButton(
                  index: 0,
                  label: isSi ? 'නේවාසිකයින්' : 'Call Residents',
                  icon: LucideIcons.users,
                  count: residents.length,
                ),
              ),
              Expanded(
                child: _buildSegmentButton(
                  index: 1,
                  label: isSi ? 'සත්කාර කණ්ඩායම' : 'Team Caregivers',
                  icon: LucideIcons.userCheck,
                  count: otherCaregivers.length,
                ),
              ),
              Expanded(
                child: _buildSegmentButton(
                  index: 2,
                  label: isSi ? 'වෛද්‍යවරු' : 'Call Doctors',
                  icon: LucideIcons.stethoscope,
                  count: _elderDoctors.length,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: activeTab == 0
                ? (isSi
                    ? 'නේවාසිකයාගේ නම හෝ කාමර අංකය සොයන්න...'
                    : 'Search resident name or room number (e.g. James Perera, 105)...')
                : (activeTab == 1
                    ? (isSi
                        ? 'සත්කාරකයාගේ නම සොයන්න...'
                        : 'Search caregiver name or role (e.g. Sarangi, Maya)...')
                    : (isSi
                        ? 'වෛද්‍යවරයාගේ නම හෝ අංශය සොයන්න...'
                        : 'Search doctor by name or specialty (e.g. Dr. Nimal, Neurology)...')),
            prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.muted),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (currentList.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.phoneOff, size: 36, color: AppColors.muted),
                const SizedBox(height: 12),
                Text(
                  isSi
                      ? '"$_searchQuery" සඳහා ගැලපෙන සම්බන්ධතා හමු නොවීය'
                      : 'No matching contacts found for "$_searchQuery"',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  isSi
                      ? 'වෙනත් නමක් හෝ කාමර අංකයක් උත්සාහ කරන්න'
                      : 'Try another name, room number, or extension',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final int cols = constraints.maxWidth >= 720 ? 2 : 1;
              final List<Widget> rows = [];
              for (int i = 0; i < currentList.length; i += cols) {
                final rowChildren = <Widget>[];
                for (int j = 0; j < cols; j++) {
                  final idx = i + j;
                  if (j > 0) rowChildren.add(const SizedBox(width: 16));
                  if (idx < currentList.length) {
                    rowChildren.add(
                      Expanded(
                        child: _buildContactCard(
                          currentList[idx],
                          index: idx,
                          isSi: isSi,
                        ),
                      ),
                    );
                  } else {
                    rowChildren.add(const Expanded(child: SizedBox.shrink()));
                  }
                }
                if (i > 0) rows.add(const SizedBox(height: 16));
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rowChildren,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows,
              );
            },
          ),
      ],
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required IconData icon,
    required int count,
  }) {
    final isSelected = _caregiverSelectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _caregiverSelectedTab = index;
          _searchController.clear();
          _searchQuery = '';
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.24),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.body,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.24)
                    : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.primaryDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
    CallContactItem contact, {
    required int index,
    required bool isSi,
  }) {
    final gradientColors = _avatarGradientFor(index);
    final initials = _extractInitials(contact.name);
    final avatarUrl = _resolveAvatarUrl(contact, index);
    final displayName = _localizeContactName(contact, isSi);
    final displayRole = _localizeRole(contact.roleOrRoom, isSi);
    final displayStatus = _localizeStatus(contact.status, isSi);
    final displaySubtitle =
        contact.subtitle != null ? _localizeSubtitle(contact.subtitle!, isSi) : null;
    final activeTab = _caregiverSelectedTab > 2 ? 0 : _caregiverSelectedTab;
    final wpNumber = (contact.whatsappNumber != null && contact.whatsappNumber!.isNotEmpty)
        ? contact.whatsappNumber!
        : contact.phoneOrExt.replaceAll(RegExp(r'[^0-9]'), '');

    String buildWhatsAppMessage() {
      final cleanEn = contact.name.trim();
      final hasRealName = cleanEn.isNotEmpty && cleanEn != '-';
      final targetName = hasRealName ? (isSi ? displayName : cleanEn) : '';
      final authName = ref.read(authProvider).state.userName?.trim() ?? '';
      final senderEn = authName.isNotEmpty ? authName : 'your caregiver';

      if (activeTab == 0) {
        // Caregiver checking in on an Elder (Resident)
        if (isSi) {
          return hasRealName
              ? 'ආයුබෝවන් $targetName, මම Carevora සත්කාර කණ්ඩායමෙන් කතා කරන්නේ. ඔබ අද කොහොමද? ඔබට කිසියම් උදව්වක් අවශ්‍ය නම් දන්වන්න.'
              : 'ආයුබෝවන්, මම Carevora සත්කාර කණ්ඩායමෙන් කතා කරන්නේ. ඔබ අද කොහොමද? ඔබට කිසියම් උදව්වක් අවශ්‍ය නම් දන්වන්න.';
        }
        return hasRealName
            ? 'Hello $targetName, this is $senderEn from Carevora checking in on you. How are you feeling today? Please let me know if you need anything.'
            : 'Hello, this is $senderEn from Carevora checking in on you. How are you feeling today? Please let me know if you need anything.';
      } else if (activeTab == 1) {
        // Caregiver contacting a fellow Team Caregiver
        if (isSi) {
          return 'ආයුබෝවන් $targetName, මම Carevora සත්කාර කණ්ඩායමෙන්. නේවාසික සත්කාර කටයුත්තක් පිළිබඳව කතා කරන්න පුළුවන්ද?';
        }
        return 'Hello $targetName, this is $senderEn from Carevora. Could we coordinate on resident care when you have a moment?';
      } else {
        // Caregiver contacting a Doctor
        if (isSi) {
          return 'ආයුබෝවන් $targetName, මම Carevora සත්කාර කණ්ඩායමෙන්. නේවාසිකයෙකුගේ සෞඛ්‍ය තත්ත්වය පිළිබඳව වෛද්‍ය උපදෙසක් අවශ්‍යයි.';
        }
        return 'Hello $targetName, this is $senderEn from Carevora requesting a quick clinical consultation regarding a resident.';
      }
    }

    return _HoverCareCard(
      accentColor: gradientColors.first,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFAF9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4E0F7), width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Matching top gradient accent strip
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Glowing gradient halo + real DB CarevoraAvatar + live pulsing dot
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradientColors.first.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: CarevoraAvatar(
                                  avatarUrl: avatarUrl,
                                  radius: 26,
                                  initials: initials,
                                  backgroundColor: gradientColors.first,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: _PulsingStatusDot(color: contact.statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: contact.statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: contact.statusColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: contact.statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      displayStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: contact.statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                displayRole,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: gradientColors.first,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (displaySubtitle != null && displaySubtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  contact.phoneOrExt.isNotEmpty
                                      ? '$displaySubtitle • ${contact.phoneOrExt}'
                                      : displaySubtitle,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else if (contact.phoneOrExt.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  contact.phoneOrExt,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Full-width green WhatsApp button only (Voice Call removed per request)
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          onTap: () {
                            UrlLauncherService.launchWhatsApp(
                              wpNumber,
                              buildWhatsAppMessage(),
                            );
                            _showLaunchToast(
                              isSi
                                  ? '$displayName සඳහා WhatsApp විවෘත වෙමින්...'
                                  : 'Opening WhatsApp for $displayName...',
                            );
                          },
                          borderRadius: BorderRadius.circular(13),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.24),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.messageCircle, size: 17, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
}

// --------------------------------------------------------------------------
// PULSING ONLINE STATUS DOT
// --------------------------------------------------------------------------
class _PulsingStatusDot extends StatefulWidget {
  final Color color;

  const _PulsingStatusDot({required this.color});

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.25 + _ctrl.value * 0.45),
                  blurRadius: 4 + _ctrl.value * 5,
                  spreadRadius: _ctrl.value * 2,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------------------
// SUBTLE HOVER LIFT WRAPPER FOR CAREGIVER / CONTACT CARDS
// --------------------------------------------------------------------------
class _HoverCareCard extends StatefulWidget {
  final Color accentColor;
  final Widget child;

  const _HoverCareCard({
    required this.accentColor,
    required this.child,
  });

  @override
  State<_HoverCareCard> createState() => _HoverCareCardState();
}

class _HoverCareCardState extends State<_HoverCareCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -4.5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF312E81).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}

// --------------------------------------------------------------------------
// CALM CALL-THEMED SOUNDWAVE & CARE SPARKLE AMBIENT BACKDROP (BEHIND CARDS)
// --------------------------------------------------------------------------
class _CareStationAmbientBackdrop extends StatefulWidget {
  const _CareStationAmbientBackdrop();

  @override
  State<_CareStationAmbientBackdrop> createState() =>
      _CareStationAmbientBackdropState();
}

class _CareStationAmbientBackdropState
    extends State<_CareStationAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
            painter: _CareStationAmbientPainter(t: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CareStationAmbientPainter extends CustomPainter {
  final double t;

  const _CareStationAmbientPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double angle = t * 2 * math.pi;

    // 1. Soft breathing pastel aurora glows in the corners
    _drawOrb(
      canvas,
      Offset(size.width * 0.05 + math.sin(angle) * 24, size.height * 0.16 + math.cos(angle) * 18),
      210,
      const Color(0xFF7C3AED).withValues(alpha: 0.10),
    );
    _drawOrb(
      canvas,
      Offset(size.width * 0.95 + math.cos(angle) * 24, size.height * 0.22 + math.sin(angle) * 20),
      220,
      const Color(0xFF10B981).withValues(alpha: 0.11),
    );
    _drawOrb(
      canvas,
      Offset(size.width * 0.08 + math.cos(angle * 0.8) * 22, size.height * 0.85 + math.sin(angle) * 20),
      220,
      const Color(0xFF0D9488).withValues(alpha: 0.10),
    );
    _drawOrb(
      canvas,
      Offset(size.width * 0.93 + math.sin(angle * 0.9) * 22, size.height * 0.80 + math.cos(angle) * 22),
      215,
      const Color(0xFF6366F1).withValues(alpha: 0.09),
    );

    // 2. Expanding calm voice-call soundwave ripples along left & right outer edges
    _drawSoundwaveRipples(
      canvas,
      Offset(size.width * 0.025, size.height * 0.34),
      const Color(0xFF10B981),
      t,
    );
    _drawSoundwaveRipples(
      canvas,
      Offset(size.width * 0.975, size.height * 0.66),
      const Color(0xFF6366F1),
      (t + 0.45) % 1.0,
    );

    // 3. Soft acoustic sine ribbon along top & bottom edges
    _drawAcousticRibbon(
      canvas,
      size,
      yBase: 14,
      amplitude: 7,
      phase: angle,
      color: const Color(0xFF0D9488).withValues(alpha: 0.14),
    );
    _drawAcousticRibbon(
      canvas,
      size,
      yBase: size.height - 16,
      amplitude: 8,
      phase: -angle * 1.15,
      color: const Color(0xFF6366F1).withValues(alpha: 0.13),
    );

    // 4. Twinkling soft care sparkles along margins
    const specs = [
      (0.02, 0.15, 0.0, Color(0xFF10B981)),
      (0.98, 0.24, 0.25, Color(0xFF7C3AED)),
      (0.025, 0.62, 0.50, Color(0xFF6366F1)),
      (0.975, 0.48, 0.72, Color(0xFF0D9488)),
      (0.02, 0.84, 0.18, Color(0xFFEC4899)),
      (0.98, 0.86, 0.64, Color(0xFF10B981)),
    ];
    for (final s in specs) {
      final (rx, ry, shift, color) = s;
      final lt = (t + shift) % 1.0;
      final pulse = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(lt * 4 * math.pi));
      final c = Offset(
        size.width * rx + math.cos(lt * 2 * math.pi) * 4,
        size.height * ry + math.sin(lt * 2 * math.pi) * 10,
      );
      _drawSparkle(canvas, c, 5.0 + pulse * 3.0, color.withValues(alpha: 0.22 + pulse * 0.25));
    }
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawSoundwaveRipples(Canvas canvas, Offset center, Color color, double phase) {
    for (int i = 0; i < 3; i++) {
      final p = (phase + i * 0.33) % 1.0;
      final r = 16.0 + p * 86.0;
      final alpha = (1.0 - p) * 0.22;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: alpha),
      );
    }
    canvas.drawCircle(
      center,
      4.0,
      Paint()..color = color.withValues(alpha: 0.32),
    );
  }

  void _drawAcousticRibbon(
    Canvas canvas,
    Size size, {
    required double yBase,
    required double amplitude,
    required double phase,
    required Color color,
  }) {
    final path = Path();
    const steps = 40;
    for (int i = 0; i <= steps; i++) {
      final frac = i / steps;
      final x = size.width * frac;
      final y = yBase + math.sin(frac * 3.0 * math.pi + phase) * amplitude;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = color,
    );
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.18, c.dy - r * 0.18, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.18, c.dy + r * 0.18, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.18, c.dy + r * 0.18, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.18, c.dy - r * 0.18, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CareStationAmbientPainter oldDelegate) =>
      oldDelegate.t != t;
}
