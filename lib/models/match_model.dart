import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String? matchID;
  final String eventID;
  final List<String> teams;
  final Map<String, List<String>> players;
  final String matchType;
  final String matchPlayType; // New field for match play or greensome
  final DateTime matchDateTime;
  final Map<String, dynamic> holeResults; // Changed from List to Map
  final String matchStatus;
  final bool bonusPoint; // New field for bonus point
  final List<String> participantUids; // Flattened list of all player uids
  final bool matchOver;
  final num regularPoints;
  final num bonusPoints;

  Match({
    this.matchID,
    required this.eventID,
    required this.teams,
    required this.players,
    required this.matchType,
    this.matchPlayType = 'match play', // Default to 'match play'
    required this.matchDateTime,
    this.holeResults = const {}, // Default to empty map
    this.matchStatus = 'active',
    this.bonusPoint = false, // Default to false
    this.participantUids = const [],
    this.matchOver = false,
    this.regularPoints = 0,
    this.bonusPoints = 0,
  });

  Map<String, dynamic> toMap() {
    // Create a safe map with no null values
    final Map<String, dynamic> map = {
      'teams': teams,
      'players': players,
      'matchType': matchType,
      'matchPlayType': matchPlayType, // Include the new field
      'matchDateTime': Timestamp.fromDate(matchDateTime),
      'holeResults': holeResults, // Now a map
      'matchStatus': matchStatus,
      'bonusPoint': bonusPoint, // Include the new field
      'participantUids': participantUids,
      'matchOver': matchOver,
      'regularPoints': regularPoints,
      'bonusPoints': bonusPoints,
    };

    // Add matchID if it exists
    if (matchID != null) {
      map['matchID'] = matchID;
    }

    return map;
  }

  factory Match.fromMap(Map<String, dynamic> map, String id, String eventId) {
    return Match(
      matchID: id,
      eventID: eventId,
      teams: List<String>.from(map['teams'] ?? []),
      players: Map<String, List<String>>.from(
        (map['players'] ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value ?? [])),
        ),
      ),
      matchType: map['matchType'] ?? '4-ball',
      matchPlayType:
          map['matchPlayType'] ?? 'match play', // Extract the new field
      matchDateTime: (map['matchDateTime'] as Timestamp).toDate(),
      holeResults: Map<String, dynamic>.from(map['holeResults'] ?? {}),
      matchStatus: map['matchStatus'] ?? 'active',
      bonusPoint: map['bonusPoint'] ?? false, // Extract the new field
      participantUids: List<String>.from(map['participantUids'] ?? []),
      matchOver: map['matchOver'] ?? false,
      regularPoints: map['regularPoints'] ?? 0,
      bonusPoints: map['bonusPoints'] ?? 0,
    );
  }
}
