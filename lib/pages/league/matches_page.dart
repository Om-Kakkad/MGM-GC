import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/match_service.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final MatchService _matchService = MatchService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _events = [];
  Map<String, List<Map<String, dynamic>>> _matchesByEvent = {};
  bool _loading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
      });

      // Get current user ID
      _currentUserId = _authService.currentUser?.uid;

      // Get all league events
      final events = await _matchService.getLeagueEvents();
      _events = events;

      // For each event, get matches where the current user is a participant
      _matchesByEvent = {};

      for (var event in events) {
        final eventId = event['id'] as String;
        final matches = await _getUserMatches(eventId);
        if (matches.isNotEmpty) {
          _matchesByEvent[eventId] = matches;
        }
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      print('Error loading matches: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading matches: $e')));
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getUserMatches(String eventId) async {
    try {
      if (_currentUserId == null) return [];

      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .where('participantUids', arrayContains: _currentUserId)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'matchDateTime': data['matchDateTime'],
          'teams': data['teams'] ?? [],
          'players': data['players'] ?? {'teamA': [], 'teamB': []},
          'matchType': data['matchType'] ?? '4-ball',
          'matchOver': data['matchOver'] ?? false,
          'eventId': eventId,
        };
      }).toList();
    } catch (e) {
      print('Error getting user matches: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Matches'), elevation: 2),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _matchesByEvent.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sports_golf, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No matches found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You don\'t have any upcoming or past matches.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Back to Features'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final eventId = event['id'] as String;
                    final eventMatches = _matchesByEvent[eventId] ?? [];

                    if (eventMatches.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            event['name'] ?? 'Unknown Event',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...eventMatches.map((match) {
                          // Get match date
                          final matchDateTime =
                              (match['matchDateTime'] as Timestamp).toDate();
                          final formattedDate = DateFormat(
                            'MMM d, y - h:mm a',
                          ).format(matchDateTime);

                          // Get team names
                          List<String> teams = List<String>.from(
                            match['teams'] ?? [],
                          );
                          String teamNames =
                              teams.isNotEmpty
                                  ? '${teams[0]} vs ${teams[1]}'
                                  : 'Match';

                          // Get match type
                          String matchType = match['matchType'] ?? '4-ball';

                          // Check if match is today
                          bool isToday = DateUtils.isSameDay(
                            matchDateTime,
                            DateTime.now(),
                          );
                          bool isPast = matchDateTime.isBefore(
                            DateTime.now().subtract(const Duration(days: 1)),
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                if (match['matchOver'] == true || !isToday) {
                                  // View match details
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        match['matchOver'] == true
                                            ? 'This match is complete.'
                                            : 'You can only score matches scheduled for today.',
                                      ),
                                    ),
                                  );
                                } else {
                                  // Navigate to match scoring page
                                  Navigator.pushNamed(
                                    context,
                                    '/match-scoring',
                                    arguments: {
                                      'eventId': eventId,
                                      'matchId': match['id'],
                                    },
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            teamNames,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        _buildMatchStatusChip(match),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$matchType - $formattedDate',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        isToday && !match['matchOver']
                                            ? ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/match-scoring',
                                                  arguments: {
                                                    'eventId': eventId,
                                                    'matchId': match['id'],
                                                  },
                                                );
                                              },
                                              icon: const Icon(Icons.edit),
                                              label: const Text('Score Match'),
                                            )
                                            : isPast && match['matchOver']
                                            ? OutlinedButton.icon(
                                              onPressed: () {
                                                // View match results
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Match results view coming soon!',
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.leaderboard,
                                              ),
                                              label: const Text('View Results'),
                                            )
                                            : const SizedBox.shrink(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
    );
  }

  Widget _buildMatchStatusChip(Map<String, dynamic> match) {
    final matchDateTime = (match['matchDateTime'] as Timestamp).toDate();
    final bool isToday = DateUtils.isSameDay(matchDateTime, DateTime.now());
    final bool isPast = matchDateTime.isBefore(DateTime.now());
    final bool matchOver = match['matchOver'] ?? false;

    if (matchOver) {
      return const Chip(
        label: Text('Completed'),
        backgroundColor: Color.fromARGB(255, 210, 250, 212),
        labelStyle: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
      );
    } else if (isToday) {
      return const Chip(
        label: Text('Today'),
        backgroundColor: Color.fromARGB(255, 255, 243, 203),
        labelStyle: TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (isPast) {
      return const Chip(
        label: Text('Missed'),
        backgroundColor: Color.fromARGB(255, 255, 220, 220),
        labelStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      );
    } else {
      return const Chip(
        label: Text('Upcoming'),
        backgroundColor: Color.fromARGB(255, 220, 237, 255),
        labelStyle: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      );
    }
  }
}
