import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class LeagueFeatures extends StatefulWidget {
  const LeagueFeatures({super.key});

  @override
  _LeagueFeaturesState createState() => _LeagueFeaturesState();
}

class _LeagueFeaturesState extends State<LeagueFeatures> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_authService.currentUser != null) {
      UserModel userData = await _authService.getUserData(
        _authService.currentUser!.uid,
      );

      // Check if user has appropriate role
      if (userData.role != 'league_player' && userData.role != 'admin') {
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      setState(() {
        _currentUser = userData;
        _isLoading = false;
      });
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('League Features')),
      body: DefaultTabController(
        length: 5, // Change from 4 to 5 tabs
        child: Column(
          children: [
            TabBar(
              labelColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.event), text: 'Upcoming Events'),
                Tab(icon: Icon(Icons.leaderboard), text: 'Leaderboard'),
                Tab(icon: Icon(Icons.people), text: 'My Team'),
                Tab(icon: Icon(Icons.sports_golf), text: 'Scoring'),
                Tab(
                  icon: Icon(Icons.scoreboard),
                  text: 'Live Scores',
                ), // New tab
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildEventsTab(),
                  _buildLeaderboardTab(),
                  _buildTeamTab(),
                  _buildScoringTab(),
                  _buildLiveScoresTab(), // New tab view
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('events')
              .where('date', isGreaterThanOrEqualTo: DateTime.now())
              .orderBy('date')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<DocumentSnapshot> events = snapshot.data!.docs;

        if (events.isEmpty) {
          return const Center(child: Text('No upcoming events'));
        }

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> eventData =
                events[index].data() as Map<String, dynamic>;
            DateTime eventDate = (eventData['date'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              child: ListTile(
                title: Text(
                  eventData['name'] ?? 'Unnamed Event',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${eventDate.day}/${eventDate.month}/${eventDate.year}',
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Register for event
                        _firestore.collection('event_registrations').add({
                          'userId': _authService.currentUser!.uid,
                          'eventId': events[index].id,
                          'registeredAt': FieldValue.serverTimestamp(),
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Successfully registered for event'),
                          ),
                        );
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboardTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .where('role', whereIn: ['league_player', 'admin'])
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<DocumentSnapshot> players = snapshot.data!.docs;

        // Sort players by handicap if available
        players.sort((a, b) {
          double handicapA =
              (a.data() as Map<String, dynamic>)['handicap'] ?? 100;
          double handicapB =
              (b.data() as Map<String, dynamic>)['handicap'] ?? 100;
          return handicapA.compareTo(handicapB);
        });

        return ListView.builder(
          itemCount: players.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            Map<String, dynamic> playerData =
                players[index].data() as Map<String, dynamic>;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playerData['email'] ?? 'No email',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Handicap: ${playerData['handicap'] != null ? playerData['handicap'].toStringAsFixed(1) : 'N/A'}',
                          ),
                          if (playerData['teamName'] != null)
                            Text('Team: ${playerData['teamName']}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamTab() {
    // Check if user has eventId and teamId
    final String? eventId = _currentUser?.golfDetails.eventId;
    final String? teamId = _currentUser?.golfDetails.teamId;

    if (eventId == null || teamId == null) {
      return const Center(child: Text('No team information available'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(teamId)
              .get(),
      builder: (context, teamSnapshot) {
        if (teamSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
          return const Center(child: Text('No team information available'));
        }

        Map<String, dynamic> teamData =
            teamSnapshot.data!.data() as Map<String, dynamic>;

        return StreamBuilder<QuerySnapshot>(
          stream:
              _firestore
                  .collection('users')
                  .where('golfDetails.teamId', isEqualTo: teamId)
                  .snapshots(),
          builder: (context, playersSnapshot) {
            if (playersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            List<DocumentSnapshot> teamMembers =
                playersSnapshot.data?.docs ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Team: ${teamData['teamName'] ?? 'Unnamed Team'}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 32),
                          const Text(
                            'Team Members:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (teamMembers.isEmpty)
                            const Text('No members found')
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: teamMembers.length,
                              itemBuilder: (context, index) {
                                Map<String, dynamic> memberData =
                                    teamMembers[index].data()
                                        as Map<String, dynamic>;

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text((index + 1).toString()),
                                  ),
                                  title: Text(memberData['email'] ?? 'Unknown'),
                                  subtitle: Text(
                                    'Handicap: ${memberData['golfDetails']?['handicap'] ?? 'N/A'}',
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScoringTab() {
    // Check if user has eventId and teamId
    final String? eventId = _currentUser?.golfDetails.eventId;
    final String? teamId = _currentUser?.golfDetails.teamId;
    final String? userId = _authService.currentUser?.uid;

    if (eventId == null || teamId == null || userId == null) {
      return const Center(child: Text('No match information available'));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .where('participantUids', arrayContains: userId)
              .where(
                'matchDateTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(today),
              )
              .where(
                'matchDateTime',
                isLessThan: Timestamp.fromDate(
                  today.add(const Duration(days: 1)),
                ),
              )
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No matches available for scoring today'),
          );
        }

        final userMatches = snapshot.data!.docs;

        if (userMatches.isEmpty) {
          return const Center(
            child: Text('You have no matches to score today'),
          );
        }

        return ListView.builder(
          itemCount: userMatches.length,
          padding: const EdgeInsets.all(16.0),
          itemBuilder: (context, index) {
            final match = userMatches[index];
            final matchData = match.data() as Map<String, dynamic>;
            final matchTime =
                (matchData['matchDateTime'] as Timestamp).toDate();
            final matchId = match.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: ListTile(
                title: Text(
                  'Match: ${matchData['matchType'] ?? ''} - ${matchData['matchPlayType'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Time: ${matchTime.hour}:${matchTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/match_scoring',
                      arguments: {'eventId': eventId, 'matchId': matchId},
                    );
                  },
                  child: const Text('Score'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Add a new method for the Live Scores tab
  Widget _buildLiveScoresTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.scoreboard, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'View Live Match Scores',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check ongoing match scores in real-time',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('View Live Scores'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0D6EFD),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/live-scores');
            },
          ),
        ],
      ),
    );
  }
}
