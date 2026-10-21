import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../../medicine/application/dose_schedule_service.dart';

class MockDataRepository extends ChangeNotifier {
  final List<Resident> _residents = [
    const Resident(id: 'R-101', name: 'Florence Nightingale', roomNo: '101', age: 84, gender: 'Female', allergies: ['Penicillin'], avatarUrl: 'assets/images/landing/testimonial_1.jpg'),
    const Resident(id: 'R-102', name: 'Arthur Pendelton', roomNo: '102', age: 79, gender: 'Male', allergies: [], avatarUrl: 'assets/images/landing/testimonial_2.jpg'),
    const Resident(id: 'R-103', name: 'Eleanor Vance', roomNo: '103', age: 88, gender: 'Female', allergies: ['Sulfa', 'Aspirin'], avatarUrl: 'assets/images/landing/caregivers_team.jpg'),
    const Resident(id: 'R-104', name: 'Robert Chen', roomNo: '104', age: 75, gender: 'Male', allergies: [], avatarUrl: 'assets/images/landing/testimonial_3.jpg'),
    const Resident(id: 'R-105', name: 'James Perera', roomNo: '105', age: 82, gender: 'Male', allergies: ['Codeine'], avatarUrl: 'assets/images/landing/senior_neutral_calm_face.jpg'),
    const Resident(id: 'R-106', name: 'Clara Oswald', roomNo: '106', age: 78, gender: 'Female', allergies: [], avatarUrl: 'assets/images/landing/testimonial_1.jpg'),
    const Resident(id: 'R-107', name: 'Harold Finch', roomNo: '107', age: 85, gender: 'Male', allergies: ['Lisinopril'], avatarUrl: 'assets/images/landing/senior_happy_face.jpg'),
    const Resident(id: 'R-108', name: 'Beatrice Potter', roomNo: '108', age: 91, gender: 'Female', allergies: [], avatarUrl: 'assets/images/landing/testimonial_3.jpg'),
  ];

  final List<DoctorModel> _doctors = [
    const DoctorModel(id: 'DOC-1', name: 'Dr. Nimal Fernando', specialty: 'Geriatric Specialist & Medical Lead', phone: '+94 77 123 4567'),
    const DoctorModel(id: 'DOC-2', name: 'Dr. Aris Thorne', specialty: 'Neurology Specialist', phone: '+94 71 987 6543'),
    const DoctorModel(id: 'DOC-3', name: 'Dr. Sarah Jenkins', specialty: 'General Physician', phone: '+94 75 456 7890'),
  ];

  List<Prescription> _prescriptions = [];
  final List<DoseEvent> _doseEvents = [];
  final List<AuditLog> _auditLogs = [];

  List<SlotWindow> _slotWindows = [
    const SlotWindow(slot: DoseSlot.morning, startHour: 6, startMinute: 0, endHour: 10, endMinute: 0),
    const SlotWindow(slot: DoseSlot.afternoon, startHour: 12, startMinute: 0, endHour: 14, endMinute: 0),
    const SlotWindow(slot: DoseSlot.evening, startHour: 17, startMinute: 0, endHour: 19, endMinute: 0),
    const SlotWindow(slot: DoseSlot.night, startHour: 20, startMinute: 0, endHour: 22, endMinute: 0),
  ];

  int _overdueGraceMinutes = 30;

  MockDataRepository() {
    _seedData();
  }

  // Getters
  List<Resident> get residents => List.unmodifiable(_residents);
  List<DoctorModel> get doctors => List.unmodifiable(_doctors);
  List<Prescription> get prescriptions => List.unmodifiable(_prescriptions);
  List<DoseEvent> get doseEvents => List.unmodifiable(_doseEvents);
  List<AuditLog> get auditLogs => List.unmodifiable(_auditLogs);
  List<SlotWindow> get slotWindows => List.unmodifiable(_slotWindows);
  int get overdueGraceMinutes => _overdueGraceMinutes;

  void updateSlotWindow(DoseSlot slot, int startH, int startM, int endH, int endM) {
    _slotWindows = _slotWindows.map((w) {
      if (w.slot == slot) {
        return SlotWindow(slot: slot, startHour: startH, startMinute: startM, endHour: endH, endMinute: endM);
      }
      return w;
    }).toList();
    notifyListeners();
  }

  void updateGraceMinutes(int minutes) {
    _overdueGraceMinutes = minutes;
    notifyListeners();
  }

  void _seedData() {
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 2));

    final seedRxList = [
      Prescription(
        id: 'RX-101',
        residentId: 'R-105', // James Perera Room 105
        doctorId: 'DOC-1',
        medicineName: 'Metformin',
        strength: '500mg',
        form: PrescriptionForm.tablet,
        doseAmount: '1 tablet',
        pattern: const DosePattern(morning: 1, afternoon: 0, evening: 2, night: 1),
        mealTiming: MealTiming.afterMeal,
        startDate: startDate,
        durationDays: 7,
        endDate: DoseScheduleService.computeEndDate(startDate, 7),
        instructions: 'Take with water after meals',
        type: PrescriptionType.regular,
        status: PrescriptionStatus.active,
        createdAt: startDate,
      ),
      Prescription(
        id: 'RX-102',
        residentId: 'R-105', // James Perera
        doctorId: 'DOC-1',
        medicineName: 'Donepezil',
        strength: '10mg',
        form: PrescriptionForm.tablet,
        doseAmount: '1 tablet',
        pattern: const DosePattern(morning: 0, afternoon: 0, evening: 0, night: 1),
        mealTiming: MealTiming.emptyStomach,
        startDate: startDate,
        durationDays: 14,
        endDate: DoseScheduleService.computeEndDate(startDate, 14),
        instructions: 'Take right before sleep',
        type: PrescriptionType.regular,
        status: PrescriptionStatus.active,
        createdAt: startDate,
      ),
      Prescription(
        id: 'RX-103',
        residentId: 'R-101', // Florence Nightingale
        doctorId: 'DOC-2',
        medicineName: 'Memantine',
        strength: '5mg',
        form: PrescriptionForm.tablet,
        doseAmount: '1 tablet',
        pattern: const DosePattern(morning: 1, afternoon: 0, evening: 1, night: 0),
        mealTiming: MealTiming.withMeal,
        startDate: startDate,
        durationDays: 10,
        endDate: DoseScheduleService.computeEndDate(startDate, 10),
        instructions: 'Take during breakfast & dinner',
        type: PrescriptionType.regular,
        status: PrescriptionStatus.active,
        createdAt: startDate,
      ),
      Prescription(
        id: 'RX-104',
        residentId: 'R-103', // Eleanor Vance
        doctorId: 'DOC-3',
        medicineName: 'Multivitamin',
        strength: '1 cap',
        form: PrescriptionForm.capsule,
        doseAmount: '1 capsule',
        pattern: const DosePattern(morning: 1, afternoon: 0, evening: 0, night: 0),
        mealTiming: MealTiming.afterMeal,
        startDate: startDate,
        durationDays: 30,
        endDate: DoseScheduleService.computeEndDate(startDate, 30),
        instructions: 'Daily morning supplement',
        type: PrescriptionType.regular,
        status: PrescriptionStatus.active,
        createdAt: startDate,
      ),
    ];

    _prescriptions = seedRxList;

    for (final rx in seedRxList) {
      _doseEvents.addAll(DoseScheduleService.generateEventsForPrescription(rx));
    }

    _auditLogs.add(AuditLog(
      id: 'AUD-1',
      userId: 'DOC-1',
      action: 'PRESCRIBE_MEDICINE',
      entity: 'Prescription RX-101',
      before: 'None',
      after: 'Metformin 500mg prescribed for James Perera (Room 105)',
      at: DateTime.now().subtract(const Duration(hours: 4)),
    ));
  }

  void addDoctor(DoctorModel doctor) {
    _doctors.add(doctor);
    notifyListeners();
  }

  void addPrescription(Prescription rx, String userId) {
    _prescriptions.add(rx);
    final newEvents = DoseScheduleService.generateEventsForPrescription(rx);
    _doseEvents.addAll(newEvents);
    _auditLogs.insert(0, AuditLog(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      action: 'PRESCRIBE_MEDICINE',
      entity: 'Prescription ${rx.id}',
      before: 'None',
      after: '${rx.medicineName} ${rx.strength} (${rx.pattern.summary}) prescribed',
      at: DateTime.now(),
    ));
    notifyListeners();
  }

  void stopPrescription(String rxId, String reason, String userId) {
    final index = _prescriptions.indexWhere((p) => p.id == rxId);
    if (index != -1) {
      final oldRx = _prescriptions[index];
      _prescriptions[index] = oldRx.copyWith(status: PrescriptionStatus.stopped);
      _auditLogs.insert(0, AuditLog(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        action: 'STOP_PRESCRIPTION',
        entity: 'Prescription $rxId',
        before: 'Status: active',
        after: 'Status: stopped. Reason: $reason',
        at: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  void markDoseStatus({
    required String doseEventId,
    required DoseStatus status,
    required String givenBy,
    String? note,
  }) {
    final index = _doseEvents.indexWhere((e) => e.id == doseEventId);
    if (index != -1) {
      final oldEvent = _doseEvents[index];
      _doseEvents[index] = oldEvent.copyWith(
        status: status,
        givenBy: givenBy,
        givenAt: DateTime.now(),
        note: note,
      );
      _auditLogs.insert(0, AuditLog(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        userId: givenBy,
        action: 'MARK_DOSE_STATUS',
        entity: 'DoseEvent $doseEventId',
        before: 'Status: ${oldEvent.status.name}',
        after: 'Status: ${status.name}. Note: ${note ?? "None"}',
        at: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  void markAllResidentDosesForSlot({
    required String residentId,
    required DoseSlot slot,
    required DateTime date,
    required String givenBy,
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    for (int i = 0; i < _doseEvents.length; i++) {
      final e = _doseEvents[i];
      final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
      if (e.residentId == residentId && e.slot == slot && eventDate.isAtSameMomentAs(targetDate) && e.status == DoseStatus.pending) {
        _doseEvents[i] = e.copyWith(
          status: DoseStatus.given,
          givenBy: givenBy,
          givenAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
  }
}
