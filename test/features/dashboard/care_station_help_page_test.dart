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
        userName: 'Malini Bandara',
        role: UserRole.elder,
        residentId: 165,
        elderHomeId: 3,
        elderHomeName: 'Serenity Elder Home',
        token: 'test-elder-token',
      );
}

class MockSereneElderAuthNotifier extends AuthNotifier {
  @override
  AuthState get state => const AuthState(
        isAuthenticated: true,
        userName: 'Sarah Jenkins',
        role: UserRole.elder,
        residentId: 1,
        elderHomeId: 1,
        elderHomeName: 'Serene Valley Senior Living',
        token: 'test-serene-elder-token',
      );
}

class MockCaregiverAuthNotifier extends AuthNotifier {
  @override
  AuthState get state => const AuthState(
        isAuthenticated: true,
        userName: 'Pasidi Sarangi',
        role: UserRole.caregiver,
        elderHomeId: 3,
        elderHomeName: 'Serenity Elder Home',
        token: 'test-caregiver-token',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CareStationHelpPage Feature & Calling Tests', () {
    testWidgets('1. Elder view displays ONLY caregivers belonging to the logged-in elder home', (tester) async {
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

      // Verify Elder Header
      expect(find.text('Caregiver & Station Help'), findsOneWidget);
      expect(find.text('Emergency SOS Assistance'), findsNothing);
      expect(find.text('SOS Call'), findsNothing);

      // Verify ONLY caregivers belonging to Serenity Elder Home (Home 3) are displayed
      expect(find.text('My Assigned Caregivers'), findsOneWidget);
      expect(find.text('Caregiver Pasidi Sarangi'), findsOneWidget);
      expect(find.text('Caregiver Maya Ekanayaka'), findsOneWidget);
      expect(find.text('Caregiver Indika Perera'), findsOneWidget);
      expect(find.text('Caregiver Malini Silva'), findsOneWidget);
      expect(find.text('Caregiver Sarangi'), findsOneWidget);

      // Verify other elder homes caregivers are NOT shown
      expect(find.text('Caregiver Eleanor Vance'), findsNothing);
      expect(find.text('Caregiver David Silva'), findsNothing);
      expect(find.text('Caregiver Florence Nightingale'), findsNothing);
      expect(find.text('Caregiver Clara Barton'), findsNothing);

      // Verify phone number is NOT displayed anywhere on the UI
      expect(find.textContaining('+94 76 037 6031'), findsNothing);
      expect(find.textContaining('94760376031'), findsNothing);

      // Verify Nurses, Stations, and Doctors are excluded from Elder view
      expect(find.text('Nurse Seetha N. (RN)'), findsNothing);
      expect(find.text('Station 2 Central Reception'), findsNothing);
      expect(find.text('My Consulting Medical Doctors'), findsNothing);
      expect(find.text('Dr. Nimal Fernando'), findsNothing);

      // Verify direct WhatsApp Start Voice Call buttons are present
      final startVoiceCallButtons = find.text('Start Voice Call');
      expect(startVoiceCallButtons, findsWidgets);

      // Tap Start Voice Call on the first caregiver (Caregiver Sarangi)
      await tester.tap(startVoiceCallButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Active Call Dialog opened without exposing the raw phone number
      expect(find.text('Caregiver Sarangi'), findsWidgets);
      expect(find.textContaining('+94 76 037 6031'), findsNothing);
      expect(find.byIcon(LucideIcons.phoneOff), findsOneWidget);

      // End Call
      await tester.tap(find.byIcon(LucideIcons.phoneOff));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.phoneOff), findsNothing);
    });

    testWidgets('1b. Serene Valley Elder view displays strictly Serene Valley caregivers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockSereneElderAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CareStationHelpPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ONLY caregivers belonging to Serene Valley Senior Living (Home 1) are shown
      expect(find.text('Caregiver Eleanor Vance'), findsOneWidget);
      expect(find.text('Caregiver Florence Nightingale'), findsOneWidget);
      expect(find.text('Caregiver Clara Barton'), findsOneWidget);

      // Other homes are NOT shown
      expect(find.text('Caregiver Pasidi Sarangi'), findsNothing);
      expect(find.text('Caregiver Maya Ekanayaka'), findsNothing);
      expect(find.text('Caregiver David Silva'), findsNothing);

      // Raw phone number is NOT shown
      expect(find.textContaining('+94 76 037 6031'), findsNothing);
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
