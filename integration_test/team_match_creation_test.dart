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

  testWidgets('team and match creation workflow without scoring', (
    tester,
  ) async {
    final auth = FirebaseAuth.instance;
    final store = FirebaseFirestore.instance;
    final teamService = TeamService();
    final matchService = MatchService();

    const adminEmail = 'setup_admin@example.com';
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
      'eventName': 'Setup League Test',
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
        teamName: 'Setup Team ${i + 1}',
        teamPassword: 'SetupPass${i + 1}!',
        eventID: eventId,
        players: [], // Make sure this is initialized
      );
      final id = await teamService.createTeam(t);
      teams.add(
        Team(
          teamID: id,
          teamName: t.teamName,
          teamPassword: t.teamPassword,
          eventID: eventId,
          players: [],
        ),
      );
    }

    // 6. log out admin
    await auth.signOut();

    // 7. create players and submit team join requests
    final playersByTeam = <String, List<String>>{};
    for (final team in teams) {
      playersByTeam[team.teamID!] = [];

      for (var i = 0; i < 3; i++) {
        final email =
            'setup_${team.teamName.replaceAll(' ', '').toLowerCase()}${i + 1}@example.com';
        final password = 'Setup${i + 1}@123';
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user!.uid;

        // Create basic user account
        await store.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'firstName': 'Setup',
          'lastName': '${team.teamName} ${i + 1}',
          'role': 'user', // Start as regular user
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        // Create team join request
        await store.collection('team_requests').add({
          'userId': uid,
          'userEmail': email,
          'userName': 'Setup ${team.teamName} ${i + 1}',
          'teamId': team.teamID,
          'eventId': eventId,
          'teamName': team.teamName,
          'requestDate': FieldValue.serverTimestamp(),
          'status': 'pending',
          'playerIndex': i, // Store the player index for later reference
        });

        await auth.signOut();
      }
    }

    // 8. login as admin to approve requests
    await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );

    // 9. Fetch and approve all team requests
    final requests =
        await store
            .collection('team_requests')
            .where('status', isEqualTo: 'pending')
            .get();

    for (final request in requests.docs) {
      final requestData = request.data();
      final userId = requestData['userId'];
      final teamId = requestData['teamId'];
      final eventId = requestData['eventId'];
      final teamName = requestData['teamName'];

      // Get the player index from the stored value (or default to 0 if not found)
      final int playerIndex = requestData['playerIndex'] ?? 0;
      final int teamIndex = teams.indexWhere((t) => t.teamID == teamId);

      double handicap;
      if (playerIndex == 0) {
        // Low handicap range (0-8)
        handicap = 2.0 + teamIndex * 2.0; // 2, 4, 6, 8
      } else if (playerIndex == 1) {
        // Mid handicap range (9-16)
        handicap = 10.0 + teamIndex * 1.5; // 10, 11.5, 13, 14.5
      } else {
        // High handicap range (17-24)
        handicap = 18.0 + teamIndex * 1.5; // 18, 19.5, 21, 22.5
      }

      // Approve request with batch operation
      final batch = store.batch();

      // 1. Update user role and golf details
      batch.update(store.collection('users').doc(userId), {
        'role': 'league_player',
        'golfDetails': {
          'playingInLeague': true,
          'teamId': teamId,
          'teamName': teamName,
          'eventId': eventId,
          'handicap': handicap,
        },
      });

      // 2. Add user to team's players array
      batch.update(
        store.collection('events').doc(eventId).collection('teams').doc(teamId),
        {
          'players': FieldValue.arrayUnion([userId]),
        },
      );

      // 3. Mark request as approved
      batch.update(store.collection('team_requests').doc(request.id), {
        'status': 'approved',
        'processedDate': FieldValue.serverTimestamp(),
        'approvedHandicap': handicap,
      });

      // Commit the batch
      await batch.commit();

      // Keep track of player IDs for match creation
      playersByTeam[teamId]!.add(userId);
    }

    // Verify players were added to teams
    for (final team in teams) {
      final teamDoc =
          await store
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(team.teamID)
              .get();
      final List<dynamic> players = teamDoc['players'] ?? [];
      expect(
        players.length,
        3,
        reason: 'Team ${team.teamName} should have 3 players',
      );
    }

    // Verify player roles were updated
    for (final teamId in playersByTeam.keys) {
      for (final playerId in playersByTeam[teamId]!) {
        final userDoc = await store.collection('users').doc(playerId).get();
        expect(
          userDoc['role'],
          'league_player',
          reason: 'Player $playerId should have role "league_player"',
        );
        expect(
          userDoc['golfDetails.teamId'] ?? userDoc['golfDetails']?['teamId'],
          teamId,
          reason: 'Player should be linked to correct team',
        );
      }
    }

    // Create matches for future scoring
    DateTime baseDate = DateTime.now();

    // helper to create a match
    Future<String> createMatch(
      String type,
      List<String> teamIds,
      List<String> teamAPlayers,
      List<String> teamBPlayers,
      int offset,
      String matchPlayType,
      bool bonusPoint,
    ) async {
      final match = Match(
        eventID: eventId,
        teams: teamIds,
        players: {'teamA': teamAPlayers, 'teamB': teamBPlayers},
        matchType: type,
        matchPlayType: matchPlayType,
        matchDateTime: baseDate.add(Duration(hours: offset)),
        bonusPoint: bonusPoint,
      );
      return await matchService.createMatch(match);
    }

    // Create matches with different configurations
    final match1Id = await createMatch(
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

    final match2Id = await createMatch(
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

    final match3Id = await createMatch(
      '4-ball',
      [teams[0].teamID!, teams[2].teamID!],
      [playersByTeam[teams[0].teamID!]![2]],
      [playersByTeam[teams[2].teamID!]![2]],
      2,
      'greensome',
      false,
    );

    // Verify all matches were created
    final matchesSnapshot =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .get();
    expect(matchesSnapshot.docs.length, 3);

    // Verify match details without checking for matchOver
    final match1Doc =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(match1Id)
            .get();
    expect(match1Doc.exists, true);
    expect(match1Doc['matchType'], '4-ball');
    expect(match1Doc['matchPlayType'], 'match play');
    expect(match1Doc['bonusPoint'], false);

    final match2Doc =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(match2Id)
            .get();
    expect(match2Doc.exists, true);
    expect(match2Doc['matchType'], '4-ball');
    expect(match2Doc['matchPlayType'], 'match play');
    expect(match2Doc['bonusPoint'], true);

    final match3Doc =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(match3Id)
            .get();
    expect(match3Doc.exists, true);
    expect(match3Doc['matchType'], '4-ball');
    expect(match3Doc['matchPlayType'], 'greensome');

    // Verify no hole results were added
    final holeResults1 =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(match1Id)
            .collection('holeResults')
            .get();
    expect(
      holeResults1.docs.isEmpty,
      true,
      reason: 'No hole results should be present',
    );

    // Verify no aggregate scores exist yet
    final aggScores =
        await store
            .collection('events')
            .doc(eventId)
            .collection('aggregateScores')
            .get();
    expect(
      aggScores.docs.isEmpty,
      true,
      reason: 'No aggregate scores should exist until matches are scored',
    );

    print(
      'Successfully created and verified ${teams.length} teams and ${matchesSnapshot.docs.length} matches',
    );
  });
}
