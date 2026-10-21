import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carevora/features/auth/application/auth_controller.dart';
import 'package:carevora/features/dashboard/presentation/settings_page.dart';

class MockElderAuthNotifier extends AuthNotifier {
  @override
  AuthState get state => const AuthState(
        isAuthenticated: true,
        userName: 'James Perera',
        role: UserRole.elder,
        residentId: 1,
        elderHomeId: 1,
        elderHomeName: 'Serenity Elder Home',
        token: 'test-elder-token',
      );
}

class MockCaregiverAuthNotifier extends AuthNotifier {
  @override
  AuthState get state => const AuthState(
        isAuthenticated: true,
        userName: 'Pasidi Sarangi',
        role: UserRole.caregiver,
        elderHomeId: 1,
        elderHomeName: 'Serenity Elder Home',
        token: 'test-caregiver-token',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsPage Role Adaptation & Feature Tests', () {
    testWidgets('1. SettingsPage renders elder-specific living and accessibility preferences for Elder role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockElderAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Elder Headers & Badges
      expect(find.text('Personal Living & Display Settings'), findsOneWidget);
      expect(find.text('SENIOR RESIDENT'), findsOneWidget);
      expect(find.text('James Perera'), findsOneWidget);

      // Verify Elder-specific sections & controls
      expect(find.text('Easy Reading & Screen Comfort'), findsOneWidget);
      expect(find.text('Large & Clear Text'), findsOneWidget);
      expect(find.text('High Contrast Mode'), findsOneWidget);
      expect(find.text('Gentle Calming Colors'), findsOneWidget);

      expect(find.text('Spoken Audio & Voice Assistance'), findsOneWidget);
      expect(find.text('Read Questions Out Loud'), findsOneWidget);
      expect(find.text('Voice Reading Speed'), findsOneWidget);
      expect(find.text('Uplifting Game Sounds'), findsOneWidget);

      // Verify Caregiver & Station Help has been moved away from Settings
      expect(find.text('Caregiver & Station Help'), findsNothing);
      expect(find.text('Quick Call Caregiver Button'), findsNothing);

      // Verify Caregiver-specific sections are NOT rendered
      expect(find.text('Care Specialist Settings'), findsNothing);
      expect(find.text('STAFF CAREGIVER'), findsNothing);
      expect(find.text('Critical Cognitive Decline Alerts'), findsNothing);
      expect(find.text('Medication Overdue Warnings'), findsNothing);
    });

    testWidgets('2. SettingsPage renders caregiver clinical and telemetry settings for Caregiver role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Caregiver Headers & Badges
      expect(find.text('Care Specialist Settings'), findsOneWidget);
      expect(find.text('STAFF CAREGIVER'), findsOneWidget);
      expect(find.text('Pasidi Sarangi'), findsOneWidget);

      // Verify Caregiver-specific clinical alerts
      expect(find.text('Clinical Alerts & Threshold Notifications'), findsOneWidget);
      expect(find.text('Critical Cognitive Decline Alerts'), findsOneWidget);
      expect(find.text('Medication Overdue Warnings'), findsOneWidget);
      expect(find.text('Metabolic & Vitals Anomaly Alarms'), findsOneWidget);
      expect(find.text('Audible Chime for High-Risk Events'), findsOneWidget);

      // Verify Caregiver-specific assessment tooling & compliance
      expect(find.text('Auto-Read Prompts to Resident'), findsOneWidget);
      expect(find.text('Real-time AI Speech Confidence Meter'), findsOneWidget);
      expect(find.text('Encrypted Offline Session Caching'), findsOneWidget);
      expect(find.text('Clinical Report Export Format'), findsOneWidget);

      // Verify Elder-specific sections are NOT rendered
      expect(find.text('Personal Living & Display Settings'), findsNothing);
      expect(find.text('SENIOR RESIDENT'), findsNothing);
      expect(find.text('Quick Call Caregiver Button'), findsNothing);
      expect(find.text('Uplifting Game Sounds'), findsNothing);
    });

    testWidgets('3. Save Preferences displays confirmation feedback for Caregiver', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.text('Save Preferences');
      expect(saveButton, findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Clinical and system settings updated successfully!'), findsOneWidget);
    });
  });
}
