import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/match_service.dart';

class MatchScoringPage extends StatefulWidget {
  final String eventId;
  final String matchId;

  const MatchScoringPage({super.key, required this.eventId, required this.matchId});

  @override
  State<MatchScoringPage> createState() => _MatchScoringPageState();
}

class _MatchScoringPageState extends State<MatchScoringPage> {
  final MatchService _matchService = MatchService();
  Map<String, dynamic>? _matchData;
  final Map<String, double> _handicaps = {};
  final Map<int, Map<String, dynamic>> _holeResults = {};
  bool _loading = true;
  DateTime? _matchDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    Map<String, dynamic>? match =
        await _matchService.getMatchById(widget.eventId, widget.matchId);

    if (match != null) {
      _matchDate = (match['matchDateTime'] as Timestamp).toDate();
      Map<String, dynamic> players = Map<String, dynamic>.from(match['players']);

      for (var team in players.values) {
        for (var playerId in List<String>.from(team)) {
          DocumentSnapshot doc =
              await FirebaseFirestore.instance.collection('users').doc(playerId).get();
          double handicap =
              (doc.data() as Map<String, dynamic>)['golfDetails']?['handicap']?.toDouble() ?? 0;
          _handicaps[playerId] = handicap;
        }
      }

      Map<String, dynamic> holeResults =
          Map<String, dynamic>.from(match['holeResults'] ?? {});
      holeResults.forEach((key, value) {
        int number = int.parse(key.split('_')[1]);
        _holeResults[number] = Map<String, dynamic>.from(value);
      });
    }

    setState(() {
      _matchData = match;
      _loading = false;
    });
  }

  bool get _isMatchDay {
    if (_matchDate == null) return false;
    DateTime now = DateTime.now();
    return now.year == _matchDate!.year &&
        now.month == _matchDate!.month &&
        now.day == _matchDate!.day;
  }

  bool get _canEdit {
    if (!_isMatchDay || _matchDate == null) return false;
    DateTime cutoff = DateTime(
      _matchDate!.year,
      _matchDate!.month,
      _matchDate!.day,
      20,
    );
    return DateTime.now().isBefore(cutoff);
  }

  List<int> get _holes => List<int>.generate(18, (index) => index + 1);

  List<int> _strokeHoles() {
    if (_matchData == null) return [];
    Map<String, dynamic> players = Map<String, dynamic>.from(_matchData!['players']);
    List<String> teamAPlayers = List<String>.from(players['teamA'] ?? []);
    List<String> teamBPlayers = List<String>.from(players['teamB'] ?? []);

    double handicapA = teamAPlayers
        .map((p) => _handicaps[p] ?? 0)
        .fold(0.0, (a, b) => a + b) /
        (teamAPlayers.isEmpty ? 1 : teamAPlayers.length);
    double handicapB = teamBPlayers
        .map((p) => _handicaps[p] ?? 0)
        .fold(0.0, (a, b) => a + b) /
        (teamBPlayers.isEmpty ? 1 : teamBPlayers.length);

    int diff = (handicapA - handicapB).abs().round();
    return List<int>.generate(diff.clamp(0, 18), (i) => i + 1);
  }

  void _setHoleResult(int hole, String result) async {
    Map<String, dynamic> data;
    if (result == 'AS') {
      data = {'teamA': 'AS', 'teamB': 'AS'};
    } else if (result == 'A') {
      data = {'teamA': 'Win', 'teamB': 'Loss'};
    } else {
      data = {'teamA': 'Loss', 'teamB': 'Win'};
    }
    _holeResults[hole] = data;
    await _matchService.updateHoleResult(widget.eventId, widget.matchId, hole, data);

    if (_holeResults.length == _holes.length) {
      await _finalizeMatch();
    }
    setState(() {});
  }

  Future<void> _finalizeMatch() async {
    int aWins = 0;
    int bWins = 0;
    int halves = 0;

    for (var data in _holeResults.values) {
      if (data['teamA'] == 'Win') {
        aWins++;
      } else if (data['teamB'] == 'Win') {
        bWins++;
      } else {
        halves++;
      }
    }

    double ptsA = aWins + halves * 0.5;
    double ptsB = bWins + halves * 0.5;

    await _matchService.updateMatchStatus(
      widget.eventId,
      widget.matchId,
      'completed',
      leaguePoints: {'teamA': ptsA, 'teamB': ptsB},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final strokeHoles = _matchData?['matchType'] == 'Matchplay' ? _strokeHoles() : <int>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Match Scoring')),
      body: ListView(
        children: _holes.map((hole) {
          final data = _holeResults[hole] ?? {};
          return Card(
            child: ListTile(
              title: Text(
                'Hole $hole${strokeHoles.contains(hole) ? " - Stroke" : ""}',
              ),
              subtitle: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canEdit ? () => _setHoleResult(hole, 'A') : null,
                      child: Text(data['teamA'] == 'Win' ? 'Team A Win' : 'Team A'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canEdit ? () => _setHoleResult(hole, 'AS') : null,
                      child: Text(data['teamA'] == 'AS' ? 'Halved' : 'AS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canEdit ? () => _setHoleResult(hole, 'B') : null,
                      child: Text(data['teamB'] == 'Win' ? 'Team B Win' : 'Team B'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
