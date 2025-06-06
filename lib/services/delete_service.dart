import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Delete a match and cascade
  Future<void> deleteMatchWithCascade(String eventId, String matchId) async {
    try {
      // Get the match document first to get its data
      final matchDoc =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .doc(matchId)
              .get();
      if (!matchDoc.exists) {
        throw Exception('Match not found');
      }

      final matchData = matchDoc.data()!;

      // FIX: Proper type conversion using .map()
      final List<dynamic> teamsDynamic = matchData['teams'] ?? [];
      final List<String> teamIds =
          teamsDynamic.map((id) => id.toString()).toList();

      // Start a batch operation for better transaction handling
      final batch = _firestore.batch();

      // 1. Remove match references from users
      // Get all users who participated in this match
      final Map<String, dynamic> playersRaw = matchData['players'] ?? {};
      final Map<String, List<String>> players = {};

      // Properly convert nested player lists
      playersRaw.forEach((teamKey, playerList) {
        if (playerList is List) {
          players[teamKey] =
              playerList.map((player) => player.toString()).toList();
        }
      });

      // Flatten the list of player IDs
      final List<String> allPlayerIds = [];
      players.forEach((_, playerList) {
        allPlayerIds.addAll(playerList);
      });

      // For each player, remove the match reference
      for (final playerId in allPlayerIds) {
        final userRef = _firestore.collection('users').doc(playerId);
        final userDoc = await userRef.get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final List<dynamic> userMatchesDynamic = userData['matches'] ?? [];
          final List<String> userMatches =
              userMatchesDynamic.map((m) => m.toString()).toList();

          if (userMatches.contains(matchId)) {
            userMatches.remove(matchId);
            batch.update(userRef, {'matches': userMatches});
          }
        }
      }

      // 2. Remove match references from teams
      for (final teamId in teamIds) {
        final teamRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .doc(teamId);
        final teamDoc = await teamRef.get();

        if (teamDoc.exists) {
          final teamData = teamDoc.data()!;
          final List<dynamic> teamMatchesDynamic = teamData['matches'] ?? [];
          final List<String> teamMatches =
              teamMatchesDynamic.map((m) => m.toString()).toList();

          if (teamMatches.contains(matchId)) {
            teamMatches.remove(matchId);
            batch.update(teamRef, {'matches': teamMatches});
          }
        }
      }

      // 3. Check if there are hole results subcollection
      final holeResultsCollection =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .doc(matchId)
              .collection('holeResults')
              .get();

      // Delete any hole results documents
      for (var doc in holeResultsCollection.docs) {
        batch.delete(doc.reference);
      }

      // 4. Finally, delete the match itself
      batch.delete(
        _firestore
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .doc(matchId),
      );

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error in deleteMatchWithCascade: $e');
      rethrow;
    }
  }

  // 2. Delete a team and cascade
  Future<void> deleteTeamWithCascade(String eventId, String teamId) async {
    try {
      // Get the team document first to access all its data
      final teamDoc =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(teamId)
              .get();
      if (!teamDoc.exists) {
        throw Exception('Team not found');
      }

      final teamData = teamDoc.data()!;

      // Start a batch operation
      WriteBatch batch = _firestore.batch();

      // 1. Get all matches associated with this team
      final matchesSnapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .where('teams', arrayContains: teamId)
              .get();

      // Track all users affected by this team's deletion
      Set<String> affectedUserIds = {};

      // For each match, we need to delete it with cascade
      // But we can't call deleteMatchWithCascade directly in a batch
      // So we'll handle the cascade manually here
      for (final matchDoc in matchesSnapshot.docs) {
        final matchId = matchDoc.id;
        final matchData = matchDoc.data();

        // Properly handle players map conversion
        final Map<String, dynamic> playersRaw = matchData['players'] ?? {};
        final Map<String, List<String>> players = {};

        playersRaw.forEach((teamKey, playerList) {
          if (playerList is List) {
            players[teamKey] =
                playerList.map((player) => player.toString()).toList();
          }
        });

        // Get all player IDs and add to affected users
        final List<String> allPlayerIds = [];
        players.forEach((_, playerList) {
          allPlayerIds.addAll(playerList);
        });
        affectedUserIds.addAll(allPlayerIds);

        // Remove match references from other teams
        final List<dynamic> teamIdsDynamic = matchData['teams'] ?? [];
        final List<String> teamIds =
            teamIdsDynamic.map((id) => id.toString()).toList();

        for (final otherTeamId in teamIds) {
          if (otherTeamId != teamId) {
            // Skip the team being deleted
            final teamRef = _firestore
                .collection('events')
                .doc(eventId)
                .collection('teams')
                .doc(otherTeamId);
            final teamDoc = await teamRef.get();

            if (teamDoc.exists) {
              final teamData = teamDoc.data()!;
              final List<dynamic> teamMatchesDynamic =
                  teamData['matches'] ?? [];
              final List<String> teamMatches =
                  teamMatchesDynamic.map((m) => m.toString()).toList();

              if (teamMatches.contains(matchId)) {
                teamMatches.remove(matchId);
                batch.update(teamRef, {'matches': teamMatches});
              }
            }
          }
        }

        // Delete any hole results for this match
        final holeResultsCollection =
            await _firestore
                .collection('events')
                .doc(eventId)
                .collection('matches')
                .doc(matchId)
                .collection('holeResults')
                .get();

        for (var holeDoc in holeResultsCollection.docs) {
          batch.delete(holeDoc.reference);
        }

        // Delete the match
        batch.delete(matchDoc.reference);
      }

      // 2. Get all team members and add to affected users
      final List<dynamic> playerIdsDynamic = teamData['players'] ?? [];
      final List<String> playerIds =
          playerIdsDynamic.map((id) => id.toString()).toList();
      affectedUserIds.addAll(playerIds);

      // 3. Update each affected user to remove team and match references
      for (final userId in affectedUserIds) {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await userRef.get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;

          // Check if user is on this team
          if (userData['golfDetails']?['teamId'] == teamId) {
            // Remove team reference from user
            batch.update(userRef, {
              'golfDetails.teamId': null,
              'golfDetails.teamName': null,
              'role': 'user', // Downgrade from league_player to user
            });
          }

          // Remove match references for all matches from this team
          final List<dynamic> userMatchesDynamic = userData['matches'] ?? [];
          if (userMatchesDynamic.isNotEmpty) {
            final List<String> userMatches =
                userMatchesDynamic.map((m) => m.toString()).toList();

            // Get all matches that were with this team
            final List<String> matchesToRemove =
                matchesSnapshot.docs
                    .map((doc) => doc.id)
                    .where((id) => userMatches.contains(id))
                    .toList();

            if (matchesToRemove.isNotEmpty) {
              userMatches.removeWhere((id) => matchesToRemove.contains(id));
              batch.update(userRef, {'matches': userMatches});
            }
          }
        }
      }

      // 5. Finally, delete the team
      batch.delete(
        _firestore
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .doc(teamId),
      );

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error in deleteTeamWithCascade: $e');
      rethrow;
    }
  }

  // 3. Delete a user and cascade
  Future<void> deleteUserWithCascade(String userId) async {
    try {
      // Get user data first to access all references
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;

      // Start a batch operation
      WriteBatch batch = _firestore.batch();

      // 1. Remove user from teams
      final String? teamId = userData['golfDetails']?['teamId'];
      final String? eventId = userData['golfDetails']?['eventId'];

      if (teamId != null && eventId != null) {
        final teamRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .doc(teamId);
        final teamDoc = await teamRef.get();

        if (teamDoc.exists) {
          final teamData = teamDoc.data()!;
          final List<dynamic> playersDynamic = teamData['players'] ?? [];
          final List<String> players =
              playersDynamic.map((id) => id.toString()).toList();

          if (players.contains(userId)) {
            players.remove(userId);
            batch.update(teamRef, {'players': players});
          }
        }
      }

      // 2. Update matches to remove user (need to check in all events)
      final List<dynamic> userMatchesDynamic = userData['matches'] ?? [];
      final List<String> userMatches =
          userMatchesDynamic.map((m) => m.toString()).toList();

      // Query all events
      final eventsSnapshot = await _firestore.collection('events').get();

      for (final eventDoc in eventsSnapshot.docs) {
        final eventId = eventDoc.id;

        // For each event, check if user is in any matches
        for (final matchId in userMatches) {
          final matchRef = _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .doc(matchId);
          final matchDoc = await matchRef.get();

          if (matchDoc.exists) {
            final matchData = matchDoc.data()!;

            // Properly handle players map conversion
            final Map<String, dynamic> playersRaw = matchData['players'] ?? {};
            final Map<String, List<String>> players = {};

            // Convert each team's player list
            playersRaw.forEach((teamKey, playerList) {
              if (playerList is List) {
                players[teamKey] = playerList.map((p) => p.toString()).toList();
              }
            });

            // Check each team's player list and remove user
            bool updated = false;
            players.forEach((teamKey, playerList) {
              if (playerList.contains(userId)) {
                playerList.remove(userId);
                updated = true;
              }
            });

            if (updated) {
              batch.update(matchRef, {'players': players});
            }
          }
        }

        // 3. Remove user from event registrations
        final registrationsSnapshot =
            await _firestore
                .collection('events')
                .doc(eventId)
                .collection('registrations')
                .where('userId', isEqualTo: userId)
                .get();

        for (final regDoc in registrationsSnapshot.docs) {
          batch.delete(regDoc.reference);
        }
      }

      // 4. Delete user document
      batch.delete(_firestore.collection('users').doc(userId));

      // Commit the batch
      await batch.commit();

      // 5. Finally, delete user from Firebase Authentication
      // This must be done after Firestore operations in case Auth deletion fails
      final user =
          _auth.currentUser?.uid == userId
              ? _auth.currentUser
              : await _getAdminAuthUser(userId);

      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      print('Error in deleteUserWithCascade: $e');
      rethrow;
    }
  }

  // Helper method to get a user for admin deletion purposes
  // Note: In a real app, you would need to use Firebase Admin SDK or Cloud Functions
  Future<User?> _getAdminAuthUser(String uid) async {
    // This is a simplified implementation
    // In a real app, this would be implemented with Cloud Functions
    // or through a secure admin backend
    print('Warning: Direct user deletion by ID requires Firebase Admin SDK');
    return null;
  }

  // 4. Delete an event and cascade
  Future<void> deleteEventWithCascade(String eventId) async {
    try {
      // Get the event document to access its data
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        throw Exception('Event not found');
      }

      final batch = _firestore.batch();

      // 1. Get all teams in this event
      final teamsSnapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .get();

      // Track all users affected by this event's deletion
      Set<String> affectedUserIds = <String>{};

      // 2. For each team, get all players and matches
      for (final teamDoc in teamsSnapshot.docs) {
        final teamData = teamDoc.data();
        final List<dynamic> playersDynamic = teamData['players'] ?? [];
        final List<String> players =
            playersDynamic.map((id) => id.toString()).toList();

        // Add all players to affected users
        affectedUserIds.addAll(players);
      }

      // 3. Get all matches in this event
      final matchesSnapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .get();

      // 4. For each match, get players and update their references
      for (final matchDoc in matchesSnapshot.docs) {
        final matchId = matchDoc.id;
        final matchData = matchDoc.data();

        // Get all players from this match
        final Map<String, dynamic> playersRaw = matchData['players'] ?? {};
        playersRaw.forEach((teamKey, playerList) {
          if (playerList is List) {
            final players = playerList.map((p) => p.toString()).toList();
            affectedUserIds.addAll(players);
          }
        });

        // Delete hole results subcollection
        final holeResultsSnapshot =
            await _firestore
                .collection('events')
                .doc(eventId)
                .collection('matches')
                .doc(matchId)
                .collection('holeResults')
                .get();

        for (final holeDoc in holeResultsSnapshot.docs) {
          batch.delete(holeDoc.reference);
        }

        // Delete the match
        batch.delete(matchDoc.reference);
      }

      // 5. Update all affected users to remove references
      for (final userId in affectedUserIds) {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await userRef.get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;

          // Check if user belongs to a team in this event
          if (userData['golfDetails']?['eventId'] == eventId) {
            batch.update(userRef, {
              'golfDetails.teamId': null,
              'golfDetails.teamName': null,
              'golfDetails.eventId': null,
              'role': 'user', // Downgrade from league_player to user
            });
          }

          // Remove match references for matches in this event
          final List<dynamic> userMatchesDynamic = userData['matches'] ?? [];
          if (userMatchesDynamic.isNotEmpty) {
            final List<String> userMatches =
                userMatchesDynamic.map((m) => m.toString()).toList();
            final List<String> matchesToRemove =
                matchesSnapshot.docs.map((doc) => doc.id).toList();

            if (matchesToRemove.isNotEmpty) {
              userMatches.removeWhere((id) => matchesToRemove.contains(id));
              batch.update(userRef, {'matches': userMatches});
            }
          }
        }
      }

      // 6. Delete all teams
      for (final teamDoc in teamsSnapshot.docs) {
        batch.delete(teamDoc.reference);
      }

      // 7. Delete all registrations
      final registrationsSnapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('registrations')
              .get();

      for (final regDoc in registrationsSnapshot.docs) {
        batch.delete(regDoc.reference);
      }

      // 8. Finally, delete the event document
      batch.delete(_firestore.collection('events').doc(eventId));

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error in deleteEventWithCascade: $e');
      rethrow;
    }
  }
}
