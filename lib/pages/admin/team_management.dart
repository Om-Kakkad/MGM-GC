import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mgm_gc/models/team.dart';
import 'package:mgm_gc/services/delete_service.dart';
import 'package:mgm_gc/services/team_service.dart';

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  _TeamManagementPageState createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeleteService _deleteService = DeleteService();
  final TeamService _teamService = TeamService();
  bool _isLoading = false;
  List<Team> _teams = [];
  String? _selectedEventId;
  List<DocumentSnapshot> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all events
      final eventsSnapshot = await _firestore.collection('events').get();

      setState(() {
        _events = eventsSnapshot.docs;
        if (_events.isNotEmpty && _selectedEventId == null) {
          _selectedEventId = _events.first.id;
          _loadTeams(_selectedEventId!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading events: $e')));
    }
  }

  Future<void> _loadTeams(String eventId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get teams from the subcollection of the event
      final querySnapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .get();

      final teams =
          querySnapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            // Create Team object with this team's data
            return Team(
              teamID: doc.id,
              teamName: data['teamName'] ?? '',
              teamPassword: data['teamPassword'] ?? '',
              eventID: eventId, // Use the event ID we're querying
              players: List<String>.from(data['players'] ?? []),
            );
          }).toList();

      setState(() {
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading teams: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading teams: $e')));
    }
  }

  Future<void> _deleteTeam(String eventId, String teamId) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Team'),
                content: const Text(
                  'Are you sure you want to delete this team? This will also delete all associated matches and remove players from the team.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the updated deleteTeamWithCascade method that handles nested collections
      await _deleteService.deleteTeamWithCascade(eventId, teamId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team deleted successfully')),
      );

      _loadTeams(eventId);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting team: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Team Management',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Teams',
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/create-team').then(
                              (_) =>
                                  _selectedEventId != null
                                      ? _loadTeams(_selectedEventId!)
                                      : null,
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Team'),
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

                  // Event selector dropdown
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                            final data = event.data() as Map<String, dynamic>;
                            final name =
                                data['eventName'] ??
                                data['name'] ??
                                'Unnamed Event';
                            return DropdownMenuItem<String>(
                              value: event.id,
                              child: Text(name),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedEventId = value;
                          });
                          _loadTeams(value);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child:
                        _selectedEventId == null
                            ? const Center(
                              child: Text('Please select an event'),
                            )
                            : _teams.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.group_work,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No teams available',
                                    style: GoogleFonts.raleway(
                                      textStyle: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Click "Create Team" to add a new team',
                                    style: GoogleFonts.raleway(
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _teams.length,
                              itemBuilder: (context, index) {
                                final team = _teams[index];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                team.teamName,
                                                style: GoogleFonts.raleway(
                                                  textStyle: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed:
                                                  () => _deleteTeam(
                                                    team.eventID,
                                                    team.teamID!,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Team ID: ${team.teamID}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Password: ${team.teamPassword}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Players: ${team.players.length}',
                                          style: GoogleFonts.raleway(
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (team.players.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Wrap(
                                              spacing: 8,
                                              children:
                                                  team.players.map((playerId) {
                                                    return Chip(
                                                      label: Text(playerId),
                                                      backgroundColor:
                                                          Colors.blue[100],
                                                    );
                                                  }).toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () =>
                _selectedEventId != null
                    ? _loadTeams(_selectedEventId!)
                    : _loadEvents(),
        backgroundColor: const Color(0xff0D6EFD),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
