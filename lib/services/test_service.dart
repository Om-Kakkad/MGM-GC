import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestOperationResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data; // Added missing data field

  TestOperationResult({
    required this.success,
    required this.message,
    this.data,
  });
}

class TestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Delete all test data
  Future<TestOperationResult> deleteAllTestData() async {
    try {
      // Store current user credentials
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return TestOperationResult(
          success: false,
          message: "Must be logged in to perform this operation",
        );
      }

      final String adminUid = currentUser.uid;
      final adminDoc = await _firestore.collection('users').doc(adminUid).get();

      if (!adminDoc.exists || adminDoc.data()?['role'] != 'admin') {
        return TestOperationResult(
          success: false,
          message: "Only administrators can perform this operation",
        );
      }

      // 1. Delete all non-admin users from Firestore
      final QuerySnapshot usersSnapshot =
          await _firestore.collection('users').get();

      // First, let's handle Firestore documents
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final String userId = doc.id;
        final String userRole = userData['role'] ?? 'user';

        if (userRole != 'admin' && userId != adminUid) {
          // Delete the user document
          await _firestore.collection('users').doc(userId).delete();
        }
      }

      // 2. Delete all events
      final QuerySnapshot eventsSnapshot =
          await _firestore.collection('events').get();
      for (final doc in eventsSnapshot.docs) {
        await _firestore.collection('events').doc(doc.id).delete();
      }

      // 3. Delete all teams
      final QuerySnapshot teamsSnapshot =
          await _firestore.collection('teams').get();
      for (final doc in teamsSnapshot.docs) {
        await _firestore.collection('teams').doc(doc.id).delete();
      }

      // 4. Delete all matches (fourBalls)
      final QuerySnapshot matchesSnapshot =
          await _firestore.collection('fourBalls').get();
      for (final doc in matchesSnapshot.docs) {
        await _firestore.collection('fourBalls').doc(doc.id).delete();
      }

      // Also check for matches in event subcollections
      // Changed variable name to avoid duplication
      final eventDocs = await _firestore.collection('events').get();
      for (final eventDoc in eventDocs.docs) {
        final eventId = eventDoc.id;
        final eventMatchesSnapshot =
            await _firestore
                .collection('events')
                .doc(eventId)
                .collection('matches')
                .get();

        for (final matchDoc in eventMatchesSnapshot.docs) {
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .doc(matchDoc.id)
              .delete();
        }
      }

      // Note: We can't programmatically delete other Firebase Auth users
      // without using Admin SDK or Cloud Functions
      // Inform the user about this limitation
      return TestOperationResult(
        success: true,
        message:
            "Firestore test data deleted successfully. Note: Firebase Auth accounts require manual deletion.",
      );
    } catch (e) {
      print('Error in deleteAllTestData: $e');
      return TestOperationResult(
        success: false,
        message: "Error deleting test data: $e",
      );
    }
  }

  // Create test data
  Future<TestOperationResult> createTestData() async {
    try {
      // Verify admin permissions
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return TestOperationResult(
          success: false,
          message: "Must be logged in to perform this operation",
        );
      }

      final String adminUid = currentUser.uid;
      final adminDoc = await _firestore.collection('users').doc(adminUid).get();

      if (!adminDoc.exists || adminDoc.data()?['role'] != 'admin') {
        return TestOperationResult(
          success: false,
          message: "Only administrators can perform this operation",
        );
      }

      // 1. Create a test league event
      final DocumentReference eventRef = await _firestore
          .collection('events')
          .add({
            'eventName': 'Test League Event',
            'eventType': 'League',
            'eventDescription': 'This is a test league event for development',
            'eventDates': [
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 21))),
            ],
            'createdAt': FieldValue.serverTimestamp(),
          });

      final String eventId = eventRef.id;

      // 2. Create two teams
      final List<String> teamIds = [];
      final teamNames = ['Test Team A', 'Test Team B'];

      for (int i = 0; i < teamNames.length; i++) {
        final DocumentReference teamRef = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .add({
              'teamName': teamNames[i],
              'teamPassword': 'team${String.fromCharCode(65 + i)}123',
              'eventID': eventId,
              'players': [],
              'createdAt': FieldValue.serverTimestamp(),
            });
        teamIds.add(teamRef.id);
      }

      // Update event with team IDs
      await eventRef.update({'teamIDs': teamIds});

      // 3. Create a test match between the teams
      final DocumentReference matchRef = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('matches')
          .add({
            'teams': teamIds,
            'players': {'teamA': [], 'teamB': []},
            'matchType': '4-ball',
            'matchPlayType': 'match play',
            'matchDateTime': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 7)),
            ),
            'matchStatus': 'active',
            'holeResults': {},
            'bonusPoint': false, // Add the new field
            'createdAt': FieldValue.serverTimestamp(),
          });

      // 4. Create test users in Firestore only (no Auth accounts)
      // For each team, create 2 players
      for (int teamIndex = 0; teamIndex < teamIds.length; teamIndex++) {
        for (int playerNum = 1; playerNum <= 2; playerNum++) {
          final String playerEmail =
              'testplayer${teamIndex + 1}$playerNum@example.com';
          final String playerName = 'Player ${teamIndex + 1}$playerNum';

          // Create the Firestore document
          final userDoc = await _firestore.collection('users').add({
            'email': playerEmail,
            'firstName': 'Test',
            'lastName': playerName,
            'role': 'league_player',
            'dateOfBirth': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 365 * 30)),
            ),
            'gender': 'Male',
            'phoneNumber': '123-456-7890',
            'golfDetails': {
              'handicap': 15.0 + teamIndex * 2 + playerNum,
              'isMember': true,
              'membershipId': 'TEST$teamIndex$playerNum',
              'playingInLeague': true,
              'teamId': teamIds[teamIndex],
              'teamName': teamNames[teamIndex],
            },
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Add user to team players array
          await _firestore.collection('teams').doc(teamIds[teamIndex]).update({
            'players': FieldValue.arrayUnion([userDoc.id]),
          });
        }
      }

      // Add an extra regular user
      await _firestore.collection('users').add({
        'email': 'testuser@example.com',
        'firstName': 'Test',
        'lastName': 'User',
        'role': 'user',
        'dateOfBirth': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 365 * 25)),
        ),
        'gender': 'Other',
        'phoneNumber': '123-456-7890',
        'golfDetails': {
          'handicap': 20.0,
          'isMember': false,
          'playingInLeague': false,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return TestOperationResult(
        success: true,
        message: 'Test data created successfully',
        data: {'eventId': eventId, 'teamIds': teamIds, 'matchId': matchRef.id},
      );
    } catch (e) {
      print('Error in createTestData: $e');
      return TestOperationResult(
        success: false,
        message: "Error creating test data: $e",
      );
    }
  }
}
