import 'package:cloud_firestore/cloud_firestore.dart';

abstract class Event {
  final String id;
  final String eventName;
  final String eventDescription;
  final String eventType;
  final List<DateTime> eventDates;

  Event({
    required this.id,
    required this.eventName,
    required this.eventDescription,
    required this.eventType,
    required this.eventDates,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<DateTime> dates = [];
    if (data['eventDates'] != null) {
      dates =
          (data['eventDates'] as List)
              .map((date) => (date as Timestamp).toDate())
              .toList();
    }

    if (data['eventType'] == 'League') {
      return LeagueEvent(
        id: doc.id,
        eventName: data['eventName'] ?? '',
        eventDescription: data['eventDescription'] ?? '',
        eventType: data['eventType'] ?? '',
        eventDates: dates,
        scoringType: data['scoringType'] ?? '',
      );
    } else {
      return TournamentEvent(
        id: doc.id,
        eventName: data['eventName'] ?? '',
        eventDescription: data['eventDescription'] ?? '',
        eventType: data['eventType'] ?? '',
        eventDates: dates,
        tournamentFormat: data['tournamentFormat'] ?? '',
        bracketType: data['bracketType'] ?? '',
        prizeDetails: data['prizeDetails'] ?? '',
        customRules: data['customRules'] ?? '',
      );
    }
  }
}

class LeagueEvent extends Event {
  final String scoringType;

  LeagueEvent({
    required super.id,
    required super.eventName,
    required super.eventDescription,
    required super.eventType,
    required super.eventDates,
    required this.scoringType,
  });
}

class TournamentEvent extends Event {
  final String tournamentFormat;
  final String bracketType;
  final String prizeDetails;
  final String customRules;

  TournamentEvent({
    required super.id,
    required super.eventName,
    required super.eventDescription,
    required super.eventType,
    required super.eventDates,
    required this.tournamentFormat,
    required this.bracketType,
    required this.prizeDetails,
    required this.customRules,
  });
}
