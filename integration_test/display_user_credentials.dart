import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mgm_gc/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets('Display all user credentials for league setup test', (
    tester,
  ) async {
    final auth = FirebaseAuth.instance;
    final store = FirebaseFirestore.instance;

    // Admin credentials from the league setup test
    const adminEmail = 'league_setup_admin@example.com';
    const adminPassword = 'AdminTest@123';

    print('========== USER CREDENTIALS ==========');
    print('\nADMIN USER:');
    print('Email: $adminEmail');
    print('Password: $adminPassword');

    print('\nPLAYER USERS:');
    print('- All players have password: Player@123');

    // Format for player emails used in the test
    print(
      '\nPlayer email format: player_setup_[teamIndex]_[playerIndex]@example.com',
    );
    print('Where:');
    print('- teamIndex: 0-9 (representing the 10 teams)');
    print('- playerIndex: 0-9 (representing the 10 players per team)');

    print('\nExample player emails:');
    for (int teamIndex = 0; teamIndex < 10; teamIndex++) {
      print('\nTeam $teamIndex players:');
      for (int playerIndex = 0; playerIndex < 10; playerIndex++) {
        final email = 'player_setup_${teamIndex}_$playerIndex@example.com';
        String bracket;
        if (playerIndex < 3) {
          bracket = 'Gold';
        } else if (playerIndex < 6) {
          bracket = 'Silver';
        } else {
          bracket = 'Bronze';
        }
        print('- $email (Bracket: $bracket)');
      }
    }

    print('\n========== TEAM PASSWORDS ==========');
    final teamNames = [
      'Eagles Flight',
      'Birdie Masters',
      'Ace Hunters',
      'Par Breakers',
      'Iron Shots',
      'Green Warriors',
      'Fairway Legends',
      'Chip Shots',
      'Sand Trap Kings',
      'Eagle Eye',
    ];

    for (var i = 0; i < 10; i++) {
      print('Team: ${teamNames[i]} - Password: team${i + 1}pass');
    }

    print('\n========== EVENT INFORMATION ==========');
    print('Event Name: League Setup Championship');
    print('Event Type: League');
    print('Bracket Type: Multi-Tier');

    print('\nTo access this data in Firebase:');
    print('1. Use the Firebase emulator at localhost:8080');
    print('2. Login with the admin credentials above');
    print('3. Browse events, teams, and matches collections');
  });
}
