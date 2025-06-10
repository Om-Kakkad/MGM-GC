import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mgm_gc/firebase_options.dart';
import 'package:mgm_gc/models/team.dart';
import 'package:mgm_gc/services/team_service.dart';
import 'package:mgm_gc/services/match_service.dart';
import 'package:mgm_gc/models/match_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets('admin workflow end to end', (tester) async {
    final auth = FirebaseAuth.instance;
    final store = FirebaseFirestore.instance;
    final teamService = TeamService();
    final matchService = MatchService();

    const adminEmail = 'integration_admin@example.com';
    const adminPassword = 'AdminTest@123';

    // 1. create admin user
    final adminCred = await auth.createUserWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    final adminId = adminCred.user!.uid;
    await store.collection('users').doc(adminId).set({
      'uid': adminId,
      'email': adminEmail,
      'role': 'admin',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // 2. log out
    await auth.signOut();

    // 3. log back in
    await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    expect(auth.currentUser, isNotNull);

    // 4. create league event with match play scoring
    final eventRef = await store.collection('events').add({
      'eventName': 'Integration League',
      'eventType': 'League',
      'scoringType': 'Matchplay',
      'eventDates': [
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });
    final eventId = eventRef.id;
    await eventRef.update({'eventID': eventId});

    // 5. create 4 teams for the event
    final teams = <Team>[];
    for (var i = 0; i < 4; i++) {
      final t = Team(
        teamName: 'Team ${i + 1}',
        teamPassword: 'TeamPass${i + 1}!',
        eventID: eventId,
      );
      final id = await teamService.createTeam(t);
      teams.add(
        Team(
          teamID: id,
          teamName: t.teamName,
          teamPassword: t.teamPassword,
          eventID: eventId,
        ),
      );
    }

    // 6. log out admin
    await auth.signOut();

    // 7. create 3 players per team using team password
    for (final team in teams) {
      for (var i = 0; i < 3; i++) {
        final email =
            'player_${team.teamName.replaceAll(' ', '').toLowerCase()}${i + 1}@example.com';
        final password = 'Player${i + 1}@123';
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user!.uid;
        await store.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'role': 'league_player',
          'golfDetails': {
            'playingInLeague': true,
            'teamId': team.teamID,
            'teamName': team.teamName,
            'eventId': eventId,
          },
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        await store
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .doc(team.teamID)
            .update({
              'players': FieldValue.arrayUnion([uid]),
            });
      }
    }

    // 8. login as admin again
    await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );

    // fetch players for match creation
    final playersByTeam = <String, List<String>>{};
    for (final team in teams) {
      final doc =
          await store
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(team.teamID)
              .get();
      playersByTeam[team.teamID!] = List<String>.from(
        doc['players'] as List<dynamic>,
      );
    }

    DateTime baseDate = DateTime.now().add(const Duration(days: 1));

    // helper to create a match
    Future<void> createMatch(
      String type,
      List<String> teamIds,
      List<String> teamAPlayers,
      List<String> teamBPlayers,
      int offset,
    ) async {
      final match = Match(
        eventID: eventId,
        teams: teamIds,
        players: {'teamA': teamAPlayers, 'teamB': teamBPlayers},
        matchType: type,
        matchDateTime: baseDate.add(Duration(hours: offset)),
      );
      await matchService.createMatch(match);
    }

    // Two 2-ball matches
    await createMatch(
      '2-ball',
      [teams[0].teamID!, teams[1].teamID!],
      [playersByTeam[teams[0].teamID!]![0]],
      [playersByTeam[teams[1].teamID!]![0]],
      0,
    );
    await createMatch(
      '2-ball',
      [teams[2].teamID!, teams[3].teamID!],
      [playersByTeam[teams[2].teamID!]![0]],
      [playersByTeam[teams[3].teamID!]![0]],
      1,
    );

    // Four 4-ball matches
    await createMatch(
      '4-ball',
      [teams[0].teamID!, teams[2].teamID!],
      [
        playersByTeam[teams[0].teamID!]![1],
        playersByTeam[teams[0].teamID!]![2],
      ],
      [
        playersByTeam[teams[2].teamID!]![1],
        playersByTeam[teams[2].teamID!]![2],
      ],
      2,
    );
    await createMatch(
      '4-ball',
      [teams[1].teamID!, teams[3].teamID!],
      [
        playersByTeam[teams[1].teamID!]![1],
        playersByTeam[teams[1].teamID!]![2],
      ],
      [
        playersByTeam[teams[3].teamID!]![1],
        playersByTeam[teams[3].teamID!]![2],
      ],
      3,
    );

    await createMatch(
      '4-ball',
      [teams[0].teamID!, teams[1].teamID!],
      [playersByTeam[teams[0].teamID!]![0]],
      [playersByTeam[teams[1].teamID!]![1]],
      4,
    );
    await createMatch(
      '4-ball',
      [teams[2].teamID!, teams[3].teamID!],
      [playersByTeam[teams[2].teamID!]![0]],
      [playersByTeam[teams[3].teamID!]![1]],
      5,
    );

    // verify matches count
    final matchesSnapshot =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .get();
    expect(matchesSnapshot.docs.length, 6);
  });
}
