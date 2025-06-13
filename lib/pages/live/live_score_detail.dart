import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/match_service.dart';

const List<int> pars = [4, 4, 3, 4, 5, 4, 4, 3, 5, 4, 5, 3, 4, 4, 4, 3, 4, 5];
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
  late String eventId;
  late String matchId;
  bool _loading = true;
  Map<int, String> _results = {};
  String _teamA = 'Team A';
  String _teamB = 'Team B';
  DateTime _time = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    eventId = args['eventId']!;
    matchId = args['matchId']!;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final details = await _matchService.getMatchDetails(eventId, matchId);
    if (details != null) {
      _teamA = details['teams']?[0] ?? 'Team A';
      _teamB = details['teams']?[1] ?? 'Team B';
      _time = (details['matchDateTime'] as Timestamp).toDate();
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
      if (diff > remaining) return '$_teamA wins $diff & $remaining';
      return '$_teamA +$diff';
    } else {
      final abs = -diff;
      if (abs > remaining) return '$_teamB wins $abs & $remaining';
      return '$_teamB +$abs';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_teamA vs $_teamB',
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
                      return ListTile(
                        leading: Text('$hole'),
                        title: Text('Par ${pars[index]} - SI ${strokeIndex[index]}'),
                        trailing: Text(res ?? '-'),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
