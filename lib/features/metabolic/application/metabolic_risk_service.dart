import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

/// Inputs for a metabolic risk screening. Every field is optional; the AI service uses the
/// highest tier (home, clinic labs, extended labs) whose inputs are complete.
class MetabolicInputs {
  // Home tier
  final double? age;
  final String? sex; // 'male' | 'female'
  final double? heightCm;
  final double? weightKg;
  final double? waistCm;
  final double? systolicBp;
  final double? diastolicBp;
  final double? restingHr;
  final String? smokingStatus; // 'never' | 'former' | 'current'
  final double? drinksPerWeek;
  final double? vigorousMinWeek;
  final double? moderateMinWeek;
  final double? sedentaryHours;
  final bool? onBpMeds;
  final bool? onCholesterolMeds;
  final bool? onDiabetesMeds;
  final bool? toldHypertension;
  final bool? toldHighCholesterol;
  final bool? toldDiabetes;
  // Clinic tier
  final double? fastingGlucose;
  final double? hba1c;
  final double? hdl;
  final double? ldl;
  final double? triglycerides;
  // Extended tier
  final double? alt;
  final double? ast;
  final double? ggt;
  final double? creatinine;

  const MetabolicInputs({
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.waistCm,
    this.systolicBp,
    this.diastolicBp,
    this.restingHr,
    this.smokingStatus,
    this.drinksPerWeek,
    this.vigorousMinWeek,
    this.moderateMinWeek,
    this.sedentaryHours,
    this.onBpMeds,
    this.onCholesterolMeds,
    this.onDiabetesMeds,
    this.toldHypertension,
    this.toldHighCholesterol,
    this.toldDiabetes,
    this.fastingGlucose,
    this.hba1c,
    this.hdl,
    this.ldl,
    this.triglycerides,
    this.alt,
    this.ast,
    this.ggt,
    this.creatinine,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'age': age,
      'sex': sex,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'waistCm': waistCm,
      'systolicBp': systolicBp,
      'diastolicBp': diastolicBp,
      'restingHr': restingHr,
      'smokingStatus': smokingStatus,
      'drinksPerWeek': drinksPerWeek,
      'vigorousMinWeek': vigorousMinWeek,
      'moderateMinWeek': moderateMinWeek,
      'sedentaryHours': sedentaryHours,
      'onBpMeds': onBpMeds,
      'onCholesterolMeds': onCholesterolMeds,
      'onDiabetesMeds': onDiabetesMeds,
      'toldHypertension': toldHypertension,
      'toldHighCholesterol': toldHighCholesterol,
      'toldDiabetes': toldDiabetes,
      'fastingGlucose': fastingGlucose,
      'hba1c': hba1c,
      'hdl': hdl,
      'ldl': ldl,
      'triglycerides': triglycerides,
      'alt': alt,
      'ast': ast,
      'ggt': ggt,
      'creatinine': creatinine,
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}

class MetabolicReason {
  final String feature;
  final String reason;
  final String suggestion;

  const MetabolicReason({required this.feature, required this.reason, required this.suggestion});

  factory MetabolicReason.fromJson(Map<String, dynamic> json) => MetabolicReason(
        feature: json['feature'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        suggestion: json['suggestion'] as String? ?? '',
      );
}

/// Result for one outcome (diabetes, cvd, fatty_liver).
class MetabolicOutcomeResult {
  final String key;
  final String status; // ok | insufficient_information | not_applicable
  final String? title;
  final String? modelTier; // home | clinic | extended
  final String? riskTier; // low | watch | high
  final String? tierText;
  final double? probability;
  final String? riskRange;
  final List<MetabolicReason> topReasons;
  final List<String> suggestions;
  final List<String> inputsToImprove;
  final List<String> estimatedInputs;
  final List<String> missingInputs;
  final String? message;
  final String? note;

  const MetabolicOutcomeResult({
    required this.key,
    required this.status,
    this.title,
    this.modelTier,
    this.riskTier,
    this.tierText,
    this.probability,
    this.riskRange,
    this.topReasons = const [],
    this.suggestions = const [],
    this.inputsToImprove = const [],
    this.estimatedInputs = const [],
    this.missingInputs = const [],
    this.message,
    this.note,
  });

  bool get isOk => status == 'ok';

  static List<String> _strings(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory MetabolicOutcomeResult.fromJson(String key, Map<String, dynamic> json) {
    return MetabolicOutcomeResult(
      key: key,
      status: json['status'] as String? ?? 'unknown',
      title: json['title'] as String?,
      modelTier: json['model_tier'] as String?,
      riskTier: json['risk_tier'] as String?,
      tierText: json['tier_text'] as String?,
      probability: (json['probability'] as num?)?.toDouble(),
      riskRange: json['risk_range'] as String?,
      topReasons: (json['top_reasons'] as List?)
              ?.map((e) => MetabolicReason.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      suggestions: _strings(json['suggestions']),
      inputsToImprove: _strings(json['inputs_to_improve_estimate']),
      estimatedInputs: _strings(json['estimated_inputs']),
      missingInputs: _strings(json['missing_inputs']),
      message: json['message'] as String?,
      note: json['note'] as String?,
    );
  }
}

/// One stored screening returned by the backend.
class MetabolicAssessmentRecord {
  final int id;
  final int residentId;
  final String? residentName;
  final String? assessedBy;
  final String? modelVersion;
  final DateTime? createdAt;
  final Map<String, dynamic> inputs;
  final String disclaimer;
  final List<String> inputWarnings;
  final List<String> inputsNotUsed;
  final List<MetabolicOutcomeResult> outcomes;

  const MetabolicAssessmentRecord({
    required this.id,
    required this.residentId,
    this.residentName,
    this.assessedBy,
    this.modelVersion,
    this.createdAt,
    required this.inputs,
    required this.disclaimer,
    required this.inputWarnings,
    required this.inputsNotUsed,
    required this.outcomes,
  });

  static const outcomeOrder = ['diabetes', 'cvd', 'fatty_liver'];

  factory MetabolicAssessmentRecord.fromJson(Map<String, dynamic> json) {
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final results = (result['results'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MetabolicAssessmentRecord(
      id: (json['id'] as num).toInt(),
      residentId: (json['residentId'] as num).toInt(),
      residentName: json['residentName'] as String?,
      assessedBy: json['assessedBy'] as String?,
      modelVersion: json['modelVersion'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      inputs: (json['inputs'] as Map?)?.cast<String, dynamic>() ?? const {},
      disclaimer: result['disclaimer'] as String? ?? '',
      inputWarnings: MetabolicOutcomeResult._strings(result['input_warnings']),
      inputsNotUsed: MetabolicOutcomeResult._strings(result['inputs_not_used']),
      outcomes: [
        for (final key in outcomeOrder)
          if (results[key] is Map)
            MetabolicOutcomeResult.fromJson(key, (results[key] as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// One screening reduced to what a trend line needs: per outcome, the tier and probability.
class MetabolicTrendPoint {
  final int id;
  final DateTime? createdAt;
  final Map<String, ({String? riskTier, double? probability})> outcomes;

  const MetabolicTrendPoint({required this.id, this.createdAt, required this.outcomes});

  factory MetabolicTrendPoint.fromJson(Map<String, dynamic> json) {
    final raw = (json['outcomes'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MetabolicTrendPoint(
      id: (json['id'] as num).toInt(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      outcomes: {
        for (final e in raw.entries)
          if (e.value is Map)
            e.key: (
              riskTier: (e.value as Map)['riskTier'] as String?,
              probability: ((e.value as Map)['probability'] as num?)?.toDouble(),
            ),
      },
    );
  }
}

/// One page of a resident's screening history (newest first).
class MetabolicHistoryPage {
  final List<MetabolicAssessmentRecord> items;
  final int page; // zero-based
  final int size;
  final int totalItems;
  final int totalPages;

  const MetabolicHistoryPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalItems,
    required this.totalPages,
  });

  factory MetabolicHistoryPage.fromJson(Map<String, dynamic> json) => MetabolicHistoryPage(
        items: (json['items'] as List? ?? const [])
            .map((e) => MetabolicAssessmentRecord.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        page: (json['page'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 0,
        totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      );
}

class MetabolicApiException implements Exception {
  final String message;
  final int? statusCode;

  const MetabolicApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class MetabolicRiskService {
  static String get baseUrl => AppConfig.backendBaseUrl;

  static Map<String, String> _headers(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic>? _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Runs a screening for the resident and returns the stored record.
  static Future<MetabolicAssessmentRecord> submitAssessment({
    required int residentId,
    required MetabolicInputs inputs,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/residents/$residentId/metabolic-assessments');
    http.Response res;
    try {
      res = await http
          .post(uri, headers: _headers(token), body: jsonEncode(inputs.toJson()))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw MetabolicApiException('Unable to connect to Carevora server at $baseUrl: $e');
    }
    final decoded = _decode(res);
    if (res.statusCode == 200 && decoded?['success'] == true && decoded?['data'] is Map) {
      return MetabolicAssessmentRecord.fromJson((decoded!['data'] as Map).cast<String, dynamic>());
    }
    String message = decoded?['message'] as String? ?? 'Metabolic screening failed (HTTP ${res.statusCode}).';
    final data = decoded?['data'];
    if (data is Map && data.isNotEmpty) {
      message = '$message ${data.values.join('; ')}';
    }
    throw MetabolicApiException(message, statusCode: res.statusCode);
  }

  /// The resident's screenings up to and including [assessmentId], oldest first (at most [limit]).
  static Future<List<MetabolicTrendPoint>> fetchTrend({
    required int residentId,
    required int assessmentId,
    int limit = 8,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/residents/$residentId/metabolic-assessments/$assessmentId/trend?limit=$limit');
    try {
      final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 8));
      final decoded = _decode(res);
      if (res.statusCode == 200 && decoded?['data'] is List) {
        return (decoded!['data'] as List)
            .map((e) => MetabolicTrendPoint.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
      throw MetabolicApiException(decoded?['message'] as String? ?? 'Could not load the trend.',
          statusCode: res.statusCode);
    } on MetabolicApiException {
      rethrow;
    } catch (e) {
      throw MetabolicApiException('Unable to connect to Carevora server at $baseUrl: $e');
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// One page of the resident's screening history, newest first (page is zero-based).
  /// [from] and [to] optionally limit it to screenings on those days (inclusive).
  static Future<MetabolicHistoryPage> fetchHistoryPage({
    required int residentId,
    int page = 0,
    int size = 5,
    DateTime? from,
    DateTime? to,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/residents/$residentId/metabolic-assessments/history').replace(
      queryParameters: {
        'page': '$page',
        'size': '$size',
        if (from != null) 'from': _isoDate(from),
        if (to != null) 'to': _isoDate(to),
      },
    );
    try {
      final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 8));
      final decoded = _decode(res);
      if (res.statusCode == 200 && decoded?['data'] is Map) {
        return MetabolicHistoryPage.fromJson((decoded!['data'] as Map).cast<String, dynamic>());
      }
      throw MetabolicApiException(decoded?['message'] as String? ?? 'Could not load screening history.',
          statusCode: res.statusCode);
    } on MetabolicApiException {
      rethrow;
    } catch (e) {
      throw MetabolicApiException('Unable to connect to Carevora server at $baseUrl: $e');
    }
  }
}
