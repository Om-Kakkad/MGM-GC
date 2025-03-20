import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get League events for dropdown
  Future<List<Map<String, dynamic>>> getLeagueEvents() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('events')
              .where('eventType', isEqualTo: 'League')
              .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting league events: $e');
      rethrow;
    }
  }

  // Get teams by event ID
  Future<List<Map<String, dynamic>>> getTeamsByEvent(String eventId) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('teams')
              .where('eventID', isEqualTo: eventId)
              .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting teams by event: $e');
      rethrow;
    }
  }

  // Get players by team ID
  Future<List<Map<String, dynamic>>> getPlayersByTeam(String teamId) async {
    try {
      DocumentSnapshot teamDoc =
          await _firestore.collection('teams').doc(teamId).get();

      if (!teamDoc.exists) {
        throw Exception('Team not found');
      }

      Map<String, dynamic> teamData = teamDoc.data() as Map<String, dynamic>;
      List<String> playerIds = List<String>.from(teamData['players'] ?? []);

      if (playerIds.isEmpty) {
        return [];
      }

      // Fetch player details from users collection
      List<Map<String, dynamic>> players = [];

      for (String playerId in playerIds) {
        DocumentSnapshot playerDoc =
            await _firestore.collection('users').doc(playerId).get();
        if (playerDoc.exists) {
          Map<String, dynamic> playerData =
              playerDoc.data() as Map<String, dynamic>;
          playerData['id'] = playerDoc.id;
          players.add(playerData);
        }
      }

      return players;
    } catch (e) {
      print('Error getting players by team: $e');
      rethrow;
    }
  }

  // Create a new match
  Future<String> createMatch(Match match) async {
    try {
      print('Creating match in Firestore...');

      // CRITICAL: Convert all complex objects to simple serializable types
      // This avoids any unexpected Firebase serialization issues
      final Map<String, dynamic> safeMap = {
        'eventID': match.eventID,
        'teams': List<String>.from(match.teams),
        'players': Map<String, dynamic>.from(
          match.players.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ),
        ),
        'matchType': match.matchType,
        'matchDateTime': Timestamp.fromDate(match.matchDateTime),
        'holeResults': [], // Always use empty array, not null
        'matchStatus': match.matchStatus,
      };

      // Add matchID if it exists
      if (match.matchID != null) {
        safeMap['matchID'] = match.matchID;
      }

      // Log the map we're about to send to Firestore
      print('Safe map to be added to Firestore:');
      safeMap.forEach((key, value) {
        print('$key: ${value?.toString() ?? "null"} (${value?.runtimeType})');
      });

      // Add document to Firestore with extremely defensive code
      print('Adding document to Firestore...');
      DocumentReference? docRef;
      try {
        docRef = await _firestore.collection('fourBalls').add(safeMap);
        print('Match added with generated ID: ${docRef.id}');

        // Return early with ID to avoid any issues with the update
        String matchId = docRef.id;

        // Try to update matchID but don't require it for success
        try {
          await docRef.update({'matchID': matchId});
          print('Match updated with matchID: $matchId');
        } catch (updateError) {
          // Just log the error but don't fail the overall operation
          print(
            'Warning: Failed to update matchID but document was created: $updateError',
          );
        }

        return matchId;
      } catch (e) {
        print('Error in initial document creation: $e');
        throw Exception('Failed to create initial document: $e');
      }
    } catch (e) {
      print('Error creating match: $e');
      print('Error stack trace: ${StackTrace.current}');
      rethrow;
    }
  }
}
