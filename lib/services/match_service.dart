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

  // Get teams by event ID - Fix this method to properly query teams
  Future<List<Map<String, dynamic>>> getTeamsByEvent(String eventId) async {
    try {
      print('Fetching teams for event ID: $eventId');

      // Query teams where eventId field matches the provided event ID
      final QuerySnapshot snapshot =
          await _firestore
              .collection('teams')
              .where('eventId', isEqualTo: eventId)
              .get();

      print('Found ${snapshot.docs.length} teams for event $eventId');

      // If no teams are found with the eventId field, try querying all teams
      // This is a fallback measure in case teams were created without eventId
      if (snapshot.docs.isEmpty) {
        print(
          'No teams found with eventId field, fetching all teams as fallback',
        );
        final QuerySnapshot allTeamsSnapshot =
            await _firestore.collection('teams').get();

        return allTeamsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'teamName': data['teamName'] ?? data['name'] ?? 'Unnamed Team',
          };
        }).toList();
      }

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

        // Update teams and players with the matchId
        await _updateTeamsWithMatch(match.teams, matchId);
        await _updatePlayersWithMatch(match.players, matchId);

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

  // Update team documents with matchId
  Future<void> _updateTeamsWithMatch(
    List<String> teamIds,
    String matchId,
  ) async {
    try {
      for (String teamId in teamIds) {
        DocumentReference teamRef = _firestore.collection('teams').doc(teamId);
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
            await playerRef.update({'matches': matches});
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
}
