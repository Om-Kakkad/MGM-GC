import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  List<String> _teamA = [];
  List<String> _teamB = [];
  String _teamAName = "Team A";
  String _teamBName = "Team B";
  List<Map<String, dynamic>> _teamAPlayerInfo = [];
  List<Map<String, dynamic>> _teamBPlayerInfo = [];
  final Map<String, double> _handicaps = {};
  final Map<String, int> _strokeDiffs = {};
  final Map<String, int> _teamStrokeDiffs = {};
  final Map<int, int> _runningDiffs = {};
  Map<String, List<int>> _strokeMap = {};
  DateTime _matchDateTime = DateTime.now();
  String _matchType = '4-ball';

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

    // Get match details
    final matchDetails = await _matchService.getMatchDetails(eventId, matchId);
    if (matchDetails == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load match details')),
        );
        Navigator.pop(context);
      }
      return;
    }

    final matchData = matchDetails;
    _matchOver = (matchData['matchOver'] ?? false) as bool;
    _bonus = matchData['bonusPoint'] ?? false;
    _matchPlayType = matchData['matchPlayType'] ?? 'match play';
    _matchType = matchData['matchType'] ?? '4-ball';
    _teamA = List<String>.from(matchData['players']?['teamA'] ?? []);
    _teamB = List<String>.from(matchData['players']?['teamB'] ?? []);

    // Get match date time
    if (matchData['matchDateTime'] != null) {
      _matchDateTime = (matchData['matchDateTime'] as Timestamp).toDate();
    }

    _strokeMap = {};
    if (matchData['strokeMap'] != null) {
      final sm = Map<String, dynamic>.from(matchData['strokeMap']);
      _strokeMap = {
        for (final e in sm.entries) e.key: List<int>.from(e.value as List),
      };
    }

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

    // Check if user is allowed to access this match
    final bool allowed =
        uid != null &&
        participantUids.contains(uid) &&
        DateUtils.isSameDay(scheduled, DateTime.now());

    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are not authorized to score this match or the match is not scheduled for today',
            ),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    final userData = uid != null ? await _authService.getUserData(uid) : null;
    _isAdmin = userData?.role == 'admin';

    // Fetch player handicaps
    final toFetch = [..._teamA, ..._teamB];
    _handicaps.clear();
    for (final id in toFetch) {
      final u = await _authService.getUserData(id);
      _handicaps[id] = u.golfDetails.handicap?.toDouble() ?? 0;
    }

    // Calculate stroke differences
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
      // Calculate pair handicaps using the formula: 0.6 × low + 0.4 × high
      // Using round() which rounds up for fractions >= 0.5
      int pairA = ((0.6 * lowA) + (0.4 * highA)).round();
      int pairB = ((0.6 * lowB) + (0.4 * highB)).round();

      // Find the lower handicap pair to calculate stroke differences
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

    // Calculate stroke map if not already available
    if (_strokeMap.isEmpty && !_matchOver) {
      Map<String, List<int>> sm = {};
      List<int> holesFor(int diff) {
        final holes = <int>[];
        if (diff <= 0) return holes;
        final loops = diff ~/ 18;
        final rem = diff % 18;
        for (var i = 1; i <= 18; i++) {
          var count = loops + (strokeIndex[i - 1] <= rem ? 1 : 0);
          for (var j = 0; j < count; j++) {
            holes.add(i);
          }
        }
        return holes;
      }

      if (_matchPlayType == 'greensome') {
        sm['A'] = holesFor(_teamStrokeDiffs['A'] ?? 0);
        sm['B'] = holesFor(_teamStrokeDiffs['B'] ?? 0);
      } else {
        for (final id in _teamA) {
          sm['A_$id'] = holesFor(_strokeDiffs[id] ?? 0);
        }
        for (final id in _teamB) {
          sm['B_$id'] = holesFor(_strokeDiffs[id] ?? 0);
        }
      }
      await _matchService.updateStrokeMap(eventId, matchId, sm);
      _strokeMap = sm;
    }

    // Fetch player information for initials
    _teamAPlayerInfo = await _fetchPlayersInfo(_teamA);
    _teamBPlayerInfo = await _fetchPlayersInfo(_teamB);

    _updateRunningResults();
    setState(() => _loading = false);
  }

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
              ((firstName.isNotEmpty ? firstName[0] : '') +
                      (lastName.isNotEmpty ? lastName[0] : ''))
                  .toUpperCase();
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

  // Get a descriptive status string for the current match
  String _getMatchStatusText() {
    int lastHole = 18;
    int? finalDiff;

    for (int i = 18; i >= 1; i--) {
      if (_results.containsKey(i)) {
        finalDiff = _runningDiffs[i];
        lastHole = i;
        break;
      }
    }

    if (finalDiff == null) return 'Match not started';

    if (finalDiff == 0) return 'All Square';

    final remaining = 18 - lastHole;

    if (finalDiff > 0) {
      if (finalDiff > remaining) {
        return '$_teamAName wins $finalDiff & $remaining';
      } else {
        return '$_teamAName +$finalDiff';
      }
    } else {
      final abs = -finalDiff;
      if (abs > remaining) {
        return '$_teamBName wins $abs & $remaining';
      } else {
        return '$_teamBName +$abs';
      }
    }
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
          diff > remaining
              ? '$_teamAName wins $diff & $remaining'
              : '$_teamAName +$diff';
    } else {
      final abs = -diff;
      bannerText =
          abs > remaining
              ? '$_teamBName wins $abs & $remaining'
              : '$_teamBName +$abs';
    }

    final banner = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        bannerText,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color:
              diff == 0
                  ? Colors.grey[700]
                  : diff > 0
                  ? Colors.blue
                  : Colors.orange,
        ),
      ),
    );

    int dotsForSide(String team) {
      if (_strokeMap.isNotEmpty) {
        if (_matchPlayType == 'greensome') {
          // For greensome, get strokes directly from the stroke map
          return _strokeMap[team]?.where((h) => h == hole).length ?? 0;
        } else {
          final players = team == 'A' ? _teamA : _teamB;
          int d = 0;
          for (final id in players) {
            d += _strokeMap['${team}_$id']?.where((h) => h == hole).length ?? 0;
          }
          return d;
        }
      } else {
        return _matchPlayType == 'greensome'
            ? _dotsFor(_teamStrokeDiffs[team] ?? 0, hole)
            : _teamA.isNotEmpty
            ? (team == 'A'
                ? _dotsFor(_strokeDiffs[_teamA.first] ?? 0, hole)
                : _dotsFor(_strokeDiffs[_teamB.first] ?? 0, hole))
            : 0;
      }
    }

    // New function to get formatted stroke text for a specific team
    String getStrokeText(String team) {
      final playerInfoList = team == 'A' ? _teamAPlayerInfo : _teamBPlayerInfo;
      final players = team == 'A' ? _teamA : _teamB;

      if (_matchPlayType == 'greensome') {
        // For greensome, we need to show strokes for the pair
        final dots = dotsForSide(team);
        if (dots <= 0) return '';

        // Return a simpler format for greensome
        return "Pair: ${dots == 1 ? '1 stroke' : '$dots strokes'}";
      } else {
        // For match play (4-ball, 2-ball), show individual player strokes
        final playerStrokes = <String, int>{};

        if (_strokeMap.isNotEmpty) {
          for (int i = 0; i < players.length; i++) {
            final playerId = players[i];
            final count =
                _strokeMap['${team}_$playerId']
                    ?.where((h) => h == hole)
                    .length ??
                0;
            if (count > 0) {
              final playerInfo = playerInfoList.firstWhere(
                (info) => info['id'] == playerId,
                orElse: () => {'initials': 'P$i'},
              );
              playerStrokes[playerInfo['initials']] = count;
            }
          }
        } else {
          // Fallback to simpler logic if stroke map is not available
          for (
            int i = 0;
            i < players.length && i < playerInfoList.length;
            i++
          ) {
            final playerId = players[i];
            final playerInfo = playerInfoList[i];
            final count = _dotsFor(_strokeDiffs[playerId] ?? 0, hole);
            if (count > 0) {
              playerStrokes[playerInfo['initials']] = count;
            }
          }
        }

        // Format the stroke text
        if (playerStrokes.isEmpty) return '';

        if (playerStrokes.length == playerInfoList.length &&
            playerStrokes.values.every(
              (v) => v == playerStrokes.values.first,
            )) {
          // All players get the same number of strokes
          final count = playerStrokes.values.first;
          return "All: ${count == 1 ? '1 each' : '$count each'}";
        } else {
          // Some players get different numbers of strokes
          return playerStrokes.entries
              .map((e) => "${e.key}: ${e.value == 1 ? '1' : e.value}")
              .join(' & ');
        }
      }
    }

    // Get stroke text for both teams
    final strokeTextA = getStrokeText('A');
    final strokeTextB = getStrokeText('B');

    // Combine stroke text if both teams have strokes
    String combinedStrokeText = '';
    if (strokeTextA.isNotEmpty && strokeTextB.isNotEmpty) {
      combinedStrokeText = '$strokeTextA | $strokeTextB';
    } else if (strokeTextA.isNotEmpty) {
      combinedStrokeText = strokeTextA;
    } else if (strokeTextB.isNotEmpty) {
      combinedStrokeText = strokeTextB;
    }

    // Create accessibility message
    String accessibilityMessage = '';
    if (strokeTextA.isNotEmpty) {
      accessibilityMessage += 'Team $_teamAName: $strokeTextA. ';
    }
    if (strokeTextB.isNotEmpty) {
      accessibilityMessage += 'Team $_teamBName: $strokeTextB.';
    }

    final dotsA = dotsForSide('A');
    final dotsB = dotsForSide('B');

    Widget buildToggle(String team, int dots) {
      final current = res?.result ?? 'AS';
      int index;

      // Determine the index based on current result
      if (team == 'A') {
        if (current == 'A') {
          index = 0; // Win
        } else if (current == 'AS') {
          index = 1; // All Square
        } else {
          index = 2; // Loss (B wins)
        }
      } else {
        if (current == 'B') {
          index = 0; // Win
        } else if (current == 'AS') {
          index = 1; // All Square
        } else {
          index = 2; // Loss (A wins)
        }
      }

      // Get stroke text for this team
      final strokeText = getStrokeText(team);

      // Create accessibility message for this team
      final String accessibilityMessage =
          strokeText.isNotEmpty
              ? 'Team ${team == 'A' ? _teamAName : _teamBName}: $strokeText'
              : '';

      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ToggleButtons(
                  direction: Axis.horizontal,
                  isSelected: [index == 0, index == 1, index == 2],
                  onPressed:
                      _matchOver && !_isAdmin
                          ? null
                          : (i) {
                            String newRes;
                            if (team == 'A') {
                              if (i == 0) {
                                newRes = 'A';
                              } else if (i == 1)
                                newRes = 'AS';
                              else
                                newRes = 'B';
                            } else {
                              if (i == 0) {
                                newRes = 'B';
                              } else if (i == 1)
                                newRes = 'AS';
                              else
                                newRes = 'A';
                            }
                            _setHoleResult(hole, newRes);
                          },
                  borderRadius: BorderRadius.circular(8),
                  selectedBorderColor:
                      team == 'A' ? Colors.blue : Colors.orange,
                  selectedColor: Colors.white,
                  fillColor: team == 'A' ? Colors.blue : Colors.orange,
                  color:
                      team == 'A'
                          ? Colors.blue.withOpacity(0.5)
                          : Colors.orange.withOpacity(0.5),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 16),
                        Text('Win', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove, size: 16),
                        Text('AS', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close, size: 16),
                        Text('Loss', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Show stroke information based on match type
          if (_matchPlayType == 'greensome') ...[
            // For greensome, check directly if there are strokes for this hole
            if (dots > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tooltip(
                  message:
                      'Team ${team == 'A' ? _teamAName : _teamBName} receives $dots stroke${dots != 1 ? 's' : ''}',
                  child: Text(
                    "Pair: ${dots == 1 ? '1 stroke' : '$dots strokes'}",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          team == 'A'
                              ? Colors.blue.withOpacity(0.8)
                              : Colors.orange.withOpacity(0.8),
                      fontWeight: FontWeight.bold, // Make more visible
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ] else if (strokeText.isNotEmpty) ...[
            // For match play, use the existing stroke text
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Tooltip(
                message: accessibilityMessage,
                child: Text(
                  strokeText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        team == 'A'
                            ? Colors.blue.withOpacity(0.8)
                            : Colors.orange.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
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
                        backgroundColor:
                            players == _teamAPlayerInfo
                                ? Colors.blue.shade100
                                : Colors.orange.shade100,
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
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hole $hole',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Par ${pars[hole - 1]}'),
                          Text('SI ${strokeIndex[hole - 1]}'),
                        ],
                      ),
                    ),
                    Expanded(flex: 5, child: buildToggle('A', dotsA)),
                    const SizedBox(width: 4),
                    Expanded(flex: 5, child: buildToggle('B', dotsB)),
                  ],
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

    final formattedDate = DateFormat('EEEE, MMMM d').format(_matchDateTime);
    final formattedTime = DateFormat('h:mm a').format(_matchDateTime);

    return Scaffold(
      appBar: AppBar(title: const Text('Match Scoring'), elevation: 2),
      body: Column(
        children: [
          // Enhanced match header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$_matchType - $_matchPlayType',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_matchOver)
                      Chip(
                        label: const Text('Match Complete'),
                        backgroundColor: Colors.green.withOpacity(0.2),
                        labelStyle: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$formattedDate at $formattedTime',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _matchOver ? Icons.emoji_events : Icons.golf_course,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getMatchStatusText(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_bonus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Bonus Point Match',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Hole list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 18,
              itemBuilder: (context, index) => _buildRow(index + 1),
            ),
          ),

          // Match over button with enhanced styling
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _matchOver && !_isAdmin
                        ? null
                        : () async {
                          // Show confirmation dialog
                          final confirm =
                              await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Match Over'),
                                      content: const Text(
                                        'Are you sure you want to finalize this match? Once complete, scoring can only be modified by an admin.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('Finalize Match'),
                                        ),
                                      ],
                                    ),
                              ) ??
                              false;

                          if (confirm) {
                            final pts = _calculatePoints();
                            await _matchService.setMatchOver(
                              eventId,
                              matchId,
                              regularPoints: pts['a']!,
                              bonusPoints: pts['aBonus']!,
                            );
                            await _loadData();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Match has been finalized'),
                                ),
                              );
                            }
                          }
                        },
                icon: Icon(_matchOver ? Icons.check_circle : Icons.sports_golf),
                label: Text(_matchOver ? 'Match Complete' : 'Finalize Match'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _matchOver ? Colors.grey : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
