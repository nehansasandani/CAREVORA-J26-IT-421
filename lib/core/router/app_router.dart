import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/dashboard/presentation/dashboard_shell.dart';
import '../../features/dashboard/presentation/overview_page.dart';
import '../../features/dashboard/presentation/resident_directory_page.dart';
import '../../features/dashboard/presentation/generic_placeholder_tab.dart';
import '../../features/dashboard/presentation/alerts_notifications_page.dart';
import '../../features/dashboard/presentation/care_plans_page.dart';
import '../../features/dashboard/presentation/memory_games_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/doctor/presentation/pages/doctor_dashboard_page.dart';
import '../../features/medicine/presentation/pages/live_medicine_board_page.dart';
import '../../features/medicine/presentation/pages/medicine_history_page.dart';
import '../../features/assessment/presentation/assessment_session_page.dart';
import '../../features/assessment/presentation/emotional_wellness_page.dart';
import '../../features/assessment/presentation/caregiver_social_audit_dashboard_page.dart';
import '../../features/assessment/presentation/resident_social_audit_detail_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/metabolic/presentation/metabolic_health_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final reason = state.uri.queryParameters['reason'];
          return LoginPage(timeoutReason: reason);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const OverviewPage(),
          ),
          GoRoute(
            path: '/dashboard/residents',
            builder: (context, state) => const ResidentDirectoryPage(),
          ),
          GoRoute(
            path: '/dashboard/cognitive/session',
            builder: (context, state) => const AssessmentSessionPage(),
          ),
          GoRoute(
            path: '/dashboard/emotional',
            builder: (context, state) {
              final resId = state.uri.queryParameters['residentId'];
              return EmotionalWellnessPage(initialResidentId: resId);
            },
          ),
          GoRoute(
            path: '/dashboard/emotional/session',
            builder: (context, state) {
              final resId = state.uri.queryParameters['residentId'];
              return EmotionalWellnessPage(initialResidentId: resId);
            },
          ),
          GoRoute(
            path: '/dashboard/metabolic',
            builder: (context, state) {
              final idParam = state.uri.queryParameters['residentId'];
              return MetabolicHealthPage(
                key: ValueKey(state.uri.toString()),
                initialResidentId: idParam != null ? int.tryParse(idParam) : null,
                startNew: state.uri.queryParameters['new'] == '1',
                showHistory: state.uri.queryParameters['history'] == '1',
              );
            },
          ),
          GoRoute(
            path: '/dashboard/alerts',
            builder: (context, state) => const AlertsNotificationsPage(),
          ),
          GoRoute(
            path: '/dashboard/reports',
            builder: (context, state) => const ResidentDirectoryPage(),
          ),
          GoRoute(
            path: '/dashboard/care-plans',
            builder: (context, state) {
              final idParam = state.uri.queryParameters['residentId'];
              final id = idParam != null ? int.tryParse(idParam) : null;
              return CarePlansPage(initialResidentId: id);
            },
          ),
          GoRoute(
            path: '/dashboard/doctor',
            builder: (context, state) => const DoctorDashboardPage(),
          ),
          GoRoute(
            path: '/dashboard/medicine',
            builder: (context, state) => const LiveMedicineBoardPage(),
          ),
          GoRoute(
            path: '/dashboard/medicine/history',
            builder: (context, state) => const MedicineHistoryPage(),
          ),
          GoRoute(
            path: '/dashboard/social-audit',
            builder: (context, state) => const CaregiverSocialAuditDashboardPage(),
          ),
          GoRoute(
            path: '/dashboard/social-audit/resident/:id',
            builder: (context, state) {
              final residentId = state.pathParameters['id'] ?? '1';
              return ResidentSocialAuditDetailPage(residentId: residentId);
            },
          ),
          GoRoute(
            path: '/dashboard/memory-games',
            builder: (context, state) => const MemoryGamesPage(),
          ),
          GoRoute(
            path: '/dashboard/settings',
            builder: (context, state) => const GenericPlaceholderTab(
              title: 'Facility Settings',
              description: 'Accessibility, text sizing, and clinical telemetry configurations',
              icon: LucideIcons.settings,
            ),
          ),
        ],
      ),
    ],
  );
}
