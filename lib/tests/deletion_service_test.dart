import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgm_gc/services/delete_service.dart';

/// Comprehensive test for DeleteService's cascade deletion functionality
///
/// This utility can be used to verify that the cascade deletion works correctly
/// by creating test data, deleting it, and verifying all references are cleaned up.
class DeletionServiceTest {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeleteService _deleteService = DeleteService();

  // Test IDs to track created resources
  String? _testEventId;
  String? _testTeamId1;
  String? _testTeamId2;
  String? _testUserId1;
  String? _testUserId2;
  String? _testUserId3;
  String? _testUserId4;
  String? _testMatchId;

  /// Run the comprehensive deletion test
  Future<TestResult> runDeletionTest() async {
    TestResult result = TestResult();
    result.log('Starting comprehensive deletion test');

    try {
      // Step 1: Create test data
      await _createTestData();
      result.log('Test data created successfully');

      // Step 2: Test event deletion
      result.log('Testing event deletion cascade...');
      await _testEventDeletion(result);

      // Step 3: Create test data again (since previous test deleted everything)
      await _createTestData();
      result.log('Test data re-created for team deletion test');

      // Step 4: Test team deletion
      result.log('Testing team deletion cascade...');
      await _testTeamDeletion(result);

      // Step 5: Create test data again
      await _createTestData();
      result.log('Test data re-created for match deletion test');

      // Step 6: Test match deletion
      result.log('Testing match deletion cascade...');
      await _testMatchDeletion(result);

      // Step 7: Create test data again
      await _createTestData();
      result.log('Test data re-created for user deletion test');

      // Step 8: Test user deletion
      result.log('Testing user deletion cascade...');
      await _testUserDeletion(result);

      // Final cleanup
      await _cleanup();
      result.log('Final cleanup completed');

      result.success = true;
      result.log('All tests completed successfully');
    } catch (e, stackTrace) {
      result.success = false;
      result.log('Test failed with error: $e');
      result.log('Stack trace: $stackTrace');

      // Try to clean up even if test failed
      try {
        await _cleanup();
        result.log('Cleanup after failure completed');
      } catch (cleanupError) {
        result.log('Failed to clean up after test failure: $cleanupError');
      }
    }

    return result;
  }

  /// Create test data for deletion tests
  Future<void> _createTestData() async {
    // 1. Create an event
    DocumentReference eventRef = await _firestore.collection('events').add({
      'eventName': 'Test Event for Deletion',
      'eventType': 'League',
      'eventDescription': 'This is a test event for deletion testing',
      'eventDates': [
        Timestamp.fromDate(DateTime.now().add(Duration(days: 1))),
        Timestamp.fromDate(DateTime.now().add(Duration(days: 2))),
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'teamIDs': [],
    });
    _testEventId = eventRef.id;

    // 2. Create two teams for this event
    DocumentReference team1Ref = await _firestore.collection('teams').add({
      'teamName': 'Test Team 1',
      'teamPassword': 'password123',
      'eventID': _testEventId,
      'players': [],
      'matches': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    _testTeamId1 = team1Ref.id;

    DocumentReference team2Ref = await _firestore.collection('teams').add({
      'teamName': 'Test Team 2',
      'teamPassword': 'password456',
      'eventID': _testEventId,
      'players': [],
      'matches': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    _testTeamId2 = team2Ref.id;

    // Update event with team IDs
    await eventRef.update({
      'teamIDs': [_testTeamId1, _testTeamId2],
    });

    // 3. Create four test users
    DocumentReference user1Ref = await _firestore.collection('users').add({
      'email': 'testuser1@example.com',
      'firstName': 'Test',
      'lastName': 'User1',
      'role': 'league_player',
      'matches': [],
      'golfDetails': {
        'teamId': _testTeamId1,
        'teamName': 'Test Team 1',
        'handicap': 10,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    _testUserId1 = user1Ref.id;

    DocumentReference user2Ref = await _firestore.collection('users').add({
      'email': 'testuser2@example.com',
      'firstName': 'Test',
      'lastName': 'User2',
      'role': 'league_player',
      'matches': [],
      'golfDetails': {
        'teamId': _testTeamId1,
        'teamName': 'Test Team 1',
        'handicap': 12,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    _testUserId2 = user2Ref.id;

    DocumentReference user3Ref = await _firestore.collection('users').add({
      'email': 'testuser3@example.com',
      'firstName': 'Test',
      'lastName': 'User3',
      'role': 'league_player',
      'matches': [],
      'golfDetails': {
        'teamId': _testTeamId2,
        'teamName': 'Test Team 2',
        'handicap': 8,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    _testUserId3 = user3Ref.id;

    DocumentReference user4Ref = await _firestore.collection('users').add({
      'email': 'testuser4@example.com',
      'firstName': 'Test',
      'lastName': 'User4',
      'role': 'league_player',
      'matches': [],
      'golfDetails': {
        'teamId': _testTeamId2,
        'teamName': 'Test Team 2',
        'handicap': 15,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    _testUserId4 = user4Ref.id;

    // Update teams with their players
    await team1Ref.update({
      'players': [_testUserId1, _testUserId2],
    });

    await team2Ref.update({
      'players': [_testUserId3, _testUserId4],
    });

    // 4. Create a match between the two teams
    DocumentReference matchRef = await _firestore.collection('fourBalls').add({
      'eventID': _testEventId,
      'teams': [_testTeamId1, _testTeamId2],
      'players': {
        'teamA': [_testUserId1, _testUserId2],
        'teamB': [_testUserId3, _testUserId4],
      },
      'matchType': '4-ball',
      'matchDateTime': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 1)),
      ),
      'matchStatus': 'active',
      'holeResults': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    _testMatchId = matchRef.id;

    // Update teams with the match reference
    await team1Ref.update({
      'matches': [_testMatchId],
    });

    await team2Ref.update({
      'matches': [_testMatchId],
    });

    // Update users with the match reference
    await user1Ref.update({
      'matches': [_testMatchId],
    });

    await user2Ref.update({
      'matches': [_testMatchId],
    });

    await user3Ref.update({
      'matches': [_testMatchId],
    });

    await user4Ref.update({
      'matches': [_testMatchId],
    });

    // 5. Create event registration
    await _firestore.collection('event_registrations').add({
      'eventId': _testEventId,
      'userId': _testUserId1,
      'registeredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Test event deletion cascade
  Future<void> _testEventDeletion(TestResult result) async {
    if (_testEventId == null) {
      throw Exception('Test event ID is null, cannot test event deletion');
    }

    // Delete the event
    await _deleteService.deleteEventWithCascade(_testEventId!);
    result.log('Event deleted: $_testEventId');

    // Verify event was deleted
    DocumentSnapshot eventDoc =
        await _firestore.collection('events').doc(_testEventId!).get();
    if (eventDoc.exists) {
      throw Exception('Event was not deleted');
    }
    result.log('✓ Event document was deleted');

    // Verify teams were deleted
    DocumentSnapshot team1Doc =
        await _firestore.collection('teams').doc(_testTeamId1!).get();
    DocumentSnapshot team2Doc =
        await _firestore.collection('teams').doc(_testTeamId2!).get();
    if (team1Doc.exists || team2Doc.exists) {
      throw Exception('Teams were not deleted');
    }
    result.log('✓ Team documents were deleted');

    // Verify match was deleted
    DocumentSnapshot matchDoc =
        await _firestore.collection('fourBalls').doc(_testMatchId!).get();
    if (matchDoc.exists) {
      throw Exception('Match was not deleted');
    }
    result.log('✓ Match document was deleted');

    // Verify users were updated (not deleted, but team references removed)
    DocumentSnapshot user1Doc =
        await _firestore.collection('users').doc(_testUserId1!).get();
    DocumentSnapshot user2Doc =
        await _firestore.collection('users').doc(_testUserId2!).get();
    DocumentSnapshot user3Doc =
        await _firestore.collection('users').doc(_testUserId3!).get();
    DocumentSnapshot user4Doc =
        await _firestore.collection('users').doc(_testUserId4!).get();

    if (!user1Doc.exists ||
        !user2Doc.exists ||
        !user3Doc.exists ||
        !user4Doc.exists) {
      throw Exception('Users were incorrectly deleted');
    }

    Map<String, dynamic> user1Data = user1Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> user2Data = user2Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> user3Data = user3Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> user4Data = user4Doc.data() as Map<String, dynamic>;

    // Verify team references were removed
    if (user1Data['golfDetails']?['teamId'] != null ||
        user2Data['golfDetails']?['teamId'] != null ||
        user3Data['golfDetails']?['teamId'] != null ||
        user4Data['golfDetails']?['teamId'] != null) {
      throw Exception('Team references in users were not removed');
    }
    result.log('✓ Team references were removed from users');

    // Verify match references were removed
    if ((user1Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (user2Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (user3Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (user4Data['matches'] as List?)?.contains(_testMatchId) == true) {
      throw Exception('Match references in users were not removed');
    }
    result.log('✓ Match references were removed from users');

    // Verify event registrations were deleted
    final eventRegistrationsSnapshot =
        await _firestore
            .collection('event_registrations')
            .where('eventId', isEqualTo: _testEventId)
            .get();

    if (eventRegistrationsSnapshot.docs.isNotEmpty) {
      throw Exception('Event registrations were not deleted');
    }
    result.log('✓ Event registrations were deleted');

    // Test passed!
    result.log('Event deletion cascade test passed successfully');
  }

  /// Test team deletion cascade
  Future<void> _testTeamDeletion(TestResult result) async {
    if (_testTeamId1 == null) {
      throw Exception('Test team ID is null, cannot test team deletion');
    }

    // Delete team 1
    await _deleteService.deleteTeamWithCascade(_testTeamId1!);
    result.log('Team deleted: $_testTeamId1');

    // Verify team was deleted
    DocumentSnapshot teamDoc =
        await _firestore.collection('teams').doc(_testTeamId1!).get();
    if (teamDoc.exists) {
      throw Exception('Team was not deleted');
    }
    result.log('✓ Team document was deleted');

    // Verify event was updated (team reference removed)
    DocumentSnapshot eventDoc =
        await _firestore.collection('events').doc(_testEventId!).get();
    if (!eventDoc.exists) {
      throw Exception('Event was incorrectly deleted');
    }

    Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
    List<dynamic> teamIDs = eventData['teamIDs'] ?? [];
    if (teamIDs.contains(_testTeamId1)) {
      throw Exception('Team reference in event was not removed');
    }
    result.log('✓ Team reference was removed from event');

    // Verify match was updated or deleted
    DocumentSnapshot matchDoc =
        await _firestore.collection('fourBalls').doc(_testMatchId!).get();
    if (matchDoc.exists) {
      // If match still exists, verify team1 is not in it
      Map<String, dynamic> matchData = matchDoc.data() as Map<String, dynamic>;
      List<dynamic> teams = matchData['teams'] ?? [];
      if (teams.contains(_testTeamId1)) {
        throw Exception('Team reference in match was not removed');
      }
      result.log('✓ Team reference was removed from match');
    } else {
      result.log('✓ Match was deleted as expected');
    }

    // Verify team members (users) were updated
    DocumentSnapshot user1Doc =
        await _firestore.collection('users').doc(_testUserId1!).get();
    DocumentSnapshot user2Doc =
        await _firestore.collection('users').doc(_testUserId2!).get();

    if (!user1Doc.exists || !user2Doc.exists) {
      throw Exception('Team members were incorrectly deleted');
    }

    Map<String, dynamic> user1Data = user1Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> user2Data = user2Doc.data() as Map<String, dynamic>;

    // Verify team references were removed
    if (user1Data['golfDetails']?['teamId'] == _testTeamId1 ||
        user2Data['golfDetails']?['teamId'] == _testTeamId1) {
      throw Exception('Team references in users were not removed');
    }
    result.log('✓ Team references were removed from users');

    // Verify role was downgraded from league_player to user
    if (user1Data['role'] != 'user' || user2Data['role'] != 'user') {
      throw Exception(
        'User roles were not downgraded from league_player to user',
      );
    }
    result.log('✓ User roles were properly downgraded');

    // Verify match references were removed
    if ((user1Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (user2Data['matches'] as List?)?.contains(_testMatchId) == true) {
      throw Exception('Match references in users were not removed');
    }
    result.log('✓ Match references were removed from users');

    // Test passed!
    result.log('Team deletion cascade test passed successfully');
  }

  /// Test match deletion cascade
  Future<void> _testMatchDeletion(TestResult result) async {
    if (_testMatchId == null) {
      throw Exception('Test match ID is null, cannot test match deletion');
    }

    // Delete the match
    await _deleteService.deleteMatchWithCascade(_testMatchId!);
    result.log('Match deleted: $_testMatchId');

    // Verify match was deleted
    DocumentSnapshot matchDoc =
        await _firestore.collection('fourBalls').doc(_testMatchId!).get();
    if (matchDoc.exists) {
      throw Exception('Match was not deleted');
    }
    result.log('✓ Match document was deleted');

    // Verify team match references were removed
    DocumentSnapshot team1Doc =
        await _firestore.collection('teams').doc(_testTeamId1!).get();
    DocumentSnapshot team2Doc =
        await _firestore.collection('teams').doc(_testTeamId2!).get();

    if (!team1Doc.exists || !team2Doc.exists) {
      throw Exception('Teams were incorrectly deleted');
    }

    Map<String, dynamic> team1Data = team1Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> team2Data = team2Doc.data() as Map<String, dynamic>;

    if ((team1Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (team2Data['matches'] as List?)?.contains(_testMatchId) == true) {
      throw Exception('Match references in teams were not removed');
    }
    result.log('✓ Match references were removed from teams');

    // Verify user match references were removed
    DocumentSnapshot user1Doc =
        await _firestore.collection('users').doc(_testUserId1!).get();
    DocumentSnapshot user2Doc =
        await _firestore.collection('users').doc(_testUserId2!).get();
    DocumentSnapshot user3Doc =
        await _firestore.collection('users').doc(_testUserId3!).get();
    DocumentSnapshot user4Doc =
        await _firestore.collection('users').doc(_testUserId4!).get();

    Map<String, dynamic> user1Data = user1Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> user2Data = user2Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> user3Data = user3Doc.data() as Map<String, dynamic>;
    Map<String, dynamic> user4Data = user4Doc.data() as Map<String, dynamic>;

    if ((user1Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (user2Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (user3Data['matches'] as List?)?.contains(_testMatchId) == true ||
        (user4Data['matches'] as List?)?.contains(_testMatchId) == true) {
      throw Exception('Match references in users were not removed');
    }
    result.log('✓ Match references were removed from users');

    // Verify event was not deleted
    DocumentSnapshot eventDoc =
        await _firestore.collection('events').doc(_testEventId!).get();
    if (!eventDoc.exists) {
      throw Exception('Event was incorrectly deleted');
    }
    result.log('✓ Event document was preserved');

    // Test passed!
    result.log('Match deletion cascade test passed successfully');
  }

  /// Test user deletion cascade
  Future<void> _testUserDeletion(TestResult result) async {
    if (_testUserId1 == null) {
      throw Exception('Test user ID is null, cannot test user deletion');
    }

    // Delete user 1
    await _deleteService.deleteUserWithCascade(_testUserId1!);
    result.log('User deleted: $_testUserId1');

    // Verify user was deleted
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(_testUserId1!).get();
    if (userDoc.exists) {
      throw Exception('User was not deleted');
    }
    result.log('✓ User document was deleted');

    // Verify team was updated (user removed from players list)
    DocumentSnapshot teamDoc =
        await _firestore.collection('teams').doc(_testTeamId1!).get();
    if (!teamDoc.exists) {
      throw Exception('Team was incorrectly deleted');
    }

    Map<String, dynamic> teamData = teamDoc.data() as Map<String, dynamic>;
    List<dynamic> players = teamData['players'] ?? [];
    if (players.contains(_testUserId1)) {
      throw Exception('User reference in team players was not removed');
    }
    result.log('✓ User reference was removed from team players');

    // Verify match players were updated
    DocumentSnapshot matchDoc =
        await _firestore.collection('fourBalls').doc(_testMatchId!).get();
    if (!matchDoc.exists) {
      throw Exception('Match was incorrectly deleted');
    }

    Map<String, dynamic> matchData = matchDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> matchPlayers = matchData['players'] ?? {};

    bool userFoundInAnyTeam = false;
    matchPlayers.forEach((team, playerList) {
      if ((playerList as List).contains(_testUserId1)) {
        userFoundInAnyTeam = true;
      }
    });

    if (userFoundInAnyTeam) {
      throw Exception('User reference in match players was not removed');
    }
    result.log('✓ User reference was removed from match players');

    // Verify event was not deleted
    DocumentSnapshot eventDoc =
        await _firestore.collection('events').doc(_testEventId!).get();
    if (!eventDoc.exists) {
      throw Exception('Event was incorrectly deleted');
    }
    result.log('✓ Event document was preserved');

    // Test passed!
    result.log('User deletion cascade test passed successfully');
  }

  /// Clean up all test data
  Future<void> _cleanup() async {
    try {
      // Try to delete the event which should cascade and clean up everything
      if (_testEventId != null) {
        await _deleteService.deleteEventWithCascade(_testEventId!);
      }

      // Explicitly delete any remaining users
      for (String? userId in [
        _testUserId1,
        _testUserId2,
        _testUserId3,
        _testUserId4,
      ]) {
        if (userId != null) {
          try {
            await _firestore.collection('users').doc(userId).delete();
          } catch (e) {
            // Ignore errors if document doesn't exist
          }
        }
      }

      // Reset all IDs
      _testEventId = null;
      _testTeamId1 = null;
      _testTeamId2 = null;
      _testUserId1 = null;
      _testUserId2 = null;
      _testUserId3 = null;
      _testUserId4 = null;
      _testMatchId = null;
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }
}

/// Result class for tracking test outcomes
class TestResult {
  bool success = false;
  List<String> messages = [];

  void log(String message) {
    messages.add(message);
    print(message);
  }

  String get summary {
    return 'Test ${success ? 'PASSED' : 'FAILED'}\n\n' + messages.join('\n');
  }
}

/// Test Runner Widget for UI-based testing
class DeletionTestRunner extends StatefulWidget {
  const DeletionTestRunner({Key? key}) : super(key: key);

  @override
  State<DeletionTestRunner> createState() => _DeletionTestRunnerState();
}

class _DeletionTestRunnerState extends State<DeletionTestRunner> {
  bool _isRunning = false;
  TestResult? _result;

  Future<void> _runTest() async {
    setState(() {
      _isRunning = true;
      _result = null;
    });

    try {
      final tester = DeletionServiceTest();
      final result = await tester.runDeletionTest();

      setState(() {
        _result = result;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        final result = TestResult();
        result.success = false;
        result.log('Test runner encountered an error: $e');
        _result = result;
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deletion Service Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test explanation
            Text(
              'Deletion Service Cascade Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This test verifies that the cascade deletion functionality works correctly for events, teams, matches, and users. It creates test data, performs deletions, and verifies that all references are properly cleaned up.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),

            // Run test button
            Center(
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runTest,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _isRunning
                        ? 'Running Test...'
                        : 'Run Cascade Deletion Test',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),

            // Results area
            Expanded(
              child:
                  _isRunning
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Running test, please wait...'),
                          ],
                        ),
                      )
                      : _result == null
                      ? Center(child: Text('Press the button to run the test'))
                      : Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              _result!.success
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _result!.success ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _result!.success
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color:
                                      _result!.success
                                          ? Colors.green
                                          : Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _result!.success
                                      ? 'TEST PASSED'
                                      : 'TEST FAILED',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color:
                                        _result!.success
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      _result!.messages.map((message) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4.0,
                                          ),
                                          child: Text(message),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
