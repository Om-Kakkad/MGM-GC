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
  Map<int, HoleResult> _results = {};
  bool _loading = true;
  bool _matchOver = false;
  bool _bonus = false;
  bool _isAdmin = false;
  String _matchPlayType = 'match play';
  List<String> _teamA = [];
  List<String> _teamB = [];
  final Map<String, double> _handicaps = {};
  final Map<String, int> _strokeDiffs = {};
  final Map<String, int> _teamStrokeDiffs = {};
  final Map<int, int> _runningDiffs = {};

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
    _bonus = matchData['bonusPoint'] ?? false;
    _matchPlayType = matchData['matchPlayType'] ?? 'match play';
    _teamA = List<String>.from(matchData['players']?['teamA'] ?? []);
    _teamB = List<String>.from(matchData['players']?['teamB'] ?? []);

    final uid = _authService.currentUser?.uid;
    final participantUids = List<String>.from(matchData['participantUids'] ?? []);
    final DateTime scheduled = (matchData['matchDateTime'] as Timestamp).toDate();
    final bool allowed = uid != null && participantUids.contains(uid) &&
        DateUtils.isSameDay(scheduled, DateTime.now());
    if(!allowed){
      if(mounted){
        Navigator.pop(context);
      }
      return;
    }

    final userData = uid != null ? await _authService.getUserData(uid) : null;
    _isAdmin = userData?.role == 'admin';

    final toFetch = [..._teamA, ..._teamB];
    _handicaps.clear();
    for (final id in toFetch) {
      final u = await _authService.getUserData(id);
      _handicaps[id] = u.golfDetails.handicap?.toDouble() ?? 0;
    }

    _strokeDiffs.clear();
    _teamStrokeDiffs.clear();
    if (_matchPlayType == 'greensome') {
      double lowA = 999;
      double highA = 0;
      for (final id in _teamA) {
        final h = _handicaps[id] ?? 0;
        if (h < lowA) lowA = h;
        if (h > highA) highA = h;
      }
      double lowB = 999;
      double highB = 0;
      for (final id in _teamB) {
        final h = _handicaps[id] ?? 0;
        if (h < lowB) lowB = h;
        if (h > highB) highB = h;
      }
      int pairA = ((0.6 * lowA) + (0.4 * highA)).round();
      int pairB = ((0.6 * lowB) + (0.4 * highB)).round();
      int lowPair = pairA < pairB ? pairA : pairB;
      _teamStrokeDiffs['A'] = pairA - lowPair;
      _teamStrokeDiffs['B'] = pairB - lowPair;
    } else {
      double lowest = 999;
      for (final h in _handicaps.values) {
        if (h < lowest) lowest = h;
      }
      _handicaps.forEach((uid, h) {
        _strokeDiffs[uid] = (h - lowest).round();
      });
    }

    _updateRunningResults();
    setState(() => _loading = false);
  }

  Future<void> _setHoleResult(int hole, String res) async {
    final newRes = HoleResult(result: res);
    await _matchService.updateHoleResult(eventId, matchId, hole, newRes.toMap());
    _results[hole] = newRes;
    _updateRunningResults();
    if (mounted) setState(() {});
  }

  int _dotsFor(int diff, int hole) {
    if (diff <= 0) return 0;
    final si = strokeIndex[hole - 1];
    final loops = diff ~/ 18;
    final rem = diff % 18;
    return loops + (si <= rem ? 1 : 0);
  }

  void _updateRunningResults() {
    int diff = 0;
    for (var i = 1; i <= 18; i++) {
      final res = _results[i];
      if (res != null) {
        if (res.result == 'A') diff++;
        if (res.result == 'B') diff--;
      }
      _runningDiffs[i] = diff;
    }
  }

  Map<String, num> _calculatePoints() {
    num aPoints = 0;
    num bPoints = 0;
    int diff = 0;
    int endHole = 18;
    for (var i = 1; i <= 18; i++) {
      final res = _results[i];
      if (res != null) {
        switch (res.result) {
          case 'A':
            aPoints += 2;
            diff++;
            break;
          case 'B':
            bPoints += 2;
            diff--;
            break;
          case 'AS':
            aPoints += 1;
            bPoints += 1;
            break;
        }
      }
      if (_bonus && endHole == 18) {
        final holesLeft = 18 - i;
        if (diff.abs() > holesLeft) {
          endHole = i;
        }
      }
    }

    num aBonus = 0;
    num bBonus = 0;
    if (_bonus && endHole < 18) {
      int bonusDiff = 0;
      for (var i = endHole + 1; i <= 18; i++) {
        final res = _results[i];
        if (res != null) {
          if (res.result == 'A') bonusDiff++;
          if (res.result == 'B') bonusDiff--;
        }
      }
      if (bonusDiff > 0) aBonus = 0.5;
      if (bonusDiff < 0) bBonus = 0.5;
    }

    return {
      'a': aPoints,
      'b': bPoints,
      'aBonus': aBonus,
      'bBonus': bBonus,
    };
  }

  Widget _buildRow(int hole) {
    final res = _results[hole];

    // Determine display of running result under this hole
    final diff = _runningDiffs[hole] ?? 0;
    final remaining = 18 - hole;
    String bannerText;
    if (diff == 0) {
      bannerText = 'All Square';
    } else if (diff > 0) {
      bannerText = diff > remaining
          ? 'Team A wins $diff & $remaining'
          : 'Team A +$diff';
    } else {
      final abs = -diff;
      bannerText = abs > remaining
          ? 'Team B wins $abs & $remaining'
          : 'Team B +$abs';
    }

    final banner = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(bannerText),
    );

    final dotsA = _matchPlayType == 'greensome'
        ? _dotsFor(_teamStrokeDiffs['A'] ?? 0, hole)
        : _teamA.isNotEmpty
            ? _dotsFor(_strokeDiffs[_teamA.first] ?? 0, hole)
            : 0;
    final dotsB = _matchPlayType == 'greensome'
        ? _dotsFor(_teamStrokeDiffs['B'] ?? 0, hole)
        : _teamB.isNotEmpty
            ? _dotsFor(_strokeDiffs[_teamB.first] ?? 0, hole)
            : 0;

    Widget buildToggle(String team, int dots) {
      final current = res?.result ?? 'AS';
      int index;
      if (team == 'A') {
        if (current == 'A') {
          index = 0;
        } else if (current == 'AS') {
          index = 1;
        } else {
          index = 2; // B wins -> A loss
        }
      } else {
        if (current == 'B') {
          index = 0;
        } else if (current == 'AS') {
          index = 1;
        } else {
          index = 2; // A wins -> B loss
        }
      }

      return Row(
        children: [
          ToggleButtons(
            isSelected: [index == 0, index == 1, index == 2],
            onPressed: _matchOver && !_isAdmin
                ? null
                : (i) {
                    String newRes;
                    if (team == 'A') {
                      if (i == 0) newRes = 'A';
                      else if (i == 1) newRes = 'AS';
                      else newRes = 'B';
                    } else {
                      if (i == 0) newRes = 'B';
                      else if (i == 1) newRes = 'AS';
                      else newRes = 'A';
                    }
                    _setHoleResult(hole, newRes);
                  },
            children: const [
              Icon(Icons.check),
              Icon(Icons.remove),
              Icon(Icons.close),
            ],
          ),
          if (dots > 0) Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('•' * dots),
          ),
        ],
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(width: 24, child: Text(hole.toString())),
                SizedBox(width: 24, child: Text(pars[hole - 1].toString())),
                SizedBox(width: 24, child: Text(strokeIndex[hole - 1].toString())),
                Expanded(child: buildToggle('A', dotsA)),
                const SizedBox(width: 8),
                Expanded(child: buildToggle('B', dotsB)),
              ],
            ),
          ),
        ),
        banner,
      ],
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
              onPressed: _matchOver && !_isAdmin
                  ? null
                  : () async {
                      final pts = _calculatePoints();
                      await _matchService.setMatchOver(
                        eventId,
                        matchId,
                        regularPoints: pts['a']!,
                        bonusPoints: pts['aBonus']!,
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
