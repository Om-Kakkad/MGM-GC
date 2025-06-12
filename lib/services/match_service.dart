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

  // Get teams by event ID from the nested collection
  Future<List<Map<String, dynamic>>> getTeamsByEvent(String eventId) async {
    try {
      print('Fetching teams for event ID: $eventId');

      // Query teams subcollection in the event
      final QuerySnapshot snapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .get();

      print('Found ${snapshot.docs.length} teams for event $eventId');

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'teamName': data['teamName'] ?? data['name'] ?? 'Unnamed Team',
        };
      }).toList();
    } catch (e) {
      print('Error getting teams by event: $e');
      return [];
    }
  }

  // Get players by team ID - updated for nested collections
  Future<List<Map<String, dynamic>>> getPlayersByTeam(
    String eventId,
    String teamId,
  ) async {
    try {
      DocumentSnapshot teamDoc =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(teamId)
              .get();

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
        'teams': List<String>.from(match.teams),
        'players': Map<String, dynamic>.from(
          match.players.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ),
        ),
        'matchType': match.matchType,
        'matchPlayType': match.matchPlayType, // Add the new field
        'matchDateTime': Timestamp.fromDate(match.matchDateTime),
        'matchStatus': match.matchStatus,
        // Convert holeResults from array to map
        'holeResults': {}, // Initialize empty map
        'bonusPoint': match.bonusPoint, // Add the bonusPoint field
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
        docRef = await _firestore
            .collection('events')
            .doc(match.eventID)
            .collection('matches')
            .add(safeMap);

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

        // Update teams and players with the matchId
        await _updateTeamsWithMatch(match.eventID, match.teams, matchId);
        await _updatePlayersWithMatch(match.eventID, match.players, matchId);

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

  // Update hole results with a map-based structure
  Future<void> updateHoleResult(
    String eventId,
    String matchId,
    int holeNumber,
    Map<String, dynamic> holeData,
  ) async {
    try {
      // Create hole key (e.g., "hole_1", "hole_2")
      String holeKey = 'hole_$holeNumber';

      // Update match document with new hole result
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('matches')
          .doc(matchId)
          .update({'holeResults.$holeKey': holeData});

      print('Updated hole result for hole $holeNumber');
    } catch (e) {
      print('Error updating hole result: $e');
      rethrow;
    }
  }

  // Update team documents with matchId
  Future<void> _updateTeamsWithMatch(
    String eventId,
    List<String> teamIds,
    String matchId,
  ) async {
    try {
      for (String teamId in teamIds) {
        DocumentReference teamRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .doc(teamId);
        DocumentSnapshot teamDoc = await teamRef.get();

        if (teamDoc.exists) {
          // Get current matches array or create a new one
          List<String> matches = [];
          if (teamDoc.data() != null) {
            Map<String, dynamic> data = teamDoc.data() as Map<String, dynamic>;
            if (data.containsKey('matches') && data['matches'] is List) {
              matches = List<String>.from(data['matches']);
            }
          }

          // Add matchId if it doesn't exist already
          if (!matches.contains(matchId)) {
            matches.add(matchId);
            await teamRef.update({'matches': matches});
            print('Updated team $teamId with match $matchId');
          }
        } else {
          print('Team $teamId not found, cannot update with match');
        }
      }
    } catch (e) {
      print('Error updating teams with match: $e');
      // Don't throw, just log the error to avoid breaking match creation
    }
  }

  // Update player documents with matchId
  Future<void> _updatePlayersWithMatch(
    String eventId,
    Map<String, List<String>> players,
    String matchId,
  ) async {
    try {
      // Process all players from all teams
      List<String> allPlayerIds = [];
      players.forEach((_, playerList) {
        allPlayerIds.addAll(playerList);
      });

      for (String playerId in allPlayerIds) {
        DocumentReference playerRef = _firestore
            .collection('users')
            .doc(playerId);
        DocumentSnapshot playerDoc = await playerRef.get();

        if (playerDoc.exists) {
          // Get current matches array or create a new one
          List<String> matches = [];
          if (playerDoc.data() != null) {
            Map<String, dynamic> data =
                playerDoc.data() as Map<String, dynamic>;
            if (data.containsKey('matches') && data['matches'] is List) {
              matches = List<String>.from(data['matches']);
            }
          }

          // Add matchId if it doesn't exist already
          if (!matches.contains(matchId)) {
            matches.add(matchId);
            await playerRef.update({
              'matches': matches,
              'golfDetails.eventId': eventId, // Store event ID in user document
            });
            print('Updated player $playerId with match $matchId');
          }
        } else {
          print('Player $playerId not found, cannot update with match');
        }
      }
    } catch (e) {
      print('Error updating players with match: $e');
      // Don't throw, just log the error to avoid breaking match creation
    }
  }

  // Get match by ID
  Future<Map<String, dynamic>?> getMatchById(
    String eventId,
    String matchId,
  ) async {
    try {
      DocumentSnapshot matchDoc =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .doc(matchId)
              .get();

      if (!matchDoc.exists) {
        return null;
      }

      Map<String, dynamic> matchData = matchDoc.data() as Map<String, dynamic>;
      matchData['id'] = matchDoc.id;

      return matchData;
    } catch (e) {
      print('Error getting match: $e');
      return null;
    }
  }

  // Get all matches for an event
  Future<List<Map<String, dynamic>>> getMatchesByEventId(String eventId) async {
    try {
      print('Fetching matches for event ID: $eventId');

      final QuerySnapshot snapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .orderBy('matchDateTime', descending: true)
              .get();

      print('Found ${snapshot.docs.length} matches for event $eventId');

      List<Map<String, dynamic>> matches = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> match = doc.data() as Map<String, dynamic>;
        match['id'] = doc.id;
        match['eventId'] = eventId;
        matches.add(match);
      }

      return matches;
    } catch (e) {
      print('Error getting matches for event: $e');
      return [];
    }
  }
}
