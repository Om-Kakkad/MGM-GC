import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String? matchID;
  final String eventID;
  final List<String> teams;
  final Map<String, List<String>> players;
  final String matchType;
  final DateTime matchDateTime;
  final List<Map<String, dynamic>> holeResults;
  final String matchStatus;

  Match({
    this.matchID,
    required this.eventID,
    required this.teams,
    required this.players,
    required this.matchType,
    required this.matchDateTime,
    this.holeResults = const [], // Default to empty list
    this.matchStatus = 'active',
  });

  Map<String, dynamic> toMap() {
    // Create a safe map with no null values
    final Map<String, dynamic> map = {
      'eventID': eventID,
      'teams': teams,
      'players': players,
      'matchType': matchType,
      'matchDateTime': Timestamp.fromDate(matchDateTime),
      'holeResults': holeResults ?? [], // Ensure this is never null
      'matchStatus': matchStatus,
    };

    // Add matchID if it exists
    if (matchID != null) {
      map['matchID'] = matchID;
    }

    return map;
  }

  factory Match.fromMap(Map<String, dynamic> map, String id) {
    return Match(
      matchID: id,
      eventID: map['eventID'] ?? '',
      teams: List<String>.from(map['teams'] ?? []),
      players: Map<String, List<String>>.from(
        (map['players'] ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value ?? [])),
        ),
      ),
      matchType: map['matchType'] ?? '4-ball',
      matchDateTime: (map['matchDateTime'] as Timestamp).toDate(),
      holeResults: List<Map<String, dynamic>>.from(map['holeResults'] ?? []),
      matchStatus: map['matchStatus'] ?? 'active',
    );
  }
}
