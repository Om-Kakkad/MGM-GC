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
      'eventDates': [Timestamp.fromDate(DateTime.now())],
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

        // Assign handicaps so each team has one low, one mid, and one high handicap player
        double handicap;
        if (i == 0) {
          // Low handicap range (0-8)
          handicap = 2.0 + teams.indexOf(team) * 2.0; // 2, 4, 6, 8
        } else if (i == 1) {
          // Mid handicap range (9-16)
          handicap = 10.0 + teams.indexOf(team) * 1.5; // 10, 11.5, 13, 14.5
        } else {
          // High handicap range (17-24)
          handicap = 18.0 + teams.indexOf(team) * 1.5; // 18, 19.5, 21, 22.5
        }

        await store.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'firstName': 'Player', // Add first name
          'lastName':
              '${team.teamName} ${i + 1}', // Add last name with team context
          'role': 'league_player',
          'golfDetails': {
            'playingInLeague': true,
            'teamId': team.teamID,
            'teamName': team.teamName,
            'eventId': eventId,
            'handicap': handicap, // Balanced handicap distribution
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

    DateTime baseDate = DateTime.now();

    // helper to create a match
    Future<void> createMatch(
      String type,
      List<String> teamIds,
      List<String> teamAPlayers,
      List<String> teamBPlayers,
      int offset,
      String matchPlayType,
      bool bonusPoint, // Add bonusPoint parameter
    ) async {
      final match = Match(
        eventID: eventId,
        teams: teamIds,
        players: {'teamA': teamAPlayers, 'teamB': teamBPlayers},
        matchType: type,
        matchPlayType: matchPlayType,
        matchDateTime: baseDate.add(Duration(hours: offset)),
        bonusPoint: bonusPoint, // Set bonusPoint in Match object
      );
      await matchService.createMatch(match);
    }

    // Create matches for scoring tests
    await createMatch(
      '4-ball',
      [teams[0].teamID!, teams[1].teamID!],
      [
        playersByTeam[teams[0].teamID!]![0],
        playersByTeam[teams[0].teamID!]![1],
      ],
      [
        playersByTeam[teams[1].teamID!]![0],
        playersByTeam[teams[1].teamID!]![1],
      ],
      0,
      'match play',
      false,
    );

    await createMatch(
      '4-ball',
      [teams[2].teamID!, teams[3].teamID!],
      [
        playersByTeam[teams[2].teamID!]![0],
        playersByTeam[teams[2].teamID!]![1],
      ],
      [
        playersByTeam[teams[3].teamID!]![0],
        playersByTeam[teams[3].teamID!]![1],
      ],
      1,
      'match play',
      true, // bonus enabled
    );

    await createMatch(
      '4-ball',
      [teams[0].teamID!, teams[2].teamID!],
      [playersByTeam[teams[0].teamID!]![2]],
      [playersByTeam[teams[2].teamID!]![2]],
      2,
      'greensome',
      false,
    );

    // verify matches count
    final matchesSnapshot =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .get();
    expect(matchesSnapshot.docs.length, 3);

    final matchIds = matchesSnapshot.docs.map((d) => d.id).toList();
    final matchId = matchIds[0];

    await matchService.updateHoleResult(eventId, matchId, 1, {'result': 'A'});
    await matchService.updateHoleResult(eventId, matchId, 2, {'result': 'A'});
    await matchService.updateHoleResult(eventId, matchId, 3, {'result': 'B'});

    final holeDoc =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(matchId)
            .collection('holeResults')
            .doc('1')
            .get();
    expect(holeDoc.exists, true);
    expect(holeDoc['result'], 'A');

    final holeDoc2 =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(matchId)
            .collection('holeResults')
            .doc('2')
            .get();
    expect(holeDoc2.exists, true);
    expect(holeDoc2['result'], 'A');

    await matchService.setMatchOver(
      eventId,
      matchId,
      regularPoints: 4,
      bonusPoints: 0,
    );

    final updatedMatch =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(matchId)
            .get();
    expect(updatedMatch['matchOver'], true);
    expect(updatedMatch['regularPoints'], 4);

    // finalize remaining matches to trigger aggregate score updates
    await matchService.setMatchOver(
      eventId,
      matchIds[1],
      regularPoints: 3,
      bonusPoints: 1,
    );
    await matchService.setMatchOver(
      eventId,
      matchIds[2],
      regularPoints: 2,
      bonusPoints: 0,
    );

    // verify aggregate scores collection
    final aggSnapshot = await store
        .collection('events')
        .doc(eventId)
        .collection('aggregateScores')
        .get();
    expect(aggSnapshot.docs.length, teams.length);

    Map<String, Map<String, dynamic>> scores = {
      for (final doc in aggSnapshot.docs)
        doc.id: doc.data() as Map<String, dynamic>
    };

    expect(scores[teams[0].teamID]!['regularPoints'], 6);
    expect(scores[teams[0].teamID]!['bonusPoints'], 0);
    expect(scores[teams[1].teamID]!['regularPoints'], 0);
    expect(scores[teams[1].teamID]!['bonusPoints'], 0);
    expect(scores[teams[2].teamID]!['regularPoints'], 3);
    expect(scores[teams[2].teamID]!['bonusPoints'], 1);
    expect(scores[teams[3].teamID]!['regularPoints'], 0);
    expect(scores[teams[3].teamID]!['bonusPoints'], 0);
  });
}
