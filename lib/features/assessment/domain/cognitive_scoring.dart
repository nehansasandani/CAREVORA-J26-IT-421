/// Carevora Cognitive Assessment Scoring & Domain Mapping (Flutter/Dart)
///
/// Maps the 10-question cognitive battery to the 5 ACRF cognitive categories:
/// - orientation: Temporal orientation and calendar awareness (Q1, Q2)
/// - memory: Immediate registration and verbal encoding (Q3, Q4)
/// - attention: Calculation and magnitude discrimination (Q5, Q6)
/// - recall: Delayed verbal recall and cued recognition (Q7, Q8)
/// - reasoning: Practical tool reasoning and conceptual categorization (Q9, Q10)
///
/// Designed with short, elderly-friendly prompts answerable in 1-2 words.
/// Non-diagnostic screening instrument for clinical decision support.
library;

class CognitiveQuestionItem {
  final int id;
  final String category;
  final String domain; // memory, attention, orientation, recall, reasoning
  final String prompt;
  final String promptSinhala; // Sinhala translation of the prompt (display only)
  final String aiTip;
  final String recommendedAnswerGuide;

  const CognitiveQuestionItem({
    required this.id,
    required this.category,
    required this.domain,
    required this.prompt,
    this.promptSinhala = '',
    required this.aiTip,
    required this.recommendedAnswerGuide,
  });
}

class CognitiveScoring {
  static const List<String> domains = [
    'memory',
    'attention',
    'orientation',
    'recall',
    'reasoning',
  ];

  static const Map<String, double> domainWeights = {
    'memory': 0.25,
    'attention': 0.20,
    'orientation': 0.20,
    'recall': 0.20,
    'reasoning': 0.15,
  };

  static const Map<int, String> questionDomainMap = {
    1: 'orientation', // Day of the week
    2: 'orientation', // Current year
    3: 'memory', // 3 objects immediate registration (Sun, Book, Tree)
    4: 'memory', // Immediate repetition confirmation
    5: 'attention', // Simple mental addition (2 + 3)
    6: 'attention', // Number comparison (which is bigger: 3 or 8)
    7: 'recall', // Delayed recall of 3 objects
    8: 'recall', // Cued recognition of registered object
    9: 'reasoning', // Practical reasoning: timekeeping instruments (clock / watch)
    10: 'reasoning', // Conceptual categorization (apple & orange)
  };

  static const Map<String, List<int>> questionIdsByDomain = {
    'orientation': [1, 2],
    'memory': [3, 4],
    'attention': [5, 6],
    'recall': [7, 8],
    'reasoning': [9, 10],
  };

  static const List<CognitiveQuestionItem> questions = [
    CognitiveQuestionItem(
      id: 1,
      category: 'Orientation',
      domain: 'orientation',
      prompt: 'What day is it today?',
      promptSinhala: 'අද මොන දවසද?',
      aiTip: 'Temporal orientation. Accept day of the week (e.g. Monday).',
      recommendedAnswerGuide: 'Correct day of the week.',
    ),
    CognitiveQuestionItem(
      id: 2,
      category: 'Orientation',
      domain: 'orientation',
      prompt: 'What year is this?',
      promptSinhala: 'මේ මොන අවුරුද්දද?',
      aiTip: 'Calendar awareness. Accept current four-digit year.',
      recommendedAnswerGuide: 'Current year (e.g., 2026).',
    ),
    CognitiveQuestionItem(
      id: 3,
      category: 'Immediate Memory',
      domain: 'memory',
      prompt: 'Repeat these words: Sun, Book, Tree.',
      promptSinhala: 'මෙම වචන නැවත කියන්න: ඉර, පොත, ගස.',
      aiTip: 'Immediate verbal registration of three common targets.',
      recommendedAnswerGuide:
          'Score 1.0 if all 3 repeated, 0.5 for 1-2 words, 0.0 for none.',
    ),
    CognitiveQuestionItem(
      id: 4,
      category: 'Immediate Memory',
      domain: 'memory',
      prompt: 'Say those three words once more.',
      promptSinhala: 'ඒ වචන තුන තවත් වරක් කියන්න.',
      aiTip: 'Reinforces memory encoding prior to delayed recall.',
      recommendedAnswerGuide:
          'Score 1.0 if all 3 repeated, 0.5 for 1-2 words, 0.0 for none.',
    ),
    CognitiveQuestionItem(
      id: 5,
      category: 'Attention & Math',
      domain: 'attention',
      prompt: 'What is 2 plus 3?',
      promptSinhala: '2 යි 3 යි එකතු කළාම කීයද?',
      aiTip: 'Simple mental addition. Evaluates focus and basic arithmetic.',
      recommendedAnswerGuide: '5 (Five).',
    ),
    CognitiveQuestionItem(
      id: 6,
      category: 'Attention & Number',
      domain: 'attention',
      prompt: 'Which is bigger: 3 or 8?',
      promptSinhala: '3 සහ 8 අතරින් විශාල අංකය කුමක්ද?',
      aiTip: 'Magnitude discrimination and focused attention.',
      recommendedAnswerGuide: '8 (Eight).',
    ),
    CognitiveQuestionItem(
      id: 7,
      category: 'Delayed Recall',
      domain: 'recall',
      prompt: 'What were the three words from earlier?',
      promptSinhala: 'කලින් කියපු වචන තුන මොනවාද?',
      aiTip: 'Spontaneous delayed recall for: Sun, Book, Tree.',
      recommendedAnswerGuide:
          'Score 1.0 if all 3 recalled, 0.5 for 1-2 words, 0.0 for none.',
    ),
    CognitiveQuestionItem(
      id: 8,
      category: 'Delayed Recall',
      domain: 'recall',
      prompt: 'Did you hear the word Sun earlier?',
      promptSinhala: 'කලින් ඉර කියන වචනය ඔබට ඇසුණාද?',
      aiTip: 'Cued recognition memory.',
      recommendedAnswerGuide: "'Yes'.",
    ),
    CognitiveQuestionItem(
      id: 9,
      category: 'Practical Reasoning',
      domain: 'reasoning',
      prompt: 'What do you use to tell the time?',
      promptSinhala: 'වේලාව බලාගන්න ඔබ භාවිතා කරන්නේ මොනවාද?',
      aiTip: 'Practical reasoning and tool identification. Accepts clock, watch, or equivalent.',
      recommendedAnswerGuide: "'Clock', 'Watch', 'Wall clock', or 'Wristwatch'.",
    ),
    CognitiveQuestionItem(
      id: 10,
      category: 'Abstract Reasoning',
      domain: 'reasoning',
      prompt: 'Are an apple and an orange both fruits?',
      promptSinhala: 'ඇපල් සහ දොඩම් යන දෙකම පලතුරුද?',
      aiTip: 'Semantic categorization and conceptual reasoning.',
      recommendedAnswerGuide: "'Yes' (or 'Both fruits').",
    ),
  ];

  /// Normalizes raw response text: lowercase, punctuation to space, collapses whitespace, trims.
  static String normalizeAnswer(String? input) {
    if (input == null) return '';
    // Replace punctuation with spaces so adjacent words do not merge (e.g. "sun,book,tree")
    final cleaned = input.toLowerCase().replaceAll(
      RegExp(r'''[.,\/#!$%\^&\*;:{}=\-_`~()?"'’]'''),
      ' ',
    );
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Evaluates an individual question's answer deterministically according to question-specific rubric:
  /// - Q1: Temporal orientation comparing against referenceDate (default: current day)
  /// - Q2: Calendar year comparing against referenceDate (default: current year)
  /// - Q3: Immediate memory registration (Sun, Book, Tree) - distinct word count
  /// - Q4: Repetition confirmation (Sun, Book, Tree) - distinct word count
  /// - Q5: Mental addition (2 + 3) -> 5, five
  /// - Q6: Number comparison -> 8, eight (rejects '3 is bigger')
  /// - Q7: Delayed recall (Sun, Book, Tree) - distinct word count
  /// - Q8: Cued recognition affirmative response (yes, etc.)
  /// - Q9: Practical reasoning: tool to tell time (clock, watch, wall clock, wristwatch, etc.)
  /// - Q10: Semantic categorization (yes, both fruits, fruits, etc.)
  ///
  /// Rubric: Correct = 1.0; Partial = 0.5 (Q3, Q4, Q7 only); Incorrect = 0.0.
  /// Missing or blank response returns null (strictly incomplete; NEVER graded as 0.0).
  static double? scoreQuestion(
    int questionId,
    String? rawAnswer, {
    DateTime? referenceDate,
  }) {
    if (rawAnswer == null || rawAnswer.trim().isEmpty) {
      return null;
    }

    final normalized = normalizeAnswer(rawAnswer);
    if (normalized.isEmpty) {
      return null;
    }

    final ref = referenceDate ?? DateTime.now();

    switch (questionId) {
      case 1:
        // Q1: What day is it today? (English & Sinhala weekday names)
        const weekdayNames = [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ];
        const sinhalaWeekdays = [
          'සඳුදා',
          'අඟහරුවාදා',
          'බදාදා',
          'බ්‍රහස්පතින්දා',
          'සිකුරාදා',
          'සෙනසුරාදා',
          'ඉරිදා',
        ];
        final currentWeekdayName = weekdayNames[ref.weekday - 1];
        final currentSinhalaDay = sinhalaWeekdays[ref.weekday - 1];
        final hasTargetDay = RegExp(
              r'\b' + currentWeekdayName + r'\b',
            ).hasMatch(normalized) ||
            rawAnswer.contains(currentSinhalaDay);
        return hasTargetDay ? 1.0 : 0.0;

      case 2:
        // Q2: What year is this?
        final currentYear = ref.year.toString();
        final hasYear = RegExp(r'\b' + currentYear + r'\b').hasMatch(normalized) ||
            normalized.contains('twenty twenty six') ||
            normalized.contains('twenty twenty-six') ||
            rawAnswer.contains('දෙදහස් විසි හය');
        return hasYear ? 1.0 : 0.0;

      case 3:
      case 4:
      case 7:
        // Q3: Repeat these words: Sun, Book, Tree (ඉර, පොත, ගස).
        final distinctTargets = <String>{};
        if (RegExp(r'\bsun\b').hasMatch(normalized) ||
            rawAnswer.contains('ඉර') ||
            rawAnswer.contains('හිරු')) {
          distinctTargets.add('sun');
        }
        if (RegExp(r'\bbooks?\b').hasMatch(normalized) ||
            rawAnswer.contains('පොත') ||
            rawAnswer.contains('පොත්')) {
          distinctTargets.add('book');
        }
        if (RegExp(r'\btrees?\b').hasMatch(normalized) ||
            rawAnswer.contains('ගස') ||
            rawAnswer.contains('ගහ') ||
            rawAnswer.contains('ගස්')) {
          distinctTargets.add('tree');
        }

        final count = distinctTargets.length;
        if (count == 3) return 1.0;
        if (count >= 1) return 0.5; // Rubric supports partial credit for 1-2 words
        return 0.0;

      case 5:
        // Q5: What is 2 plus 3? Accept 5, five, පහ
        final isFive = RegExp(r'\b(5|five)\b').hasMatch(normalized) ||
            rawAnswer.contains('පහ');
        return isFive ? 1.0 : 0.0;

      case 6:
        // Q6: Which is bigger: 3 or 8? Accept 8, eight, අට
        final mentionsEight = RegExp(r'\b(8|eight)\b').hasMatch(normalized) ||
            rawAnswer.contains('අට');
        final saysThreeBigger = RegExp(
          r'\b(3|three)\s+is\s+bigger\b',
        ).hasMatch(normalized);
        return (mentionsEight && !saysThreeBigger) ? 1.0 : 0.0;

      case 8:
        // Q8: Did you hear the word Sun earlier? Accept unambiguous affirmative (English & Sinhala)
        final isAffirmative = RegExp(
              r'\b(yes|yeah|yep|yup|i did|affirmative|certainly|sure|true|correct|heard|i heard|i heard sun|heard sun|heard it|i heard it|yes i did)\b',
            ).hasMatch(normalized) ||
            rawAnswer.contains('ඔව්') ||
            rawAnswer.contains('ඇසුණා') ||
            rawAnswer.contains('ඇහුණා');
        final isNegative = RegExp(
              r'\b(no|nope|not|never|did not|didn t|didnt)\b',
            ).hasMatch(normalized) ||
            rawAnswer.contains('නැහැ') ||
            rawAnswer.contains('නෑ');
        return (isAffirmative && !isNegative) ? 1.0 : 0.0;

      case 9:
        // Q9: What do you use to tell the time? (English & Sinhala)
        final hasValidDevice = RegExp(
              r'\b(clock|clocks|watch|watches|wristwatch|wristwatches|smartwatch|smartwatches|pocketwatch|stopwatch|timepiece|timepieces|chronometer|chronometers|sundial|sundials|hourglass|hourglasses)\b',
            ).hasMatch(normalized) ||
            rawAnswer.contains('ඔරලෝසු') ||
            rawAnswer.contains('අත් ඔරලෝසුව');

        final isNegated = RegExp(
          r'\b(no|not|never|neither|without)\s+(a\s+|an\s+|the\s+|my\s+|any\s+)?(clock|clocks|watch|watches|wristwatch|timepiece|sundial)\b',
        ).hasMatch(normalized) ||
        RegExp(
          r'\b(don t know|dont know|no idea|cannot tell|can t tell|cant tell|not sure|unsure|don t use|dont use|do not use)\b',
        ).hasMatch(normalized) ||
        RegExp(r'^(no|nope|not|never|nothing|none)\b').hasMatch(normalized);

        final isDisallowedIdiom = RegExp(
          r'\b(biological clock|body clock|around the clock|round the clock|against the clock|clock in|clock out|punch the clock|clean your clock)\b',
        ).hasMatch(normalized);

        return (hasValidDevice && !isNegated && !isDisallowedIdiom) ? 1.0 : 0.0;

      case 10:
        // Q10: Are an apple and an orange both fruits? (English & Sinhala)
        final isFruits = RegExp(
              r'\b(yes|both fruits|both are fruits|fruits|fruit|they are fruits|yes they are|affirmative|correct)\b',
            ).hasMatch(normalized) ||
            rawAnswer.contains('ඔව්') ||
            rawAnswer.contains('පලතුරු');
        final isNegative = RegExp(
              r'\b(no|nope|neither|vegetables?)\b',
            ).hasMatch(normalized) ||
            rawAnswer.contains('නැහැ') ||
            rawAnswer.contains('නෑ');
        return (isFruits && !isNegative) ? 1.0 : 0.0;

      default:
        return 0.0;
    }
  }

  /// Automatically scores all answers in the 10-question battery.
  /// If an answer is missing or blank, its grade is null (incomplete).
  static Map<int, double?> autoScoreBattery(
    Map<int, String> responses, {
    DateTime? referenceDate,
  }) {
    final Map<int, double?> grades = {};
    for (final q in questions) {
      grades[q.id] = scoreQuestion(
        q.id,
        responses[q.id],
        referenceDate: referenceDate,
      );
    }
    return grades;
  }

  /// Returns whether a question response is considered answered (non-empty).
  static bool isAnswerProvided(String? answer) {
    return answer != null && answer.trim().isNotEmpty;
  }

  /// Returns the list of question IDs that lack an answer.
  static List<int> getUnansweredQuestionIds(Map<int, String> responses) {
    final List<int> unanswered = [];
    for (final q in questions) {
      if (!isAnswerProvided(responses[q.id])) {
        unanswered.add(q.id);
      }
    }
    return unanswered;
  }

  /// Checks whether all 10 questions have valid, non-blank answers.
  static bool isAllQuestionsAnswered(Map<int, String> responses) {
    return getUnansweredQuestionIds(responses).isEmpty;
  }

  /// Validates whether the 10-question battery is fully assessed with both saved responses and grades.
  static bool isBatteryComplete({
    required Map<int, String> responses,
    required Map<int, double?> grades,
  }) {
    for (final q in questions) {
      final hasAns = responses[q.id]?.trim().isNotEmpty == true;
      final hasGrd = grades[q.id] != null;
      if (!hasAns || !hasGrd) return false;
    }
    return true;
  }

  /// Calculates per-domain accuracies in [0.0, 1.0] range based on grades (1.0, 0.5, 0.0).
  /// Strictly distinguishes between missing scores (null) and legitimate Incorrect scores (0.0).
  /// If [allowIncomplete] is false (default), missing grades are rejected to prevent converting
  /// unassessed items to zero.
  static Map<String, double> calculateDomainAccuracies(
    Map<int, double?> grades, {
    bool allowIncomplete = false,
  }) {
    final Map<String, double> accuracies = {};

    for (final domain in domains) {
      final qIds = questionIdsByDomain[domain] ?? [];
      if (qIds.isEmpty) {
        accuracies[domain] = 0.0;
        continue;
      }

      double sum = 0.0;
      for (final id in qIds) {
        final score = grades[id];
        if (score == null) {
          if (!allowIncomplete) {
            throw ArgumentError(
              'Cannot calculate domain accuracy: Question $id has no grade. Missing grades must not be converted to 0.0.',
            );
          }
          sum += 0.0;
        } else if (!score.isNaN) {
          sum += score;
        }
      }

      final mean = sum / qIds.length;
      accuracies[domain] = double.parse(mean.toStringAsFixed(4));
    }

    return accuracies;
  }

  /// Calculates domain scores on [0.0, 100.0] scale from accuracies.
  static Map<String, double> calculateDomainScores(
    Map<String, double> accuracies,
  ) {
    final Map<String, double> scores = {};
    for (final domain in domains) {
      final acc = accuracies[domain] ?? 0.0;
      scores[domain] = double.parse((acc * 100.0).toStringAsFixed(2));
    }
    return scores;
  }

  /// Aggregates measured question viewing durations in seconds to mean domain response times.
  /// Enforces a minimum of 0.5s so response times are strictly positive.
  static Map<String, double> aggregateDomainResponseTimes(
    Map<int, double> questionTimesInSeconds,
  ) {
    final Map<String, double> responseTimes = {};

    for (final domain in domains) {
      final qIds = questionIdsByDomain[domain] ?? [];
      double totalTime = 0.0;
      int count = 0;

      for (final id in qIds) {
        final t = questionTimesInSeconds[id];
        if (t != null && !t.isNaN && t > 0.0) {
          totalTime += t;
          count++;
        }
      }

      final mean = count > 0 ? (totalTime / count) : 4.0;
      final clamped = mean < 0.5 ? 0.5 : mean;
      responseTimes[domain] = double.parse(clamped.toStringAsFixed(2));
    }

    return responseTimes;
  }

  /// Calculates arithmetic ACRF score:
  /// memory*0.25 + attention*0.20 + orientation*0.20 + recall*0.20 + reasoning*0.15
  static double calculateAcrfWeightedScore(Map<String, double> domainScores) {
    double total = 0.0;
    for (final domain in domains) {
      final score = domainScores[domain] ?? 0.0;
      final weight = domainWeights[domain] ?? 0.20;
      total += score * weight;
    }
    return double.parse(total.toStringAsFixed(2));
  }
}

