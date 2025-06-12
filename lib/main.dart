import 'package:flutter/material.dart';
import 'package:mgm_gc/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:mgm_gc/pages/login/login.dart';
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
import 'package:mgm_gc/pages/events/events_list.dart';
import 'package:mgm_gc/pages/events/event_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mgm_gc/pages/admin/match_management.dart';
import 'package:mgm_gc/pages/league/join_team.dart';
import 'package:mgm_gc/pages/league/match_scoring.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => Login(),
        '/signup': (context) => Signup(),
        '/home': (context) => HomePage(),
        '/admin': (context) => AdminPanel(),
        '/league': (context) => LeagueFeatures(),
        '/events': (context) => const EventsListPage(),
        '/event-details': (context) => const EventDetailsPage(),
        '/create-match': (context) => const MatchCreationForm(),
        '/create-team': (context) => const TeamCreationForm(),
        '/user-management': (context) => const UserManagementPage(),
        '/team-management': (context) => const TeamManagementPage(),
        '/event-management': (context) => const EventManagementPage(),
        '/match-management': (context) => const MatchManagementPage(),
        '/create-event': (context) => const EventCreationForm(),
        '/join-team': (context) => const JoinTeamPage(),
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
    );
  }
}
