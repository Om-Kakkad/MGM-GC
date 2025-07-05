import 'package:flutter/material.dart';
import 'package:mgm_gc/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:mgm_gc/pages/login/login.dart';
import 'package:mgm_gc/pages/splash/sponsor_splash.dart';
import 'package:mgm_gc/pages/signup/signup.dart';
import 'package:mgm_gc/pages/home/home_page.dart';
import 'package:mgm_gc/pages/admin/admin_panel.dart';
import 'package:mgm_gc/pages/admin/match_creation.dart';
import 'package:mgm_gc/pages/admin/team_creation.dart';
import 'package:mgm_gc/pages/admin/user_management.dart';
import 'package:mgm_gc/pages/admin/team_management.dart';
import 'package:mgm_gc/pages/admin/event_management.dart';
import 'package:mgm_gc/pages/admin/event_creation_form.dart';
import 'package:mgm_gc/pages/league/league_features.dart';
import 'package:mgm_gc/pages/league/user_league_features.dart';
import 'package:mgm_gc/pages/events/events_list.dart';
import 'package:mgm_gc/pages/events/event_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mgm_gc/pages/admin/match_management.dart';
import 'package:mgm_gc/pages/admin/sponsor_management.dart';
import 'package:mgm_gc/pages/league/join_team.dart';
import 'package:mgm_gc/pages/league/match_scoring.dart';
import 'package:mgm_gc/pages/live/live_scores_list.dart';
import 'package:mgm_gc/pages/live/live_score_detail.dart';
import 'package:mgm_gc/pages/admin/team_requests_page.dart';
import 'package:mgm_gc/pages/sponsor/sponsors_page.dart';
import 'package:mgm_gc/pages/league/aggregate_scores.dart';
import 'package:provider/provider.dart';
import 'package:mgm_gc/services/tee_time_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    // Connect to Firebase emulators
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

    print('Connected to Firebase emulators: Auth, Firestore, and Functions');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => TeeTimeService())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SponsorSplash(),
          '/login': (context) => Login(),
          '/signup': (context) => Signup(),
          '/home': (context) => HomePage(),
          '/admin': (context) => AdminPanel(),
          '/league': (context) => LeagueFeatures(),
          '/user-league': (context) => const UserLeagueFeatures(),
          '/events': (context) => const EventsListPage(),
          '/event-details': (context) => const EventDetailsPage(),
          '/create-match': (context) => const MatchCreationForm(),
          '/create-team': (context) => const TeamCreationForm(),
          '/user-management': (context) => const UserManagementPage(),
          '/team-management': (context) => const TeamManagementPage(),
          '/event-management': (context) => const EventManagementPage(),
          '/match-management': (context) => const MatchManagementPage(),
          '/sponsor-management': (context) => const SponsorManagementPage(),
          '/team-requests': (context) => const TeamRequestsPage(),
          '/create-event': (context) => const EventCreationForm(),
          '/join-team': (context) => const JoinTeamPage(),
          '/live-scores': (context) => const LiveScoresListPage(),
          '/live-score-detail': (context) => const LiveScoreDetailPage(),
          '/sponsors': (context) => const SponsorsPage(),
          '/aggregate-scores': (context) => const AggregateScoresPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/match_scoring') {
            final args = settings.arguments as Map<String, String>;
            return MaterialPageRoute(
              builder: (context) => MatchScoringPage(),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}
