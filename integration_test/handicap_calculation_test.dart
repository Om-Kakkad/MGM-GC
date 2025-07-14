import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:mgm_gc/firebase_options.dart';
import 'package:mgm_gc/models/scorecard_model.dart';
import 'package:mgm_gc/models/user_model.dart';
import 'dart:convert';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Use Firebase emulators for testing
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

    // Clear existing users and data for clean testing
    await _clearAllData();
  });

  testWidgets('Test handicap calculation workflow', (tester) async {
    final auth = FirebaseAuth.instance;
    final store = FirebaseFirestore.instance;

    // ================= 1. CREATE TEST USERS =================
    print('Creating test users with varying handicaps...');

    final testUsers = [
      // User with existing handicap index (low)
      _TestUser(
        email: 'low_handicap@example.com',
        password: 'Password123!',
        firstName: 'James',
        lastName: 'Wilson',
        gender: 'Male',
        dateOfBirth: DateTime(1985, 3, 15),
        phoneNumber: '555-123-4567',
        handicap: 5.2,
        isMember: true,
        membershipId: 'MGM-001',
      ),

      // User with existing handicap index (mid)
      _TestUser(
        email: 'mid_handicap@example.com',
        password: 'Password123!',
        firstName: 'Sarah',
        lastName: 'Johnson',
        gender: 'Female',
        dateOfBirth: DateTime(1990, 6, 22),
        phoneNumber: '555-987-6543',
        handicap: 14.7,
        isMember: true,
        membershipId: 'MGM-002',
      ),

      // User with existing handicap index (high)
      _TestUser(
        email: 'high_handicap@example.com',
        password: 'Password123!',
        firstName: 'Robert',
        lastName: 'Smith',
        gender: 'Male',
        dateOfBirth: DateTime(1975, 9, 10),
        phoneNumber: '555-456-7890',
        handicap: 24.3,
        isMember: true,
        membershipId: 'MGM-003',
      ),

      // User without existing handicap
      _TestUser(
        email: 'new_golfer@example.com',
        password: 'Password123!',
        firstName: 'Emma',
        lastName: 'Davis',
        gender: 'Female',
        dateOfBirth: DateTime(1992, 12, 5),
        phoneNumber: '555-555-5555',
        handicap: null, // No established handicap yet
        isMember: true,
        membershipId: 'MGM-004',
      ),
    ];

    // Store created user IDs and credentials
    final Map<String, UserCredential> userCredentials = {};
    final Map<String, String> userIds = {};

    // Create all users
    for (var user in testUsers) {
      print('Creating user: ${user.email}');

      // Create user in Firebase Auth
      final credential = await auth.createUserWithEmailAndPassword(
        email: user.email,
        password: user.password,
      );

      final uid = credential.user!.uid;
      userIds[user.email] = uid;
      userCredentials[user.email] = credential;

      // Create user model with complete profile data
      final userModel = UserModel(
        uid: uid,
        email: user.email,
        role: 'user',
        firstName: user.firstName,
        lastName: user.lastName,
        dateOfBirth: user.dateOfBirth,
        gender: user.gender,
        phoneNumber: user.phoneNumber,
        golfDetails: GolfDetails(
          handicap: user.handicap,
          isMember: user.isMember,
          membershipId: user.membershipId,
          playingInLeague: false,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user data to Firestore
      await store.collection('users').doc(uid).set(userModel.toMap());

      // Sign out before creating next user
      await auth.signOut();
    }

    // ================= 2. CREATE TEST COURSE =================
    print('Creating test course data...');

    // Create a test course with standard parameters
    final CourseData courseData = CourseData(
      id: 'test-course',
      name: 'Test Golf Club',
      par: 69,
      courseRating: 69.0, // Course rating matches par
      slopeRating: 125.0, // Moderate difficulty
      holePars: [
        3,
        3,
        4,
        4,
        5,
        3,
        5,
        4,
        3,
        4,
        5,
        3,
        5,
        3,
        4,
        3,
        4,
        4,
      ], // Par 69
      holeIndexes: [
        18,
        8,
        2,
        10,
        4,
        14,
        6,
        16,
        12,
        9,
        1,
        13,
        3,
        15,
        11,
        17,
        7,
        5,
      ],
    );

    await store
        .collection('courses')
        .doc(courseData.id)
        .set(courseData.toFirestore());

    // ================= 3. CREATE TEST BOOKINGS =================
    print('Creating test bookings...');

    // Sign in as first user to create bookings
    await auth.signInWithEmailAndPassword(
      email: testUsers[0].email,
      password: testUsers[0].password,
    );

    // Create dates for test bookings (some in the past for completed rounds)
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      10,
      0,
    ); // 10:00 AM today

    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    final threeDaysAgo = today.subtract(const Duration(days: 3));
    final fourDaysAgo = today.subtract(const Duration(days: 4));

    // Define test bookings
    final List<_TestBooking> testBookings = [
      // 18-hole round - All 4 players
      _TestBooking(
        startTime: fourDaysAgo,
        endTime: fourDaysAgo.add(const Duration(hours: 4)),
        players: testUsers.map((user) => userIds[user.email]!).toList(),
        holes: 18,
      ),

      // 9-hole round - First 3 players only
      _TestBooking(
        startTime: threeDaysAgo,
        endTime: threeDaysAgo.add(const Duration(hours: 2)),
        players:
            testUsers
                .sublist(0, 3)
                .map((user) => userIds[user.email]!)
                .toList(),
        holes: 9,
      ),

      // 18-hole round - All 4 players
      _TestBooking(
        startTime: twoDaysAgo,
        endTime: twoDaysAgo.add(const Duration(hours: 4)),
        players: testUsers.map((user) => userIds[user.email]!).toList(),
        holes: 18,
      ),

      // 9-hole round - Last 3 players only
      _TestBooking(
        startTime: yesterday,
        endTime: yesterday.add(const Duration(hours: 2)),
        players:
            testUsers.sublist(1).map((user) => userIds[user.email]!).toList(),
        holes: 9,
      ),

      // Today's round - All players
      _TestBooking(
        startTime: today,
        endTime: today.add(const Duration(hours: 4)),
        players: testUsers.map((user) => userIds[user.email]!).toList(),
        holes: 18,
      ),
    ];

    final List<String> bookingIds = [];

    // Create each booking
    for (var booking in testBookings) {
      // Create player info list
      final List<PlayerInfo> playerInfoList = [];

      for (String playerId in booking.players) {
        // Get user data
        final userData = await store.collection('users').doc(playerId).get();
        final user = userData.data()!;

        playerInfoList.add(
          PlayerInfo(
            userId: playerId,
            name: '${user['firstName']} ${user['lastName']}',
            email: user['email'],
          ),
        );
      }

      // Create booking document
      final bookingData = {
        'startTime': Timestamp.fromDate(booking.startTime),
        'endTime': Timestamp.fromDate(booking.endTime),
        'userId': auth.currentUser!.uid,
        'status': 'confirmed',
        'players':
            playerInfoList
                .map(
                  (p) => {'userId': p.userId, 'name': p.name, 'email': p.email},
                )
                .toList(),
        'holes': booking.holes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await store.collection('bookings').add(bookingData);
      bookingIds.add(docRef.id);

      print('Created booking ID: ${docRef.id} for ${booking.startTime}');
    }

    // ================= 4. CREATE SCORECARDS & ADD SCORES =================
    print('Creating scorecards and adding scores...');

    final List<_TestRound> testRounds = [
      // First round - 18 holes, 4 days ago
      _TestRound(
        bookingIndex: 0,
        scores: {
          // Low handicap player - 5.2 - Good round (2 under handicap)
          testUsers[0].email: _generateScores(18, 71),

          // Mid handicap player - 14.7 - Typical round
          testUsers[1].email: _generateScores(18, 88),

          // High handicap player - 24.3 - Bad round (4 over handicap)
          testUsers[2].email: _generateScores(18, 102),

          // New golfer - No handicap - First round
          testUsers[3].email: _generateScores(18, 95),
        },
      ),

      // Second round - 9 holes, 3 days ago
      _TestRound(
        bookingIndex: 1,
        scores: {
          // Low handicap player - 5.2 - Average round
          testUsers[0].email: _generateScores(9, 39),

          // Mid handicap player - 14.7 - Good round
          testUsers[1].email: _generateScores(9, 41),

          // High handicap player - 24.3 - Average round
          testUsers[2].email: _generateScores(9, 48),
        },
      ),

      // Third round - 18 holes, 2 days ago
      _TestRound(
        bookingIndex: 2,
        scores: {
          // Low handicap player - 5.2 - Bad round
          testUsers[0].email: _generateScores(18, 82),

          // Mid handicap player - 14.7 - Bad round
          testUsers[1].email: _generateScores(18, 95),

          // High handicap player - 24.3 - Good round
          testUsers[2].email: _generateScores(18, 92),

          // New golfer - Second round
          testUsers[3].email: _generateScores(18, 93),
        },
      ),

      // Fourth round - 9 holes, yesterday
      _TestRound(
        bookingIndex: 3,
        scores: {
          // Mid handicap player - 14.7 - Average round
          testUsers[1].email: _generateScores(9, 44),

          // High handicap player - 24.3 - Good round
          testUsers[2].email: _generateScores(9, 45),

          // New golfer - Third round
          testUsers[3].email: _generateScores(9, 47),
        },
      ),
    ];

    // Create and populate scorecards for past rounds
    for (var i = 0; i < testRounds.length; i++) {
      final round = testRounds[i];
      final bookingId = bookingIds[round.bookingIndex];

      // Get booking data
      final bookingDoc =
          await store.collection('bookings').doc(bookingId).get();
      final bookingData = bookingDoc.data()!;

      // Create scorecard
      final scorecardData = {
        'bookingId': bookingId,
        'userId': auth.currentUser!.uid,
        'playDate': bookingData['startTime'],
        'playerScores': {},
        'isCompleted': false,
        'courseName': courseData.name,
        'coursePar': courseData.par,
        'courseRating': courseData.courseRating,
        'slopeRating': courseData.slopeRating,
      };

      final scorecardRef = await store
          .collection('scorecards')
          .add(scorecardData);
      final scorecardId = scorecardRef.id;
      print('Created scorecard ID: $scorecardId for booking: $bookingId');

      // Add player scorecards with hole scores
      final Map<String, Map<String, dynamic>> playerScores = {};
      final List<dynamic> players = bookingData['players'];

      // Create player scorecards
      for (var player in players) {
        final email = player['email'];
        final userId = player['userId'];
        final name = player['name'];

        // Check if we have scores for this player
        if (round.scores.containsKey(email)) {
          final holeScores = round.scores[email]!;

          // Get player's handicap
          double? handicapIndex;
          final userDoc = await store.collection('users').doc(userId).get();
          final userData = userDoc.data()!;
          if (userData['golfDetails'] != null &&
              userData['golfDetails']['handicap'] != null) {
            handicapIndex =
                (userData['golfDetails']['handicap'] as num).toDouble();
          }

          // Create player scorecard entry
          playerScores[userId] = {
            'userId': userId,
            'playerName': name,
            'holeScores': holeScores,
            'handicapIndex': handicapIndex,
          };
        }
      }

      // Update scorecard with player scores
      await scorecardRef.update({'playerScores': playerScores});

      // Complete the scorecard and process handicaps
      await _completeScorecard(scorecardId, store, courseData);
    }

    // ================= 5. VERIFY HANDICAP CALCULATIONS =================
    print('Verifying handicap calculations...');

    // Get all handicap records
    final handicapRecords = await store.collection('handicapRecords').get();
    expect(
      handicapRecords.docs.length,
      4,
      reason: 'Should have 4 handicap records',
    );

    // Verify each player's handicap record
    for (var user in testUsers) {
      // Skip if user had no initial handicap and has played fewer than 3 rounds
      if (user.handicap == null && user.email == testUsers[3].email) {
        // Verify the new golfer has a handicap after 3+ rounds
        final userDoc =
            await store.collection('users').doc(userIds[user.email]).get();
        final userData = userDoc.data()!;

        expect(
          userData['golfDetails']['handicap'],
          isNotNull,
          reason:
              'New golfer should have a calculated handicap after 3+ rounds',
        );

        // Find handicap record for this user
        final recordDoc = handicapRecords.docs.firstWhere(
          (doc) => doc.data()['userId'] == userIds[user.email],
        );

        final handicapRecord = recordDoc.data();
        final scoreDifferentials =
            handicapRecord['scoreDifferentials'] as List<dynamic>;

        // New golfer played 3 rounds (one used for handicap calculation)
        expect(
          scoreDifferentials.length,
          3,
          reason: 'New golfer should have 3 score differentials',
        );

        // Verify the handicap index is calculated correctly
        final double? handicapIndex = handicapRecord['handicapIndex'];
        expect(
          handicapIndex,
          isNotNull,
          reason: 'Should have calculated handicap index',
        );

        // Calculate expected handicap index (average of lowest 1 out of 3-4 differentials)
        final List<double> sortedDiffs =
            scoreDifferentials
                .map<double>((diff) => (diff['value'] as num).toDouble())
                .toList()
              ..sort();

        final expectedIndex = _roundToOneDecimal(sortedDiffs[0]);
        expect(
          handicapIndex,
          expectedIndex,
          reason:
              'Handicap index should be calculated correctly for new golfer',
        );
      }
      // For existing handicap players, check that handicap has changed
      else if (user.handicap != null) {
        final userDoc =
            await store.collection('users').doc(userIds[user.email]).get();
        final userData = userDoc.data()!;

        final currentHandicap = userData['golfDetails']['handicap'];
        expect(
          currentHandicap,
          isNot(equals(user.handicap)),
          reason: 'Handicap should have changed after new rounds',
        );

        // Find handicap record
        final recordDoc = handicapRecords.docs.firstWhere(
          (doc) => doc.data()['userId'] == userIds[user.email],
        );

        final handicapRecord = recordDoc.data();
        final scoreDifferentials =
            handicapRecord['scoreDifferentials'] as List<dynamic>;

        // Verify number of recorded rounds
        int expectedRounds;
        if (user.email == testUsers[0].email)
          expectedRounds = 3; // First player played 3 rounds
        else if (user.email == testUsers[1].email)
          expectedRounds = 4; // Second player played 4 rounds
        else
          expectedRounds = 4; // Third player played 4 rounds

        expect(
          scoreDifferentials.length,
          expectedRounds,
          reason: 'Should have the correct number of score differentials',
        );

        // Verify handicap calculation
        final double handicapIndex = handicapRecord['handicapIndex'];
        final List<double> differentials =
            scoreDifferentials
                .map<double>((diff) => (diff['value'] as num).toDouble())
                .toList()
              ..sort();

        // Calculate expected handicap index based on WHS rules
        int scoresUsed;
        if (differentials.length <= 4) {
          scoresUsed = 1;
        } else if (differentials.length <= 6) {
          scoresUsed = 2;
        } else {
          scoresUsed = 3; // For more rounds, follow WHS table
        }

        double sum = 0;
        for (int i = 0; i < scoresUsed; i++) {
          sum += differentials[i];
        }

        final expectedIndex = _roundToOneDecimal(sum / scoresUsed);

        expect(
          handicapIndex,
          expectedIndex,
          reason:
              'Handicap index should be calculated correctly for ${user.email}',
        );
      }
    }

    // Sign out
    await auth.signOut();

    print('Handicap calculation test completed successfully');
  });
}

// Helper classes
class _TestUser {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final String phoneNumber;
  final double? handicap;
  final bool isMember;
  final String? membershipId;

  _TestUser({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.handicap,
    required this.isMember,
    this.membershipId,
  });
}

class _TestBooking {
  final DateTime startTime;
  final DateTime endTime;
  final List<String> players; // User IDs
  final int holes; // 9 or 18

  _TestBooking({
    required this.startTime,
    required this.endTime,
    required this.players,
    required this.holes,
  });
}

class PlayerInfo {
  final String? userId;
  final String name;
  final String? email;

  PlayerInfo({this.userId, required this.name, this.email});
}

class _TestRound {
  final int bookingIndex;
  final Map<String, Map<String, int>> scores; // email -> {hole# -> score}

  _TestRound({required this.bookingIndex, required this.scores});
}

// Helper functions

// Clear all existing data for clean testing
Future<void> _clearAllData() async {
  try {
    // Clear Firebase Auth users via the cloud function
    final url = Uri.parse(
      'http://127.0.0.1:5001/mgm-gc-338316/us-central1/clearAllUsers',
    );
    final response = await http.post(url);

    if (response.statusCode == 200) {
      print(json.decode(response.body)['message']);
    } else {
      print(
        'Error clearing auth users: ${response.statusCode} - ${response.body}',
      );
    }

    // Clear Firestore collections
    final collections = [
      'users',
      'bookings',
      'scorecards',
      'handicapRecords',
      'courses',
      'internal',
    ];

    for (var collection in collections) {
      await _clearFirestoreCollection(collection);
    }

    print('All test data cleared successfully');
  } catch (e) {
    print('Error clearing data: $e');
  }
}

// Clear a specific Firestore collection
Future<void> _clearFirestoreCollection(String collection) async {
  final store = FirebaseFirestore.instance;
  final batch = store.batch();
  final docs = await store.collection(collection).get();

  for (var doc in docs.docs) {
    batch.delete(doc.reference);
  }

  if (docs.docs.isNotEmpty) {
    await batch.commit();
    print('Cleared ${docs.docs.length} documents from $collection');
  }
}

// Generate realistic golf scores for testing
Map<String, int> _generateScores(int holes, int targetTotal) {
  final Map<String, int> scores = {};
  int remainingStrokes = targetTotal;
  int remainingHoles = holes;

  // Define realistic score patterns
  final List<int> possiblePars = [3, 4, 5];
  final List<int> relativeScores = [
    -1,
    0,
    0,
    0,
    1,
    1,
    2,
  ]; // More likely par or bogey

  for (int hole = 1; hole <= holes; hole++) {
    final int par = possiblePars[hole % possiblePars.length];

    if (hole == holes) {
      // Last hole gets whatever is left to reach target
      scores[hole.toString()] = remainingStrokes;
    } else {
      // Pick a realistic relative score (relative to par)
      final int relativeScore = relativeScores[hole % relativeScores.length];
      final int score = par + relativeScore;

      // Make sure we leave enough strokes for remaining holes
      final int minRemaining =
          remainingHoles - 1; // Minimum 1 stroke per remaining hole
      if (remainingStrokes - score >= minRemaining) {
        scores[hole.toString()] = score;
        remainingStrokes -= score;
        remainingHoles--;
      } else {
        // Adjust score to leave enough for remaining holes
        final int adjustedScore = remainingStrokes - minRemaining;
        scores[hole.toString()] = adjustedScore;
        remainingStrokes -= adjustedScore;
        remainingHoles--;
      }
    }
  }

  return scores;
}

// Complete a scorecard and calculate handicaps
Future<void> _completeScorecard(
  String scorecardId,
  FirebaseFirestore store,
  CourseData courseData,
) async {
  try {
    final scorecardRef = store.collection('scorecards').doc(scorecardId);
    final scorecardDoc = await scorecardRef.get();

    // Get the scorecard data
    final data = scorecardDoc.data()!;
    final Map<String, dynamic> playerScores = Map<String, dynamic>.from(
      data['playerScores'],
    );
    final Map<String, dynamic> updatedPlayerScores = {};
    final coursePar = data['coursePar'] as int;
    final courseRating = data['courseRating'] as double;
    final slopeRating = data['slopeRating'] as double;

    // Process each player's scores
    for (var entry in playerScores.entries) {
      final String playerId = entry.key;
      final Map<String, dynamic> playerData = Map<String, dynamic>.from(
        entry.value,
      );
      final Map<String, dynamic> holeScores = Map<String, dynamic>.from(
        playerData['holeScores'],
      );
      final double? handicapIndex = playerData['handicapIndex'];

      // Skip if player has no scores
      if (holeScores.isEmpty) {
        updatedPlayerScores[playerId] = playerData;
        continue;
      }

      // Calculate course handicap if we have handicap index
      int? courseHandicap;
      if (handicapIndex != null) {
        courseHandicap = _calculateCourseHandicap(
          handicapIndex,
          slopeRating,
          courseRating,
          coursePar,
        );
      }

      // Calculate adjusted gross score
      final adjustedGrossScore = _calculateAdjustedGrossScore(
        holeScores,
        courseData.holePars,
        courseData.holeIndexes,
        courseHandicap,
      );

      // Calculate score differential if we have all required values
      double? scoreDifferential;
      if (adjustedGrossScore != null) {
        // The score differential calculation handles 9-hole vs 18-hole rounds
        scoreDifferential = _calculateScoreDifferential(
          adjustedGrossScore,
          courseRating,
          slopeRating,
          coursePar,
          0, // PCC (Playing Condition Calculation) set to 0 for testing
        );
      }

      // Update player scorecard data
      final Map<String, dynamic> updatedPlayerData = Map<String, dynamic>.from(
        playerData,
      );
      updatedPlayerData['courseHandicap'] = courseHandicap;
      updatedPlayerData['adjustedGrossScore'] = adjustedGrossScore;
      updatedPlayerData['scoreDifferential'] = scoreDifferential;

      updatedPlayerScores[playerId] = updatedPlayerData;

      // If player has a valid score differential, store it in their handicap record
      if (scoreDifferential != null && !playerId.startsWith('guest_')) {
        await _storeScoreDifferential(
          playerId,
          scoreDifferential,
          scorecardId,
          (data['playDate'] as Timestamp).toDate(),
          data['courseName'] ?? 'Test Course',
          store,
        );
      }
    }

    // Update the scorecard with calculated values
    await scorecardRef.update({
      'playerScores': updatedPlayerScores,
      'isCompleted': true,
      'completedAt': FieldValue.serverTimestamp(),
    });

    print('Completed scorecard $scorecardId with handicap calculations');
  } catch (e) {
    print('Error completing scorecard: $e');
  }
}

// Calculate course handicap
int _calculateCourseHandicap(
  double handicapIndex,
  double slopeRating,
  double courseRating,
  int coursePar,
) {
  double ch = (handicapIndex * slopeRating / 113) + (courseRating - coursePar);
  // Round to nearest integer
  return ch.round();
}

// Calculate adjusted gross score (Net Double Bogey cap on each hole)
int? _calculateAdjustedGrossScore(
  Map<String, dynamic> holeScores,
  List<int> holePars,
  List<int> holeIndexes,
  int? courseHandicap,
) {
  // If we don't have course handicap, just sum the scores
  if (courseHandicap == null) {
    return holeScores.values.fold<int>(0, (sum, score) => sum + (score as int));
  }

  int totalAdjustedScore = 0;
  int holesPlayed = 0;

  holeScores.forEach((holeString, score) {
    try {
      final holeNumber = int.parse(holeString);
      if (holeNumber < 1 || holeNumber > 18) return;

      holesPlayed++;

      // Get par for this hole (0-indexed list)
      final holePar = holePars[holeNumber - 1];
      final strokeIndex = holeIndexes[holeNumber - 1];

      // Calculate strokes received on this hole
      int strokesReceived = 0;
      if (courseHandicap > 0) {
        // Full handicap strokes
        strokesReceived += (courseHandicap ~/ 18);

        // Additional stroke if index is less than or equal to remaining handicap
        final remaining = courseHandicap % 18;
        if (strokeIndex <= remaining) {
          strokesReceived++;
        }
      }

      // Net double bogey = Par + 2 + strokes received
      final maxScore = holePar + 2 + strokesReceived;

      // Apply cap and add to total
      final adjustedScore = (score as int) > maxScore ? maxScore : score;
      totalAdjustedScore += adjustedScore;
    } catch (e) {
      // Skip invalid hole numbers
    }
  });

  // For incomplete rounds, minimum holes required for valid score:
  // - 9-hole round: at least 7 holes must be played
  // - 18-hole round: at least 14 holes must be played

  if (holesPlayed < 7) {
    // Not enough holes played for a valid score
    return null;
  }

  return totalAdjustedScore;
}

// Calculate score differential
double _calculateScoreDifferential(
  int adjustedGrossScore,
  double courseRating,
  double slopeRating,
  int coursePar,
  int pcc, // Playing Condition Calculation
) {
  // For 9-hole rounds, adjustedGrossScore will be the actual 9-hole score
  // According to World Handicap System rules, 9-hole scores need adjustment:
  // 1. Double the 9-hole score
  // 2. Double the PCC
  // 3. Use the 9-hole course rating and par (typically half the 18-hole values)

  // Using a simple heuristic to detect 9-hole rounds
  bool isNineHoleRound = adjustedGrossScore < 80; // Rough heuristic

  if (isNineHoleRound) {
    // Double the score for 9-hole rounds
    adjustedGrossScore *= 2;

    // Double the PCC for 9-hole rounds
    pcc *= 2;

    // Adjust course rating and par for 9-hole calculation
    courseRating = courseRating / 2;
    coursePar = coursePar ~/ 2;
  }

  double sd =
      (113 / slopeRating) * (adjustedGrossScore - courseRating - pcc) +
      (courseRating - coursePar);

  // Round to 1 decimal place
  return _roundToOneDecimal(sd);
}

// Store a player's score differential in their handicap record
Future<void> _storeScoreDifferential(
  String userId,
  double scoreDifferential,
  String scorecardId,
  DateTime playDate,
  String courseName,
  FirebaseFirestore store,
) async {
  try {
    // Get the player's handicap record or create if it doesn't exist
    final querySnapshot =
        await store
            .collection('handicapRecords')
            .where('userId', isEqualTo: userId)
            .get();

    DocumentReference recordRef;
    List<Map<String, dynamic>> differentials = [];

    if (querySnapshot.docs.isEmpty) {
      // Create new record
      recordRef = store.collection('handicapRecords').doc();
    } else {
      // Use existing record
      recordRef = querySnapshot.docs.first.reference;
      final recordData = querySnapshot.docs.first.data();
      differentials = List<Map<String, dynamic>>.from(
        recordData['scoreDifferentials'] ?? [],
      );
    }

    // Add the new score differential
    differentials.add({
      'scorecardId': scorecardId,
      'playDate': Timestamp.fromDate(playDate),
      'value': scoreDifferential,
      'courseName': courseName,
    });

    // Sort by date (newest first)
    differentials.sort(
      (a, b) =>
          (b['playDate'] as Timestamp).compareTo(a['playDate'] as Timestamp),
    );

    // Keep only the 20 most recent
    if (differentials.length > 20) {
      differentials = differentials.sublist(0, 20);
    }

    // Calculate new handicap index
    double? handicapIndex = _calculateHandicapIndex(differentials);

    // Update the handicap record
    await recordRef.set({
      'userId': userId,
      'scoreDifferentials': differentials,
      'handicapIndex': handicapIndex,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Update the user's handicap in their profile
    if (handicapIndex != null) {
      await store.collection('users').doc(userId).update({
        'golfDetails.handicap': handicapIndex,
      });
    }
  } catch (e) {
    print('Error storing score differential: $e');
  }
}

// Calculate handicap index from score differentials using WHS rules
double? _calculateHandicapIndex(List<Map<String, dynamic>> differentials) {
  int count = differentials.length;

  // Need at least 3 rounds to calculate handicap
  if (count < 3) {
    return null;
  }

  // Sort differentials (lowest to highest)
  List<double> sortedDiffs =
      differentials.map((sd) => (sd['value'] as num).toDouble()).toList()
        ..sort();

  // Determine number of scores to use based on WHS table
  int scoresUsed;

  if (count <= 3) {
    scoresUsed = 1; // Lowest 1
  } else if (count <= 4) {
    scoresUsed = 1; // Lowest 1
  } else if (count <= 6) {
    scoresUsed = 2; // Lowest 2
  } else if (count <= 8) {
    scoresUsed = 2; // Lowest 2
  } else if (count <= 10) {
    scoresUsed = 3; // Lowest 3
  } else if (count <= 12) {
    scoresUsed = 4; // Lowest 4
  } else if (count <= 14) {
    scoresUsed = 5; // Lowest 5
  } else if (count <= 16) {
    scoresUsed = 6; // Lowest 6
  } else if (count <= 18) {
    scoresUsed = 7; // Lowest 7
  } else {
    scoresUsed = 8; // Lowest 8 out of 20
  }

  // Calculate average of lowest N scores
  double sum = 0;
  for (int i = 0; i < scoresUsed; i++) {
    sum += sortedDiffs[i];
  }

  double average = sum / scoresUsed;

  // Round to 1 decimal place
  return _roundToOneDecimal(average);
}

// Round to one decimal place
double _roundToOneDecimal(double value) {
  return (value * 10).round() / 10;
}
