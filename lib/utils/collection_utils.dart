import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class CollectionUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Find which event a team belongs to
  static Future<String?> findEventIdForTeam(String teamId) async {
    final eventsQuery = await _firestore.collection('events').get();

    for (var eventDoc in eventsQuery.docs) {
      final teamDoc =
          await _firestore
              .collection('events')
              .doc(eventDoc.id)
              .collection('teams')
              .doc(teamId)
              .get();

      if (teamDoc.exists) {
        return eventDoc.id;
      }
    }

    return null;
  }

  /// Find which event a match belongs to
  static Future<String?> findEventIdForMatch(String matchId) async {
    final eventsQuery = await _firestore.collection('events').get();

    for (var eventDoc in eventsQuery.docs) {
      final matchDoc =
          await _firestore
              .collection('events')
              .doc(eventDoc.id)
              .collection('matches')
              .doc(matchId)
              .get();

      if (matchDoc.exists) {
        return eventDoc.id;
      }
    }

    return null;
  }

  /// Create a match in the correct subcollection
  static Future<DocumentReference> createMatchInEvent(
    String eventId,
    Match match,
  ) async {
    return await _firestore
        .collection('events')
        .doc(eventId)
        .collection('matches')
        .add(match.toMap());
  }
}
