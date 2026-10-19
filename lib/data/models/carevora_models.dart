class Resident {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String roomNo;
  final String lastAssessmentDate;
  final double cognitiveScore;
  final double cognitiveTrend;
  final double emotionalScore;
  final double emotionalTrend;
  final double metabolicScore;
  final double metabolicTrend;
  final double overallIndex;
  final double overallTrend;
  final double? socialScore;
  final String? avatarUrl;

  const Resident({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.roomNo,
    required this.lastAssessmentDate,
    required this.cognitiveScore,
    required this.cognitiveTrend,
    required this.emotionalScore,
    required this.emotionalTrend,
    required this.metabolicScore,
    required this.metabolicTrend,
    required this.overallIndex,
    required this.overallTrend,
    this.socialScore,
    this.avatarUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Resident && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AssessmentRecord {
  final String id;
  final String dateTime;
  final double cognitiveScore;
  final double emotionalScore;
  final double metabolicScore;
  final double overallRiskScore;
  final String assessedBy;

  const AssessmentRecord({
    required this.id,
    required this.dateTime,
    required this.cognitiveScore,
    required this.emotionalScore,
    required this.metabolicScore,
    required this.overallRiskScore,
    required this.assessedBy,
  });
}

class AlertItem {
  final String id;
  final String title;
  final String description;
  final String severity; // High, Moderate, Reminder
  final String timestamp;
  final String? residentName;
  final String? roomNo;
  final int? residentAge;
  final String? residentGender;
  final String? currentStatus;
  final double? cognitiveScore;

  const AlertItem({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    this.residentName,
    this.roomNo,
    this.residentAge,
    this.residentGender,
    this.currentStatus,
    this.cognitiveScore,
  });
}

class AssessmentQuestion {
  final int id;
  final String category;
  final String prompt;
  final String? promptSi;
  final String audioPrompt;
  final String tip;

  const AssessmentQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    this.promptSi,
    required this.audioPrompt,
    required this.tip,
  });
}
