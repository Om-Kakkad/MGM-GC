import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Delete a 4-ball match and cascade
  Future<void> deleteMatchWithCascade(String matchId) async {
    try {
      // Get the match document first to get its data
      final matchDoc =
          await _firestore.collection('fourBalls').doc(matchId).get();
      if (!matchDoc.exists) {
        throw Exception('Match not found');
      }

      final matchData = matchDoc.data()!;

      // FIX: Proper type conversion using .map()
      final List<dynamic> teamsDynamic = matchData['teams'] ?? [];
      final List<String> teamIds =
          teamsDynamic.map((id) => id.toString()).toList();

      // Get eventId for potential additional cleanups
      final String eventId = matchData['eventID']?.toString() ?? '';

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
        final teamRef = _firestore.collection('teams').doc(teamId);
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

      // 3. Update event if needed
      if (eventId.isNotEmpty) {
        final eventRef = _firestore.collection('events').doc(eventId);
        final eventDoc = await eventRef.get();
        if (eventDoc.exists) {
          final eventData = eventDoc.data()!;
          final List<dynamic> eventMatchesDynamic = eventData['matches'] ?? [];
          if (eventMatchesDynamic.isNotEmpty) {
            final List<String> eventMatches =
                eventMatchesDynamic.map((m) => m.toString()).toList();
            if (eventMatches.contains(matchId)) {
              eventMatches.remove(matchId);
              batch.update(eventRef, {'matches': eventMatches});
            }
          }
        }
      }

      // 4. Finally, delete the match itself
      batch.delete(_firestore.collection('fourBalls').doc(matchId));

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error in deleteMatchWithCascade: $e');
      rethrow;
    }
  }

  // 2. Delete a team and cascade
  Future<void> deleteTeamWithCascade(String teamId) async {
    try {
      // Get the team document first to access all its data
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) {
        throw Exception('Team not found');
      }

      final teamData = teamDoc.data()!;
      final String eventId = teamData['eventID'] ?? teamData['eventId'] ?? '';

      // Start a batch operation
      WriteBatch batch = _firestore.batch();

      // 1. Get all matches associated with this team
      final matchesSnapshot =
          await _firestore
              .collection('fourBalls')
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
            final teamRef = _firestore.collection('teams').doc(otherTeamId);
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

      // 4. Update the event to remove this team
      if (eventId.isNotEmpty) {
        final eventRef = _firestore.collection('events').doc(eventId);
        final eventDoc = await eventRef.get();

        if (eventDoc.exists) {
          // Remove team from event's teamIDs array
          batch.update(eventRef, {
            'teamIDs': FieldValue.arrayRemove([teamId]),
          });
        }
      }

      // 5. Finally, delete the team
      batch.delete(_firestore.collection('teams').doc(teamId));

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
      if (teamId != null) {
        final teamRef = _firestore.collection('teams').doc(teamId);
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

      // 2. Update matches to remove user
      final List<dynamic> userMatchesDynamic = userData['matches'] ?? [];
      final List<String> userMatches =
          userMatchesDynamic.map((m) => m.toString()).toList();

      for (final matchId in userMatches) {
        final matchRef = _firestore.collection('fourBalls').doc(matchId);
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
              .collection('event_registrations')
              .where('userId', isEqualTo: userId)
              .get();

      for (final regDoc in registrationsSnapshot.docs) {
        batch.delete(regDoc.reference);
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

      final eventData = eventDoc.data()!;

      // Track all matches that need to be deleted
      Set<String> matchesToDelete = new Set<String>();

      // Start by getting all teams associated with this event
      // Check for different possible field names (eventID or eventId)
      final teamsSnapshot1 =
          await _firestore
              .collection('teams')
              .where('eventID', isEqualTo: eventId)
              .get();

      final teamsSnapshot2 =
          await _firestore
              .collection('teams')
              .where('eventId', isEqualTo: eventId)
              .get();

      // Combine results from both queries
      final List<DocumentSnapshot> teamsDocs = [
        ...teamsSnapshot1.docs,
        ...teamsSnapshot2.docs,
      ];

      // 1. First, collect all matches related to these teams
      for (final teamDoc in teamsDocs) {
        // Get matches associated with this team
        final teamMatches =
            await _firestore
                .collection('fourBalls')
                .where('teams', arrayContains: teamDoc.id)
                .get();

        // Add match IDs to the set
        for (final matchDoc in teamMatches.docs) {
          matchesToDelete.add(matchDoc.id);
        }
      }

      // 2. Delete each match with cascade
      for (final matchId in matchesToDelete) {
        await deleteMatchWithCascade(matchId);
      }

      // 3. Delete each team with cascade (this will handle players and other references)
      for (final teamDoc in teamsDocs) {
        await deleteTeamWithCascade(teamDoc.id);
      }

      // 4. Delete event registrations
      final registrationsSnapshot =
          await _firestore
              .collection('event_registrations')
              .where('eventId', isEqualTo: eventId)
              .get();

      final batch = _firestore.batch();
      for (final regDoc in registrationsSnapshot.docs) {
        batch.delete(regDoc.reference);
      }

      // 5. Finally, delete the event document
      batch.delete(_firestore.collection('events').doc(eventId));

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error in deleteEventWithCascade: $e');
      rethrow;
    }
  }
}
