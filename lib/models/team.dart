import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String? teamID;
  final String teamName;
  final String teamPassword;
  final String eventID;
  final List<String> players;

  Team({
    this.teamID,
    required this.teamName,
    required this.teamPassword,
    required this.eventID,
    this.players = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'teamID': teamID,
      'teamName': teamName,
      'teamPassword': teamPassword,
      'eventID': eventID,
      'players': players,
    };
  }

  factory Team.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Team(
      teamID: doc.id,
      teamName: data['teamName'] ?? '',
      teamPassword: data['teamPassword'] ?? '',
      eventID: data['eventID'] ?? '',
      players: List<String>.from(data['players'] ?? []),
    );
  }
}
