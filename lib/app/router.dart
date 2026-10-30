import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/config/center_config.dart';
import '../features/center/center_setup_screen.dart';
import '../features/clock/clock_screen.dart';
import '../features/advances/advances_screen.dart';
import '../features/advances/advance_decision_screen.dart';
import '../features/student_portal/student_portal_repo.dart';
import '../features/absence/absence_report_screen.dart';
import '../features/absence/absence_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/shell.dart';
import '../features/inscription/inscription_screen.dart';
import '../features/login/forgot_screen.dart';
import '../features/login/login_screen.dart';
import '../features/payments/due_payments_screen.dart';
import '../features/polycopie/polycopie_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/records/teacher_stats_screen.dart';
import '../features/records/new_record_screen.dart';
import '../features/records/records_screen.dart';
import '../features/records/report_entry_screen.dart';
import '../features/records/report_groups_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/students/student_detail_screen.dart';
import '../features/students/student_payment_screen.dart';
import '../features/students/students_screen.dart';
import '../features/student_portal/student_login_screen.dart';
import '../features/student_portal/student_space_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final student = ref.watch(studentAuthProvider);
  final center = ref.watch(centerConfigProvider);
  final centerReady = ref.watch(centerConfigReadyProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Marque blanche : tant qu'aucun centre n'est adopté, le seul écran
      // possible est la saisie du code centre. On attend la fin de la
      // restauration pour ne pas y envoyer un utilisateur déjà configuré.
      if (centerReady && center == null) {
        return loc == '/center' ? null : '/center';
      }
      if (center != null && loc == '/center') return '/eleve/login';
      // Espace élève : univers séparé (jeton `scope: student`). Un élève
      // connecté n'accède jamais aux écrans du personnel, et inversement.
      final inStudentSpace = loc.startsWith('/eleve');
      if (student != null) {
        return inStudentSpace && loc != '/eleve/login' ? null : '/eleve';
      }
      if (inStudentSpace) return null; // écran de connexion élève

      final loggingIn = loc == '/login' || loc == '/forgot';
      if (auth.loading) return null;
      if (!auth.isLoggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/center', builder: (_, __) => const CenterSetupScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/eleve/login',
          builder: (_, __) => const StudentLoginScreen()),
      GoRoute(path: '/eleve', builder: (_, __) => const StudentSpaceScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/inscription',
        builder: (_, __) => const InscriptionScreen(),
      ),
      GoRoute(
        path: '/students/:id',
        builder: (_, state) => StudentDetailScreen(
          studentId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/students/:id/pay',
        builder: (_, state) => StudentPaymentScreen(
          studentId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/absence/report',
        builder: (_, __) => const AbsenceReportScreen(),
      ),
      GoRoute(
        path: '/records/new',
        builder: (_, __) => const NewRecordScreen(),
      ),
      // Pointage du professeur. `/pointage/scan?t=…` est aussi l'URL encodée
      // dans le QR de l'accueil : ouverte par l'appareil photo, elle arrive ici
      // par lien profond et le jeton part sans passer par la caméra.
      GoRoute(
        path: '/pointage',
        builder: (_, __) => const ClockScreen(),
      ),
      GoRoute(
        path: '/pointage/scan',
        builder: (_, state) => ClockScreen(initialToken: state.uri.queryParameters['t']),
      ),
      GoRoute(
        path: '/polycopie',
        builder: (_, __) => const PolycopieScreen(),
      ),
      GoRoute(
        path: '/records/stats',
        builder: (_, __) => const TeacherStatsScreen(),
      ),
      // Avances sur salaire : boîte de réception puis page de confirmation.
      GoRoute(
        path: '/avances',
        builder: (_, __) => const AdvancesScreen(),
      ),
      GoRoute(
        path: '/avances/:id',
        builder: (_, state) => AdvanceDecisionScreen(
            advanceId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
      ),
      GoRoute(
        path: '/payments/due',
        builder: (_, __) => const DuePaymentsScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const ReportGroupsScreen(),
      ),
      GoRoute(
        path: '/reports/entry',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ReportEntryScreen(
            levelId: int.parse(q['levelId']!),
            group: q['group'] ?? '',
            subject: q['subject'] ?? '',
            levelName: q['levelName'] ?? '',
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/students',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: StudentsScreen()),
          ),
          GoRoute(
            path: '/schedule',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ScheduleScreen()),
          ),
          GoRoute(
            path: '/absence',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AbsenceScreen()),
          ),
          GoRoute(
            path: '/records',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: RecordsScreen()),
          ),
        ],
      ),
    ],
  );
});
