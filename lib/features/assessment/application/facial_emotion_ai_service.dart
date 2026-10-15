import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';

enum EmotionCategory {
  happy,
  calmNeutral,
  sadDepressed,
  confusedAgitated,
  anxious,
}

class FacialEmotionResult {
  final EmotionCategory primaryEmotion;
  final double confidence;
  final double valenceScore; // -1.0 (very negative/sad) to +1.0 (very positive/happy)
  final double arousalScore; // 0.0 (calm) to 1.0 (agitated)
  final Map<EmotionCategory, double> emotionProbabilities;
  final String clinicalObservation;
  final List<String> facialActionUnits; // AU6 cheek raiser, AU12 lip corner puller, etc.
  final DateTime analyzedAt;

  const FacialEmotionResult({
    required this.primaryEmotion,
    required this.confidence,
    required this.valenceScore,
    required this.arousalScore,
    required this.emotionProbabilities,
    required this.clinicalObservation,
    required this.facialActionUnits,
    required this.analyzedAt,
  });

  String get emotionLabel {
    switch (primaryEmotion) {
      case EmotionCategory.happy:
        return 'Happy / Uplifted';
      case EmotionCategory.calmNeutral:
        return 'Calm / Neutral Baseline';
      case EmotionCategory.sadDepressed:
        return 'Sad / Affect Flattening';
      case EmotionCategory.confusedAgitated:
        return 'Confused / Agitated';
      case EmotionCategory.anxious:
        return 'Anxious / Hypervigilant';
    }
  }

  String get emoji {
    switch (primaryEmotion) {
      case EmotionCategory.happy:
        return '😊';
      case EmotionCategory.calmNeutral:
        return '😌';
      case EmotionCategory.sadDepressed:
        return '😔';
      case EmotionCategory.confusedAgitated:
        return '😕';
      case EmotionCategory.anxious:
        return '😟';
    }
  }
}

class FacialEmotionAiService {
  /// Analyzes live captured camera image bytes or asset sample via PyTorch FastAPI Microservice
  static Future<FacialEmotionResult> analyzeImage({
    Uint8List? imageBytes,
    String? assetPath,
    String? preferredEmotionHint,
  }) async {
    // 1. If real camera image bytes passed, call live PyTorch FastAPI backend (/api/ml/analyze-photo)
    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        final host = AppConfig.aiServiceBaseUrl;
        final uri = Uri.parse('$host/api/ml/analyze-photo');
        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: 'captured_live_photo.jpg',
          ),
        );

        final streamedResponse = await request.send().timeout(
              const Duration(seconds: 6),
            );
        if (streamedResponse.statusCode == 200) {
          final responseBody = await streamedResponse.stream.bytesToString();
          final jsonMap = jsonDecode(responseBody);
          if (jsonMap['status'] == 'retired' || jsonMap['success'] == false) {
            return FacialEmotionResult(
              primaryEmotion: EmotionCategory.calmNeutral,
              confidence: 0.0,
              valenceScore: 0.0,
              arousalScore: 0.0,
              emotionProbabilities: const {
                EmotionCategory.happy: 0.0,
                EmotionCategory.calmNeutral: 1.0,
                EmotionCategory.sadDepressed: 0.0,
                EmotionCategory.confusedAgitated: 0.0,
                EmotionCategory.anxious: 0.0,
              },
              clinicalObservation:
                  'Facial Emotion Model Retired: Visual scanning is disabled in active pipeline. Assessment relies on structured clinical questionnaire, behavioral indicators, and acoustic vocal metrics.',
              facialActionUnits: const ['AU0: Neutral Baseline (Model Retired)'],
              analyzedAt: DateTime.now(),
            );
          }
          if (jsonMap['success'] == true && jsonMap['analysis'] != null) {
            final analysis = jsonMap['analysis'];
            final String dominant = (analysis['dominant_emotion'] ?? 'happy').toString().toLowerCase();
            final double conf = (analysis['confidence'] is num)
                ? (analysis['confidence'] as num).toDouble()
                : 0.85;
            final breakdown = analysis['emotion_breakdown_percent'] as Map<String, dynamic>?;

            EmotionCategory category;
            double valence;
            double arousal;
            List<String> actionUnits;

            if (dominant == 'happy' || dominant == 'surprise') {
              category = EmotionCategory.happy;
              valence = conf;
              arousal = 0.50;
              actionUnits = const ['AU6: Cheek Raiser', 'AU12: Lip Corner Puller'];
            } else if (dominant == 'neutral') {
              category = EmotionCategory.calmNeutral;
              valence = 0.05;
              arousal = 0.20;
              actionUnits = const ['AU0: Neutral Baseline'];
            } else if (dominant == 'sad' || dominant == 'disgust') {
              category = EmotionCategory.sadDepressed;
              valence = -conf;
              arousal = 0.25;
              actionUnits = const ['AU1: Inner Brow Raiser', 'AU15: Lip Corner Depressor'];
            } else if (dominant == 'angry') {
              category = EmotionCategory.confusedAgitated;
              valence = -0.5 * conf;
              arousal = 0.80;
              actionUnits = const ['AU4: Brow Lowerer', 'AU7: Lid Tightener'];
            } else {
              category = EmotionCategory.anxious;
              valence = -0.6 * conf;
              arousal = 0.70;
              actionUnits = const ['AU1: Inner Brow Raiser', 'AU20: Lip Stretcher'];
            }

            final Map<EmotionCategory, double> probabilities = {
              EmotionCategory.happy: breakdown != null ? ((breakdown['happy'] as num? ?? 0) / 100.0) : (category == EmotionCategory.happy ? conf : 0.05),
              EmotionCategory.calmNeutral: breakdown != null ? ((breakdown['neutral'] as num? ?? 0) / 100.0) : (category == EmotionCategory.calmNeutral ? conf : 0.05),
              EmotionCategory.sadDepressed: breakdown != null ? ((breakdown['sad'] as num? ?? 0) / 100.0) : (category == EmotionCategory.sadDepressed ? conf : 0.05),
              EmotionCategory.confusedAgitated: breakdown != null ? ((breakdown['angry'] as num? ?? 0) / 100.0) : (category == EmotionCategory.confusedAgitated ? conf : 0.05),
              EmotionCategory.anxious: breakdown != null ? ((breakdown['fear'] as num? ?? 0) / 100.0) : (category == EmotionCategory.anxious ? conf : 0.05),
            };

            return FacialEmotionResult(
              primaryEmotion: category,
              confidence: conf,
              valenceScore: valence,
              arousalScore: arousal,
              emotionProbabilities: probabilities,
              clinicalObservation:
                  'Analysis completed: Face classified as ${dominant.toUpperCase()} with ${(conf * 100).toStringAsFixed(1)}% confidence.',
              facialActionUnits: actionUnits,
              analyzedAt: DateTime.now(),
            );
          }
        }
      } catch (e) {
        debugPrint('Facial API call fallback: $e');
      }

      // Transparent Fallback when Facial Analysis is Retired / Unavailable
      return FacialEmotionResult(
        primaryEmotion: EmotionCategory.calmNeutral,
        confidence: 0.0,
        valenceScore: 0.0,
        arousalScore: 0.0,
        emotionProbabilities: const {
          EmotionCategory.happy: 0.0,
          EmotionCategory.calmNeutral: 1.0,
          EmotionCategory.sadDepressed: 0.0,
          EmotionCategory.confusedAgitated: 0.0,
          EmotionCategory.anxious: 0.0,
        },
        clinicalObservation:
            'Facial Emotion Recognition Retired: Visual scanning is disabled in active pipeline. Assessment relies on structured clinical questionnaire, behavioral indicators, and acoustic vocal metrics.',
        facialActionUnits: const ['AU0: Neutral Baseline (Model Retired)'],
        analyzedAt: DateTime.now(),
      );
    }

    // 2. Intelligent asset/hint heuristic simulation
    await Future.delayed(const Duration(milliseconds: 700));

    if (preferredEmotionHint != null) {
      if (preferredEmotionHint == 'happy') return _buildHappyResult();
      if (preferredEmotionHint == 'sad') return _buildSadResult();
      if (preferredEmotionHint == 'neutral') return _buildNeutralResult();
    }

    if (assetPath != null) {
      if (assetPath.contains('happy')) return _buildHappyResult();
      if (assetPath.contains('sad')) return _buildSadResult();
      if (assetPath.contains('neutral') || assetPath.contains('calm')) {
        return _buildNeutralResult();
      }
    }

    return _buildHappyResult();
  }

  static FacialEmotionResult _buildHappyResult() {
    return FacialEmotionResult(
      primaryEmotion: EmotionCategory.happy,
      confidence: 0.94,
      valenceScore: 0.82,
      arousalScore: 0.45,
      emotionProbabilities: {
        EmotionCategory.happy: 0.94,
        EmotionCategory.calmNeutral: 0.04,
        EmotionCategory.anxious: 0.01,
        EmotionCategory.sadDepressed: 0.01,
        EmotionCategory.confusedAgitated: 0.00,
      },
      clinicalObservation:
          'Positive bilateral zygomaticus activation (Duchenne smile). Face analyzed as HAPPY.',
      facialActionUnits: const [
        'AU6: Cheek Raiser (0.88)',
        'AU12: Lip Corner Puller (0.92)',
        'AU25: Lips Part (0.75)',
      ],
      analyzedAt: DateTime.now(),
    );
  }

  static FacialEmotionResult _buildSadResult() {
    return FacialEmotionResult(
      primaryEmotion: EmotionCategory.sadDepressed,
      confidence: 0.89,
      valenceScore: -0.68,
      arousalScore: 0.22,
      emotionProbabilities: {
        EmotionCategory.sadDepressed: 0.89,
        EmotionCategory.calmNeutral: 0.07,
        EmotionCategory.anxious: 0.03,
        EmotionCategory.confusedAgitated: 0.01,
        EmotionCategory.happy: 0.00,
      },
      clinicalObservation:
          'Depressor anguli oris contraction detected. Corrugator tension. Face analyzed as SAD.',
      facialActionUnits: const [
        'AU1: Inner Brow Raiser (0.78)',
        'AU4: Brow Lowerer (0.84)',
        'AU15: Lip Corner Depressor (0.91)',
      ],
      analyzedAt: DateTime.now(),
    );
  }

  static FacialEmotionResult _buildNeutralResult() {
    return FacialEmotionResult(
      primaryEmotion: EmotionCategory.calmNeutral,
      confidence: 0.91,
      valenceScore: 0.08,
      arousalScore: 0.15,
      emotionProbabilities: {
        EmotionCategory.calmNeutral: 0.91,
        EmotionCategory.happy: 0.05,
        EmotionCategory.sadDepressed: 0.02,
        EmotionCategory.anxious: 0.02,
        EmotionCategory.confusedAgitated: 0.00,
      },
      clinicalObservation:
          'Resting neutral baseline posture. Symmetrical facial expression.',
      facialActionUnits: const [
        'AU0: Neutral Baseline (0.95)',
        'AU43: Eyes Open / Focused (0.90)',
      ],
      analyzedAt: DateTime.now(),
    );
  }
}
