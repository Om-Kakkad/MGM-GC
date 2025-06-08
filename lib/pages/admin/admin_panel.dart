import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/auth_service.dart';
// Added import for CollectionUtils
import '../../utils/collection_utils.dart';
// Added prefix to resolve ambiguity
import '../../models/team.dart';
import 'event_creation_form.dart';
import 'package:mgm_gc/pages/admin/match_creation.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mgm_gc/services/team_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeamService _teamService = TeamService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final AuthService _authService = AuthService();
  final int _currentIndex = 0;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    if (_authService.currentUser != null) {
      var userData = await _authService.getUserData(
        _authService.currentUser!.uid,
      );
      if (userData.role != 'admin') {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Management Card
                    _buildAdminCard(
                      title: 'User Management',
                      description:
                          'Manage users, delete accounts, and handle user roles',
                      icon: Icons.people,
                      onTap: () {
                        Navigator.pushNamed(context, '/user-management');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Event Management Card
                    _buildAdminCard(
                      title: 'Event Management',
                      description: 'Create, edit and delete events',
                      icon: Icons.event,
                      onTap: () {
                        Navigator.pushNamed(context, '/event-management');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Team Management Card
                    _buildAdminCard(
                      title: 'Team Management',
                      description: 'Create, edit and delete teams',
                      icon: Icons.group_work,
                      onTap: () {
                        Navigator.pushNamed(context, '/team-management');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Match Management Card
                    _buildAdminCard(
                      title: 'Match Management',
                      description: 'Create and schedule matches between teams',
                      icon: Icons.sports_golf,
                      onTap: () {
                        Navigator.pushNamed(context, '/match-management');
                      },
                    ),

                    // ...other admin features...
                  ],
                ),
              ),
    );
  }

  Widget _buildAdminCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff0D6EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xff0D6EFD), size: 32),
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
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.raleway(
                        textStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  // Add a confirmation dialog before logging out
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _authService.signout(context: context); // Perform logout
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<DocumentSnapshot> users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> userData =
                users[index].data() as Map<String, dynamic>;
            String userId = users[index].id;

            return ListTile(
              title: Text(userData['email'] ?? 'No email'),
              subtitle: Text('Role: ${userData['role'] ?? 'user'}'),
              trailing: PopupMenuButton(
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'user',
                        child: const Text('Set as User'),
                      ),
                      PopupMenuItem(
                        value: 'league_player',
                        child: const Text('Set as League Player'),
                      ),
                      PopupMenuItem(
                        value: 'admin',
                        child: const Text('Set as Admin'),
                      ),
                    ],
                onSelected: (value) async {
                  try {
                    await _functions
                        .httpsCallable('setUserRole')
                        .call({'uid': userId, 'role': value});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating role: \$e')),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamsTab() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Team',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Team Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Team Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty &&
                          passwordController.text.isNotEmpty) {
                        _firestore.collection('teams').add({
                          'name': nameController.text,
                          'password': passwordController.text,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        nameController.clear();
                        passwordController.clear();
                      }
                    },
                    child: const Text('Add Team'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('teams').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              List<DocumentSnapshot> teams = snapshot.data!.docs;

              return ListView.builder(
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> teamData =
                      teams[index].data() as Map<String, dynamic>;
                  String teamId = teams[index].id;

                  return ListTile(
                    title: Text(teamData['name'] ?? 'Unnamed Team'),
                    subtitle: Text('Password: ${teamData['password']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Delete Team'),
                              content: Text(
                                'Are you sure you want to delete ${teamData['name']}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _firestore
                                        .collection('teams')
                                        .doc(teamId)
                                        .delete();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventCreationForm(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle),
                label: const Text('Create New Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0D6EFD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('events')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              List<DocumentSnapshot> events = snapshot.data!.docs;

              if (events.isEmpty) {
                return const Center(
                  child: Text(
                    'No events created yet. Click "Create New Event" to add one.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> eventData =
                      events[index].data() as Map<String, dynamic>;
                  String eventId = events[index].id;

                  // Handle different event types
                  final String eventName =
                      eventData['eventName'] ??
                      eventData['name'] ??
                      'Unnamed Event';
                  final String eventType = eventData['eventType'] ?? '';

                  // Handle date display
                  String dateDisplay = '';
                  if (eventData.containsKey('date')) {
                    // For legacy quick events with single date
                    DateTime eventDate =
                        (eventData['date'] as Timestamp).toDate();
                    dateDisplay =
                        "${eventDate.day}/${eventDate.month}/${eventDate.year}";
                  } else if (eventData.containsKey('eventDates') &&
                      (eventData['eventDates'] as List).isNotEmpty) {
                    // For events with multiple dates
                    final dates =
                        (eventData['eventDates'] as List)
                            .map((date) => (date as Timestamp).toDate())
                            .toList();
                    if (dates.length == 1) {
                      dateDisplay =
                          "${dates[0].day}/${dates[0].month}/${dates[0].year}";
                    } else {
                      dateDisplay = "${dates.length} dates scheduled";
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: ListTile(
                      title: Text(
                        eventName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date: $dateDisplay'),
                          Text('Type: $eventType'),
                          if (eventData.containsKey('eventDescription'))
                            Text(
                              'Description: ${eventData['eventDescription']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Delete Event'),
                                content: const Text(
                                  'Are you sure you want to delete this event?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _firestore
                                          .collection('events')
                                          .doc(eventId)
                                          .delete();
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
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
    );
  }

  Widget _buildFourBallTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '4-Ball Matches',
                style: GoogleFonts.raleway(
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MatchCreationForm(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Match'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0D6EFD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Update to fetch matches from an event
            // For example, get the first event's matches
            stream: _firestore.collection('events').limit(1).snapshots().asyncMap((
              eventSnapshot,
            ) async {
              if (eventSnapshot.docs.isEmpty) {
                // Return an empty QuerySnapshot by querying a non-existent collection
                return await _firestore.collection('empty_collection').get();
              }
              final eventId = eventSnapshot.docs.first.id;
              return await _firestore
                  .collection('events')
                  .doc(eventId)
                  .collection('matches')
                  .orderBy('matchDateTime', descending: true)
                  .get();
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.sports_golf,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No matches created yet',
                        style: GoogleFonts.raleway(
                          textStyle: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click "Create Match" to add a new 4-ball match',
                        style: GoogleFonts.raleway(
                          textStyle: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final match = doc.data() as Map<String, dynamic>;

                  // Format date
                  final DateTime matchDate =
                      (match['matchDateTime'] as Timestamp).toDate();
                  final String formattedDate = DateFormat(
                    'MMM dd, yyyy - hh:mm a',
                  ).format(matchDate);

                  // Get match status and type
                  final String matchStatus = match['matchStatus'] ?? 'active';
                  final String matchType = match['matchType'] ?? '4-ball';

                  // Get team IDs
                  final List<String> teamIds = List<String>.from(
                    match['teams'] ?? [],
                  );

                  return FutureBuilder<List<String>>(
                    future: _getTeamNames(teamIds),
                    builder: (context, teamsSnapshot) {
                      final String teamNames =
                          teamsSnapshot.data != null
                              ? teamsSnapshot.data!.join(' vs ')
                              : 'Loading teams...';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
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
                                      style: GoogleFonts.raleway(
                                        textStyle: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(matchStatus),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      matchStatus.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.event,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.sports_golf,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    matchType,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // View Details Button
                                  OutlinedButton(
                                    onPressed: () {
                                      // TODO: Navigate to match details page
                                    },
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('View Details'),
                                  ),
                                  const SizedBox(width: 8),
                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      _showDeleteMatchDialog(doc.id);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<String>> _getTeamNames(List<String> teamIds) async {
    List<String> teamNames = [];

    for (String teamId in teamIds) {
      try {
        // Need to find the event ID for this team first,
        // as teams are now nested under events
        String? eventId = await CollectionUtils.findEventIdForTeam(teamId);

        if (eventId != null) {
          final teamDoc =
              await _firestore
                  .collection('events')
                  .doc(eventId)
                  .collection('teams')
                  .doc(teamId)
                  .get();

          if (teamDoc.exists) {
            Map<String, dynamic> teamData =
                teamDoc.data() as Map<String, dynamic>;
            String teamName =
                teamData['teamName'] ?? teamData['name'] ?? 'Unknown Team';
            teamNames.add(teamName);
          } else {
            teamNames.add('Unknown Team');
          }
        } else {
          teamNames.add('Unknown Team');
        }
      } catch (e) {
        print('Error getting team name: $e');
        teamNames.add('Error');
      }
    }

    return teamNames;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showDeleteMatchDialog(String matchId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Match'),
          content: const Text(
            'Are you sure you want to delete this match? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Find which event this match belongs to
                  String? eventId = await CollectionUtils.findEventIdForMatch(
                    matchId,
                  );

                  if (eventId != null) {
                    await _firestore
                        .collection('events')
                        .doc(eventId)
                        .collection('matches')
                        .doc(matchId)
                        .delete();

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Match deleted successfully'),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Match not found')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting match: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

// Teams Tab Widget
class TeamsTab extends StatelessWidget {
  final TeamService teamService;

  const TeamsTab({super.key, required this.teamService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No teams found'));
        }

        // Build the list of teams
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot doc = snapshot.data!.docs[index];
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              Team team = Team.fromFirestore(doc);

              return TeamCard(
                team: team,
                onDelete: () => _deleteTeam(context, doc.id),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteTeam(BuildContext context, String teamId) async {
    // Show confirmation dialog
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Team'),
              content: const Text(
                'Are you sure you want to delete this team? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmDelete) return;

    try {
      // Start loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleting team...')));

      // Get the team document to find its event
      DocumentSnapshot teamDoc =
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .get();

      if (teamDoc.exists) {
        Map<String, dynamic> teamData = teamDoc.data() as Map<String, dynamic>;
        String? eventId = teamData['eventID'];

        // First, remove the team from its event's teamIDs array
        if (eventId != null) {
          await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .update({
                'teamIDs': FieldValue.arrayRemove([teamId]),
              });
        }

        // Then delete the team
        await FirebaseFirestore.instance
            .collection('teams')
            .doc(teamId)
            .delete();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team deleted successfully')),
        );
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting team: $e')));
    }
  }
}

// Team Card Widget
class TeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback onDelete;

  const TeamCard({super.key, required this.team, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    team.teamName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete Team',
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>?>(
              future:
                  team.eventID.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('events')
                          .doc(team.eventID)
                          .get()
                          .then((doc) => doc.data())
                      : Future.value(null),
              builder: (context, snapshot) {
                String eventName = 'Unknown Event';
                if (snapshot.hasData && snapshot.data != null) {
                  eventName =
                      snapshot.data!['eventName'] ??
                      snapshot.data!['name'] ??
                      'Unknown Event';
                }
                return Text(
                  'Event: $eventName',
                  style: TextStyle(color: Colors.grey[600]),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Players: ${team.players.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            // Password is sensitive - show option to view but default hidden
            Row(
              children: [
                Text(
                  'Team Password: ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Expanded(
                  child: Text(
                    '••••••••',
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility, size: 20),
                  onPressed: () {
                    // Fetch the actual password from Firestore to ensure we get the most recent value
                    FirebaseFirestore.instance
                        .collection('teams')
                        .doc(team.teamID)
                        .get()
                        .then((doc) {
                          if (doc.exists) {
                            Map<String, dynamic> data =
                                doc.data() as Map<String, dynamic>;
                            // Check both potential password field names
                            String password =
                                data['teamPassword'] ??
                                data['password'] ??
                                'Password not found';

                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Team Password'),
                                  content: Text(password),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            // Show error if team document doesn't exist
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Error'),
                                  content: const Text('Team not found'),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        })
                        .catchError((error) {
                          // Show error if there's an exception
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Error'),
                                content: Text(
                                  'Failed to load password: $error',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        });
                  },
                  tooltip: 'View Password',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
