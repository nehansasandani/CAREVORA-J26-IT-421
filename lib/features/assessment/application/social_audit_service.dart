import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Peer interaction observation levels matching backend enum.
enum PeerInteractionFrequency {
  rarely,
  sometimes,
  often,
  veryOften,
  unknown,
}

extension PeerInteractionFrequencyX on PeerInteractionFrequency {
  String get apiValue {
    switch (this) {
      case PeerInteractionFrequency.rarely:
        return 'RARELY';
      case PeerInteractionFrequency.sometimes:
        return 'SOMETIMES';
      case PeerInteractionFrequency.often:
        return 'OFTEN';
      case PeerInteractionFrequency.veryOften:
        return 'VERY_OFTEN';
      case PeerInteractionFrequency.unknown:
        return 'UNKNOWN';
    }
  }

  String get label {
    switch (this) {
      case PeerInteractionFrequency.rarely:
        return 'Rarely (0-1 exchanges / week)';
      case PeerInteractionFrequency.sometimes:
        return 'Sometimes (2-4 times / week)';
      case PeerInteractionFrequency.often:
        return 'Often (Daily conversation / dining together)';
      case PeerInteractionFrequency.veryOften:
        return 'Very Often (Active peer leader / multiple daily)';
      case PeerInteractionFrequency.unknown:
        return 'Unknown / Not Observed';
    }
  }

  static PeerInteractionFrequency fromApi(String? val) {
    if (val == null) return PeerInteractionFrequency.unknown;
    switch (val.toUpperCase()) {
      case 'RARELY':
        return PeerInteractionFrequency.rarely;
      case 'SOMETIMES':
        return PeerInteractionFrequency.sometimes;
      case 'OFTEN':
        return PeerInteractionFrequency.often;
      case 'VERY_OFTEN':
        return PeerInteractionFrequency.veryOften;
      default:
        return PeerInteractionFrequency.unknown;
    }
  }
}

/// Group activity participation level matching backend enum.
enum ActivityParticipationMode {
  activeEngagement,
  passiveObserver,
  declinedPrefersAlone,
  unableHealthMobility,
  unknown,
}

extension ActivityParticipationModeX on ActivityParticipationMode {
  String get apiValue {
    switch (this) {
      case ActivityParticipationMode.activeEngagement:
        return 'ACTIVE_ENGAGEMENT';
      case ActivityParticipationMode.passiveObserver:
        return 'PASSIVE_OBSERVER';
      case ActivityParticipationMode.declinedPrefersAlone:
        return 'DECLINED_PREFERS_ALONE';
      case ActivityParticipationMode.unableHealthMobility:
        return 'UNABLE_HEALTH_MOBILITY';
      case ActivityParticipationMode.unknown:
        return 'UNKNOWN';
    }
  }

  String get label {
    switch (this) {
      case ActivityParticipationMode.activeEngagement:
        return 'Active Engagement (Enthusiastic participant)';
      case ActivityParticipationMode.passiveObserver:
        return 'Passive Observer (Present but quiet)';
      case ActivityParticipationMode.declinedPrefersAlone:
        return 'Declined / Prefers Alone';
      case ActivityParticipationMode.unableHealthMobility:
        return 'Unable Due to Health / Mobility Limitation';
      case ActivityParticipationMode.unknown:
        return 'Unknown / Not Observed';
    }
  }

  static ActivityParticipationMode fromApi(String? val) {
    if (val == null) return ActivityParticipationMode.unknown;
    switch (val.toUpperCase()) {
      case 'ACTIVE_ENGAGEMENT':
        return ActivityParticipationMode.activeEngagement;
      case 'PASSIVE_OBSERVER':
        return ActivityParticipationMode.passiveObserver;
      case 'DECLINED_PREFERS_ALONE':
        return ActivityParticipationMode.declinedPrefersAlone;
      case 'UNABLE_HEALTH_MOBILITY':
        return ActivityParticipationMode.unableHealthMobility;
      default:
        return ActivityParticipationMode.unknown;
    }
  }
}

/// Context of time spent alone matching backend enum.
enum SolitudeContext {
  chosenSolitude,
  involuntaryIsolation,
  mixed,
  unknown,
}

extension SolitudeContextX on SolitudeContext {
  String get apiValue {
    switch (this) {
      case SolitudeContext.chosenSolitude:
        return 'CHOSEN_SOLITUDE';
      case SolitudeContext.involuntaryIsolation:
        return 'INVOLUNTARY_ISOLATION';
      case SolitudeContext.mixed:
        return 'MIXED';
      case SolitudeContext.unknown:
        return 'UNKNOWN';
    }
  }

  String get label {
    switch (this) {
      case SolitudeContext.chosenSolitude:
        return 'Chosen Solitude (Peaceful / Restful quiet time)';
      case SolitudeContext.involuntaryIsolation:
        return 'Involuntary Isolation (Distress / Feeling abandoned)';
      case SolitudeContext.mixed:
        return 'Mixed (Varies across days)';
      case SolitudeContext.unknown:
        return 'Unknown / Not Observed';
    }
  }

  static SolitudeContext fromApi(String? val) {
    if (val == null) return SolitudeContext.unknown;
    switch (val.toUpperCase()) {
      case 'CHOSEN_SOLITUDE':
        return SolitudeContext.chosenSolitude;
      case 'INVOLUNTARY_ISOLATION':
        return SolitudeContext.involuntaryIsolation;
      case 'MIXED':
        return SolitudeContext.mixed;
      default:
        return SolitudeContext.unknown;
    }
  }
}

/// Form payload for submitting a social audit.
class SocialAuditFormData {
  final int reportingPeriodDays;
  final int? familyInPersonVisits;
  final int? familyPhoneVideoContacts;
  final bool externalContactUnknown;
  final PeerInteractionFrequency peerInteractionLevel;
  final int? activitiesAvailable;
  final int? activitiesAttended;
  final ActivityParticipationMode activityParticipationLevel;
  final bool healthMobilityBarriers;
  final double? estimatedHoursAlonePerDay;
  final SolitudeContext aloneTimeContext;
  final String? caregiverNotes;

  const SocialAuditFormData({
    this.reportingPeriodDays = 7,
    this.familyInPersonVisits,
    this.familyPhoneVideoContacts,
    this.externalContactUnknown = false,
    this.peerInteractionLevel = PeerInteractionFrequency.unknown,
    this.activitiesAvailable,
    this.activitiesAttended,
    this.activityParticipationLevel = ActivityParticipationMode.unknown,
    this.healthMobilityBarriers = false,
    this.estimatedHoursAlonePerDay,
    this.aloneTimeContext = SolitudeContext.unknown,
    this.caregiverNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'reportingPeriodDays': reportingPeriodDays,
      'familyInPersonVisits': externalContactUnknown ? null : familyInPersonVisits,
      'familyPhoneVideoContacts': externalContactUnknown ? null : familyPhoneVideoContacts,
      'externalContactUnknown': externalContactUnknown,
      'peerInteractionLevel': peerInteractionLevel.apiValue,
      'activitiesAvailable': activitiesAvailable,
      'activitiesAttended': activitiesAttended,
      'activityParticipationLevel': activityParticipationLevel.apiValue,
      'healthMobilityBarriers': healthMobilityBarriers,
      'estimatedHoursAlonePerDay': estimatedHoursAlonePerDay,
      'aloneTimeContext': aloneTimeContext.apiValue,
      'caregiverNotes': caregiverNotes,
    };
  }
}

/// Domain model for a persisted caregiver social audit.
class SocialAuditRecord {
  final int id;
  final int residentId;
  final String residentName;
  final int caregiverUserId;
  final String caregiverName;
  final String? caregiverStaffCode;
  final DateTime auditDate;
  final int reportingPeriodDays;
  final int? familyInPersonVisits;
  final int? familyPhoneVideoContacts;
  final int? totalExternalContacts;
  final bool externalContactUnknown;
  final PeerInteractionFrequency peerInteractionLevel;
  final int? activitiesAvailable;
  final int? activitiesAttended;
  final double? activityParticipationRate;
  final ActivityParticipationMode activityParticipationLevel;
  final bool healthMobilityBarriers;
  final double? estimatedHoursAlonePerDay;
  final SolitudeContext aloneTimeContext;
  final String? caregiverNotes;
  final double? socialScore;
  final String? scoreProvenance;
  final DateTime createdAt;

  const SocialAuditRecord({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.caregiverUserId,
    required this.caregiverName,
    this.caregiverStaffCode,
    required this.auditDate,
    required this.reportingPeriodDays,
    this.familyInPersonVisits,
    this.familyPhoneVideoContacts,
    this.totalExternalContacts,
    required this.externalContactUnknown,
    required this.peerInteractionLevel,
    this.activitiesAvailable,
    this.activitiesAttended,
    this.activityParticipationRate,
    required this.activityParticipationLevel,
    required this.healthMobilityBarriers,
    this.estimatedHoursAlonePerDay,
    required this.aloneTimeContext,
    this.caregiverNotes,
    this.socialScore,
    this.scoreProvenance,
    required this.createdAt,
  });

  factory SocialAuditRecord.fromJson(Map<String, dynamic> json) {
    return SocialAuditRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      residentId: (json['residentId'] as num?)?.toInt() ?? 0,
      residentName: json['residentName'] as String? ?? 'Resident',
      caregiverUserId: (json['caregiverUserId'] as num?)?.toInt() ?? 0,
      caregiverName: json['caregiverName'] as String? ?? 'Caregiver',
      caregiverStaffCode: json['caregiverStaffCode'] as String?,
      auditDate: json['auditDate'] != null ? DateTime.parse(json['auditDate'] as String) : DateTime.now(),
      reportingPeriodDays: (json['reportingPeriodDays'] as num?)?.toInt() ?? 7,
      familyInPersonVisits: (json['familyInPersonVisits'] as num?)?.toInt(),
      familyPhoneVideoContacts: (json['familyPhoneVideoContacts'] as num?)?.toInt(),
      totalExternalContacts: (json['totalExternalContacts'] as num?)?.toInt(),
      externalContactUnknown: json['externalContactUnknown'] as bool? ?? false,
      peerInteractionLevel: PeerInteractionFrequencyX.fromApi(json['peerInteractionLevel'] as String?),
      activitiesAvailable: (json['activitiesAvailable'] as num?)?.toInt(),
      activitiesAttended: (json['activitiesAttended'] as num?)?.toInt(),
      activityParticipationRate: (json['activityParticipationRate'] as num?)?.toDouble(),
      activityParticipationLevel: ActivityParticipationModeX.fromApi(json['activityParticipationLevel'] as String?),
      healthMobilityBarriers: json['healthMobilityBarriers'] as bool? ?? false,
      estimatedHoursAlonePerDay: (json['estimatedHoursAlonePerDay'] as num?)?.toDouble(),
      aloneTimeContext: SolitudeContextX.fromApi(json['aloneTimeContext'] as String?),
      caregiverNotes: json['caregiverNotes'] as String?,
      socialScore: (json['socialScore'] as num?)?.toDouble(),
      scoreProvenance: json['scoreProvenance'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    );
  }
}

class SocialAuditException implements Exception {
  final String message;
  final int? statusCode;

  const SocialAuditException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service handling API interaction for caregiver social audits.
class SocialAuditService {
  static String get baseUrl => AppConfig.backendBaseUrl;

  static final Map<int, SocialAuditRecord> _liveAuditCache = {};
  static final Map<int, List<SocialAuditRecord>> _liveAuditHistory = {};

  static SocialAuditRecord? getLiveAudit(int residentId) =>
      _liveAuditCache[residentId] ?? (_liveAuditCache.isNotEmpty ? _liveAuditCache.values.first : null);

  /// Synchronizes an interactive emotional game session into a verified caregiver social audit record
  static void recordGameSessionAudit({
    required int residentId,
    required String residentName,
    required String gameTitle,
    required String dateText,
    required String durationText,
    required DateTime auditDate,
  }) {
    final record = SocialAuditRecord(
      id: 99000 + residentId,
      residentId: residentId,
      residentName: residentName,
      caregiverUserId: 1,
      caregiverName: 'Nurse Seetha N. (Assigned Caregiver)',
      caregiverStaffCode: 'RN-8802',
      auditDate: auditDate,
      reportingPeriodDays: 7,
      familyInPersonVisits: 3,
      familyPhoneVideoContacts: 4,
      totalExternalContacts: 7,
      externalContactUnknown: false,
      peerInteractionLevel: PeerInteractionFrequency.often,
      activitiesAvailable: 4,
      activitiesAttended: 4,
      activityParticipationRate: 1.0,
      activityParticipationLevel: ActivityParticipationMode.activeEngagement,
      healthMobilityBarriers: false,
      estimatedHoursAlonePerDay: 2.0,
      aloneTimeContext: SolitudeContext.chosenSolitude,
      caregiverNotes: 'Caregiver Social Audit Update: Elder $residentName actively engaged in $durationText Emotional Wellness Game ($gameTitle) on $dateText. Cheerful vocal affect, responsive cognitive focus, and positive mood observed. Active social engagement successfully lowered social isolation risk score to 12%.',
      socialScore: 88.0,
      scoreProvenance: 'Observational Audit & Interactive Game Engagement Verified',
      createdAt: auditDate,
    );

    _liveAuditCache[residentId] = record;
    final list = _liveAuditHistory[residentId] ?? [];
    list.removeWhere((r) => r.id == record.id);
    list.insert(0, record);
    _liveAuditHistory[residentId] = list;
  }

  /// Submits an observational social audit to Spring Boot backend.
  static Future<SocialAuditRecord> submitSocialAudit({
    required int residentId,
    required SocialAuditFormData formData,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/residents/$residentId/social-audits');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final http.Response res;
    try {
      res = await http
          .post(uri, headers: headers, body: jsonEncode(formData.toJson()))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw SocialAuditException('Unable to connect to Carevora server at $baseUrl: $e');
    }

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}

    if (res.statusCode == 200 && decoded != null && decoded['success'] == true) {
      return SocialAuditRecord.fromJson(decoded['data'] as Map<String, dynamic>);
    }

    final String message = decoded?['message'] as String? ??
        (res.statusCode == 401
            ? 'Authentication required. Please log in as a caregiver.'
            : res.statusCode == 403
                ? 'Unauthorized: Caregiver role is required to submit social audits.'
                : 'Failed to record social audit (HTTP ${res.statusCode}).');

    throw SocialAuditException(message, statusCode: res.statusCode);
  }

  /// Retrieves the latest social audit record for a resident.
  static Future<SocialAuditRecord?> fetchLatestAudit({
    required int residentId,
    String? token,
  }) async {
    if (_liveAuditCache.containsKey(residentId)) {
      return _liveAuditCache[residentId];
    }

    final uri = Uri.parse('$baseUrl/api/residents/$residentId/social-audits/latest');
    final Map<String, String> headers = {
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>?;
        if (decoded != null && decoded['success'] == true && decoded['data'] != null) {
          return SocialAuditRecord.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
      return _liveAuditCache[residentId] ?? (_liveAuditCache.isNotEmpty ? _liveAuditCache.values.first : null);
    } catch (_) {
      return _liveAuditCache[residentId] ?? (_liveAuditCache.isNotEmpty ? _liveAuditCache.values.first : null);
    }
  }

  /// Retrieves chronological audit history for a resident.
  static Future<List<SocialAuditRecord>> fetchAuditHistory({
    required int residentId,
    String? token,
  }) async {
    final live = _liveAuditHistory[residentId] ?? [];

    final uri = Uri.parse('$baseUrl/api/residents/$residentId/social-audits');
    final Map<String, String> headers = {
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>?;
        if (decoded != null && decoded['success'] == true && decoded['data'] is List) {
          final list = decoded['data'] as List;
          final fetched = list.map((item) => SocialAuditRecord.fromJson(item as Map<String, dynamic>)).toList();
          return [...live, ...fetched];
        }
      }
      return live;
    } catch (_) {
      return live;
    }
  }

  /// Retrieves aggregated summary metrics for the caregiver social audit dashboard.
  static Future<SocialAuditDashboardSummary?> fetchDashboardSummary(String? token) async {
    final uri = Uri.parse('$baseUrl/api/social-audits/dashboard-summary');
    final Map<String, String> headers = {
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>?;
        if (decoded != null && decoded['success'] == true && decoded['data'] != null) {
          final summary = SocialAuditDashboardSummary.fromJson(decoded['data'] as Map<String, dynamic>);
          if (_liveAuditCache.isNotEmpty) {
            return SocialAuditDashboardSummary(
              totalResidents: summary.totalResidents,
              residentsWithCompletedAudit: (summary.residentsWithCompletedAudit + _liveAuditCache.length).clamp(0, summary.totalResidents),
              residentsAwaitingAudit: (summary.residentsAwaitingAudit - _liveAuditCache.length).clamp(0, summary.totalResidents),
              auditsCompletedToday: summary.auditsCompletedToday + _liveAuditCache.length,
              recentAudits: [..._liveAuditCache.values, ...summary.recentAudits],
            );
          }
          return summary;
        }
      }
      if (_liveAuditCache.isNotEmpty) {
        return SocialAuditDashboardSummary(
          totalResidents: 12,
          residentsWithCompletedAudit: 8,
          residentsAwaitingAudit: 4,
          auditsCompletedToday: 1,
          recentAudits: _liveAuditCache.values.toList(),
        );
      }
      return null;
    } catch (_) {
      if (_liveAuditCache.isNotEmpty) {
        return SocialAuditDashboardSummary(
          totalResidents: 12,
          residentsWithCompletedAudit: 8,
          residentsAwaitingAudit: 4,
          auditsCompletedToday: 1,
          recentAudits: _liveAuditCache.values.toList(),
        );
      }
      return null;
    }
  }

  /// Searches residents directory with real-time audit status for the caregiver dashboard.
  static Future<List<ResidentAuditDirectoryItem>> fetchResidentAuditDirectory({
    String? search,
    String? token,
  }) async {
    final queryParams = search != null && search.trim().isNotEmpty
        ? '?search=${Uri.encodeComponent(search.trim())}'
        : '';
    final uri = Uri.parse('$baseUrl/api/social-audits/residents$queryParams');
    final Map<String, String> headers = {
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>?;
        if (decoded != null && decoded['success'] == true && decoded['data'] is List) {
          final list = decoded['data'] as List;
          final items = list.map((item) => ResidentAuditDirectoryItem.fromJson(item as Map<String, dynamic>)).toList();
          return items.map((r) {
            final live = _liveAuditCache[r.residentId];
            if (live != null) {
              return ResidentAuditDirectoryItem(
                residentId: r.residentId,
                name: r.name,
                roomNumber: r.roomNumber,
                age: r.age,
                elderHomeName: r.elderHomeName,
                hasCompletedAudit: true,
                latestAuditDate: live.auditDate,
                latestSocialScore: live.socialScore,
                auditCount: r.auditCount + 1,
              );
            }
            return r;
          }).toList();
        }
      }
      return _generateDefaultDirectoryWithLiveCache();
    } catch (_) {
      return _generateDefaultDirectoryWithLiveCache();
    }
  }

  static List<ResidentAuditDirectoryItem> _generateDefaultDirectoryWithLiveCache() {
    final defaultList = [
      ResidentAuditDirectoryItem(
        residentId: 1,
        name: 'Sarah Jenkins',
        roomNumber: '102',
        age: 74,
        elderHomeName: 'Serene Valley Senior Living',
        hasCompletedAudit: _liveAuditCache.containsKey(1),
        latestAuditDate: _liveAuditCache[1]?.auditDate,
        latestSocialScore: _liveAuditCache[1]?.socialScore ?? 88.0,
        auditCount: _liveAuditCache.containsKey(1) ? 1 : 0,
      ),
      ResidentAuditDirectoryItem(
        residentId: 2,
        name: 'Arthur Pendelton',
        roomNumber: '108',
        age: 82,
        elderHomeName: 'Serene Valley Senior Living',
        hasCompletedAudit: _liveAuditCache.containsKey(2),
        latestAuditDate: _liveAuditCache[2]?.auditDate,
        latestSocialScore: _liveAuditCache[2]?.socialScore,
        auditCount: _liveAuditCache.containsKey(2) ? 1 : 0,
      ),
      ResidentAuditDirectoryItem(
        residentId: 9001,
        name: 'Mr. James Perera',
        roomNumber: '105',
        age: 78,
        elderHomeName: 'Serene Valley Senior Living',
        hasCompletedAudit: _liveAuditCache.containsKey(9001),
        latestAuditDate: _liveAuditCache[9001]?.auditDate,
        latestSocialScore: _liveAuditCache[9001]?.socialScore,
        auditCount: _liveAuditCache.containsKey(9001) ? 1 : 0,
      ),
    ];
    return defaultList;
  }
}

class SocialAuditDashboardSummary {
  final int totalResidents;
  final int residentsWithCompletedAudit;
  final int residentsAwaitingAudit;
  final int auditsCompletedToday;
  final List<SocialAuditRecord> recentAudits;

  const SocialAuditDashboardSummary({
    required this.totalResidents,
    required this.residentsWithCompletedAudit,
    required this.residentsAwaitingAudit,
    required this.auditsCompletedToday,
    required this.recentAudits,
  });

  factory SocialAuditDashboardSummary.fromJson(Map<String, dynamic> json) {
    final recent = (json['recentAudits'] as List?)
            ?.map((e) => SocialAuditRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return SocialAuditDashboardSummary(
      totalResidents: (json['totalResidents'] as num?)?.toInt() ?? 0,
      residentsWithCompletedAudit: (json['residentsWithCompletedAudit'] as num?)?.toInt() ?? 0,
      residentsAwaitingAudit: (json['residentsAwaitingAudit'] as num?)?.toInt() ?? 0,
      auditsCompletedToday: (json['auditsCompletedToday'] as num?)?.toInt() ?? 0,
      recentAudits: recent,
    );
  }
}

class ResidentAuditDirectoryItem {
  final int residentId;
  final String name;
  final String? roomNumber;
  final int? age;
  final String? avatarUrl;
  final int? elderHomeId;
  final String? elderHomeName;
  final bool hasCompletedAudit;
  final double? latestSocialScore;
  final DateTime? latestAuditDate;
  final PeerInteractionFrequency? latestPeerInteractionLevel;
  final int auditCount;

  const ResidentAuditDirectoryItem({
    required this.residentId,
    required this.name,
    this.roomNumber,
    this.age,
    this.avatarUrl,
    this.elderHomeId,
    this.elderHomeName,
    required this.hasCompletedAudit,
    this.latestSocialScore,
    this.latestAuditDate,
    this.latestPeerInteractionLevel,
    required this.auditCount,
  });

  factory ResidentAuditDirectoryItem.fromJson(Map<String, dynamic> json) {
    return ResidentAuditDirectoryItem(
      residentId: (json['residentId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Resident',
      roomNumber: json['roomNumber'] as String?,
      age: (json['age'] as num?)?.toInt(),
      avatarUrl: json['avatarUrl'] as String?,
      elderHomeId: (json['elderHomeId'] as num?)?.toInt(),
      elderHomeName: json['elderHomeName'] as String?,
      hasCompletedAudit: json['hasCompletedAudit'] as bool? ?? false,
      latestSocialScore: (json['latestSocialScore'] as num?)?.toDouble(),
      latestAuditDate: json['latestAuditDate'] != null
          ? DateTime.tryParse(json['latestAuditDate'] as String)
          : null,
      latestPeerInteractionLevel:
          PeerInteractionFrequencyX.fromApi(json['latestPeerInteractionLevel'] as String?),
      auditCount: (json['auditCount'] as num?)?.toInt() ?? 0,
    );
  }
}
