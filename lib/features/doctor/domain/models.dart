import 'package:flutter/foundation.dart';

@immutable
class Resident {
  final String id;
  final String name;
  final String roomNo;
  final int age;
  final String gender;
  final List<String> allergies;
  final String? avatarUrl;

  const Resident({
    required this.id,
    required this.name,
    required this.roomNo,
    required this.age,
    required this.gender,
    required this.allergies,
    this.avatarUrl,
  });

  Resident copyWith({
    String? id,
    String? name,
    String? roomNo,
    int? age,
    String? gender,
    List<String>? allergies,
    String? avatarUrl,
  }) {
    return Resident(
      id: id ?? this.id,
      name: name ?? this.name,
      roomNo: roomNo ?? this.roomNo,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      allergies: allergies ?? this.allergies,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Resident && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class DoctorModel {
  final String id;
  final String name;
  final String specialty;
  final String phone;

  const DoctorModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.phone,
  });
}

enum PrescriptionForm {
  tablet,
  capsule,
  syrup,
  injection,
  drops,
  other,
}

enum MealTiming {
  beforeMeal,
  afterMeal,
  withMeal,
  emptyStomach,
  anyTime,
}

enum PrescriptionType {
  regular,
  prn,
  once,
}

enum PrescriptionStatus {
  active,
  stopped,
  completed,
}

@immutable
class DosePattern {
  final num morning;
  final num afternoon;
  final num evening;
  final num night;

  const DosePattern({
    this.morning = 0,
    this.afternoon = 0,
    this.evening = 0,
    this.night = 0,
  });

  String get summary => '${morning.toString()}-${afternoon.toString()}-${evening.toString()}-${night.toString()}';

  bool get hasAnyDose => morning > 0 || afternoon > 0 || evening > 0 || night > 0;
}

@immutable
class Prescription {
  final String id;
  final String residentId;
  final String doctorId;
  final String medicineName;
  final String strength;
  final PrescriptionForm form;
  final String doseAmount;
  final DosePattern pattern;
  final MealTiming mealTiming;
  final DateTime startDate;
  final int durationDays;
  final DateTime endDate;
  final String instructions;
  final PrescriptionType type;
  final PrescriptionStatus status;
  final DateTime createdAt;

  const Prescription({
    required this.id,
    required this.residentId,
    required this.doctorId,
    required this.medicineName,
    required this.strength,
    required this.form,
    required this.doseAmount,
    required this.pattern,
    required this.mealTiming,
    required this.startDate,
    required this.durationDays,
    required this.endDate,
    required this.instructions,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  Prescription copyWith({
    String? id,
    String? residentId,
    String? doctorId,
    String? medicineName,
    String? strength,
    PrescriptionForm? form,
    String? doseAmount,
    DosePattern? pattern,
    MealTiming? mealTiming,
    DateTime? startDate,
    int? durationDays,
    DateTime? endDate,
    String? instructions,
    PrescriptionType? type,
    PrescriptionStatus? status,
    DateTime? createdAt,
  }) {
    return Prescription(
      id: id ?? this.id,
      residentId: residentId ?? this.residentId,
      doctorId: doctorId ?? this.doctorId,
      medicineName: medicineName ?? this.medicineName,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      doseAmount: doseAmount ?? this.doseAmount,
      pattern: pattern ?? this.pattern,
      mealTiming: mealTiming ?? this.mealTiming,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      endDate: endDate ?? this.endDate,
      instructions: instructions ?? this.instructions,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum DoseSlot {
  morning,
  afternoon,
  evening,
  night,
}

enum DoseStatus {
  pending,
  given,
  refused,
  held,
  missed,
}

@immutable
class DoseEvent {
  final String id;
  final String prescriptionId;
  final String residentId;
  final DateTime date;
  final DoseSlot slot;
  final DoseStatus status;
  final String? givenBy;
  final DateTime? givenAt;
  final String? note;

  const DoseEvent({
    required this.id,
    required this.prescriptionId,
    required this.residentId,
    required this.date,
    required this.slot,
    required this.status,
    this.givenBy,
    this.givenAt,
    this.note,
  });

  DoseEvent copyWith({
    String? id,
    String? prescriptionId,
    String? residentId,
    DateTime? date,
    DoseSlot? slot,
    DoseStatus? status,
    String? givenBy,
    DateTime? givenAt,
    String? note,
  }) {
    return DoseEvent(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      residentId: residentId ?? this.residentId,
      date: date ?? this.date,
      slot: slot ?? this.slot,
      status: status ?? this.status,
      givenBy: givenBy ?? this.givenBy,
      givenAt: givenAt ?? this.givenAt,
      note: note ?? this.note,
    );
  }
}

@immutable
class SlotWindow {
  final DoseSlot slot;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const SlotWindow({
    required this.slot,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}

@immutable
class AuditLog {
  final String id;
  final String userId;
  final String action;
  final String entity;
  final String before;
  final String after;
  final DateTime at;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.entity,
    required this.before,
    required this.after,
    required this.at,
  });
}
