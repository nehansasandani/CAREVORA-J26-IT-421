import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Represents a single completed memory game session record.
class MemoryGameSessionRecord {
  final int id;
  final String sessionId;
  final int residentId;
  final String residentName;
  final String gameType;
  final double scorePercentage;
  final int attempts;
  final int correctAnswers;
  final int totalItems;
  final String status;
  final String? completionDetailsJson;
  final String? playedBy;
  final DateTime? completedAt;

  const MemoryGameSessionRecord({
    required this.id,
    required this.sessionId,
    required this.residentId,
    required this.residentName,
    required this.gameType,
    required this.scorePercentage,
    required this.attempts,
    required this.correctAnswers,
    required this.totalItems,
    required this.status,
    this.completionDetailsJson,
    this.playedBy,
    this.completedAt,
  });

  factory MemoryGameSessionRecord.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['completedAt'] != null) {
      try {
        dt = DateTime.parse(json['completedAt'].toString());
      } catch (_) {}
    }

    return MemoryGameSessionRecord(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      sessionId: json['sessionId']?.toString() ?? '',
      residentId: json['residentId'] is int
          ? json['residentId']
          : int.tryParse(json['residentId']?.toString() ?? '0') ?? 0,
      residentName: json['residentName']?.toString() ?? '',
      gameType: json['gameType']?.toString().toUpperCase() ?? '',
      scorePercentage: (json['scorePercentage'] is num)
          ? (json['scorePercentage'] as num).toDouble()
          : double.tryParse(json['scorePercentage']?.toString() ?? '0.0') ?? 0.0,
      attempts: json['attempts'] is int
          ? json['attempts']
          : int.tryParse(json['attempts']?.toString() ?? '0') ?? 0,
      correctAnswers: json['correctAnswers'] is int
          ? json['correctAnswers']
          : int.tryParse(json['correctAnswers']?.toString() ?? '0') ?? 0,
      totalItems: json['totalItems'] is int
          ? json['totalItems']
          : int.tryParse(json['totalItems']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'COMPLETED',
      completionDetailsJson: json['completionDetailsJson']?.toString(),
      playedBy: json['playedBy']?.toString(),
      completedAt: dt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'residentId': residentId,
        'residentName': residentName,
        'gameType': gameType,
        'scorePercentage': scorePercentage,
        'attempts': attempts,
        'correctAnswers': correctAnswers,
        'totalItems': totalItems,
        'status': status,
        'completionDetailsJson': completionDetailsJson,
        'playedBy': playedBy,
        'completedAt': completedAt?.toIso8601String(),
      };
}

/// Represents the aggregated progress summary for a resident's memory games.
class MemoryGameProgressSummary {
  final int residentId;
  final String residentName;
  final int totalCompletedSessions;
  final DateTime? latestActivityDate;
  final double? latestSequenceScore;
  final double? latestPairsScore;
  final double? latestItemsScore;
  final double? latestCollaborativeScore;
  final double? averageScore;
  final String sequenceProgress;
  final String pairsProgress;
  final String itemsProgress;
  final String collaborativeProgress;
  final String overallProgress;
  final bool hasRepeatedDecline;
  final String? caregiverNotice;
  final List<MemoryGameSessionRecord> sessions;

  const MemoryGameProgressSummary({
    required this.residentId,
    required this.residentName,
    required this.totalCompletedSessions,
    this.latestActivityDate,
    this.latestSequenceScore,
    this.latestPairsScore,
    this.latestItemsScore,
    this.latestCollaborativeScore,
    this.averageScore,
    this.sequenceProgress = 'NO_DATA',
    this.pairsProgress = 'NO_DATA',
    this.itemsProgress = 'NO_DATA',
    this.collaborativeProgress = 'NO_DATA',
    this.overallProgress = 'NO_DATA',
    this.hasRepeatedDecline = false,
    this.caregiverNotice,
    this.sessions = const [],
  });

  static String _computeTrendFromScores(List<double> scoresDescending) {
    if (scoresDescending.isEmpty) return 'NO_DATA';
    if (scoresDescending.length == 1) return 'STEADY';
    final latest = scoresDescending[0];
    final previous = scoresDescending[1];
    if (latest >= previous + 5.0) return 'IMPROVING';
    if (latest <= previous - 15.0) return 'NEEDS_PRACTICE';
    return 'STEADY';
  }

  factory MemoryGameProgressSummary.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['latestActivityDate'] != null) {
      try {
        dt = DateTime.parse(json['latestActivityDate'].toString());
      } catch (_) {}
    }

    final rawSessions = json['sessions'];
    final List<MemoryGameSessionRecord> parsedSessions = [];
    if (rawSessions is List) {
      for (final s in rawSessions) {
        if (s is Map<String, dynamic>) {
          parsedSessions.add(MemoryGameSessionRecord.fromJson(s));
        }
      }
    }

    final collabScores = parsedSessions
        .where((s) => s.gameType.contains('COLLABORATIVE'))
        .map((s) => s.scorePercentage)
        .toList();
    final computedCollabLatest = json['latestCollaborativeScore'] != null
        ? (json['latestCollaborativeScore'] as num).toDouble()
        : (collabScores.isNotEmpty ? collabScores.first : null);
    final computedCollabProgress = json['collaborativeProgress'] != null
        ? json['collaborativeProgress'].toString()
        : _computeTrendFromScores(collabScores);

    return MemoryGameProgressSummary(
      residentId: json['residentId'] is int
          ? json['residentId']
          : int.tryParse(json['residentId']?.toString() ?? '0') ?? 0,
      residentName: json['residentName']?.toString() ?? '',
      totalCompletedSessions: json['totalCompletedSessions'] is int
          ? json['totalCompletedSessions']
          : int.tryParse(json['totalCompletedSessions']?.toString() ?? '0') ?? 0,
      latestActivityDate: dt,
      latestSequenceScore: json['latestSequenceScore'] != null
          ? (json['latestSequenceScore'] as num).toDouble()
          : null,
      latestPairsScore: json['latestPairsScore'] != null
          ? (json['latestPairsScore'] as num).toDouble()
          : null,
      latestItemsScore: json['latestItemsScore'] != null
          ? (json['latestItemsScore'] as num).toDouble()
          : null,
      latestCollaborativeScore: computedCollabLatest,
      averageScore: json['averageScore'] != null
          ? (json['averageScore'] as num).toDouble()
          : null,
      sequenceProgress: json['sequenceProgress']?.toString() ?? 'NO_DATA',
      pairsProgress: json['pairsProgress']?.toString() ?? 'NO_DATA',
      itemsProgress: json['itemsProgress']?.toString() ?? 'NO_DATA',
      collaborativeProgress: computedCollabProgress,
      overallProgress: json['overallProgress']?.toString() ?? 'NO_DATA',
      hasRepeatedDecline: json['hasRepeatedDecline'] == true,
      caregiverNotice: json['caregiverNotice']?.toString(),
      sessions: parsedSessions,
    );
  }

  factory MemoryGameProgressSummary.empty(int residentId, [String residentName = '']) {
    return MemoryGameProgressSummary(
      residentId: residentId,
      residentName: residentName,
      totalCompletedSessions: 0,
      sequenceProgress: 'NO_DATA',
      pairsProgress: 'NO_DATA',
      itemsProgress: 'NO_DATA',
      collaborativeProgress: 'NO_DATA',
      overallProgress: 'NO_DATA',
      hasRepeatedDecline: false,
      sessions: const [],
    );
  }
}

/// Service providing unified Memory Game persistence and progress retrieval.
class MemoryGameService {
  MemoryGameService._();

  static http.Client? client;

  static String get baseUrl => AppConfig.backendBaseUrl;

  /// Saves a completed memory game session.
  /// Rejects incomplete/abandoned sessions.
  static Future<MemoryGameSessionRecord> saveCompletedSession({
    required int residentId,
    required String gameType,
    required double scorePercentage,
    required int attempts,
    required int correctAnswers,
    required int totalItems,
    String status = 'COMPLETED',
    String? completionDetailsJson,
    String? token,
  }) async {
    if (status.toUpperCase() != 'COMPLETED') {
      throw ArgumentError('Incomplete or abandoned game sessions cannot be saved as completed');
    }

    final clientToUse = client ?? http.Client();
    final uri = Uri.parse('$baseUrl/api/memory-games/sessions');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'residentId': residentId,
      'gameType': gameType.toUpperCase().trim(),
      'scorePercentage': (scorePercentage.clamp(0.0, 100.0) * 10).round() / 10.0,
      'attempts': attempts,
      'correctAnswers': correctAnswers,
      'totalItems': totalItems,
      'status': 'COMPLETED',
      'completionDetailsJson': completionDetailsJson,
    });

    final res = await clientToUse
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return MemoryGameSessionRecord.fromJson(json['data'] as Map<String, dynamic>);
      }
      throw Exception(json['message'] ?? 'Failed to parse game session response');
    } else {
      String msg = 'Failed to save game session (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['message'] != null) msg = errJson['message'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// Fetches all historical completed game sessions for a resident.
  static Future<List<MemoryGameSessionRecord>> fetchResidentSessions(
    int residentId, {
    String? token,
  }) async {
    final clientToUse = client ?? http.Client();
    final uri = Uri.parse('$baseUrl/api/memory-games/resident/$residentId');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final res = await clientToUse.get(uri, headers: headers).timeout(const Duration(seconds: 10));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] is List) {
        return (json['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MemoryGameSessionRecord.fromJson)
            .toList();
      }
      return [];
    } else {
      String msg = 'Failed to load resident game sessions (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['message'] != null) msg = errJson['message'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// Fetches aggregated progress summary and trends for a resident.
  static Future<MemoryGameProgressSummary> fetchResidentProgress(
    int residentId, {
    String? token,
  }) async {
    final clientToUse = client ?? http.Client();
    final uri = Uri.parse('$baseUrl/api/memory-games/resident/$residentId/progress');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final res = await clientToUse.get(uri, headers: headers).timeout(const Duration(seconds: 10));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        return MemoryGameProgressSummary.fromJson(json['data'] as Map<String, dynamic>);
      }
      return MemoryGameProgressSummary.empty(residentId);
    } else {
      String msg = 'Failed to load memory game progress (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['message'] != null) msg = errJson['message'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// Formats score percentage cleanly (e.g. 85.0 -> '85.0%', null -> '--').
  static String formatScore(double? score) {
    if (score == null || score.isNaN || score.isInfinite) return '--';
    return '${score.toStringAsFixed(1)}%';
  }
}
