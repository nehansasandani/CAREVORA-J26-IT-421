import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Clinical domain result after submitting an emotional wellness assessment.
class EmotionalAssessmentSubmissionResult {
  final int id;
  final int residentId;
  final double overallScore;
  final double emotionalScore;
  final double socialScore;
  final String status;
  final String riskLevel;
  final String trajectory;
  final String encouragingMessage;
  final bool facialCheckIncluded;
  final bool voiceCheckIncluded;

  const EmotionalAssessmentSubmissionResult({
    required this.id,
    required this.residentId,
    required this.overallScore,
    required this.emotionalScore,
    required this.socialScore,
    required this.status,
    required this.riskLevel,
    required this.trajectory,
    required this.encouragingMessage,
    this.facialCheckIncluded = false,
    this.voiceCheckIncluded = false,
  });

  factory EmotionalAssessmentSubmissionResult.fromJson(Map<String, dynamic> json) {
    return EmotionalAssessmentSubmissionResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      residentId: (json['residentId'] as num?)?.toInt() ?? 0,
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0.0,
      emotionalScore: (json['emotionalScore'] as num?)?.toDouble() ?? 0.0,
      socialScore: (json['socialScore'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'STABLE',
      riskLevel: json['riskLevel'] as String? ?? 'LOW',
      trajectory: json['trajectory'] as String? ?? 'STABLE',
      encouragingMessage: json['encouragingMessage'] as String? ?? '',
      facialCheckIncluded: json['facialCheckIncluded'] as bool? ?? false,
      voiceCheckIncluded: json['voiceCheckIncluded'] as bool? ?? false,
    );
  }
}

/// Custom exception for assessment submission failures.
class EmotionalAssessmentException implements Exception {
  final String message;
  final int? statusCode;

  const EmotionalAssessmentException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service handling score calculation and authenticated submission for emotional assessments.
class EmotionalAssessmentService {
  /// Question IDs with Negative Polarity (Reverse-Scored):
  /// Q4: "Do you often feel left out or lonely when people gather around?"
  /// Q5: "Do you find yourself spending most of your day alone in your room?"
  /// For these items, answering 'No' is favorable (wellness=1), and 'Yes' is adverse (wellness=0).
  static const Set<int> negativeQuestionIds = {4, 5};

  /// Question IDs with Positive Polarity:
  /// Q1, Q2, Q3, Q6, Q7, Q8, Q9, Q10.
  /// For these items, answering 'Yes' is favorable (wellness=1), and 'No' is adverse (wellness=0).
  static const Set<int> positiveQuestionIds = {1, 2, 3, 6, 7, 8, 9, 10};

  static String get baseUrl => AppConfig.backendBaseUrl;

  /// Validates that all questions from 1 to [totalQuestions] have been answered.
  static bool areAllQuestionsAnswered(
    Map<int, bool?> answers, {
    int totalQuestions = 10,
  }) {
    for (int i = 1; i <= totalQuestions; i++) {
      if (answers[i] == null) {
        return false;
      }
    }
    return true;
  }

  /// Returns a list of question IDs that have not yet been answered.
  static List<int> getUnansweredQuestions(
    Map<int, bool?> answers, {
    int totalQuestions = 10,
  }) {
    final List<int> missing = [];
    for (int i = 1; i <= totalQuestions; i++) {
      if (answers[i] == null) {
        missing.add(i);
      }
    }
    return missing;
  }

  /// Maps a question ID and boolean answer to the Spring Boot backend's selectedIndex contract.
  /// Backend expects `List<Integer>` answers where:
  ///   0 = Favorable/Wellness choice (0 deduction)
  ///   1 = Adverse/Risk choice (1 deduction)
  static int mapAnswerToBackendIndex(int questionId, bool answer) {
    if (negativeQuestionIds.contains(questionId)) {
      // Negative question (e.g. "Do you feel left out?"):
      // No is favorable (0), Yes is adverse (1).
      return answer ? 1 : 0;
    } else {
      // Positive question (e.g. "Are you feeling peaceful?"):
      // Yes is favorable (0), No is adverse (1).
      return answer ? 0 : 1;
    }
  }

  /// Calculates the standardized Questionnaire Emotional Wellness Score (0.0 to 100.0).
  /// Higher is better.
  /// Each favorable answer awards (100 / totalQuestions) points.
  static double calculateWellnessScore(
    Map<int, bool?> answers, {
    int totalQuestions = 10,
  }) {
    if (totalQuestions <= 0) return 0.0;
    double favorableCount = 0.0;

    for (int i = 1; i <= totalQuestions; i++) {
      final ans = answers[i];
      if (ans == null) continue;

      final backendIndex = mapAnswerToBackendIndex(i, ans);
      if (backendIndex == 0) {
        favorableCount += 1.0;
      }
    }

    final score = (favorableCount / totalQuestions) * 100.0;
    return double.parse(score.toStringAsFixed(1));
  }

  /// Calculates the Loneliness & Social Isolation Risk Score (0.0 to 100.0).
  /// Higher is worse.
  /// Risk Score = 100.0 - Wellness Score.
  static double calculateLonelinessRiskScore(double wellnessScore) {
    final risk = (100.0 - wellnessScore).clamp(0.0, 100.0);
    return double.parse(risk.toStringAsFixed(1));
  }

  /// Builds the `List<int>` answers payload matching Spring Boot AssessmentSubmissionRequest.
  static List<int> buildAnswersPayload(
    Map<int, bool?> answers, {
    int totalQuestions = 10,
  }) {
    final List<int> payload = [];
    for (int i = 1; i <= totalQuestions; i++) {
      final ans = answers[i];
      if (ans == null) {
        payload.add(1);
      } else {
        payload.add(mapAnswerToBackendIndex(i, ans));
      }
    }
    return payload;
  }

  /// Submits the completed assessment to Spring Boot endpoint POST /api/assessments/submit.
  static Future<EmotionalAssessmentSubmissionResult> submitAssessment({
    required int residentId,
    required List<int> answers,
    bool includeFacialCheck = false,
    bool includeVoiceCheck = false,
    double? facialScore,
    double? vocalScore,
    String? dominantEmotion,
    double? facialConfidence,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/assessments/submit');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final Map<String, dynamic> bodyMap = {
      'residentId': residentId,
      'answers': answers,
      'includeFacialCheck': includeFacialCheck,
      'includeVoiceCheck': includeVoiceCheck,
      'facialScore': ?facialScore,
      'vocalScore': ?vocalScore,
      'dominantEmotion': ?dominantEmotion,
      'facialConfidence': ?facialConfidence,
    };

    final http.Response res;
    try {
      res = await http
          .post(uri, headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      throw EmotionalAssessmentException(
        'Unable to connect to Carevora server at $baseUrl. Please verify your connection.',
      );
    }

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}

    if (res.statusCode == 200 && decoded != null && decoded['success'] == true) {
      final data = decoded['data'] as Map<String, dynamic>;
      return EmotionalAssessmentSubmissionResult.fromJson(data);
    }

    final String message = decoded?['message'] as String? ??
        (res.statusCode == 401
            ? 'Authentication required. Please log in to save the assessment.'
            : res.statusCode == 403
                ? 'Permission denied: You are not authorized to record assessments for this resident.'
                : res.statusCode == 404
                    ? 'Resident record (ID: $residentId) was not found in the database.'
                    : 'Failed to save assessment to server (HTTP ${res.statusCode}).');

    throw EmotionalAssessmentException(message, statusCode: res.statusCode);
  }

  /// Fetches historical assessments for a resident from GET /api/assessments/resident/{residentId}.
  static Future<List<Map<String, dynamic>>> fetchResidentAssessments({
    required int residentId,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/assessments/resident/$residentId');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
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
          return List<Map<String, dynamic>>.from(decoded['data'] as List);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetches real RALPA trajectory prediction from GET /api/ai/trajectory/{residentId}.
  static Future<Map<String, dynamic>?> fetchRalpaTrajectory({
    required int residentId,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/ai/trajectory/$residentId');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>?;
        if (decoded != null && decoded['success'] == true && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data'] as Map);
        }
      }
    } catch (_) {}
    return null;
  }
}

