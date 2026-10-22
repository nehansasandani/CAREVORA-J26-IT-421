import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/url_launcher_service.dart';
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
    final finalHomeId = _getResolvedElderHomeId(authState);
    return _facilityCaregivers.where((cg) => cg.elderHomeId == finalHomeId).toList();
  }

  List<CallContactItem> _getOtherCaregivers(AuthState authState) {
    final homeId = _getResolvedElderHomeId(authState);
    final currentUserName = authState.userName?.toLowerCase().trim() ?? '';
    final currentClean = currentUserName.replaceAll('caregiver', '').trim();

    final filtered = _facilityCaregivers.where((cg) {
      if (cg.elderHomeId != homeId) return false;
      if (currentClean.isNotEmpty) {
        final cgNameClean = cg.name.toLowerCase().replaceAll('caregiver', '').trim();
        // Exact match with logged-in user name
        if (cgNameClean == currentClean) {
          return false;
        }
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return _facilityCaregivers.where((cg) => cg.elderHomeId == homeId).toList();
    }
    return filtered;
  }

  final List<CallContactItem> _elderDoctors = const [
    CallContactItem(
      id: 'DOC-1',
      name: 'Dr. Nimal Fernando',
      roleOrRoom: 'Geriatric Specialist & Medical Lead',
      subtitle: 'Attending Physician • Weekly Review',
      phoneOrExt: '+94 77 123 4567',
      status: 'On Call Today',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.stethoscope,
    ),
    CallContactItem(
      id: 'DOC-2',
      name: 'Dr. Aris Thorne',
      roleOrRoom: 'Neurology Specialist',
      subtitle: 'Cognitive Health Consultant',
      phoneOrExt: '+94 71 987 6543',
      status: 'Available for Urgent Calls',
      statusColor: AppColors.riskLow,
      icon: LucideIcons.brain,
    ),
    CallContactItem(
      id: 'DOC-3',
      name: 'Dr. Samantha Reed',
      roleOrRoom: 'General Care Physician',
      subtitle: 'Resident Wellness Consultant',
      phoneOrExt: '+94 72 345 6789',
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

  void _triggerCallDialog(CallContactItem contact, {required bool isVideo}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ActiveCallModal(
        contact: contact,
        isVideo: isVideo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).state;
    final isElder = authState.isElder;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isElder),
              const SizedBox(height: 20),
              if (isElder) ...[
                _buildElderView(authState),
              ] else ...[
                _buildCaregiverView(authState),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isElder) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lilac, width: 1.2),
          ),
          child: const Icon(
            LucideIcons.phoneCall,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isElder
                    ? 'Caregiver & Station Help'
                    : 'Care Station & Emergency Calls',
                style: AppTextStyles.h2.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                isElder
                    ? 'Contact your assigned caregiver whenever you need assistance.'
                    : 'Immediate direct intercom and audio/video calling to residents, fellow caregivers, on-call doctors, and nurse stations.',
                style: AppTextStyles.caption.copyWith(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // ELDER VIEW: Call Caregivers belonging strictly to the Elder's Elder Home
  // --------------------------------------------------------------------------
  Widget _buildElderView(AuthState authState) {
    final caregivers = _getElderCaregivers(authState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assigned Caregiver
        Row(
          children: [
            const Icon(LucideIcons.heartHandshake, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              caregivers.length > 1 ? 'My Assigned Caregivers' : 'My Assigned Caregiver',
              style: AppTextStyles.h4.copyWith(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...caregivers.map((c) => _buildContactCard(c, isElder: true)),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // CAREGIVER VIEW: Call Elders & Other Caregivers in Assigned Elder Home
  // --------------------------------------------------------------------------
  Widget _buildCaregiverView(AuthState authState) {
    final residents = _getCaregiverResidents(authState);
    final otherCaregivers = _getOtherCaregivers(authState);

    List<CallContactItem> currentList;
    if (_caregiverSelectedTab == 0) {
      currentList = residents;
    } else if (_caregiverSelectedTab == 1) {
      currentList = otherCaregivers;
    } else if (_caregiverSelectedTab == 2) {
      currentList = _elderDoctors;
    } else {
      currentList = _caregiverStations;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      currentList = currentList.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.roleOrRoom.toLowerCase().contains(q) ||
            item.phoneOrExt.toLowerCase().contains(q) ||
            (item.subtitle != null && item.subtitle!.toLowerCase().contains(q));
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab selector
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  index: 0,
                  label: 'Call Residents (Elders)',
                  icon: LucideIcons.users,
                  count: residents.length,
                ),
              ),
              Expanded(
                child: _buildSegmentButton(
                  index: 1,
                  label: 'Team Caregivers',
                  icon: LucideIcons.userCheck,
                  count: otherCaregivers.length,
                ),
              ),
              Expanded(
                child: _buildSegmentButton(
                  index: 2,
                  label: 'Call Doctors',
                  icon: LucideIcons.stethoscope,
                  count: _elderDoctors.length,
                ),
              ),
              Expanded(
                child: _buildSegmentButton(
                  index: 3,
                  label: 'Duty Stations',
                  icon: LucideIcons.radio,
                  count: _caregiverStations.length,
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
            hintText: _caregiverSelectedTab == 0
                ? 'Search resident name or room number (e.g. James Perera, 105)...'
                : (_caregiverSelectedTab == 1
                    ? 'Search caregiver name or role (e.g. Sarangi, Maya)...'
                    : (_caregiverSelectedTab == 2
                        ? 'Search doctor by name or specialty (e.g. Dr. Nimal, Neurology)...'
                        : 'Search station or wing...')),
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
            fillColor: AppColors.card,
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.phoneOff, size: 36, color: AppColors.muted),
                const SizedBox(height: 12),
                Text('No matching contacts found for "$_searchQuery"', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                const Text('Try another name, room number, or extension', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          )
        else
          ...currentList.map((item) => _buildContactCard(item, isElder: false)),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.navy : AppColors.body,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySoft : AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(CallContactItem contact, {required bool isElder}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(contact.icon, color: AppColors.primary, size: 22),
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
                        contact.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: contact.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        contact.status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: contact.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  contact.roleOrRoom,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                if (contact.subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    isElder
                        ? contact.subtitle!
                        : (contact.phoneOrExt.isNotEmpty ? '${contact.subtitle!} • ${contact.phoneOrExt}' : contact.subtitle!),
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          // Action Buttons
          if (isElder) ...[
            // Elder View: Direct WhatsApp Voice Call
            ElevatedButton.icon(
              onPressed: () {
                final wpNumber = contact.whatsappNumber ?? contact.phoneOrExt;
                UrlLauncherService.launchWhatsApp(
                  wpNumber,
                  'Hello ${contact.name}, this is from Carevora. Please start a voice call with me for assistance.',
                );
                _triggerCallDialog(contact, isVideo: false);
              },
              icon: const Icon(LucideIcons.phoneCall, size: 15, color: Colors.white),
              label: const Text(
                'Start Voice Call',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ] else ...[
            // Caregiver View: Full communication options (WhatsApp, Voice Call, Video)
            if (contact.whatsappNumber != null && contact.whatsappNumber!.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () {
                  UrlLauncherService.launchWhatsApp(
                    contact.whatsappNumber!,
                    'Hello ${contact.name}, this is from Carevora. I need assistance.',
                  );
                },
                icon: const Icon(LucideIcons.messageCircle, size: 14, color: Colors.white),
                label: const Text(
                  'WhatsApp',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Audio Call Button
            ElevatedButton.icon(
              onPressed: () {
                if (contact.phoneOrExt.startsWith('+') || RegExp(r'^\d{9,}').hasMatch(contact.phoneOrExt)) {
                  UrlLauncherService.launchTel(contact.phoneOrExt);
                }
                _triggerCallDialog(contact, isVideo: false);
              },
              icon: const Icon(LucideIcons.phone, size: 14, color: Colors.white),
              label: const Text(
                'Voice Call',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 8),
            // Video Call Button
            OutlinedButton.icon(
              onPressed: () => _triggerCallDialog(contact, isVideo: true),
              icon: const Icon(LucideIcons.video, size: 14),
              label: const Text(
                'Video',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.border, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// ACTIVE CALL MODAL (Ringing / Connected Animation Dialog)
// --------------------------------------------------------------------------
class _ActiveCallModal extends StatefulWidget {
  final CallContactItem contact;
  final bool isVideo;

  const _ActiveCallModal({
    required this.contact,
    required this.isVideo,
  });

  @override
  State<_ActiveCallModal> createState() => _ActiveCallModalState();
}

class _ActiveCallModalState extends State<_ActiveCallModal> {
  bool _isConnected = false;
  int _secondsElapsed = 0;
  Timer? _callTimer;
  Timer? _connectTimer;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    // Simulate connection after 1.8 seconds of ringing
    _connectTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _secondsElapsed++;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _callTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF130E2E), // Rich dark navy call screen
      child: Container(
        width: 380,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _isConnected
                    ? AppColors.riskLow.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isVideo ? LucideIcons.video : LucideIcons.phoneCall,
                    color: _isConnected ? AppColors.riskLow : const Color(0xFFD8B4FE),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected
                        ? 'Connected • ${_formatDuration(_secondsElapsed)}'
                        : (widget.isVideo ? 'Calling Video Intercom...' : 'Ringing...'),
                    style: TextStyle(
                      color: _isConnected ? Colors.greenAccent : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Contact Avatar with pulse effect
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                widget.contact.icon,
                color: Colors.white,
                size: 44,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              widget.contact.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.contact.roleOrRoom,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 36),

            // In-call action controls (Mute, Speaker, End)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mute toggle
                IconButton(
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                  icon: Icon(
                    _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                    color: _isMuted ? Colors.redAccent : Colors.white,
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(width: 20),

                // End Call button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(18),
                    elevation: 4,
                  ),
                  child: const Icon(LucideIcons.phoneOff, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 20),

                // Speaker toggle
                IconButton(
                  onPressed: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  icon: Icon(
                    _isSpeakerOn ? LucideIcons.volume2 : LucideIcons.volumeX,
                    color: _isSpeakerOn ? AppColors.riskLow : Colors.white60,
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
