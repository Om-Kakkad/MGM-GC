import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/match_service.dart';

const List<int> pars = [3, 3, 4, 4, 5, 3, 5, 4, 3, 4, 5, 3, 5, 3, 4, 3, 4, 4];
const List<int> strokeIndex = [
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

class LiveScoreDetailPage extends StatefulWidget {
  const LiveScoreDetailPage({super.key});

  @override
  State<LiveScoreDetailPage> createState() => _LiveScoreDetailPageState();
}

class _LiveScoreDetailPageState extends State<LiveScoreDetailPage> {
  final MatchService _matchService = MatchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String eventId;
  late String matchId;
  bool _loading = true;
  final Map<int, String> _results = {};
  String _teamAId = '';
  String _teamBId = '';
  String _teamAName = 'Team A';
  String _teamBName = 'Team B';
  DateTime _time = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    eventId = args['eventId']!;
    matchId = args['matchId']!;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final details = await _matchService.getMatchDetails(eventId, matchId);
    if (details != null) {
      _teamAId = details['teams']?[0] ?? '';
      _teamBId = details['teams']?[1] ?? '';
      _time = (details['matchDateTime'] as Timestamp).toDate();

      // Fetch team names
      if (_teamAId.isNotEmpty) {
        _teamAName = await _getTeamName(eventId, _teamAId) ?? 'Team A';
      }
      if (_teamBId.isNotEmpty) {
        _teamBName = await _getTeamName(eventId, _teamBId) ?? 'Team B';
      }
    }
    _results.clear();
    for (var i = 1; i <= 18; i++) {
      final res = await _matchService.getHoleResult(eventId, matchId, i);
      if (res != null && res['result'] != null) {
        _results[i] = res['result'] as String;
      }
    }
    setState(() => _loading = false);
  }

  Future<String?> _getTeamName(String eventId, String teamId) async {
    try {
      final teamDoc =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(teamId)
              .get();

      if (teamDoc.exists) {
        final data = teamDoc.data();
        if (data != null) {
          // Check for both possible field names (teamName and name)
          return data['teamName'] ?? data['name'] as String?;
        }
      }
      return null;
    } catch (e) {
      print("Error getting team name: $e");
      return null;
    }
  }

  String _leadText() {
    int diff = 0;
    int lastHole = 0;
    for (var i = 1; i <= 18; i++) {
      final r = _results[i];
      if (r == 'A') diff++;
      if (r == 'B') diff--;
      if (r != null) lastHole = i;
    }
    if (diff == 0) return 'AS';
    final remaining = 18 - lastHole;
    if (diff > 0) {
      if (diff > remaining) return '$_teamAName wins $diff & $remaining';
      return '$_teamAName +$diff';
    } else {
      final abs = -diff;
      if (abs > remaining) return '$_teamBName wins $abs & $remaining';
      return '$_teamBName +$abs';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_teamAName vs $_teamBName',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(DateFormat('h:mm a').format(_time)),
                        const SizedBox(height: 8),
                        Text(
                          _leadText(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 18,
                      itemBuilder: (context, index) {
                        final hole = index + 1;
                        final res = _results[hole];
                        String displayResult;
                        if (res == null) {
                          displayResult = '-';
                        } else if (res == 'A') {
                          displayResult = _teamAName;
                        } else if (res == 'B') {
                          displayResult = _teamBName;
                        } else {
                          // 'AS'
                          displayResult = 'All Square';
                        }
                        return ListTile(
                          leading: Text('$hole'),
                          title: Text(
                            'Par ${pars[index]} - SI ${strokeIndex[index]}',
                          ),
                          trailing: Text(displayResult),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
