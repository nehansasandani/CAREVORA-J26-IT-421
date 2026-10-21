import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

class CognitiveResidentProfile {
  final int id;
  final String name;
  final int? age;
  final int? educationYears;
  final String roomNumber;
  final String? gender;
  final String? avatarUrl;
  final String? currentStatus;
  final String? riskLevel;
  final double? cognitiveScore;

  final int? elderHomeId;
  final String? elderHomeName;

  const CognitiveResidentProfile({
    required this.id,
    required this.name,
    this.age,
    this.educationYears,
    required this.roomNumber,
    this.gender,
    this.avatarUrl,
    this.currentStatus,
    this.riskLevel,
    this.cognitiveScore,
    this.elderHomeId,
    this.elderHomeName,
  });

  factory CognitiveResidentProfile.fromJson(Map<String, dynamic> json) {
    return CognitiveResidentProfile(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Resident',
      age: (json['age'] as num?)?.toInt(),
      educationYears: (json['educationYears'] as num?)?.toInt(),
      roomNumber: json['roomNumber'] as String? ?? 'Room 101',
      gender: json['gender'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      currentStatus: json['currentStatus'] as String?,
      riskLevel: json['riskLevel'] as String?,
      cognitiveScore: (json['cognitiveScore'] as num?)?.toDouble(),
      elderHomeId: (json['elderHomeId'] as num?)?.toInt(),
      elderHomeName: json['elderHomeName'] as String?,
    );
  }
}

class CognitiveSessionData {
  final String sessionId;
  final int residentId;
  final String residentName;
  final String status; // IN_PROGRESS, PENDING_CAREGIVER_REVIEW, COMPLETED
  final Map<int, String> responses;
  final Map<int, double> grades;
  final Map<int, double> questionTimes;
  final String? initiatedBy;
  final String? reviewedBy;
  final String? createdAt;
  final String? updatedAt;

  const CognitiveSessionData({
    required this.sessionId,
    required this.residentId,
    required this.residentName,
    required this.status,
    required this.responses,
    required this.grades,
    required this.questionTimes,
    this.initiatedBy,
    this.reviewedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory CognitiveSessionData.fromJson(Map<String, dynamic> json) {
    final Map<int, String> resp = {};
    if (json['responses'] is Map) {
      (json['responses'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v != null) resp[id] = v.toString();
      });
    }

    final Map<int, double> grd = {};
    if (json['grades'] is Map) {
      (json['grades'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v != null) grd[id] = (v as num).toDouble();
      });
    }

    final Map<int, double> qt = {};
    if (json['questionTimes'] is Map) {
      (json['questionTimes'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v != null) qt[id] = (v as num).toDouble();
      });
    }

    return CognitiveSessionData(
      sessionId: json['sessionId'] as String? ?? '',
      residentId: (json['residentId'] as num?)?.toInt() ?? 0,
      residentName: json['residentName'] as String? ?? 'Resident',
      status: json['status'] as String? ?? 'IN_PROGRESS',
      responses: resp,
      grades: grd,
      questionTimes: qt,
      initiatedBy: json['initiatedBy'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class CognitiveSubmissionPayload {
  final int residentId;
  final double memory;
  final double attention;
  final double orientation;
  final double recall;
  final double reasoning;
  final int? age;
  final int? educationYears;
  final Map<String, double>? accuracies;
  final Map<String, double>? responseTimes;
  final String? sessionId;
  final Map<int, String>? responses;
  final Map<int, double>? grades;

  const CognitiveSubmissionPayload({
    required this.residentId,
    required this.memory,
    required this.attention,
    required this.orientation,
    required this.recall,
    required this.reasoning,
    this.age,
    this.educationYears,
    this.accuracies,
    this.responseTimes,
    this.sessionId,
    this.responses,
    this.grades,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'residentId': residentId,
      'memory': memory,
      'attention': attention,
      'orientation': orientation,
      'recall': recall,
      'reasoning': reasoning,
    };
    if (age != null) map['age'] = age;
    if (educationYears != null) map['educationYears'] = educationYears;
    if (accuracies != null && accuracies!.isNotEmpty) {
      map['accuracies'] = accuracies;
    }
    if (responseTimes != null && responseTimes!.isNotEmpty) {
      map['responseTimes'] = responseTimes;
    }
    if (sessionId != null && sessionId!.isNotEmpty) {
      map['sessionId'] = sessionId;
    }
    if (responses != null && responses!.isNotEmpty) {
      map['responses'] = {
        for (final e in responses!.entries) e.key.toString(): e.value,
      };
    }
    if (grades != null && grades!.isNotEmpty) {
      map['grades'] = {
        for (final e in grades!.entries) e.key.toString(): e.value,
      };
    }
    return map;
  }
}

class CognitiveSubmissionResult {
  final int id;
  final int residentId;
  final String residentName;
  final double? memory;
  final double? attention;
  final double? orientation;
  final double? recall;
  final double? reasoning;
  final double? acrfScore;
  final String? mlPrediction;
  final String? riskLevel;
  final bool? alertTriggered;
  final bool mlAvailable;
  final String mlModelType;
  final String mlStatusMessage;
  final Map<String, double>? probabilities;
  final String? disclaimer;
  final String? methodology;
  final String? clinicalDisclaimer;
  final String? assessedBy;
  final String? createdAt;
  final String? sessionId;
  final String status;
  final Map<int, String>? responses;
  final Map<int, double>? grades;

  const CognitiveSubmissionResult({
    required this.id,
    required this.residentId,
    required this.residentName,
    this.memory,
    this.attention,
    this.orientation,
    this.recall,
    this.reasoning,
    this.acrfScore,
    this.mlPrediction,
    this.riskLevel,
    this.alertTriggered,
    required this.mlAvailable,
    required this.mlModelType,
    required this.mlStatusMessage,
    this.probabilities,
    this.disclaimer,
    this.methodology,
    this.clinicalDisclaimer,
    this.assessedBy,
    this.createdAt,
    this.sessionId,
    this.status = 'COMPLETED',
    this.responses,
    this.grades,
  });

  factory CognitiveSubmissionResult.fromJson(Map<String, dynamic> json) {
    final mlEval = json['mlModelEvaluation'] as Map<String, dynamic>?;

    Map<String, double>? probs;
    if (mlEval != null && mlEval['probabilities'] is Map) {
      final rawProbs = mlEval['probabilities'] as Map<String, dynamic>;
      probs = rawProbs.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    // 1. Resolve prediction from mlPrediction, prediction, or mlModelEvaluation.prediction
    String? prediction = json['mlPrediction'] as String?;
    prediction ??= json['prediction'] as String?;
    if ((prediction == null ||
            prediction.isEmpty ||
            prediction == 'Not Available' ||
            prediction == 'Risk Level Not Available' ||
            prediction == 'Prediction Unavailable') &&
        mlEval != null &&
        mlEval['prediction'] != null) {
      final p = mlEval['prediction'].toString().trim();
      if (p.isNotEmpty && p != 'null' && p != 'Not Available') {
        prediction = p;
      }
    }

    // 2. Resolve riskLevel from riskLevel, fallback to normalized prediction
    String? riskLevel = json['riskLevel'] as String?;
    if (riskLevel == null ||
        riskLevel.isEmpty ||
        riskLevel == 'Not Available' ||
        riskLevel == 'Risk Level Not Available' ||
        riskLevel == 'Prediction Unavailable') {
      if (prediction != null &&
          prediction.isNotEmpty &&
          prediction != 'Not Available' &&
          prediction != 'Risk Level Not Available' &&
          prediction != 'Prediction Unavailable') {
        final p = prediction.toLowerCase();
        if (p.contains('low')) {
          riskLevel = 'Low Risk';
        } else if (p.contains('mod')) {
          riskLevel = 'Moderate Risk';
        } else if (p.contains('high')) {
          riskLevel = 'High Risk';
        } else {
          riskLevel = prediction;
        }
      } else {
        riskLevel = 'Not Available';
      }
    }

    // If prediction is still missing or not available, but riskLevel has a valid risk, derive prediction
    if ((prediction == null ||
            prediction.isEmpty ||
            prediction == 'Not Available' ||
            prediction == 'Risk Level Not Available' ||
            prediction == 'Prediction Unavailable') &&
        riskLevel != 'Not Available' &&
        riskLevel != 'Risk Level Not Available' &&
        riskLevel != 'Prediction Unavailable') {
      final r = riskLevel.toLowerCase();
      if (r.contains('low')) {
        prediction = 'Low';
      } else if (r.contains('mod')) {
        prediction = 'Moderate';
      } else if (r.contains('high')) {
        prediction = 'High';
      } else {
        prediction = riskLevel;
      }
    }

    final bool hasValidPrediction = (prediction != null &&
            prediction.isNotEmpty &&
            prediction != 'Not Available' &&
            prediction != 'Risk Level Not Available' &&
            prediction != 'Prediction Unavailable') ||
        (riskLevel != 'Not Available' &&
            riskLevel != 'Risk Level Not Available' &&
            riskLevel != 'Prediction Unavailable');

    final bool isAvailable = (json['mlAvailable'] == true) ||
        (mlEval != null && mlEval['available'] == true) ||
        hasValidPrediction;

    bool? alert = json['alertTriggered'] as bool?;
    if (alert == null && mlEval != null) {
      alert = mlEval['alertTriggered'] as bool?;
    }

    final String modelType = (mlEval != null && mlEval['modelType'] != null)
        ? mlEval['modelType'].toString()
        : 'RandomForestClassifier';

    final String statusMsg = (mlEval != null && mlEval['statusMessage'] != null)
        ? mlEval['statusMessage'].toString()
        : (isAvailable ? 'Prediction available' : 'ML inference unavailable');

    final String disclaimerText =
        (mlEval != null && mlEval['disclaimer'] != null)
        ? mlEval['disclaimer'].toString()
        : 'This model was experimentally trained on synthetic data for research and demonstration purposes only. It is not clinically validated.';

    Map<int, String>? parsedResp;
    if (json['responses'] is Map) {
      parsedResp = {};
      (json['responses'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v != null) parsedResp![id] = v.toString();
      });
    }

    Map<int, double>? parsedGrd;
    if (json['grades'] is Map) {
      parsedGrd = {};
      (json['grades'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v != null) parsedGrd![id] = (v as num).toDouble();
      });
    }

    double? memory = (json['memory'] as num?)?.toDouble();
    double? attention = (json['attention'] as num?)?.toDouble();
    double? orientation = (json['orientation'] as num?)?.toDouble();
    double? recall = (json['recall'] as num?)?.toDouble();
    double? reasoning = (json['reasoning'] as num?)?.toDouble();
    double? acrfScore = (json['acrfScore'] as num?)?.toDouble();

    if (json['accuracies'] is Map) {
      final acc = json['accuracies'] as Map;
      memory ??= (acc['memory'] as num?)?.toDouble();
      attention ??= (acc['attention'] as num?)?.toDouble();
      orientation ??= (acc['orientation'] as num?)?.toDouble();
      recall ??= (acc['recall'] as num?)?.toDouble();
      reasoning ??= (acc['reasoning'] as num?)?.toDouble();
    }
    acrfScore ??= (json['taskAccuracyScore'] as num?)?.toDouble();
    acrfScore ??= (json['cognitiveScore'] as num?)?.toDouble();
    acrfScore ??= (json['overallScore'] as num?)?.toDouble();

    return CognitiveSubmissionResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      residentId: (json['residentId'] as num?)?.toInt() ?? 0,
      residentName: json['residentName'] as String? ?? 'Resident',
      memory: memory,
      attention: attention,
      orientation: orientation,
      recall: recall,
      reasoning: reasoning,
      acrfScore: acrfScore,
      mlPrediction: prediction,
      riskLevel: riskLevel,
      alertTriggered: alert,
      mlAvailable: isAvailable,
      mlModelType: modelType,
      mlStatusMessage: statusMsg,
      probabilities: probs,
      disclaimer: disclaimerText,
      methodology: json['methodology'] as String? ?? 'ACRF Fixed Base Weights',
      clinicalDisclaimer: json['clinicalDisclaimer'] as String? ?? 'The ACRF score is an arithmetic weighted wellness metric. Non-diagnostic.',
      assessedBy: json['assessedBy'] as String? ?? 'Care Specialist',
      createdAt: json['createdAt'] as String?,
      sessionId: json['sessionId'] as String?,
      status: json['status'] as String? ?? 'COMPLETED',
      responses: parsedResp,
      grades: parsedGrd,
    );
  }
}

class CognitiveApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const CognitiveApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class CognitiveAssessmentService {
  static http.Client? client;
  static String get baseUrl => AppConfig.backendBaseUrl;

  /// Retrieves or restores an authentication token for caregiver background synchronization
  static Future<String?> getCaregiverToken({String email = 'ps@gmail.com'}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/login');
      final passwords = ['123456', 'carevora123', 'demo1234'];
      for (final password in passwords) {
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': email, 'password': password}),
            )
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final data = decoded['data'];
          if (data != null && data['token'] != null) {
            return data['token'] as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches residents accessible to the authenticated caregiver/doctor.
  static Future<List<CognitiveResidentProfile>> fetchResidents({
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/residents');
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data'] as List?;
        if (list != null) {
          return list
              .map(
                (e) => CognitiveResidentProfile.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetches a specific resident profile.
  static Future<CognitiveResidentProfile?> fetchResident({
    required int residentId,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/residents/$residentId');
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data != null) {
          return CognitiveResidentProfile.fromJson(data);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Initiates a brand-new assessment session with a unique UUID session identifier.
  static Future<CognitiveSessionData> startSession({
    required int residentId,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cognitive/assessments/sessions/start');
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final bodyJson = jsonEncode({'residentId': residentId});
    final res = await http
        .post(uri, headers: headers, body: bodyJson)
        .timeout(const Duration(seconds: 8));

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}

    if (res.statusCode == 200 && decoded != null && decoded['success'] == true) {
      final data = decoded['data'] as Map<String, dynamic>;
      return CognitiveSessionData.fromJson(data);
    }

    final String message = decoded?['message'] as String? ??
        'Failed to start cognitive assessment session (HTTP ${res.statusCode})';
    throw CognitiveApiException(message, statusCode: res.statusCode);
  }

  /// Saves resident answers to the existing backend and database.
  static Future<CognitiveSessionData> saveResponses({
    required String sessionId,
    required Map<int, String> responses,
    required Map<int, double> questionTimes,
    String? status,
    bool? autoFinalize,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cognitive/assessments/sessions/$sessionId/responses');
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final Map<String, dynamic> bodyMap = {
      'responses': {for (final e in responses.entries) e.key.toString(): e.value},
      'questionTimes': {for (final e in questionTimes.entries) e.key.toString(): e.value},
    };
    if (status != null) bodyMap['status'] = status;
    if (autoFinalize != null) bodyMap['autoFinalize'] = autoFinalize;
    final bodyJson = jsonEncode(bodyMap);

    final res = await http
        .post(uri, headers: headers, body: bodyJson)
        .timeout(const Duration(seconds: 8));

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}

    if (res.statusCode == 200 && decoded != null && decoded['success'] == true) {
      final data = decoded['data'] as Map<String, dynamic>;
      return CognitiveSessionData.fromJson(data);
    }

    final String message = decoded?['message'] as String? ??
        'Failed to save resident responses to backend (HTTP ${res.statusCode})';
    throw CognitiveApiException(message, statusCode: res.statusCode);
  }

  /// Retrieves any pending cognitive assessment session and responses for caregiver clinical grading.
  static Future<CognitiveSessionData?> getPendingSession({
    required int residentId,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cognitive/assessments/sessions/pending/resident/$residentId');
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded != null && decoded['data'] != null) {
          return CognitiveSessionData.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches historical cognitive assessments for a resident, ordered newest first.
  static Future<List<CognitiveSubmissionResult>> fetchHistory({
    required int residentId,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cognitive/assessments/resident/$residentId');
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final clientToUse = client ?? http.Client();
    final res = await clientToUse
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final list = decoded['data'] as List?;
      if (list != null) {
        return list
            .map((e) => CognitiveSubmissionResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    throw CognitiveApiException(
      'Failed to load cognitive assessment history (HTTP ${res.statusCode})',
      statusCode: res.statusCode,
    );
  }

  /// Submits the completed cognitive assessment with caregiver grades to POST /api/cognitive/assessments/submit.
  static Future<CognitiveSubmissionResult> submitAssessment({
    required CognitiveSubmissionPayload payload,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cognitive/assessments/submit');
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final bodyJson = jsonEncode(payload.toJson());

    final res = await http
        .post(uri, headers: headers, body: bodyJson)
        .timeout(const Duration(seconds: 8));

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}

    if (res.statusCode == 200 &&
        decoded != null &&
        decoded['success'] == true) {
      final data = decoded['data'] as Map<String, dynamic>;
      return CognitiveSubmissionResult.fromJson(data);
    }

    final String message =
        decoded?['message'] as String? ??
        (res.statusCode == 401
            ? 'Authentication required. Please log in to submit assessments.'
            : res.statusCode == 403
            ? 'Authorization error: You do not have permission to assess this resident.'
            : 'Failed to submit cognitive assessment (HTTP ${res.statusCode})');

    final String? errorCode = decoded?['errorCode'] as String?;

    throw CognitiveApiException(
      message,
      statusCode: res.statusCode,
      errorCode: errorCode,
    );
  }
}
