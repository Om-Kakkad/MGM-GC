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

  testWidgets('League setup without scores - 10 teams and 100 players', (
    tester,
  ) async {
    final auth = FirebaseAuth.instance;
    final store = FirebaseFirestore.instance;
    final teamService = TeamService();
    final matchService = MatchService();

    const adminEmail = 'league_setup_admin@example.com';
    const adminPassword = 'AdminTest@123';

    print('========== PHASE 1: ADMIN SETUP ==========');

    // 1. Create admin user
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

    // 2. Log out and back in
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    expect(auth.currentUser, isNotNull);

    print('✓ Admin user created and authenticated');

    // 3. Create league event
    final eventRef = await store.collection('events').add({
      'eventName': 'League Setup Championship',
      'eventType': 'League',
      'eventDates': [Timestamp.fromDate(DateTime.now())],
      'bracketType': 'Multi-Tier',
      'goldMinHandicap': 0.0,
      'goldMaxHandicap': 8.0,
      'silverMinHandicap': 8.1,
      'silverMaxHandicap': 16.0,
      'bronzeMinHandicap': 16.1,
      'bronzeMaxHandicap': 36.0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final eventId = eventRef.id;
    await eventRef.update({'eventID': eventId});

    print('✓ League event created: $eventId');

    print('========== PHASE 2: TEAM CREATION ==========');

    // 4. Create 10 teams for the event
    final teams = <Team>[];
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
      final t = Team(
        teamName: teamNames[i],
        teamPassword: 'team${i + 1}pass',
        eventID: eventId,
        players: [],
      );
      final id = await teamService.createTeam(t);
      teams.add(
        Team(
          teamID: id,
          teamName: teamNames[i],
          teamPassword: 'team${i + 1}pass',
          eventID: eventId,
          players: [],
        ),
      );
    }

    expect(teams.length, 10);
    print('✓ Created 10 teams');

    // 5. Log out admin to create players
    await auth.signOut();

    print('========== PHASE 3: PLAYER CREATION & TEAM JOINING ==========');

    // 6. Create 100 players (10 per team) and submit team join requests
    final playersByTeam = <String, List<String>>{};
    final playerEmails = <String>[];

    for (int teamIndex = 0; teamIndex < teams.length; teamIndex++) {
      final team = teams[teamIndex];
      playersByTeam[team.teamID!] = [];

      for (var playerIndex = 0; playerIndex < 10; playerIndex++) {
        final playerEmail =
            'player_setup_${teamIndex}_$playerIndex@example.com';
        final playerPassword = 'Player@123';
        playerEmails.add(playerEmail);

        // Create player account
        final playerCred = await auth.createUserWithEmailAndPassword(
          email: playerEmail,
          password: playerPassword,
        );
        final playerId = playerCred.user!.uid;

        // Assign handicaps based on tiers and create variety
        double handicap;
        if (playerIndex < 3) {
          // Gold tier players (0-8 handicap)
          handicap = (playerIndex * 2.5) + (teamIndex * 0.3);
        } else if (playerIndex < 6) {
          // Silver tier players (8.1-16 handicap)
          handicap = 8.5 + ((playerIndex - 3) * 2.5) + (teamIndex * 0.2);
        } else {
          // Bronze tier players (16.1-36 handicap)
          handicap = 17.0 + ((playerIndex - 6) * 4.0) + (teamIndex * 0.5);
        }

        // Create user document with complete profile
        await store.collection('users').doc(playerId).set({
          'uid': playerId,
          'email': playerEmail,
          'role': 'user',
          'firstName': 'Player$teamIndex$playerIndex',
          'lastName': 'Team${teamIndex + 1}',
          'golfDetails': {
            'handicap': handicap,
            'isMember': playerIndex % 2 == 0, // Half are members
            'membershipId':
                playerIndex % 2 == 0 ? 'MEM$teamIndex$playerIndex' : null,
            'playingInLeague': false, // Will be updated upon approval
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Submit team join request
        await store.collection('team_requests').add({
          'userId': playerId,
          'teamId': team.teamID,
          'eventId': eventId,
          'teamName': team.teamName,
          'playerIndex': playerIndex,
          'requestedHandicap': handicap,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        playersByTeam[team.teamID!]!.add(playerId);

        // Sign out player
        await auth.signOut();
      }
    }

    expect(playerEmails.length, 100);
    print('✓ Created 100 players across 10 teams');

    print('========== PHASE 4: ADMIN APPROVAL ==========');

    // 7. Login as admin to approve requests
    await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );

    // 8. Fetch and approve all team requests
    final requests =
        await store
            .collection('team_requests')
            .where('eventId', isEqualTo: eventId)
            .where('status', isEqualTo: 'pending')
            .get();

    expect(requests.docs.length, 100);

    for (final request in requests.docs) {
      final requestData = request.data();
      final userId = requestData['userId'];
      final teamId = requestData['teamId'];
      final handicap = requestData['requestedHandicap'];
      final playerIndex = requestData['playerIndex'];

      // Determine bracket based on handicap
      String bracket;
      if (handicap <= 8.0) {
        bracket = 'Gold';
      } else if (handicap <= 16.0) {
        bracket = 'Silver';
      } else {
        bracket = 'Bronze';
      }

      // Approve request with batch operation
      final batch = store.batch();

      // 1. Update user role and golf details
      batch.update(store.collection('users').doc(userId), {
        'role': 'league_player',
        'golfDetails': {
          'playingInLeague': true,
          'teamId': teamId,
          'teamName': requestData['teamName'],
          'eventId': eventId,
          'handicap': handicap,
          'bracket': bracket,
          'isMember': playerIndex % 2 == 0,
          'membershipId':
              playerIndex % 2 == 0
                  ? 'MEM${teamId.substring(0, 5)}$playerIndex'
                  : null,
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
        'assignedBracket': bracket,
      });

      await batch.commit();
    }

    print('✓ Approved all 100 player requests');

    // Verify teams have correct number of players
    for (final team in teams) {
      final teamDoc =
          await store
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(team.teamID!)
              .get();
      final players = List<String>.from(teamDoc.data()!['players'] ?? []);
      expect(
        players.length,
        10,
        reason: 'Team ${team.teamName} should have 10 players',
      );
    }

    print('========== PHASE 5: MATCH CREATION ==========');

    // 9. Create matches - 5 matches per team as specified
    final allMatches = <String>[];
    DateTime baseDate = DateTime.now();

    // Helper function to create a match
    Future<String> createMatch(
      String matchType,
      String matchPlayType,
      List<String> teamIds,
      List<String> teamAPlayers,
      List<String> teamBPlayers,
      int offsetHours,
      bool bonusPoint,
      String tier,
    ) async {
      final match = Match(
        eventID: eventId,
        teams: teamIds,
        players: {'teamA': teamAPlayers, 'teamB': teamBPlayers},
        matchType: matchType,
        matchPlayType: matchPlayType,
        matchDateTime: baseDate.add(Duration(hours: offsetHours)),
        bonusPoint: bonusPoint,
      );
      final matchId = await matchService.createMatch(match);
      print(
        '✓ Created $matchType $matchPlayType match for $tier tier: ${teamIds[0]} vs ${teamIds[1]}',
      );
      return matchId;
    }

    // Get players by bracket for each team
    final teamPlayersByBracket = <String, Map<String, List<String>>>{};

    for (final team in teams) {
      teamPlayersByBracket[team.teamID!] = {
        'Gold': [],
        'Silver': [],
        'Bronze': [],
      };

      final teamDoc =
          await store
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(team.teamID!)
              .get();
      final playerIds = List<String>.from(teamDoc.data()!['players'] ?? []);

      for (final playerId in playerIds) {
        final playerDoc = await store.collection('users').doc(playerId).get();
        final bracket = playerDoc.data()!['golfDetails']['bracket'] ?? 'Bronze';
        teamPlayersByBracket[team.teamID!]![bracket]!.add(playerId);
      }
    }

    int matchCounter = 0;

    // Create matches for each team (ensuring exactly 5 matches per team)
    for (int i = 0; i < teams.length; i++) {
      final teamA = teams[i];
      final teamB = teams[(i + 1) % teams.length]; // Rotate opponents

      // 1. Greensome match (1 per team pair)
      final greensomeMatch = await createMatch(
        '4-ball',
        'greensome',
        [teamA.teamID!, teamB.teamID!],
        teamPlayersByBracket[teamA.teamID!]!['Gold']!.take(2).toList(),
        teamPlayersByBracket[teamB.teamID!]!['Gold']!.take(2).toList(),
        matchCounter++,
        false,
        'Mixed',
      );
      allMatches.add(greensomeMatch);

      // 2. Two-ball match play (1 per team pair)
      final twoBallMatch = await createMatch(
        '2-ball',
        'match play',
        [teamA.teamID!, teamB.teamID!],
        teamPlayersByBracket[teamA.teamID!]!['Silver']!.take(1).toList(),
        teamPlayersByBracket[teamB.teamID!]!['Silver']!.take(1).toList(),
        matchCounter++,
        false,
        'Silver',
      );
      allMatches.add(twoBallMatch);

      // 3. Four-ball Gold tier
      final goldMatch = await createMatch(
        '4-ball',
        'match play',
        [teamA.teamID!, teamB.teamID!],
        teamPlayersByBracket[teamA.teamID!]!['Gold']!.skip(2).take(2).toList(),
        teamPlayersByBracket[teamB.teamID!]!['Gold']!.skip(2).take(2).toList(),
        matchCounter++,
        true, // Bonus point
        'Gold',
      );
      allMatches.add(goldMatch);

      // 4. Four-ball Silver tier
      final silverMatch = await createMatch(
        '4-ball',
        'match play',
        [teamA.teamID!, teamB.teamID!],
        teamPlayersByBracket[teamA.teamID!]!['Silver']!
            .skip(1)
            .take(2)
            .toList(),
        teamPlayersByBracket[teamB.teamID!]!['Silver']!
            .skip(1)
            .take(2)
            .toList(),
        matchCounter++,
        false,
        'Silver',
      );
      allMatches.add(silverMatch);

      // 5. Four-ball Bronze tier
      final bronzeMatch = await createMatch(
        '4-ball',
        'match play',
        [teamA.teamID!, teamB.teamID!],
        teamPlayersByBracket[teamA.teamID!]!['Bronze']!.take(2).toList(),
        teamPlayersByBracket[teamB.teamID!]!['Bronze']!.take(2).toList(),
        matchCounter++,
        false,
        'Bronze',
      );
      allMatches.add(bronzeMatch);
    }

    expect(allMatches.length, 50); // 10 teams * 5 matches per team
    print('✓ Created 50 total matches (5 per team)');

    print('========== PHASE 6: VERIFICATION ==========');

    // 10. Verify match creation
    final matches =
        await store
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .get();
    expect(matches.docs.length, 50);

    // Verify match types
    final matchTypes = <String, int>{};
    final playTypes = <String, int>{};
    int bonusMatches = 0;

    for (final matchDoc in matches.docs) {
      final data = matchDoc.data();
      final matchType = data['matchType'] ?? 'unknown';
      final playType = data['matchPlayType'] ?? 'unknown';
      final hasBonus = data['bonusPoint'] ?? false;

      matchTypes[matchType] = (matchTypes[matchType] ?? 0) + 1;
      playTypes[playType] = (playTypes[playType] ?? 0) + 1;
      if (hasBonus) bonusMatches++;
    }

    print('✓ Match type distribution verified:');
    print('   - Greensome: ${playTypes['greensome']} matches');
    print('   - Match Play: ${playTypes['match play']} matches');
    print('   - Two-ball: ${matchTypes['2-ball']} matches');
    print('   - Four-ball: ${matchTypes['4-ball']} matches');
    print('   - Bonus matches: $bonusMatches');

    expect(playTypes['greensome'], 10); // 1 per team pair
    expect(playTypes['match play'], 40); // 4 per team pair
    expect(matchTypes['2-ball'], 10); // 1 per team pair
    expect(matchTypes['4-ball'], 40); // 4 per team pair
    expect(bonusMatches, 10); // 1 bonus match per team pair

    // 11. Verify player bracket distribution
    final bracketCounts = <String, int>{'Gold': 0, 'Silver': 0, 'Bronze': 0};
    final allPlayers =
        await store
            .collection('users')
            .where('golfDetails.playingInLeague', isEqualTo: true)
            .where('golfDetails.eventId', isEqualTo: eventId)
            .get();

    for (final playerDoc in allPlayers.docs) {
      final bracket = playerDoc.data()['golfDetails']['bracket'] ?? 'Unknown';
      bracketCounts[bracket] = (bracketCounts[bracket] ?? 0) + 1;
    }

    print('✓ Player bracket distribution:');
    print('   - Gold: ${bracketCounts['Gold']} players');
    print('   - Silver: ${bracketCounts['Silver']} players');
    print('   - Bronze: ${bracketCounts['Bronze']} players');

    expect(allPlayers.docs.length, 100);
    expect(
      bracketCounts['Gold']! +
          bracketCounts['Silver']! +
          bracketCounts['Bronze']!,
      100,
    );

    print('========== LEAGUE SETUP COMPLETED ==========');
    print('✓ League setup test completed successfully!');
    print('✓ Created: 1 admin, 10 teams, 100 players, 50 matches');
    print('✓ All matches are ready for manual scoring');
    print('✓ You can now log in and add scores to test scoring features');

    // Save admin credentials for later use
    print('\nADMIN LOGIN CREDENTIALS:');
    print('Email: $adminEmail');
    print('Password: $adminPassword');

    // Clean up - sign out
    await auth.signOut();
  });
}
