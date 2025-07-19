import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/award_model.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all award categories with their statistics for a specific event
  Future<List<AwardCategory>> getEventAwards(String eventId) async {
    final List<AwardCategory> awards = [];

    try {
      // Fetch all required data first
      final eventData = await _getEventData(eventId);
      final matches = eventData['matches'] as List<DocumentSnapshot>;
      final players = eventData['players'] as Map<String, Map<String, dynamic>>;
      final teams = eventData['teams'] as Map<String, Map<String, dynamic>>;

      // Calculate each award category
      awards.add(await _getTopPlayersAward(eventId, matches, players, teams));
      awards.add(await _getTopPairsAward(eventId, matches, players, teams));
      awards.add(await _getMostParsAward(eventId, matches, players, teams));
      awards.add(await _getMostBirdiesAward(eventId, matches, players, teams));
      awards.add(await _getMostBogeysAward(eventId, matches, players, teams));
      awards.add(await _getWorstPairAward(eventId, matches, players, teams));
      awards.add(
        await _getMostParticipationAward(eventId, matches, players, teams),
      );

      return awards;
    } catch (e) {
      print('Error getting event awards: $e');
      rethrow;
    }
  }

  // Gather all required data for award calculations
  Future<Map<String, dynamic>> _getEventData(String eventId) async {
    final matches =
        await _firestore
            .collection('events')
            .doc(eventId)
            .collection('matches')
            .get();

    final teams =
        await _firestore
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .get();

    // Get all unique player IDs from teams
    final Set<String> playerIds = {};
    final Map<String, Map<String, dynamic>> teamData = {};

    for (final teamDoc in teams.docs) {
      final data = teamDoc.data();
      teamData[teamDoc.id] = data;

      final List<String> teamPlayers = List<String>.from(data['players'] ?? []);
      playerIds.addAll(teamPlayers);
    }

    // Fetch player data
    final Map<String, Map<String, dynamic>> playerData = {};
    for (final playerId in playerIds) {
      try {
        final playerDoc =
            await _firestore.collection('users').doc(playerId).get();
        if (playerDoc.exists) {
          playerData[playerId] = playerDoc.data() as Map<String, dynamic>;
        }
      } catch (e) {
        print('Error fetching player $playerId: $e');
      }
    }

    return {'matches': matches.docs, 'players': playerData, 'teams': teamData};
  }

  // Helper method to fetch hole results for a match from subcollection
  Future<Map<String, dynamic>> _getMatchHoleResults(
    String eventId,
    String matchId,
  ) async {
    try {
      final holeResultsQuery =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .doc(matchId)
              .collection('holeResults')
              .get();

      final Map<String, dynamic> holeResults = {};
      for (final holeDoc in holeResultsQuery.docs) {
        holeResults[holeDoc.id] = holeDoc.data()['result'];
      }
      return holeResults;
    } catch (e) {
      print('Error fetching hole results for match $matchId: $e');
      return {};
    }
  }

  // Calculate Top Players award - players who won with different partners
  Future<AwardCategory> _getTopPlayersAward(
    String eventId,
    List<DocumentSnapshot> matches,
    Map<String, Map<String, dynamic>> players,
    Map<String, Map<String, dynamic>> teams,
  ) async {
    final Map<String, Set<String>> playerPartners = {};
    final Map<String, int> playerWins = {};
    final Map<String, String> playerTeams = {};

    // Track each player's partners and wins
    for (final match in matches) {
      final data = match.data() as Map<String, dynamic>;

      // Try to get hole results from match document, fallback to subcollection
      Map<String, dynamic> holeResults =
          data['holeResults'] as Map<String, dynamic>? ?? {};
      if (holeResults.isEmpty) {
        holeResults = await _getMatchHoleResults(eventId, match.id);
      }

      final playersMap = data['players'] as Map<String, dynamic>? ?? {};

      // Count wins for each team
      int teamAWins = 0;
      int teamBWins = 0;

      for (final result in holeResults.values) {
        if (result == 'A') teamAWins++;
        if (result == 'B') teamBWins++;
      }

      final teamAPlayers = List<String>.from(playersMap['teamA'] ?? []);
      final teamBPlayers = List<String>.from(playersMap['teamB'] ?? []);
      final teamIds = List<String>.from(data['teams'] ?? []);

      String? winningTeam;
      List<String> winningPlayers = [];

      if (teamAWins > teamBWins) {
        winningTeam = teamIds.isNotEmpty ? teamIds[0] : null;
        winningPlayers = teamAPlayers;
      } else if (teamBWins > teamAWins) {
        winningTeam = teamIds.length > 1 ? teamIds[1] : null;
        winningPlayers = teamBPlayers;
      }

      // Track partnerships and wins
      if (winningPlayers.isNotEmpty) {
        for (final playerId in winningPlayers) {
          playerWins[playerId] = (playerWins[playerId] ?? 0) + 1;
          if (winningTeam != null) {
            playerTeams[playerId] = winningTeam;
          }

          // Track partners (other players in the same match)
          playerPartners.putIfAbsent(playerId, () => <String>{});
          for (final partnerId in winningPlayers) {
            if (partnerId != playerId) {
              playerPartners[playerId]!.add(partnerId);
            }
          }
        }
      }
    }

    // Find players with most wins and most diverse partnerships
    final List<PlayerStat> stats = [];

    for (final entry in playerWins.entries) {
      final playerId = entry.key;
      final wins = entry.value;
      final partnerCount = playerPartners[playerId]?.length ?? 0;

      if (players.containsKey(playerId)) {
        final playerData = players[playerId]!;
        final playerName =
            '${playerData['firstName'] ?? ''} ${playerData['lastName'] ?? ''}'
                .trim();
        final teamId = playerTeams[playerId];
        final teamName =
            teamId != null
                ? (teams[teamId]?['teamName'] ?? 'Unknown Team')
                : null;

        stats.add(
          PlayerStat(
            playerId: playerId,
            playerName:
                playerName.isEmpty
                    ? playerData['email'] ?? 'Unknown'
                    : playerName,
            teamId: teamId,
            teamName: teamName,
            value: wins,
            displayValue: '$wins wins with $partnerCount different partners',
            additionalData: {
              'wins': wins,
              'partnerCount': partnerCount,
              'versatilityScore':
                  wins *
                  partnerCount, // Score based on wins and partner diversity
            },
          ),
        );
      }
    }

    // Sort by versatility score (wins * partner count)
    stats.sort(
      (a, b) => (b.additionalData['versatilityScore'] as int).compareTo(
        a.additionalData['versatilityScore'] as int,
      ),
    );

    return AwardCategory(
      award: Award(
        id: 'top_players',
        title: 'Top Players',
        description: 'Players who won matches with different partners',
        iconName: 'star',
        color: 'gold',
        order: 1,
        isPositive: true,
      ),
      stats: stats,
    );
  }

  // Calculate Top Pairs award
  Future<AwardCategory> _getTopPairsAward(
    String eventId,
    List<DocumentSnapshot> matches,
    Map<String, Map<String, dynamic>> players,
    Map<String, Map<String, dynamic>> teams,
  ) async {
    final Map<String, int> pairWins = {};
    final Map<String, String> pairTeams = {};
    final Map<String, List<String>> pairPlayers = {};

    for (final match in matches) {
      final data = match.data() as Map<String, dynamic>;

      // Try to get hole results from match document, fallback to subcollection
      Map<String, dynamic> holeResults =
          data['holeResults'] as Map<String, dynamic>? ?? {};
      if (holeResults.isEmpty) {
        holeResults = await _getMatchHoleResults(eventId, match.id);
      }

      final playersMap = data['players'] as Map<String, dynamic>? ?? {};

      // Count wins
      int teamAWins = 0;
      int teamBWins = 0;

      for (final result in holeResults.values) {
        if (result == 'A') teamAWins++;
        if (result == 'B') teamBWins++;
      }

      final teamAPlayers = List<String>.from(playersMap['teamA'] ?? []);
      final teamBPlayers = List<String>.from(playersMap['teamB'] ?? []);
      final teamIds = List<String>.from(data['teams'] ?? []);

      List<String> winningPlayers = [];
      String? winningTeamId;

      if (teamAWins > teamBWins) {
        winningPlayers = teamAPlayers;
        winningTeamId = teamIds.isNotEmpty ? teamIds[0] : null;
      } else if (teamBWins > teamAWins) {
        winningPlayers = teamBPlayers;
        winningTeamId = teamIds.length > 1 ? teamIds[1] : null;
      }

      if (winningPlayers.length >= 2) {
        // Create pair key (sorted to ensure consistency)
        winningPlayers.sort();
        final pairKey = winningPlayers.join('-');

        pairWins[pairKey] = (pairWins[pairKey] ?? 0) + 1;
        pairPlayers[pairKey] = winningPlayers;
        if (winningTeamId != null) {
          pairTeams[pairKey] = winningTeamId;
        }
      }
    }

    final List<PlayerStat> stats = [];

    for (final entry in pairWins.entries) {
      final pairKey = entry.key;
      final wins = entry.value;
      final playerIds = pairPlayers[pairKey] ?? [];
      final teamId = pairTeams[pairKey];

      if (playerIds.isNotEmpty) {
        final playerNames =
            playerIds.map((id) {
              final playerData = players[id];
              final name =
                  '${playerData?['firstName'] ?? ''} ${playerData?['lastName'] ?? ''}'
                      .trim();
              return name.isEmpty ? (playerData?['email'] ?? 'Unknown') : name;
            }).toList();

        final teamName =
            teamId != null
                ? (teams[teamId]?['teamName'] ?? 'Unknown Team')
                : null;

        stats.add(
          PlayerStat(
            playerId: pairKey,
            playerName: playerNames.join(' & '),
            teamId: teamId,
            teamName: teamName,
            value: wins,
            displayValue: '$wins wins',
            additionalData: {'playerIds': playerIds, 'wins': wins},
          ),
        );
      }
    }

    stats.sort((a, b) => b.value.compareTo(a.value));

    return AwardCategory(
      award: Award(
        id: 'top_pairs',
        title: 'Top Pairs',
        description: 'Best performing player pairs',
        iconName: 'group',
        color: 'blue',
        order: 2,
        isPositive: true,
      ),
      stats: stats,
    );
  }

  // Calculate Most Pars award - Enhanced with match performance data
  Future<AwardCategory> _getMostParsAward(
    String eventId,
    List<DocumentSnapshot> matches,
    Map<String, Map<String, dynamic>> players,
    Map<String, Map<String, dynamic>> teams,
  ) async {
    final Map<String, int> pairMatchesWon = {};
    final Map<String, String> pairTeams = {};
    final Map<String, List<String>> pairPlayers = {};

    // Count matches won as a proxy for consistent par performance
    for (final match in matches) {
      final data = match.data() as Map<String, dynamic>;
      // Try to get hole results from match document, fallback to subcollection
      Map<String, dynamic> holeResults =
          data['holeResults'] as Map<String, dynamic>? ?? {};
      if (holeResults.isEmpty) {
        holeResults = await _getMatchHoleResults(eventId, match.id);
      }
      final playersMap = data['players'] as Map<String, dynamic>? ?? {};

      int teamAWins = 0;
      int teamBWins = 0;

      for (final result in holeResults.values) {
        if (result == 'A') teamAWins++;
        if (result == 'B') teamBWins++;
      }

      final teamAPlayers = List<String>.from(playersMap['teamA'] ?? []);
      final teamBPlayers = List<String>.from(playersMap['teamB'] ?? []);
      final teamIds = List<String>.from(data['teams'] ?? []);

      List<String> winningPlayers = [];
      String? winningTeamId;

      if (teamAWins > teamBWins) {
        winningPlayers = teamAPlayers;
        winningTeamId = teamIds.isNotEmpty ? teamIds[0] : null;
      } else if (teamBWins > teamAWins) {
        winningPlayers = teamBPlayers;
        winningTeamId = teamIds.length > 1 ? teamIds[1] : null;
      }

      if (winningPlayers.length >= 2) {
        winningPlayers.sort();
        final pairKey = winningPlayers.join('-');

        pairMatchesWon[pairKey] = (pairMatchesWon[pairKey] ?? 0) + 1;
        pairPlayers[pairKey] = winningPlayers;
        if (winningTeamId != null) {
          pairTeams[pairKey] = winningTeamId;
        }
      }
    }

    final List<PlayerStat> stats = [];

    for (final entry in pairMatchesWon.entries) {
      final pairKey = entry.key;
      final matchesWon = entry.value;
      final playerIds = pairPlayers[pairKey] ?? [];
      final teamId = pairTeams[pairKey];

      if (playerIds.isNotEmpty && matchesWon >= 2) {
        // Only show pairs with 2+ wins (consistent performance)
        final playerNames =
            playerIds.map((id) {
              final playerData = players[id];
              final name =
                  '${playerData?['firstName'] ?? ''} ${playerData?['lastName'] ?? ''}'
                      .trim();
              return name.isEmpty ? (playerData?['email'] ?? 'Unknown') : name;
            }).toList();

        final teamName =
            teamId != null
                ? (teams[teamId]?['teamName'] ?? 'Unknown Team')
                : null;

        stats.add(
          PlayerStat(
            playerId: pairKey,
            playerName: playerNames.join(' & '),
            teamId: teamId,
            teamName: teamName,
            value: matchesWon,
            displayValue: '$matchesWon consistent wins',
            additionalData: {'playerIds': playerIds, 'matchesWon': matchesWon},
          ),
        );
      }
    }

    stats.sort((a, b) => b.value.compareTo(a.value));

    return AwardCategory(
      award: Award(
        id: 'most_pars',
        title: 'Most Consistent',
        description: 'Pairs with most consistent performance',
        iconName: 'golf_course',
        color: 'green',
        order: 3,
        isPositive: true,
      ),
      stats: stats,
    );
  }

  // Calculate Most Birdies award - Enhanced with hole win dominance
  Future<AwardCategory> _getMostBirdiesAward(
    String eventId,
    List<DocumentSnapshot> matches,
    Map<String, Map<String, dynamic>> players,
    Map<String, Map<String, dynamic>> teams,
  ) async {
    final Map<String, int> pairHoleWins = {};
    final Map<String, String> pairTeams = {};
    final Map<String, List<String>> pairPlayers = {};

    // Count total hole wins as a proxy for birdie performance
    for (final match in matches) {
      final data = match.data() as Map<String, dynamic>;
      // Try to get hole results from match document, fallback to subcollection
      Map<String, dynamic> holeResults =
          data['holeResults'] as Map<String, dynamic>? ?? {};
      if (holeResults.isEmpty) {
        holeResults = await _getMatchHoleResults(eventId, match.id);
      }
      final playersMap = data['players'] as Map<String, dynamic>? ?? {};

      final teamAPlayers = List<String>.from(playersMap['teamA'] ?? []);
      final teamBPlayers = List<String>.from(playersMap['teamB'] ?? []);
      final teamIds = List<String>.from(data['teams'] ?? []);

      int teamAHoleWins = 0;
      int teamBHoleWins = 0;

      for (final result in holeResults.values) {
        if (result == 'A') teamAHoleWins++;
        if (result == 'B') teamBHoleWins++;
      }

      // Track hole wins for team A
      if (teamAPlayers.length >= 2 && teamAHoleWins > 0) {
        final sortedPlayers = List<String>.from(teamAPlayers)..sort();
        final pairKey = sortedPlayers.join('-');

        pairHoleWins[pairKey] = (pairHoleWins[pairKey] ?? 0) + teamAHoleWins;
        pairPlayers[pairKey] = sortedPlayers;
        if (teamIds.isNotEmpty) {
          pairTeams[pairKey] = teamIds[0];
        }
      }

      // Track hole wins for team B
      if (teamBPlayers.length >= 2 && teamBHoleWins > 0) {
        final sortedPlayers = List<String>.from(teamBPlayers)..sort();
        final pairKey = sortedPlayers.join('-');

        pairHoleWins[pairKey] = (pairHoleWins[pairKey] ?? 0) + teamBHoleWins;
        pairPlayers[pairKey] = sortedPlayers;
        if (teamIds.length > 1) {
          pairTeams[pairKey] = teamIds[1];
        }
      }
    }

    final List<PlayerStat> stats = [];

    for (final entry in pairHoleWins.entries) {
      final pairKey = entry.key;
      final holeWins = entry.value;
      final playerIds = pairPlayers[pairKey] ?? [];
      final teamId = pairTeams[pairKey];

      if (playerIds.isNotEmpty && holeWins >= 5) {
        // Only show pairs with significant hole wins
        final playerNames =
            playerIds.map((id) {
              final playerData = players[id];
              final name =
                  '${playerData?['firstName'] ?? ''} ${playerData?['lastName'] ?? ''}'
                      .trim();
              return name.isEmpty ? (playerData?['email'] ?? 'Unknown') : name;
            }).toList();

        final teamName =
            teamId != null
                ? (teams[teamId]?['teamName'] ?? 'Unknown Team')
                : null;

        stats.add(
          PlayerStat(
            playerId: pairKey,
            playerName: playerNames.join(' & '),
            teamId: teamId,
            teamName: teamName,
            value: holeWins,
            displayValue: '$holeWins hole wins',
            additionalData: {'playerIds': playerIds, 'holeWins': holeWins},
          ),
        );
      }
    }

    stats.sort((a, b) => b.value.compareTo(a.value));

    return AwardCategory(
      award: Award(
        id: 'most_birdies',
        title: 'Most Dominant',
        description: 'Pairs with most hole wins',
        iconName: 'flutter_dash',
        color: 'orange',
        order: 4,
        isPositive: true,
      ),
      stats: stats,
    );
  }

  // Calculate Most Bogeys award - Enhanced with hole losses
  Future<AwardCategory> _getMostBogeysAward(
    String eventId,
    List<DocumentSnapshot> matches,
    Map<String, Map<String, dynamic>> players,
    Map<String, Map<String, dynamic>> teams,
  ) async {
    final Map<String, int> pairHoleLosses = {};
    final Map<String, String> pairTeams = {};
    final Map<String, List<String>> pairPlayers = {};

    // Count total hole losses as a proxy for bogey performance
    for (final match in matches) {
      final data = match.data() as Map<String, dynamic>;
      // Try to get hole results from match document, fallback to subcollection
      Map<String, dynamic> holeResults =
          data['holeResults'] as Map<String, dynamic>? ?? {};
      if (holeResults.isEmpty) {
        holeResults = await _getMatchHoleResults(eventId, match.id);
      }
      final playersMap = data['players'] as Map<String, dynamic>? ?? {};

      final teamAPlayers = List<String>.from(playersMap['teamA'] ?? []);
      final teamBPlayers = List<String>.from(playersMap['teamB'] ?? []);
      final teamIds = List<String>.from(data['teams'] ?? []);

      int teamAHoleWins = 0;
      int teamBHoleWins = 0;

      for (final result in holeResults.values) {
        if (result == 'A') teamAHoleWins++;
        if (result == 'B') teamBHoleWins++;
      }

      // Calculate hole losses for team A
      final teamAHoleLosses = teamBHoleWins;
      if (teamAPlayers.length >= 2 && teamAHoleLosses > 0) {
        final sortedPlayers = List<String>.from(teamAPlayers)..sort();
        final pairKey = sortedPlayers.join('-');

        pairHoleLosses[pairKey] =
            (pairHoleLosses[pairKey] ?? 0) + teamAHoleLosses;
        pairPlayers[pairKey] = sortedPlayers;
        if (teamIds.isNotEmpty) {
          pairTeams[pairKey] = teamIds[0];
        }
      }

      // Calculate hole losses for team B
      final teamBHoleLosses = teamAHoleWins;
      if (teamBPlayers.length >= 2 && teamBHoleLosses > 0) {
        final sortedPlayers = List<String>.from(teamBPlayers)..sort();
        final pairKey = sortedPlayers.join('-');

        pairHoleLosses[pairKey] =
            (pairHoleLosses[pairKey] ?? 0) + teamBHoleLosses;
        pairPlayers[pairKey] = sortedPlayers;
        if (teamIds.length > 1) {
          pairTeams[pairKey] = teamIds[1];
        }
      }
    }

    final List<PlayerStat> stats = [];

    for (final entry in pairHoleLosses.entries) {
      final pairKey = entry.key;
      final holeLosses = entry.value;
      final playerIds = pairPlayers[pairKey] ?? [];
      final teamId = pairTeams[pairKey];

      if (playerIds.isNotEmpty && holeLosses >= 8) {
        // Only show pairs with significant hole losses
        final playerNames =
            playerIds.map((id) {
              final playerData = players[id];
              final name =
                  '${playerData?['firstName'] ?? ''} ${playerData?['lastName'] ?? ''}'
                      .trim();
              return name.isEmpty ? (playerData?['email'] ?? 'Unknown') : name;
            }).toList();

        final teamName =
            teamId != null
                ? (teams[teamId]?['teamName'] ?? 'Unknown Team')
                : null;

        stats.add(
          PlayerStat(
            playerId: pairKey,
            playerName: playerNames.join(' & '),
            teamId: teamId,
            teamName: teamName,
            value: holeLosses,
            displayValue: '$holeLosses hole losses',
            additionalData: {'playerIds': playerIds, 'holeLosses': holeLosses},
          ),
        );
      }
    }

    stats.sort((a, b) => b.value.compareTo(a.value));

    return AwardCategory(
      award: Award(
        id: 'most_bogeys',
        title: 'Unlucky Shots',
        description: 'Pairs with most hole losses (it happens to the best!)',
        iconName: 'sentiment_dissatisfied',
        color: 'red',
        order: 5,
        isPositive: false,
      ),
      stats: stats,
    );
  }

  // Calculate Worst Pair award
  Future<AwardCategory> _getWorstPairAward(
    String eventId,
    List<DocumentSnapshot> matches,
    Map<String, Map<String, dynamic>> players,
    Map<String, Map<String, dynamic>> teams,
  ) async {
    final Map<String, int> pairLosses = {};
    final Map<String, String> pairTeams = {};
    final Map<String, List<String>> pairPlayers = {};

    for (final match in matches) {
      final data = match.data() as Map<String, dynamic>;
      // Try to get hole results from match document, fallback to subcollection
      Map<String, dynamic> holeResults =
          data['holeResults'] as Map<String, dynamic>? ?? {};
      if (holeResults.isEmpty) {
        holeResults = await _getMatchHoleResults(eventId, match.id);
      }
      final playersMap = data['players'] as Map<String, dynamic>? ?? {};

      // Count wins/losses
      int teamAWins = 0;
      int teamBWins = 0;

      for (final result in holeResults.values) {
        if (result == 'A') teamAWins++;
        if (result == 'B') teamBWins++;
      }

      final teamAPlayers = List<String>.from(playersMap['teamA'] ?? []);
      final teamBPlayers = List<String>.from(playersMap['teamB'] ?? []);
      final teamIds = List<String>.from(data['teams'] ?? []);

      List<String> losingPlayers = [];
      String? losingTeamId;

      if (teamAWins < teamBWins) {
        losingPlayers = teamAPlayers;
        losingTeamId = teamIds.isNotEmpty ? teamIds[0] : null;
      } else if (teamBWins < teamAWins) {
        losingPlayers = teamBPlayers;
        losingTeamId = teamIds.length > 1 ? teamIds[1] : null;
      }

      if (losingPlayers.length >= 2) {
        losingPlayers.sort();
        final pairKey = losingPlayers.join('-');

        pairLosses[pairKey] = (pairLosses[pairKey] ?? 0) + 1;
        pairPlayers[pairKey] = losingPlayers;
        if (losingTeamId != null) {
          pairTeams[pairKey] = losingTeamId;
        }
      }
    }

    final List<PlayerStat> stats = [];

    for (final entry in pairLosses.entries) {
      final pairKey = entry.key;
      final losses = entry.value;
      final playerIds = pairPlayers[pairKey] ?? [];
      final teamId = pairTeams[pairKey];

      if (playerIds.isNotEmpty) {
        final playerNames =
            playerIds.map((id) {
              final playerData = players[id];
              final name =
                  '${playerData?['firstName'] ?? ''} ${playerData?['lastName'] ?? ''}'
                      .trim();
              return name.isEmpty ? (playerData?['email'] ?? 'Unknown') : name;
            }).toList();

        final teamName =
            teamId != null
                ? (teams[teamId]?['teamName'] ?? 'Unknown Team')
                : null;

        stats.add(
          PlayerStat(
            playerId: pairKey,
            playerName: playerNames.join(' & '),
            teamId: teamId,
            teamName: teamName,
            value: losses,
            displayValue: '$losses losses',
            additionalData: {'playerIds': playerIds, 'losses': losses},
          ),
        );
      }
    }

    stats.sort((a, b) => b.value.compareTo(a.value));

    return AwardCategory(
      award: Award(
        id: 'worst_pair',
        title: 'Worst Pair',
        description: 'Pair who lost all matches',
        iconName: 'sentiment_very_dissatisfied',
        color: 'grey',
        order: 6,
        isPositive: false,
      ),
      stats: stats,
    );
  }

  // Calculate Most Participation award
  Future<AwardCategory> _getMostParticipationAward(
    String eventId,
    List<DocumentSnapshot> matches,
    Map<String, Map<String, dynamic>> players,
    Map<String, Map<String, dynamic>> teams,
  ) async {
    final Map<String, int> playerParticipation = {};
    final Map<String, String> playerTeamIds = {};

    for (final match in matches) {
      final data = match.data() as Map<String, dynamic>;
      final playersMap = data['players'] as Map<String, dynamic>? ?? {};
      final teamIds = List<String>.from(data['teams'] ?? []);

      final teamAPlayers = List<String>.from(playersMap['teamA'] ?? []);
      final teamBPlayers = List<String>.from(playersMap['teamB'] ?? []);

      // Count participation for team A players
      for (final playerId in teamAPlayers) {
        playerParticipation[playerId] =
            (playerParticipation[playerId] ?? 0) + 1;
        if (teamIds.isNotEmpty) {
          playerTeamIds[playerId] = teamIds[0];
        }
      }

      // Count participation for team B players
      for (final playerId in teamBPlayers) {
        playerParticipation[playerId] =
            (playerParticipation[playerId] ?? 0) + 1;
        if (teamIds.length > 1) {
          playerTeamIds[playerId] = teamIds[1];
        }
      }
    }

    final List<PlayerStat> stats = [];

    for (final entry in playerParticipation.entries) {
      final playerId = entry.key;
      final participation = entry.value;
      final teamId = playerTeamIds[playerId];

      if (players.containsKey(playerId)) {
        final playerData = players[playerId]!;
        final playerName =
            '${playerData['firstName'] ?? ''} ${playerData['lastName'] ?? ''}'
                .trim();
        final teamName =
            teamId != null
                ? (teams[teamId]?['teamName'] ?? 'Unknown Team')
                : null;

        stats.add(
          PlayerStat(
            playerId: playerId,
            playerName:
                playerName.isEmpty
                    ? playerData['email'] ?? 'Unknown'
                    : playerName,
            teamId: teamId,
            teamName: teamName,
            value: participation,
            displayValue: '$participation matches',
            additionalData: {'matches': participation},
          ),
        );
      }
    }

    stats.sort((a, b) => b.value.compareTo(a.value));

    return AwardCategory(
      award: Award(
        id: 'most_participation',
        title: 'Most Participation',
        description: 'Player who attended the most matches',
        iconName: 'emoji_events',
        color: 'cyan',
        order: 8,
        isPositive: true,
      ),
      stats: stats,
    );
  }
}
