import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mgm_gc/models/booking_model.dart';
import 'package:mgm_gc/models/scorecard_model.dart';

class ScorecardService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Default course data (can be overridden with data from Firestore)
  final CourseData _defaultCourse = CourseData(
    id: 'default',
    name: 'MGM Golf Club',
    par: 69,
    courseRating: 69.0,
    slopeRating: 113.0,
    holePars: [3, 3, 4, 4, 5, 3, 5, 4, 3, 4, 5, 3, 5, 3, 4, 3, 4, 4],
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
  ); // Get or create a scorecard for a booking
  Future<ScorecardModel> getOrCreateScorecard(BookingModel booking) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if scorecard already exists for this booking
      final querySnapshot =
          await _firestore
              .collection('scorecards')
              .where('bookingId', isEqualTo: booking.id)
              .get();

      // If exists, return the first one
      if (querySnapshot.docs.isNotEmpty) {
        return ScorecardModel.fromFirestore(querySnapshot.docs.first);
      }

      // Otherwise, create a new scorecard
      final courseData = await _getCourseData();

      // Create player scorecards map
      Map<String, PlayerScorecard> playerScores = {};

      for (PlayerInfo player in booking.players) {
        if (player.userId != null) {
          // For registered players, use their user ID
          playerScores[player.userId!] = PlayerScorecard(
            userId: player.userId!,
            playerName: player.name,
            holeScores: {},
            handicapIndex: await _getPlayerHandicapIndex(player.userId!),
          );
        } else {
          // For guests, create a temporary ID
          String tempId =
              'guest_${DateTime.now().millisecondsSinceEpoch}_${player.name.hashCode}';
          playerScores[tempId] = PlayerScorecard(
            userId: tempId,
            playerName: player.name,
            holeScores: {},
          );
        }
      }

      // Create the new scorecard
      final scorecard = ScorecardModel(
        id: '', // Will be set by Firestore
        bookingId: booking.id,
        userId: userId,
        playDate: booking.startTime,
        playerScores: playerScores,
        courseName: courseData.name,
        coursePar: courseData.par,
        courseRating: courseData.courseRating,
        slopeRating: courseData.slopeRating,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('scorecards')
          .add(scorecard.toFirestore());

      // Return with the generated ID
      return ScorecardModel(
        id: docRef.id,
        bookingId: scorecard.bookingId,
        userId: scorecard.userId,
        playDate: scorecard.playDate,
        playerScores: scorecard.playerScores,
        courseName: scorecard.courseName,
        coursePar: scorecard.coursePar,
        courseRating: scorecard.courseRating,
        slopeRating: scorecard.slopeRating,
      );
    } catch (e) {
      print('Error creating or getting scorecard: $e');
      throw Exception('Error loading scorecard: $e');
    }
  }

  // Get scorecard by ID
  Future<ScorecardModel?> getScorecardById(String scorecardId) async {
    try {
      final docSnapshot =
          await _firestore.collection('scorecards').doc(scorecardId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      return ScorecardModel.fromFirestore(docSnapshot);
    } catch (e) {
      print('Error getting scorecard: $e');
      return null;
    }
  }

  // Get scorecard by booking ID
  Future<ScorecardModel?> getScorecardByBookingId(String bookingId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('scorecards')
              .where('bookingId', isEqualTo: bookingId)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return ScorecardModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      print('Error getting scorecard by booking ID: $e');
      return null;
    }
  }

  // Update a player's hole scores
  Future<bool> updatePlayerScore(
    String scorecardId,
    String playerId,
    Map<String, int> holeScores,
  ) async {
    try {
      // Get current scorecard
      final scorecardRef = _firestore.collection('scorecards').doc(scorecardId);
      final scorecard = await scorecardRef.get();

      if (!scorecard.exists) {
        return false;
      }

      // Update the specific player's scores
      final data = scorecard.data() as Map<String, dynamic>;
      final playerScores = data['playerScores'] as Map<String, dynamic>? ?? {};

      // Get existing player data or create new
      Map<String, dynamic> playerData =
          playerScores[playerId] as Map<String, dynamic>? ?? {};
      Map<String, dynamic> existingHoleScores =
          playerData['holeScores'] as Map<String, dynamic>? ?? {};

      // Merge new scores with existing scores
      for (var entry in holeScores.entries) {
        existingHoleScores[entry.key] = entry.value;
      }

      // Update player data
      playerData['holeScores'] = existingHoleScores;
      playerScores[playerId] = playerData;

      // Update Firestore document
      await scorecardRef.update({'playerScores': playerScores});

      return true;
    } catch (e) {
      print('Error updating player score: $e');
      return false;
    }
  }

  // Complete a scorecard and calculate handicap data
  Future<bool> completeScorecard(String scorecardId) async {
    try {
      final scorecardRef = _firestore.collection('scorecards').doc(scorecardId);
      final scorecardDoc = await scorecardRef.get();

      if (!scorecardDoc.exists) {
        return false;
      }

      // Get the scorecard data
      final scorecard = ScorecardModel.fromFirestore(scorecardDoc);
      final courseData = await _getCourseData();

      // Calculate adjusted gross scores and score differentials for each player
      Map<String, PlayerScorecard> updatedPlayerScores = {};

      for (var entry in scorecard.playerScores.entries) {
        final String playerId = entry.key;
        final PlayerScorecard playerCard = entry.value;

        // Skip if player has no scores or is missing too many holes
        if (playerCard.holeScores.isEmpty || playerCard.holeScores.length < 9) {
          updatedPlayerScores[playerId] = playerCard;
          continue;
        }

        // Get player's handicap index
        double? handicapIndex = playerCard.handicapIndex;
        handicapIndex ??= await _getPlayerHandicapIndex(playerId);

        // Calculate course handicap if we have handicap index and slope rating
        int? courseHandicap;
        if (handicapIndex != null && scorecard.slopeRating != null) {
          courseHandicap = _calculateCourseHandicap(
            handicapIndex,
            scorecard.slopeRating!,
            scorecard.courseRating!,
            scorecard.coursePar,
          );
        } // Calculate adjusted gross score
        final adjustedGrossScore = _calculateAdjustedGrossScore(
          playerCard.holeScores,
          courseData.holePars,
          courseData.holeIndexes,
          courseHandicap,
        );

        // Calculate score differential if we have all required values
        double? scoreDifferential;
        if (adjustedGrossScore != null &&
            scorecard.slopeRating != null &&
            scorecard.courseRating != null) {
          // The score differential calculation will handle 9-hole vs 18-hole rounds
          // based on the adjusted gross score value
          scoreDifferential = _calculateScoreDifferential(
            adjustedGrossScore,
            scorecard.courseRating!,
            scorecard.slopeRating!,
            scorecard.coursePar,
            scorecard.pcc ?? 0,
          );
        }

        // Create updated player scorecard
        updatedPlayerScores[playerId] = PlayerScorecard(
          userId: playerCard.userId,
          playerName: playerCard.playerName,
          holeScores: playerCard.holeScores,
          handicapIndex: handicapIndex,
          courseHandicap: courseHandicap,
          adjustedGrossScore: adjustedGrossScore,
          scoreDifferential: scoreDifferential,
        );

        // If player has a valid score differential, store it in their handicap record
        if (scoreDifferential != null &&
            playerCard.userId.startsWith('guest_') == false) {
          await _storeScoreDifferential(
            playerCard.userId,
            scoreDifferential,
            scorecard.id,
            scorecard.playDate,
            scorecard.courseName ?? 'Unknown Course',
          );
        }
      }

      // Update the scorecard with calculated values
      await scorecardRef.update({
        'playerScores': updatedPlayerScores.map(
          (userId, card) => MapEntry(userId, card.toMap()),
        ),
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error completing scorecard: $e');
      return false;
    }
  }

  // Get a player's handicap index
  Future<double?> _getPlayerHandicapIndex(String userId) async {
    try {
      if (userId.startsWith('guest_')) {
        return null; // Guests don't have handicap indexes
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data();
      if (userData == null) return null;

      // Check in golfDetails first, then fall back to root level
      if (userData['golfDetails'] != null) {
        return (userData['golfDetails']['handicap'] as num?)?.toDouble();
      } else {
        return (userData['handicap'] as num?)?.toDouble();
      }
    } catch (e) {
      print('Error getting player handicap: $e');
      return null;
    }
  }

  // Store a player's score differential in their handicap record
  Future<void> _storeScoreDifferential(
    String userId,
    double scoreDifferential,
    String scorecardId,
    DateTime playDate,
    String courseName,
  ) async {
    try {
      // Get the player's handicap record or create if it doesn't exist
      final querySnapshot =
          await _firestore
              .collection('handicapRecords')
              .where('userId', isEqualTo: userId)
              .get();

      DocumentReference recordRef;
      List<ScoreDifferential> differentials = [];

      if (querySnapshot.docs.isEmpty) {
        // Create new record
        recordRef = _firestore.collection('handicapRecords').doc();
      } else {
        // Use existing record
        recordRef = querySnapshot.docs.first.reference;
        final record = HandicapRecord.fromFirestore(querySnapshot.docs.first);
        differentials = record.scoreDifferentials;
      }

      // Add the new score differential
      differentials.add(
        ScoreDifferential(
          scorecardId: scorecardId,
          playDate: playDate,
          value: scoreDifferential,
          courseName: courseName,
        ),
      );

      // Sort by date (newest first)
      differentials.sort((a, b) => b.playDate.compareTo(a.playDate));

      // Keep only the 20 most recent
      if (differentials.length > 20) {
        differentials = differentials.sublist(0, 20);
      }

      // Calculate new handicap index
      double? handicapIndex = _calculateHandicapIndex(differentials);

      // Update the handicap record
      await recordRef.set({
        'userId': userId,
        'scoreDifferentials': differentials.map((sd) => sd.toMap()).toList(),
        'handicapIndex': handicapIndex,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error storing score differential: $e');
    }
  }

  // Calculate adjusted gross score (Net Double Bogey cap on each hole)
  int? _calculateAdjustedGrossScore(
    Map<String, int> holeScores,
    List<int> holePars,
    List<int> holeIndexes,
    int? courseHandicap,
  ) {
    // If we don't have course handicap, just sum the scores
    if (courseHandicap == null) {
      return holeScores.values.fold<int>(0, (sum, score) => sum + score);
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
        final adjustedScore = score > maxScore ? maxScore : score;
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

    // For 9-hole rounds in the official WHS, certain adjustments are made for handicap calculation
    // This will be handled in the _calculateScoreDifferential method

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
      // Assuming the provided courseRating and coursePar are for the full 18 holes
      courseRating = courseRating / 2;
      coursePar = coursePar ~/ 2;
    }

    double sd =
        (113 / slopeRating) * (adjustedGrossScore - courseRating - pcc) +
        (courseRating - coursePar);

    // Round to 1 decimal place
    return (sd * 10).round() / 10;
  }

  // Calculate course handicap
  int _calculateCourseHandicap(
    double handicapIndex,
    double slopeRating,
    double courseRating,
    int coursePar,
  ) {
    double ch =
        (handicapIndex * slopeRating / 113) + (courseRating - coursePar);
    // Round to nearest integer
    return ch.round();
  }

  // Calculate handicap index from score differentials using WHS rules
  double? _calculateHandicapIndex(List<ScoreDifferential> differentials) {
    int count = differentials.length;

    // Need at least 3 rounds to calculate handicap
    if (count < 3) {
      return null;
    }

    // Sort differentials (lowest to highest)
    List<double> sortedDiffs =
        differentials.map((sd) => sd.value).toList()..sort();

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
    return (average * 10).round() / 10;
  }

  // Get course data (use default if not found)
  Future<CourseData> _getCourseData() async {
    try {
      final querySnapshot =
          await _firestore.collection('courses').limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        return CourseData.fromFirestore(querySnapshot.docs.first);
      }
    } catch (e) {
      print('Error getting course data: $e');
    }

    // Return default course if no data found
    return _defaultCourse;
  }

  // Monthly handicap recalculation job (to be called by Cloud Function)
  Future<void> recalculateAllHandicaps() async {
    try {
      // Get all handicap records
      final recordsSnapshot =
          await _firestore.collection('handicapRecords').get();

      for (var doc in recordsSnapshot.docs) {
        final record = HandicapRecord.fromFirestore(doc);

        // Only recalculate if player has enough rounds
        if (record.scoreDifferentials.length >= 3) {
          double? newHandicapIndex = _calculateHandicapIndex(
            record.scoreDifferentials,
          );

          // Update handicap record with the new handicap index
          await doc.reference.update({
            'handicapIndex': newHandicapIndex,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Update user record with the handicap index (not course handicap)
          if (newHandicapIndex != null) {
            await _firestore.collection('users').doc(record.userId).update({
              'golfDetails.handicap':
                  newHandicapIndex, // This is the player's handicap index
            });
          }
        }
      }
    } catch (e) {
      print('Error in handicap recalculation job: $e');
    }
  }

  // Get all scorecards for a specific user
  Future<List<ScorecardModel>> getUserScorecards() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final querySnapshot =
          await _firestore
              .collection('scorecards')
              .where('playerScores.$userId', isNull: false)
              .orderBy('playDate', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => ScorecardModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting user scorecards: $e');
      return [];
    }
  }

  // Debug method for testing - creates a scorecard in memory without Firestore
  Future<ScorecardModel> createDebugScorecard(BookingModel booking) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated for debug scorecard');
      }

      // Create player scorecards map
      Map<String, PlayerScorecard> playerScores = {};

      for (PlayerInfo player in booking.players) {
        final playerId = player.userId ?? 'guest_${player.name.hashCode}';
        playerScores[playerId] = PlayerScorecard(
          userId: playerId,
          playerName: player.name,
          holeScores: {
            "1": 4, "2": 5, "3": 3, // Sample scores for debugging
          },
        );
      }

      // Create test scorecard
      return ScorecardModel(
        id: 'debug-${DateTime.now().millisecondsSinceEpoch}',
        bookingId: booking.id,
        userId: userId,
        playDate: booking.startTime,
        playerScores: playerScores,
        courseName: 'Debug Golf Course',
        coursePar: 72,
        courseRating: 72.0,
        slopeRating: 113.0,
      );
    } catch (e) {
      print('Error creating debug scorecard: $e');
      rethrow;
    }
  }
}
