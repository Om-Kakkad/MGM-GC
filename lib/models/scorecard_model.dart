import 'package:cloud_firestore/cloud_firestore.dart';

class ScorecardModel {
  final String id;
  final String bookingId;
  final String userId;
  final DateTime playDate;
  final Map<String, PlayerScorecard> playerScores;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? courseName;
  final int coursePar;
  final double? courseRating;
  final double? slopeRating;
  final int? pcc; // Playing Condition Calculation (-1 to +3)

  ScorecardModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.playDate,
    required this.playerScores,
    this.isCompleted = false,
    this.completedAt,
    this.courseName,
    required this.coursePar,
    this.courseRating,
    this.slopeRating,
    this.pcc,
  });

  factory ScorecardModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Convert player scores map
    Map<String, PlayerScorecard> playersScoreMap = {};
    if (data['playerScores'] != null) {
      Map<String, dynamic> scoreData = Map<String, dynamic>.from(
        data['playerScores'],
      );
      scoreData.forEach((userId, scoreData) {
        playersScoreMap[userId] = PlayerScorecard.fromMap(
          Map<String, dynamic>.from(scoreData),
        );
      });
    }

    return ScorecardModel(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      userId: data['userId'] ?? '',
      playDate: (data['playDate'] as Timestamp).toDate(),
      playerScores: playersScoreMap,
      isCompleted: data['isCompleted'] ?? false,
      completedAt:
          data['completedAt'] != null
              ? (data['completedAt'] as Timestamp).toDate()
              : null,
      courseName: data['courseName'],
      coursePar: data['coursePar'] ?? 69,
      courseRating: data['courseRating'],
      slopeRating: data['slopeRating'],
      pcc: data['pcc'],
    );
  }

  Map<String, dynamic> toFirestore() {
    // Convert PlayerScorecard objects to map for Firestore
    Map<String, Map<String, dynamic>> playersScoreMap = {};
    playerScores.forEach((userId, scorecard) {
      playersScoreMap[userId] = scorecard.toMap();
    });

    return {
      'bookingId': bookingId,
      'userId': userId,
      'playDate': Timestamp.fromDate(playDate),
      'playerScores': playersScoreMap,
      'isCompleted': isCompleted,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'courseName': courseName,
      'coursePar': coursePar,
      'courseRating': courseRating,
      'slopeRating': slopeRating,
      'pcc': pcc,
    };
  }
}

class PlayerScorecard {
  final String userId;
  final String playerName;
  final Map<String, int> holeScores; // hole number as string -> score
  final double? handicapIndex;
  final int? courseHandicap;
  final int? adjustedGrossScore;
  final double? scoreDifferential;

  PlayerScorecard({
    required this.userId,
    required this.playerName,
    required this.holeScores,
    this.handicapIndex,
    this.courseHandicap,
    this.adjustedGrossScore,
    this.scoreDifferential,
  });

  factory PlayerScorecard.fromMap(Map<String, dynamic> map) {
    Map<String, int> scores = {};
    if (map['holeScores'] != null) {
      Map<String, dynamic> holeData = Map<String, dynamic>.from(
        map['holeScores'],
      );
      holeData.forEach((holeNum, score) {
        scores[holeNum] = score as int;
      });
    }

    return PlayerScorecard(
      userId: map['userId'] ?? '',
      playerName: map['playerName'] ?? '',
      holeScores: scores,
      handicapIndex: map['handicapIndex'],
      courseHandicap: map['courseHandicap'],
      adjustedGrossScore: map['adjustedGrossScore'],
      scoreDifferential: map['scoreDifferential'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'playerName': playerName,
      'holeScores': holeScores,
      'handicapIndex': handicapIndex,
      'courseHandicap': courseHandicap,
      'adjustedGrossScore': adjustedGrossScore,
      'scoreDifferential': scoreDifferential,
    };
  }

  // Calculate total gross score
  int get totalScore {
    return holeScores.values.fold(0, (sum, score) => sum + score);
  }

  // Check if this is a 9-hole round
  bool get isNineHoleRound {
    // We consider it a 9-hole round if:
    // - Between 7 and 13 holes have been played
    // - Or if exactly 9 holes are recorded with numbers 1-9 (front nine) or 10-18 (back nine)

    int holesPlayed = holeScores.length;

    if (holesPlayed < 7) {
      return false; // Not enough holes for valid score
    }

    if (holesPlayed < 14) {
      return true; // Between 7 and 13 holes = 9-hole round
    }

    // Additional logic could check if all holes are front nine or back nine

    return false; // 14 or more holes = 18-hole round
  }
}

// This class represents a player's stored score differential history
class HandicapRecord {
  final String id;
  final String userId;
  final List<ScoreDifferential> scoreDifferentials;
  final double? handicapIndex;
  final DateTime lastUpdated;

  HandicapRecord({
    required this.id,
    required this.userId,
    required this.scoreDifferentials,
    this.handicapIndex,
    required this.lastUpdated,
  });

  factory HandicapRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<ScoreDifferential> differentials = [];
    if (data['scoreDifferentials'] != null) {
      List<dynamic> diffList = data['scoreDifferentials'] as List<dynamic>;
      differentials =
          diffList
              .map(
                (item) =>
                    ScoreDifferential.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList();
    }

    return HandicapRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      scoreDifferentials: differentials,
      handicapIndex: data['handicapIndex'],
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'scoreDifferentials': scoreDifferentials.map((sd) => sd.toMap()).toList(),
      'handicapIndex': handicapIndex,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class ScoreDifferential {
  final String scorecardId;
  final DateTime playDate;
  final double value;
  final String courseName;

  ScoreDifferential({
    required this.scorecardId,
    required this.playDate,
    required this.value,
    required this.courseName,
  });

  factory ScoreDifferential.fromMap(Map<String, dynamic> map) {
    return ScoreDifferential(
      scorecardId: map['scorecardId'] ?? '',
      playDate: (map['playDate'] as Timestamp).toDate(),
      value: map['value'] ?? 0.0,
      courseName: map['courseName'] ?? 'Unknown Course',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scorecardId': scorecardId,
      'playDate': Timestamp.fromDate(playDate),
      'value': value,
      'courseName': courseName,
    };
  }
}

class CourseData {
  final String id;
  final String name;
  final int par;
  final double courseRating;
  final double slopeRating;
  final List<int> holePars;
  final List<int> holeIndexes; // Stroke index for each hole

  CourseData({
    required this.id,
    required this.name,
    required this.par,
    required this.courseRating,
    required this.slopeRating,
    required this.holePars,
    required this.holeIndexes,
  });

  factory CourseData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return CourseData(
      id: doc.id,
      name: data['name'] ?? '',
      par: data['par'] ?? 72,
      courseRating: data['courseRating'] ?? 72.0,
      slopeRating: data['slopeRating'] ?? 113.0,
      holePars: List<int>.from(data['holePars'] ?? List.filled(18, 4)),
      holeIndexes: List<int>.from(
        data['holeIndexes'] ?? List.generate(18, (i) => i + 1),
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'par': par,
      'courseRating': courseRating,
      'slopeRating': slopeRating,
      'holePars': holePars,
      'holeIndexes': holeIndexes,
    };
  }
}
