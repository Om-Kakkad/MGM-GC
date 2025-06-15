import 'package:flutter/material.dart';
import 'package:mgm_gc/services/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveScoresListPage extends StatefulWidget {
  const LiveScoresListPage({super.key});

  @override
  State<LiveScoresListPage> createState() => _LiveScoresListPageState();
}

class _LiveScoresListPageState extends State<LiveScoresListPage> {
  final MatchService _matchService = MatchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _matches = [];
  final Set<String> _allTeams = {};
  final Set<String> _allPlayers = {};
  final Set<String> _selectedTeams = {};
  final Set<String> _selectedPlayers = {};

  // Maps to store names keyed by IDs
  final Map<String, String> _teamNames = {};
  final Map<String, String> _playerNames = {};

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _loading = true;
      _teamNames.clear();
      _playerNames.clear();
    });

    final now = DateTime.now();
    final matches = await _matchService.getMatchesByDate(now);

    // Collect all team and player IDs
    final Set<String> teamIds = {};
    final Set<String> playerIds = {};

    for (final m in matches) {
      final teams = List<String>.from(m['teams'] ?? []);
      teamIds.addAll(teams);
      _allTeams.addAll(teams);

      final players = (m['players'] as Map<String, dynamic>?) ?? {};
      for (final list in players.values) {
        final playerList = List<String>.from(list);
        playerIds.addAll(playerList);
        _allPlayers.addAll(playerList);
      }

      final count = await _matchService.holeResultCount(m['eventId'], m['id']);
      m['_holeCount'] = count;
    }

    // Fetch team names
    await _fetchTeamNames(teamIds);

    // Fetch player names
    await _fetchPlayerNames(playerIds);

    setState(() {
      _matches = matches;
      _loading = false;
    });
  }

  // Fetch team names from Firestore
  Future<void> _fetchTeamNames(Set<String> teamIds) async {
    for (final teamId in teamIds) {
      try {
        // First find which event this team belongs to
        final eventQuery = await _firestore.collection('events').get();

        for (final eventDoc in eventQuery.docs) {
          final teamDoc =
              await _firestore
                  .collection('events')
                  .doc(eventDoc.id)
                  .collection('teams')
                  .doc(teamId)
                  .get();

          if (teamDoc.exists) {
            final data = teamDoc.data();
            if (data != null) {
              _teamNames[teamId] = data['teamName'] ?? 'Unknown Team';
              break;
            }
          }
        }

        // If team name wasn't found, use a placeholder
        if (!_teamNames.containsKey(teamId)) {
          _teamNames[teamId] = 'Team $teamId';
        }
      } catch (e) {
        print('Error fetching team name for $teamId: $e');
        _teamNames[teamId] = 'Team $teamId';
      }
    }
  }

  // Fetch player names from Firestore
  Future<void> _fetchPlayerNames(Set<String> playerIds) async {
    for (final playerId in playerIds) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(playerId).get();

        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            final firstName = data['firstName'] ?? '';
            final lastName = data['lastName'] ?? '';

            if (firstName.isNotEmpty || lastName.isNotEmpty) {
              _playerNames[playerId] = '$firstName $lastName'.trim();
            } else {
              _playerNames[playerId] = data['email'] ?? 'Unknown Player';
            }
          }
        }

        // If player name wasn't found, use a placeholder
        if (!_playerNames.containsKey(playerId)) {
          _playerNames[playerId] = 'Player $playerId';
        }
      } catch (e) {
        print('Error fetching player name for $playerId: $e');
        _playerNames[playerId] = 'Player $playerId';
      }
    }
  }

  // Get team name by ID
  String _getTeamName(String teamId) {
    return _teamNames[teamId] ?? 'Team $teamId';
  }

  // Get player name by ID
  String _getPlayerName(String playerId) {
    return _playerNames[playerId] ?? 'Player $playerId';
  }

  List<Map<String, dynamic>> get _filteredMatches {
    return _matches.where((m) {
      final teams = List<String>.from(m['teams'] ?? []);
      final playersMap = Map<String, dynamic>.from(m['players'] ?? {});
      final players =
          playersMap.values
              .expand((p) => List<String>.from(p as List))
              .toList();
      if (_selectedTeams.isNotEmpty &&
          !_selectedTeams.any((t) => teams.contains(t))) {
        return false;
      }
      if (_selectedPlayers.isNotEmpty &&
          !_selectedPlayers.any((p) => players.contains(p))) {
        return false;
      }
      return true;
    }).toList();
  }

  void _toggleTeam(String team) {
    setState(() {
      if (_selectedTeams.contains(team)) {
        _selectedTeams.remove(team);
      } else {
        _selectedTeams.add(team);
      }
    });
  }

  void _togglePlayer(String player) {
    setState(() {
      if (_selectedPlayers.contains(player)) {
        _selectedPlayers.remove(player);
      } else {
        _selectedPlayers.add(player);
      }
    });
  }

  String _statusFor(Map<String, dynamic> m) {
    if (m['matchOver'] == true) return 'Finished';
    if ((m['_holeCount'] ?? 0) == 0) return 'Not Started';
    return 'In Play';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Scores'),
        actions: [
          IconButton(onPressed: _loadMatches, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (_allTeams.isNotEmpty)
                    ExpansionTile(
                      title: const Text('Filter Teams'),
                      children:
                          _allTeams
                              .map(
                                (t) => CheckboxListTile(
                                  value: _selectedTeams.contains(t),
                                  onChanged: (_) => _toggleTeam(t),
                                  title: Text(_getTeamName(t)),
                                ),
                              )
                              .toList(),
                    ),
                  if (_allPlayers.isNotEmpty)
                    ExpansionTile(
                      title: const Text('Filter Players'),
                      children:
                          _allPlayers
                              .map(
                                (p) => CheckboxListTile(
                                  value: _selectedPlayers.contains(p),
                                  onChanged: (_) => _togglePlayer(p),
                                  title: Text(_getPlayerName(p)),
                                ),
                              )
                              .toList(),
                    ),
                  Expanded(
                    child:
                        _filteredMatches.isEmpty
                            ? const Center(child: Text('No matches today'))
                            : ListView.builder(
                              itemCount: _filteredMatches.length,
                              itemBuilder: (context, index) {
                                final m = _filteredMatches[index];
                                final dt =
                                    (m['matchDateTime'] as Timestamp).toDate();
                                final teams = List<String>.from(
                                  m['teams'] ?? [],
                                );

                                // Get team names for display
                                final teamNames =
                                    teams
                                        .map((teamId) => _getTeamName(teamId))
                                        .toList();

                                // Get player names for display
                                final playersMap = Map<String, dynamic>.from(
                                  m['players'] ?? {},
                                );
                                final allPlayerIds =
                                    playersMap.values
                                        .expand(
                                          (e) => List<String>.from(e as List),
                                        )
                                        .toList();
                                final playerNames =
                                    allPlayerIds
                                        .map(
                                          (playerId) =>
                                              _getPlayerName(playerId),
                                        )
                                        .toList();

                                return Card(
                                  margin: const EdgeInsets.all(8),
                                  child: ListTile(
                                    title: Text(
                                      teamNames.join(' vs '),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tee: ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                        ),
                                        Text(
                                          'Players: ${playerNames.join(', ')}',
                                        ),
                                      ],
                                    ),
                                    trailing: Chip(label: Text(_statusFor(m))),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/live-score-detail',
                                        arguments: {
                                          'eventId': m['eventId'],
                                          'matchId': m['id'],
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
