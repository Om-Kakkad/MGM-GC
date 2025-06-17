import 'package:flutter/material.dart';
import '../../services/aggregate_score_service.dart';
import '../../services/match_service.dart';
import '../../models/aggregate_score.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AggregateScoresPage extends StatefulWidget {
  const AggregateScoresPage({super.key});

  @override
  State<AggregateScoresPage> createState() => _AggregateScoresPageState();
}

class _AggregateScoresPageState extends State<AggregateScoresPage> {
  final AggregateScoreService _service = AggregateScoreService();
  final MatchService _matchService = MatchService();
  late Future<List<AggregateScore>> _scoresFuture;
  List<Map<String, dynamic>> _events = [];
  String? _selectedEventId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _matchService.getLeagueEvents();
      setState(() {
        _events = events;
        if (events.isNotEmpty) {
          _selectedEventId = events.first['id'];
          _loadScores(_selectedEventId!);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
    }
  }

  void _loadScores(String eventId) {
    setState(() {
      _scoresFuture = _service.getAggregateScores(eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aggregate Scores')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (_events.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Event',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: _selectedEventId,
                        items:
                            _events.map((event) {
                              return DropdownMenuItem<String>(
                                value: event['id'],
                                child: Text(
                                  event['eventName'] ??
                                      event['name'] ??
                                      'Unnamed Event',
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedEventId = value);
                            _loadScores(value);
                          }
                        },
                      ),
                    ),
                  Expanded(
                    child:
                        _selectedEventId == null
                            ? const Center(
                              child: Text('Please select an event'),
                            )
                            : FutureBuilder<List<AggregateScore>>(
                              future: _scoresFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text('Error: ${snapshot.error}'),
                                  );
                                }

                                final scores = snapshot.data ?? [];
                                if (scores.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No scores found for this event',
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: scores.length,
                                  padding: const EdgeInsets.all(16),
                                  itemBuilder: (context, index) {
                                    final score = scores[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          child: Text('${index + 1}'),
                                        ),
                                        title: FutureBuilder<String>(
                                          future: _getTeamName(
                                            _selectedEventId!,
                                            score.teamId!,
                                          ),
                                          builder: (context, snapshot) {
                                            return Text(
                                              snapshot.data ??
                                                  'Team ${index + 1}',
                                            );
                                          },
                                        ),
                                        subtitle: Text(
                                          'Regular: ${score.regularPoints} | Bonus: ${score.bonusPoints}',
                                        ),
                                        trailing: Text(
                                          '${score.total}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  Future<String> _getTeamName(String eventId, String teamId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(teamId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        return data['teamName'] ?? data['name'] ?? 'Unknown Team';
      }
      return 'Unknown Team';
    } catch (e) {
      print('Error getting team name: $e');
      return 'Error';
    }
  }
}
