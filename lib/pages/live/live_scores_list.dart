import 'package:flutter/material.dart';
import 'package:mgm_gc/services/match_service.dart';

class LiveScoresListPage extends StatefulWidget {
  const LiveScoresListPage({super.key});

  @override
  State<LiveScoresListPage> createState() => _LiveScoresListPageState();
}

class _LiveScoresListPageState extends State<LiveScoresListPage> {
  final MatchService _matchService = MatchService();
  bool _loading = true;
  List<Map<String, dynamic>> _matches = [];
  final Set<String> _allTeams = {};
  final Set<String> _allPlayers = {};
  final Set<String> _selectedTeams = {};
  final Set<String> _selectedPlayers = {};

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _loading = true;
    });
    final now = DateTime.now();
    final matches = await _matchService.getMatchesByDate(now);
    for (final m in matches) {
      final teams = List<String>.from(m['teams'] ?? []);
      _allTeams.addAll(teams);
      final players = (m['players'] as Map<String, dynamic>?) ?? {};
      for (final list in players.values) {
        _allPlayers.addAll(List<String>.from(list));
      }
      final count = await _matchService.holeResultCount(m['eventId'], m['id']);
      m['_holeCount'] = count;
    }
    setState(() {
      _matches = matches;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredMatches {
    return _matches.where((m) {
      final teams = List<String>.from(m['teams'] ?? []);
      final playersMap = Map<String, dynamic>.from(m['players'] ?? {});
      final players = playersMap.values
          .expand((p) => List<String>.from(p as List))
          .toList();
      if (_selectedTeams.isNotEmpty &&
          !_selectedTeams.any((t) => teams.contains(t))) return false;
      if (_selectedPlayers.isNotEmpty &&
          !_selectedPlayers.any((p) => players.contains(p))) return false;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_allTeams.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Filter Teams'),
                    children: _allTeams
                        .map(
                          (t) => CheckboxListTile(
                            value: _selectedTeams.contains(t),
                            onChanged: (_) => _toggleTeam(t),
                            title: Text(t),
                          ),
                        )
                        .toList(),
                  ),
                if (_allPlayers.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Filter Players'),
                    children: _allPlayers
                        .map(
                          (p) => CheckboxListTile(
                            value: _selectedPlayers.contains(p),
                            onChanged: (_) => _togglePlayer(p),
                            title: Text(p),
                          ),
                        )
                        .toList(),
                  ),
                Expanded(
                  child: _filteredMatches.isEmpty
                      ? const Center(child: Text('No matches today'))
                      : ListView.builder(
                          itemCount: _filteredMatches.length,
                          itemBuilder: (context, index) {
                            final m = _filteredMatches[index];
                            final dt =
                                (m['matchDateTime'] as Timestamp).toDate();
                            final teams = List<String>.from(m['teams'] ?? []);
                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ListTile(
                                title: Text(
                                  teams.join(' vs '),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tee: ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'),
                                    Text('Players: ' + (Map<String, dynamic>.from(m['players'] ?? {})
                                            .values
                                            .expand((e) => List<String>.from(e as List))
                                            .join(', '))),
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
