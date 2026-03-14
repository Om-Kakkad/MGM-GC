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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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

    // 7. create players and submit team join requests
    final playersByTeam = <String, List<String>>{};
    for (final team in teams) {
      playersByTeam[team.teamID!] = [];

      for (var i = 0; i < 3; i++) {
        final email =
            'player_${team.teamName.replaceAll(' ', '').toLowerCase()}${i + 1}@example.com';
        final password = 'Player${i + 1}@123';
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user!.uid;

        // Create basic user account
        await store.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'firstName': 'Player',
          'lastName': '${team.teamName} ${i + 1}',
          'role': 'user', // Start as regular user
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create team join request
        final requestRef = await store.collection('team_requests').add({
          'userId': uid,
          'userEmail': email,
          'userName': 'Player ${team.teamName} ${i + 1}',
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

    // Create matches for scoring tests
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

    // Create matches
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

    // verify matches count
    final matchesSnapshot =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .get();
    expect(matchesSnapshot.docs.length, 3);

    // Add hole results
    await matchService.updateHoleResult(eventId, match1Id, 1, {'result': 'A'});
    await matchService.updateHoleResult(eventId, match1Id, 2, {'result': 'A'});
    await matchService.updateHoleResult(eventId, match1Id, 3, {'result': 'B'});

    final holeDoc =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(match1Id)
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
            .doc(match1Id)
            .collection('holeResults')
            .doc('2')
            .get();
    expect(holeDoc2.exists, true);
    expect(holeDoc2['result'], 'A');

    // Set match results
    await matchService.setMatchOver(
      eventId,
      match1Id,
      teamARegularPoints: 4,
      teamABonusPoints: 0,
      teamBRegularPoints: 2,
      teamBBonusPoints: 0,
    );

    // Check match document after being marked as over
    final updatedMatch =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(match1Id)
            .get();

    // Fix: Check fields properly
    final matchData = updatedMatch.data()!;
    expect(matchData['matchOver'], true);
    expect(matchData['regularPoints'] ?? matchData['teamARegularPoints'], 4);

    // finalize remaining matches to trigger aggregate score updates
    await matchService.setMatchOver(
      eventId,
      match2Id,
      teamARegularPoints: 3,
      teamABonusPoints: 1,
      teamBRegularPoints: 3,
      teamBBonusPoints: 1,
    );
    await matchService.setMatchOver(
      eventId,
      match3Id,
      teamARegularPoints: 2,
      teamABonusPoints: 0,
      teamBRegularPoints: 2,
      teamBBonusPoints: 0,
    );

    // verify aggregate scores collection
    final aggSnapshot =
        await store
            .collection('events')
            .doc(eventId)
            .collection('aggregateScores')
            .get();
    expect(aggSnapshot.docs.length, teams.length);

    Map<String, Map<String, dynamic>> scores = {
      for (final doc in aggSnapshot.docs) doc.id: doc.data(),
    };

    // Check team scores based on team ID
    for (final team in teams) {
      final teamScore = scores[team.teamID];
      expect(teamScore, isNotNull);

      // Use safe access to handle potential field structure changes
      final regularPoints =
          teamScore!['regularPoints'] ?? teamScore['points'] ?? 0;
      final bonusPoints = teamScore['bonusPoints'] ?? 0;

      if (team.teamID == teams[0].teamID) {
        expect(regularPoints, 6);
        expect(bonusPoints, 0);
      } else if (team.teamID == teams[1].teamID) {
        expect(regularPoints, 2);
        expect(bonusPoints, 0);
      } else if (team.teamID == teams[2].teamID) {
        expect(regularPoints, 5);
        expect(bonusPoints, 1);
      } else if (team.teamID == teams[3].teamID) {
        expect(regularPoints, 3);
        expect(bonusPoints, 1);
      }
    }
  });

  testWidgets('complete league setup with 10 teams and all matches', (
    tester,
  ) async {
    final auth = FirebaseAuth.instance;
    final store = FirebaseFirestore.instance;
    final teamService = TeamService();
    final matchService = MatchService();

    const adminEmail = 'league_admin@example.com';
    const adminPassword = 'LeagueAdmin@123';

    // 1. Create admin user
    print('Step 1: Creating admin user...');
    final adminCred = await auth.createUserWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    final adminId = adminCred.user!.uid;
    await store.collection('users').doc(adminId).set({
      'uid': adminId,
      'email': adminEmail,
      'role': 'admin',
      'firstName': 'League',
      'lastName': 'Admin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Log out admin temporarily
    await auth.signOut();

    // 3. Log back in as admin
    await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    expect(auth.currentUser, isNotNull);

    // 4. Create league event
    print('Step 4: Creating league event...');
    final eventRef = await store.collection('events').add({
      'eventName': 'Complete MGM League Championship',
      'eventDescription': 'Full season league with 10 teams',
      'eventType': 'League',
      'eventDates': [
        Timestamp.fromDate(DateTime.now()),
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 21))),
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 28))),
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });
    final eventId = eventRef.id;
    await eventRef.update({'eventID': eventId});

    // 5. Create 10 teams for the league
    print('Step 5: Creating 10 teams...');
    final teams = <Team>[];
    for (var i = 0; i < 10; i++) {
      final teamName =
          'Team ${String.fromCharCode(65 + i)}'; // Team A, Team B, etc.
      final t = Team(
        teamName: teamName,
        teamPassword: 'Team${String.fromCharCode(65 + i)}Pass@123',
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
      print('Created $teamName with ID: $id');
    }

    // 6. Log out admin
    await auth.signOut();

    // 7. Create 10 players for each team (100 players total) and submit join requests
    print('Step 7: Creating 100 players and submitting join requests...');
    final playersByTeam = <String, List<String>>{};

    for (int teamIndex = 0; teamIndex < teams.length; teamIndex++) {
      final team = teams[teamIndex];
      playersByTeam[team.teamID!] = [];

      for (var playerIndex = 0; playerIndex < 10; playerIndex++) {
        final teamLetter = String.fromCharCode(65 + teamIndex);
        final email =
            'player_${teamLetter.toLowerCase()}${playerIndex + 1}@mgmgc.com';
        final password = 'Player$teamLetter${playerIndex + 1}@123';
        final firstName = 'Player';
        final lastName = '$teamLetter${playerIndex + 1}';

        // Create player account
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user!.uid;

        // Create basic user profile
        await store.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Submit team join request
        await store.collection('team_requests').add({
          'userId': uid,
          'userEmail': email,
          'userName': '$firstName $lastName',
          'teamId': team.teamID,
          'eventId': eventId,
          'teamName': team.teamName,
          'requestDate': FieldValue.serverTimestamp(),
          'status': 'pending',
          'playerIndex': playerIndex,
          'teamIndex': teamIndex,
        });

        await auth.signOut();

        if ((teamIndex * 10 + playerIndex + 1) % 20 == 0) {
          print(
            'Created ${teamIndex * 10 + playerIndex + 1} players so far...',
          );
        }
      }
    }

    // 8. Login as admin to approve all requests
    print('Step 8: Admin approving all team join requests...');
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

    print('Found ${requests.docs.length} pending requests to approve');

    for (final request in requests.docs) {
      final requestData = request.data();
      final userId = requestData['userId'];
      final teamId = requestData['teamId'];
      final eventId = requestData['eventId'];
      final teamIndex = requestData['teamIndex'] ?? 0;
      final playerIndex = requestData['playerIndex'] ?? 0;

      // Generate handicaps based on team and player position
      // Team A: 2-11, Team B: 4-13, Team C: 6-15, etc.
      // Within team: Player 1 gets lowest, Player 10 gets highest
      double handicap = 2.0 + (teamIndex * 2.0) + (playerIndex * 1.0);

      // Cap handicap at reasonable level
      if (handicap > 28.0) handicap = 28.0;

      // Approve request with batch operation
      final batch = store.batch();

      // 1. Update user role and golf details
      batch.update(store.collection('users').doc(userId), {
        'role': 'player',
        'golfDetails': {
          'handicap': handicap,
          'isMember': true,
          'playingInLeague': true,
          'teamId': teamId,
          'teamName': requestData['teamName'],
          'eventId': eventId,
        },
        'updatedAt': FieldValue.serverTimestamp(),
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
        'approvedDate': FieldValue.serverTimestamp(),
        'approvedHandicap': handicap,
      });

      await batch.commit();
      playersByTeam[teamId]!.add(userId);
    }

    // 10. Verify all teams have 10 players
    print('Step 10: Verifying team rosters...');
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
        10,
        reason: 'Team ${team.teamName} should have 10 players',
      );
      print('${team.teamName}: ${players.length} players confirmed');
    }

    // 11. Create all matches for the league
    print('Step 11: Creating matches for all teams...');

    // Helper function to create a match
    Future<String> createMatch(
      String matchType,
      String matchPlayType,
      List<String> teamIds,
      List<String> teamAPlayers,
      List<String> teamBPlayers,
      int dayOffset,
      bool bonusPoint,
    ) async {
      final match = Match(
        eventID: eventId,
        matchType: matchType,
        matchPlayType: matchPlayType,
        teams: teamIds,
        players: {teamIds[0]: teamAPlayers, teamIds[1]: teamBPlayers},
        matchDateTime: DateTime.now().add(Duration(days: dayOffset)),
        bonusPoint: bonusPoint,
        participantUids: [...teamAPlayers, ...teamBPlayers],
      );
      return await matchService.createMatch(match);
    }

    // Create matches for each team (5 matches per team as specified)
    int totalMatchesCreated = 0;
    final createdMatches = <String>[];

    for (int teamIndex = 0; teamIndex < teams.length; teamIndex++) {
      final team = teams[teamIndex];
      final teamPlayers = playersByTeam[team.teamID!]!;

      print('Creating matches for ${team.teamName}...');

      // Determine opponent teams (round-robin style)
      final opponentIndices = <int>[];
      for (int i = 1; i <= 5; i++) {
        opponentIndices.add((teamIndex + i) % teams.length);
      }

      for (int matchIndex = 0; matchIndex < 5; matchIndex++) {
        final opponentTeam = teams[opponentIndices[matchIndex]];
        final opponentPlayers = playersByTeam[opponentTeam.teamID!]!;

        String matchType;
        String matchPlayType;
        List<String> teamAPlayers;
        List<String> teamBPlayers;
        bool bonusPoint = false;

        if (matchIndex == 0) {
          // Match 1: Greensome
          matchType = 'greensome';
          matchPlayType = 'greensome';
          teamAPlayers = teamPlayers.take(2).toList();
          teamBPlayers = opponentPlayers.take(2).toList();
          bonusPoint = true;
        } else if (matchIndex == 1) {
          // Match 2: Two-ball match-play
          matchType = '2-ball';
          matchPlayType = 'match play';
          teamAPlayers = [teamPlayers[2], teamPlayers[3]];
          teamBPlayers = [opponentPlayers[2], opponentPlayers[3]];
        } else if (matchIndex == 2) {
          // Match 3: Four-ball Gold tier
          matchType = '4-ball';
          matchPlayType = 'match play';
          teamAPlayers = [teamPlayers[0], teamPlayers[1]]; // Best players
          teamBPlayers = [opponentPlayers[0], opponentPlayers[1]];
          bonusPoint = true;
        } else if (matchIndex == 3) {
          // Match 4: Four-ball Silver tier
          matchType = '4-ball';
          matchPlayType = 'match play';
          teamAPlayers = [teamPlayers[4], teamPlayers[5]]; // Middle players
          teamBPlayers = [opponentPlayers[4], opponentPlayers[5]];
        } else {
          // Match 5: Four-ball Bronze tier
          matchType = '4-ball';
          matchPlayType = 'match play';
          teamAPlayers = [teamPlayers[8], teamPlayers[9]]; // Lower tier players
          teamBPlayers = [opponentPlayers[8], opponentPlayers[9]];
        }

        final matchId = await createMatch(
          matchType,
          matchPlayType,
          [team.teamID!, opponentTeam.teamID!],
          teamAPlayers,
          teamBPlayers,
          matchIndex, // Spread matches across different days
          bonusPoint,
        );

        createdMatches.add(matchId);
        totalMatchesCreated++;

        print(
          '  Created $matchType ($matchPlayType) vs ${opponentTeam.teamName}',
        );
      }
    }

    // 12. Verify total number of matches created
    print('Step 12: Verifying match creation...');
    final allMatches =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .get();

    expect(allMatches.docs.length, totalMatchesCreated);
    expect(
      totalMatchesCreated,
      50,
      reason: '10 teams × 5 matches each = 50 total matches',
    );

    print('Successfully created $totalMatchesCreated matches');

    // 13. Verify match distribution by type
    final matchesByType = <String, int>{};
    final matchesByPlayType = <String, int>{};

    for (final matchDoc in allMatches.docs) {
      final matchData = matchDoc.data();
      final matchType = matchData['matchType'] as String;
      final matchPlayType = matchData['matchPlayType'] as String;

      matchesByType[matchType] = (matchesByType[matchType] ?? 0) + 1;
      matchesByPlayType[matchPlayType] =
          (matchesByPlayType[matchPlayType] ?? 0) + 1;
    }

    print('Match type distribution:');
    matchesByType.forEach((type, count) {
      print('  $type: $count matches');
    });

    print('Match play type distribution:');
    matchesByPlayType.forEach((type, count) {
      print('  $type: $count matches');
    });

    // Expected: 10 greensome, 10 two-ball, 30 four-ball
    expect(matchesByType['greensome'], 10, reason: '1 greensome per team');
    expect(matchesByType['2-ball'], 10, reason: '1 two-ball per team');
    expect(
      matchesByType['4-ball'],
      30,
      reason: '3 four-ball per team (Gold, Silver, Bronze)',
    );

    // Expected: 10 greensome, 40 match play
    expect(matchesByPlayType['greensome'], 10);
    expect(matchesByPlayType['match play'], 40);

    print('✅ Complete league setup test passed!');
    print('📊 Final Summary:');
    print('   - 1 Admin created');
    print('   - 1 League event created');
    print('   - 10 Teams created');
    print('   - 100 Players created and approved');
    print('   - 50 Matches created (10 Greensome, 10 Two-ball, 30 Four-ball)');
  });
}
