import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:carevora/data/mock/mock_carevora_data.dart';
import 'package:carevora/data/models/carevora_models.dart';
import 'package:carevora/features/auth/application/auth_controller.dart';
import 'package:carevora/features/dashboard/presentation/alerts_notifications_page.dart';
import 'package:carevora/features/dashboard/presentation/dashboard_shell.dart';
import 'package:carevora/features/dashboard/presentation/overview_page.dart';
import 'package:carevora/shared/widgets/alerts_list_widget.dart';
import 'package:carevora/shared/widgets/desktop_sidebar.dart';
import 'package:carevora/shared/widgets/mobile_bottom_nav.dart';

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
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed') ||
          details.exceptionAsString().contains('RenderFlex')) {
        return;
      }
      FlutterError.dumpErrorToConsole(details);
    };
  });

  group('Elder Alerts & Notifications Visibility Control', () {
    testWidgets('1. DesktopSidebar hides Alerts & Notifications for elders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockElderAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DesktopSidebar(currentRoute: '/dashboard', isCollapsed: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alerts & Notifications'), findsNothing);
      expect(find.text('Memory Games'), findsOneWidget);
    });

    testWidgets('2. DesktopSidebar shows Alerts & Notifications for caregivers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DesktopSidebar(currentRoute: '/dashboard', isCollapsed: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alerts & Notifications'), findsOneWidget);
      expect(find.text('Resident Directory'), findsOneWidget);
    });

    testWidgets('3. DashboardShell hides bell notification icon for elders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardShell(
              child: SizedBox(key: Key('content')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockElderAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.bell), findsNothing);
      expect(find.text("Here's your personal wellness overview."), findsOneWidget);
    });

    testWidgets('4. DashboardShell shows bell notification icon for caregivers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardShell(
              child: SizedBox(key: Key('content')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();

      expect(find.byIcon(LucideIcons.bell), findsWidgets);
      expect(find.text("Here's the overall wellness overview of your residents."), findsOneWidget);
    });

    testWidgets('5. OverviewPage hides AlertsListWidget for elders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Scaffold(
              body: OverviewPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockElderAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();

      expect(find.byType(AlertsListWidget), findsNothing);
      expect(find.text('Alerts & Notifications'), findsNothing);
    });

    testWidgets('6. OverviewPage shows AlertsListWidget for caregivers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1400));

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Scaffold(
              body: OverviewPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();

      expect(find.byType(AlertsListWidget), findsOneWidget);
      expect(find.text('Alerts & Notifications'), findsOneWidget);
    });

    testWidgets('7. AlertsNotificationsPage shows staff-only shield for elders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));

      final router = GoRouter(
        initialLocation: '/dashboard/alerts',
        routes: [
          GoRoute(
            path: '/dashboard/alerts',
            builder: (context, state) => const Scaffold(
              body: AlertsNotificationsPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockElderAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();

      expect(find.text('Clinical Alerts are Staff-Only'), findsOneWidget);
      expect(find.text('Return to Overview'), findsOneWidget);
      expect(find.text('Alerts & Clinical Notifications'), findsNothing);
    });

    testWidgets('8. AlertsNotificationsPage shows clinical alerts for caregivers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));

      final router = GoRouter(
        initialLocation: '/dashboard/alerts',
        routes: [
          GoRoute(
            path: '/dashboard/alerts',
            builder: (context, state) => const Scaffold(
              body: AlertsNotificationsPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();

      expect(find.text('Alerts & Clinical Notifications'), findsOneWidget);
      expect(find.text('Clinical Alerts are Staff-Only'), findsNothing);
      expect(find.text('Pasidi Sarangi'), findsOneWidget);
    });

    testWidgets('9. Real high risk cognitive assessment displays real elder details in caregiver alerts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));

      MockCarevoraData.alerts.removeWhere((a) => a.id.startsWith('ALT-COG'));
      MockCarevoraData.alerts.insert(
        0,
        const AlertItem(
          id: 'ALT-COG-REAL-1-100',
          title: 'High Cognitive Impairment Risk: Sarah Jenkins',
          description:
              'Cognitive assessment score (42.5/100) indicates acute cognitive decline risk for Sarah Jenkins in room 204. Urgent caregiver review and clinical attention required.',
          severity: 'High',
          timestamp: 'Just now',
          residentName: 'Sarah Jenkins',
          roomNo: '204',
          residentAge: 81,
          residentGender: 'Female',
          currentStatus: 'High Cognitive Risk',
          cognitiveScore: 42.5,
        ),
      );

      final router = GoRouter(
        initialLocation: '/dashboard/alerts',
        routes: [
          GoRoute(
            path: '/dashboard/alerts',
            builder: (context, state) => const Scaffold(
              body: AlertsNotificationsPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();

      expect(find.text('High Cognitive Impairment Risk: Sarah Jenkins'), findsOneWidget);
      expect(find.text('Room 204'), findsOneWidget);
      expect(find.text('Cognitive Score: 42.5 / 100'), findsOneWidget);
    });

    testWidgets('10. Serenity Elder Home high risk cognitive alerts display Senarath and James Perera with details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));

      MockCarevoraData.alerts.removeWhere((a) => a.id.startsWith('ALT-COG'));

      final router = GoRouter(
        initialLocation: '/dashboard/alerts',
        routes: [
          GoRoute(
            path: '/dashboard/alerts',
            builder: (context, state) => const Scaffold(
              body: AlertsNotificationsPage(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();

      expect(find.text('High Cognitive Impairment Risk: Senarath'), findsOneWidget);
      expect(find.text('Room 101'), findsOneWidget);
      expect(find.text('Cognitive Score: 41.3 / 100'), findsOneWidget);

      expect(find.text('High Cognitive Impairment Risk: James Perera'), findsOneWidget);
      expect(find.text('Room 25'), findsOneWidget);
      expect(find.text('Cognitive Score: 48.8 / 100'), findsOneWidget);
    });

    testWidgets('11. DesktopSidebar hides Cognitive Assessment, Emotional Wellness, and Metabolic Health for caregivers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockCaregiverAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DesktopSidebar(currentRoute: '/dashboard/residents', isCollapsed: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsNothing);
      expect(find.text('Cognitive Assessment'), findsNothing);
      expect(find.text('Emotional Wellness'), findsNothing);
      expect(find.text('Metabolic Health'), findsNothing);
      expect(find.text('Resident Directory'), findsOneWidget);
    });

    testWidgets('12. DesktopSidebar displays Cognitive Assessment, Emotional Wellness, and Metabolic Health for elders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockElderAuthNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DesktopSidebar(currentRoute: '/dashboard', isCollapsed: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Cognitive Assessment'), findsOneWidget);
      expect(find.text('Emotional Wellness'), findsOneWidget);
      expect(find.text('Metabolic Health'), findsOneWidget);
    });

    testWidgets('13. MobileBottomNav hides Assess for caregivers and shows for elders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 667));

      // Caregiver check
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileBottomNav(
              currentRoute: '/dashboard/residents',
              isElder: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assess'), findsNothing);
      expect(find.text('Residents'), findsOneWidget);

      // Elder check
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileBottomNav(
              currentRoute: '/dashboard',
              isElder: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assess'), findsOneWidget);
    });
  });
}

