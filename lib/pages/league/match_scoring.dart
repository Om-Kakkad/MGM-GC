import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/hole_result.dart';
import '../../services/match_service.dart';
import '../../services/auth_service.dart';

class MatchScoringPage extends StatefulWidget {
  const MatchScoringPage({super.key});

  @override
  State<MatchScoringPage> createState() => _MatchScoringPageState();
}

class _MatchScoringPageState extends State<MatchScoringPage> {
  final MatchService _matchService = MatchService();
  final AuthService _authService = AuthService();

  late String eventId;
  late String matchId;
  final Map<int, HoleResult> _results = {};
  bool _loading = true;
  bool _matchOver = false;

  final List<int> pars = [
    4,4,3,4,5,4,4,3,5,
    4,5,3,4,4,4,3,4,5
  ];

  final List<int> strokeIndex = [
    18,8,2,10,4,14,6,16,12,
    9,1,13,3,15,11,17,7,5
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    eventId = args['eventId']!;
    matchId = args['matchId']!;
    _loadData();
  }

  Future<void> _loadData() async {
    for (var i = 1; i <= 18; i++) {
      final data = await _matchService.getHoleResult(eventId, matchId, i);
      if (data != null) {
        _results[i] = HoleResult.fromMap(data);
      }
    }
    final matchDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('matches')
        .doc(matchId)
        .get();
    final matchData = matchDoc.data() ?? {};
    _matchOver = (matchData['matchOver'] ?? false) as bool;

    final uid = _authService.currentUser?.uid;
    final players = matchData['players'] as Map<String, dynamic>? ?? {};
    final participantUids = <String>[];
    players.forEach((k,v){
      if (v is List) {
        participantUids.addAll(v.cast<String>());
      }
    });
    final DateTime scheduled = (matchData['matchDateTime'] as Timestamp).toDate();
    final bool allowed = uid != null && participantUids.contains(uid) &&
        DateUtils.isSameDay(scheduled, DateTime.now());
    if(!allowed){
      if(mounted){
        Navigator.pop(context);
      }
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _saveHole(int hole) async {
    final result = _results[hole];
    if (result == null) return;
    String res = 'AS';
    if (result.strokesA < result.strokesB) {
      res = 'W';
    } else if (result.strokesB < result.strokesA) {
      res = 'L';
    }
    final newRes = HoleResult(
      strokesA: result.strokesA,
      strokesB: result.strokesB,
      result: res,
    );
    await _matchService.updateHoleResult(eventId, matchId, hole, newRes.toMap());
    _results[hole] = newRes;
    await _loadData();
  }

  Map<String, num> _calculatePoints() {
    num aPoints = 0;
    num bPoints = 0;
    for (final entry in _results.entries) {
      switch (entry.value.result) {
        case 'W':
          aPoints += 2;
          break;
        case 'L':
          bPoints += 2;
          break;
        case 'AS':
          aPoints += 1;
          bPoints += 1;
          break;
      }
    }
    return {'a': aPoints, 'b': bPoints};
  }

  Widget _buildRow(int hole) {
    final res = _results[hole];
    final strokesAController = TextEditingController(text: res?.strokesA.toString() ?? '');
    final strokesBController = TextEditingController(text: res?.strokesB.toString() ?? '');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text(hole.toString())),
            SizedBox(width: 24, child: Text(pars[hole-1].toString())),
            SizedBox(width: 24, child: Text(strokeIndex[hole-1].toString())),
            Expanded(
              child: TextField(
                controller: strokesAController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'A'),
                onChanged: (val) {
                  final a = int.tryParse(val) ?? 0;
                  final existing = _results[hole];
                  _results[hole] = HoleResult(
                    strokesA: a,
                    strokesB: existing?.strokesB ?? 0,
                    result: existing?.result ?? 'AS',
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: strokesBController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'B'),
                onChanged: (val) {
                  final b = int.tryParse(val) ?? 0;
                  final existing = _results[hole];
                  _results[hole] = HoleResult(
                    strokesA: existing?.strokesA ?? 0,
                    strokesB: b,
                    result: existing?.result ?? 'AS',
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _matchOver ? null : () => _saveHole(hole),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Match Scoring')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: 18,
              itemBuilder: (context, index) => _buildRow(index + 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _matchOver
                  ? null
                  : () async {
                      final pts = _calculatePoints();
                      await _matchService.setMatchOver(
                        eventId,
                        matchId,
                        regularPoints: pts['a']!,
                        bonusPoints: 0,
                      );
                      await _loadData();
                    },
              child: const Text('Match Over'),
            ),
          ),
        ],
      ),
    );
  }
}
