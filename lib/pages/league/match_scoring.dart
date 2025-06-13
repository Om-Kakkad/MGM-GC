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
  bool _bonus = false;
  bool _isAdmin = false;
  String _matchPlayType = 'match play';
  // Change from String to List<String>
  List<String> _teamA = [];
  List<String> _teamB = [];
  // Add new variables for team names and player info
  String _teamAName = "Team A";
  String _teamBName = "Team B";
  List<Map<String, dynamic>> _teamAPlayerInfo = [];
  List<Map<String, dynamic>> _teamBPlayerInfo = [];
  final Map<String, double> _handicaps = {};
  final Map<String, int> _strokeDiffs = {};
  final Map<String, int> _teamStrokeDiffs = {};
  final Map<int, int> _runningDiffs = {};

  final List<int> pars = [4, 4, 3, 4, 5, 4, 4, 3, 5, 4, 5, 3, 4, 4, 4, 3, 4, 5];

  final List<int> strokeIndex = [
    18,
    8,
    2,
    10,
    4,
    14,
    6,
    16,
    12,
    9,
    1,
    13,
    3,
    15,
    11,
    17,
    7,
    5,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String>;
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
    final matchDoc =
        await FirebaseFirestore.instance
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

    // Fetch team names
    if (matchData['teams'] != null &&
        (matchData['teams'] as List).length >= 2) {
      List<String> teams = List<String>.from(matchData['teams']);
      if (teams.length >= 2) {
        await _fetchTeamName(teams[0], true);
        await _fetchTeamName(teams[1], false);
      }
    }

    final uid = _authService.currentUser?.uid;
    final participantUids = List<String>.from(
      matchData['participantUids'] ?? [],
    );
    final DateTime scheduled =
        (matchData['matchDateTime'] as Timestamp).toDate();
    final bool allowed =
        uid != null &&
        participantUids.contains(uid) &&
        DateUtils.isSameDay(scheduled, DateTime.now());
    if (!allowed) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    final userData = uid != null ? await _authService.getUserData(uid) : null;
    _isAdmin = userData?.role == 'admin';

    // Now the spread operator works correctly with lists
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

    // Fetch player information for initials
    _teamAPlayerInfo = await _fetchPlayersInfo(_teamA);
    _teamBPlayerInfo = await _fetchPlayersInfo(_teamB);

    _updateRunningResults();
    setState(() => _loading = false);
  }

  // Add method to fetch team name
  Future<void> _fetchTeamName(String teamId, bool isTeamA) async {
    try {
      final teamDoc =
          await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(teamId)
              .get();

      if (teamDoc.exists) {
        final data = teamDoc.data();
        if (data != null) {
          final name =
              data['teamName'] ??
              data['name'] ??
              (isTeamA ? 'Team A' : 'Team B');
          setState(() {
            if (isTeamA) {
              _teamAName = name;
            } else {
              _teamBName = name;
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching team name: $e');
    }
  }

  // Add method to fetch player info for initials
  Future<List<Map<String, dynamic>>> _fetchPlayersInfo(
    List<String> playerIds,
  ) async {
    List<Map<String, dynamic>> result = [];
    for (String id in playerIds) {
      try {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final firstName = data['firstName'] as String? ?? '';
          final lastName = data['lastName'] as String? ?? '';
          final initials =
              (firstName.isNotEmpty ? firstName[0] : '') +
              (lastName.isNotEmpty ? lastName[0] : '');
          result.add({
            'id': id,
            'initials': initials.isNotEmpty ? initials : 'P',
            'handicap': data['golfDetails']?['handicap'],
          });
        }
      } catch (e) {
        print('Error fetching player info: $e');
      }
    }
    return result;
  }

  Future<void> _setHoleResult(int hole, String res) async {
    final newRes = HoleResult(result: res);
    await _matchService.updateHoleResult(
      eventId,
      matchId,
      hole,
      newRes.toMap(),
    );
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

    return {'a': aPoints, 'b': bPoints, 'aBonus': aBonus, 'bBonus': bBonus};
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
      bannerText =
          diff > remaining ? 'Team A wins $diff & $remaining' : 'Team A +$diff';
    } else {
      final abs = -diff;
      bannerText =
          abs > remaining ? 'Team B wins $abs & $remaining' : 'Team B +$abs';
    }

    final banner = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(bannerText),
    );

    final dotsA =
        _matchPlayType == 'greensome'
            ? _dotsFor(_teamStrokeDiffs['A'] ?? 0, hole)
            : _teamA.isNotEmpty
            ? _dotsFor(_strokeDiffs[_teamA.first] ?? 0, hole)
            : 0;
    final dotsB =
        _matchPlayType == 'greensome'
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
        mainAxisSize: MainAxisSize.min, // Use minimum space required
        children: [
          Flexible(
            child: ToggleButtons(
              isSelected: [index == 0, index == 1, index == 2],
              onPressed:
                  _matchOver && !_isAdmin
                      ? null
                      : (i) {
                        String newRes;
                        if (team == 'A') {
                          if (i == 0)
                            newRes = 'A';
                          else if (i == 1)
                            newRes = 'AS';
                          else
                            newRes = 'B';
                        } else {
                          if (i == 0)
                            newRes = 'B';
                          else if (i == 1)
                            newRes = 'AS';
                          else
                            newRes = 'A';
                        }
                        _setHoleResult(hole, newRes);
                      },
              constraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 36,
              ), // Smaller constraints
              children: const [
                Icon(Icons.check, size: 18),
                Icon(Icons.remove, size: 18),
                Icon(Icons.close, size: 18),
              ],
            ),
          ),
          if (dots > 0)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '•' * dots,
                  overflow: TextOverflow.ellipsis, // Handle overflow gracefully
                  style: const TextStyle(fontSize: 12), // Smaller font size
                ),
              ),
            ),
        ],
      );
    }

    // Create a widget for team header with name and player initials
    Widget buildTeamHeader(
      String teamName,
      List<Map<String, dynamic>> players,
    ) {
      return Column(
        children: [
          Text(
            teamName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                players.map((player) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Tooltip(
                      message: 'Handicap: ${player['handicap'] ?? 'N/A'}',
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          player['initials'],
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Add team headers before the card if this is the first hole
        if (hole == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const SizedBox(width: 60), // Space for hole, par, SI
                Expanded(
                  flex: 5,
                  child: buildTeamHeader(_teamAName, _teamAPlayerInfo),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 5,
                  child: buildTeamHeader(_teamBName, _teamBPlayerInfo),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(hole.toString()),
                ), // Reduced width
                SizedBox(
                  width: 20,
                  child: Text(pars[hole - 1].toString()),
                ), // Reduced width
                SizedBox(
                  width: 20,
                  child: Text(strokeIndex[hole - 1].toString()),
                ), // Reduced width
                Expanded(
                  flex: 5, // Allocate more space for Team A
                  child: buildToggle('A', dotsA),
                ),
                const SizedBox(width: 4), // Reduced spacing
                Expanded(
                  flex: 5, // Allocate more space for Team B
                  child: buildToggle('B', dotsB),
                ),
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
              onPressed:
                  _matchOver && !_isAdmin
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
