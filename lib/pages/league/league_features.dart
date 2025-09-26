import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../models/user_model.dart';

class LeagueFeaturesPage extends StatefulWidget {
  const LeagueFeaturesPage({super.key});

  @override
  _LeagueFeaturesPageState createState() => _LeagueFeaturesPageState();
}

class _LeagueFeaturesPageState extends State<LeagueFeaturesPage> {
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
      setState(() {
        _currentUser = userData;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'League Features',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xff0D6EFD),
                    const Color(0xff0D6EFD).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sports_golf, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'League Dashboard',
                    style: GoogleFonts.raleway(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Access all your league features and manage your competitive golf experience',
                    style: GoogleFonts.raleway(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Main Features Grid
            Text(
              'League Features',
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildFeatureCard(
                  'Upcoming Events',
                  'View and register for league events',
                  Icons.event,
                  Colors.orange,
                  () => _showUpcomingEvents(),
                ),
                _buildFeatureCard(
                  'Leaderboard',
                  'Check your ranking and handicap',
                  Icons.leaderboard,
                  Colors.green,
                  () => _showLeaderboard(),
                ),
                _buildFeatureCard(
                  'My Team',
                  'View team information and members',
                  Icons.people,
                  Colors.blue,
                  () => _showMyTeam(),
                ),
                _buildFeatureCard(
                  'Match Scoring',
                  'Score matches and track progress',
                  Icons.sports_golf,
                  Colors.purple,
                  () => _showMatchScoring(),
                ),
                _buildFeatureCard(
                  'Live Scores',
                  'View ongoing match scores',
                  Icons.scoreboard,
                  Colors.red,
                  () => Navigator.pushNamed(context, '/live-scores'),
                ),
                _buildFeatureCard(
                  'Statistics',
                  'View awards and achievements',
                  Icons.emoji_events,
                  Colors.amber,
                  () => Navigator.pushNamed(context, '/stats'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Additional Features
            Text(
              'Additional Features',
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildWideFeatureCard(
                    'Aggregate Scores',
                    'View total team points and standings',
                    Icons.stacked_bar_chart,
                    Colors.indigo,
                    () => Navigator.pushNamed(context, '/aggregate-scores'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildWideFeatureCard(
                    'Sponsors',
                    'Check out our amazing event sponsors',
                    Icons.business,
                    Colors.teal,
                    () => Navigator.pushNamed(context, '/sponsors'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // User Info Card (if not in a team)
            if (_currentUser?.golfDetails.teamId == null)
              _buildJoinTeamPrompt(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.raleway(
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.raleway(
                    textStyle: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideFeatureCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.raleway(
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.raleway(
                        textStyle: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinTeamPrompt() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.group_add, color: Colors.white, size: 32),
            const SizedBox(height: 16),
            Text(
              'Ready to Compete?',
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join a team to access match scoring, team management, and exclusive league features.',
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/join-team'),
                icon: const Icon(Icons.login, color: Colors.orange),
                label: const Text(
                  'Join a Team',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modal/Dialog methods for different features
  void _showUpcomingEvents() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => _buildUpcomingEventsContent(controller),
          ),
    );
  }

  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => _buildLeaderboardContent(controller),
          ),
    );
  }

  void _showMyTeam() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => _buildMyTeamContent(controller),
          ),
    );
  }

  void _showMatchScoring() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => _buildMatchScoringContent(controller),
          ),
    );
  }

  Widget _buildUpcomingEventsContent(ScrollController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Handle(),
          const SizedBox(height: 16),
          Text(
            'Upcoming Events',
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                  controller: controller,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> eventData =
                        events[index].data() as Map<String, dynamic>;
                    DateTime eventDate =
                        (eventData['date'] as Timestamp).toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          eventData['eventName'] ?? 'Unnamed Event',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: ${eventDate.day}/${eventDate.month}/${eventDate.year}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            try {
                              final eventId = events[index].id;
                              final eventName =
                                  eventData['eventName'] ?? 'Event';
                              final EventService eventService = EventService();
                              final bool isRegistered = await eventService
                                  .isUserRegistered(eventId);

                              if (isRegistered) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'You are already registered for this event.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              await eventService.registerForEvent(eventId);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Successfully registered for $eventName!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Register'),
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

  Widget _buildLeaderboardContent(ScrollController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Handle(),
          const SizedBox(height: 16),
          Text(
            'Leaderboard',
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                      (a.data()
                          as Map<
                            String,
                            dynamic
                          >)['golfDetails']?['handicap'] ??
                      100;
                  double handicapB =
                      (b.data()
                          as Map<
                            String,
                            dynamic
                          >)['golfDetails']?['handicap'] ??
                      100;
                  return handicapA.compareTo(handicapB);
                });

                return ListView.builder(
                  controller: controller,
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> playerData =
                        players[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          '${playerData['firstName'] ?? ''} ${playerData['lastName'] ?? ''}'
                                  .trim()
                                  .isEmpty
                              ? playerData['email'] ?? 'No email'
                              : '${playerData['firstName'] ?? ''} ${playerData['lastName'] ?? ''}'
                                  .trim(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Handicap: ${playerData['golfDetails']?['handicap']?.toStringAsFixed(1) ?? 'N/A'}',
                            ),
                            if (playerData['golfDetails']?['teamName'] != null)
                              Text(
                                'Team: ${playerData['golfDetails']['teamName']}',
                              ),
                          ],
                        ),
                        isThreeLine: true,
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

  Widget _buildMyTeamContent(ScrollController controller) {
    final String? eventId = _currentUser?.golfDetails.eventId;
    final String? teamId = _currentUser?.golfDetails.teamId;

    if (eventId == null || teamId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Handle(),
            const SizedBox(height: 16),
            const Icon(Icons.group_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Team Information',
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are not currently part of a team. Join a team to access team features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/join-team');
              },
              child: const Text('Join a Team'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Handle(),
          const SizedBox(height: 16),
          Text(
            'My Team',
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
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
                  return const Center(child: Text('Team not found'));
                }

                Map<String, dynamic> teamData =
                    teamSnapshot.data!.data() as Map<String, dynamic>;

                return SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.group,
                                    color: Color(0xff0D6EFD),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    teamData['teamName'] ?? 'Unknown Team',
                                    style: GoogleFonts.raleway(
                                      textStyle: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text('Team Members:'),
                              const SizedBox(height: 8),
                              StreamBuilder<QuerySnapshot>(
                                stream:
                                    _firestore
                                        .collection('users')
                                        .where(
                                          'golfDetails.teamId',
                                          isEqualTo: teamId,
                                        )
                                        .snapshots(),
                                builder: (context, membersSnapshot) {
                                  if (!membersSnapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }

                                  List<DocumentSnapshot> teamMembers =
                                      membersSnapshot.data!.docs;

                                  if (teamMembers.isEmpty) {
                                    return const Text('No members found');
                                  }

                                  return Column(
                                    children:
                                        teamMembers.map((member) {
                                          Map<String, dynamic> memberData =
                                              member.data()
                                                  as Map<String, dynamic>;
                                          return ListTile(
                                            leading: const CircleAvatar(
                                              child: Icon(Icons.person),
                                            ),
                                            title: Text(
                                              '${memberData['firstName'] ?? ''} ${memberData['lastName'] ?? ''}'
                                                      .trim()
                                                      .isEmpty
                                                  ? memberData['email'] ??
                                                      'Unknown'
                                                  : '${memberData['firstName'] ?? ''} ${memberData['lastName'] ?? ''}'
                                                      .trim(),
                                            ),
                                            subtitle: Text(
                                              'Handicap: ${memberData['golfDetails']?['handicap']?.toStringAsFixed(1) ?? 'N/A'}',
                                            ),
                                          );
                                        }).toList(),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchScoringContent(ScrollController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Handle(),
          const SizedBox(height: 16),
          Text(
            'Match Scoring',
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_golf, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    'Match Scoring',
                    style: GoogleFonts.raleway(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Score your matches and track your progress against other teams.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/matches');
                    },
                    child: const Text('View Matches'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Handle extends StatelessWidget {
  const Handle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
