import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:carevora/features/auth/application/auth_controller.dart';
import 'package:carevora/features/dashboard/presentation/care_station_help_page.dart';

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

  group('CareStationHelpPage Feature & Calling Tests', () {
    testWidgets('1. Elder view displays caregiver contacts, medical doctors, and active call dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockElderAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CareStationHelpPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Elder Headers & Emergency Banner removed as requested
      expect(find.text('Caregiver & Station Help'), findsOneWidget);
      expect(find.text('Emergency SOS Assistance'), findsNothing);
      expect(find.text('SOS Call'), findsNothing);

      // Verify Assigned Caregivers & Nurses
      expect(find.text('My Assigned Caregivers & Nurses'), findsOneWidget);
      expect(find.text('Caregiver Pasidi Sarangi'), findsOneWidget);
      expect(find.text('Nurse Seetha N. (RN)'), findsOneWidget);
      expect(find.text('Station 2 Central Reception'), findsOneWidget);

      // Verify WhatsApp button is present for caregiver
      expect(find.text('WhatsApp'), findsOneWidget);
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();

      // Verify Doctors
      expect(find.text('My Consulting Medical Doctors'), findsOneWidget);
      expect(find.text('Dr. Nimal Fernando'), findsOneWidget);
      expect(find.text('Dr. Aris Thorne'), findsOneWidget);

      // Tap call on Caregiver Pasidi Sarangi
      final callButtons = find.text('Call');
      expect(callButtons, findsWidgets);

      await tester.tap(callButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Active Call Dialog opened
      expect(find.text('Caregiver Pasidi Sarangi'), findsWidgets);
      expect(find.byIcon(LucideIcons.phoneOff), findsOneWidget);

      // End Call
      await tester.tap(find.byIcon(LucideIcons.phoneOff));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.phoneOff), findsNothing);
    });

    testWidgets('2. Caregiver view displays resident calling, doctor calling, search, and intercom tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CareStationHelpPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Caregiver Header
      expect(find.text('Care Station & Emergency Calls'), findsOneWidget);

      // Verify Tabs
      expect(find.text('Call Residents (Elders)'), findsOneWidget);
      expect(find.text('Call Doctors'), findsOneWidget);
      expect(find.text('Duty Stations'), findsOneWidget);

      // Verify Residents are listed by default
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('James Perera'), findsOneWidget);
      expect(find.text('Arthur Pendelton'), findsOneWidget);

      // Test Search
      await tester.enterText(find.byType(TextField), 'James Perera');
      await tester.pumpAndSettle();

      expect(find.text('Room 105 • North Wing'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsNothing);

      // Switch to Call Doctors tab
      await tester.tap(find.text('Call Doctors'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Nimal Fernando'), findsOneWidget);
      expect(find.text('Dr. Aris Thorne'), findsOneWidget);

      // Test Calling Doctor
      final voiceCallButtons = find.text('Voice Call');
      expect(voiceCallButtons, findsWidgets);

      await tester.tap(voiceCallButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Active dialog
      expect(find.byIcon(LucideIcons.phoneOff), findsOneWidget);

      // End call
      await tester.tap(find.byIcon(LucideIcons.phoneOff));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.phoneOff), findsNothing);
    });
  });
}
