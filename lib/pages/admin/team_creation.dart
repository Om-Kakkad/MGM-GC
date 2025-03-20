import 'package:flutter/material.dart';
import 'package:mgm_gc/models/team.dart';
import 'package:mgm_gc/services/team_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class TeamCreationForm extends StatefulWidget {
  const TeamCreationForm({super.key});

  @override
  State<TeamCreationForm> createState() => _TeamCreationFormState();
}

class _TeamCreationFormState extends State<TeamCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final TeamService _teamService = TeamService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _teamPasswordController = TextEditingController();

  String? _selectedEventId;
  List<DocumentSnapshot> _leagueEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLeagueEvents();
  }

  Future<void> _fetchLeagueEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final eventsSnapshot =
          await _firestore
              .collection('events')
              .where('eventType', isEqualTo: 'League')
              .get();

      setState(() {
        _leagueEvents = eventsSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching league events: $e');
    }
  }

  Future<void> _createTeam() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedEventId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an event for this team')),
        );
        return;
      }

      try {
        setState(() {
          _isLoading = true;
        });

        // First, verify the event exists
        final eventDoc =
            await _firestore.collection('events').doc(_selectedEventId).get();
        if (!eventDoc.exists) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected event no longer exists')),
          );
          return;
        }

        // Create the team with eventId
        final teamRef = await _firestore.collection('teams').add({
          'teamName': _teamNameController.text,
          'password': _teamPasswordController.text,
          'eventId': _selectedEventId, // Store the event ID reference
          'createdAt': FieldValue.serverTimestamp(),
          'players': [], // Initialize empty players array
        });

        print(
          'Created team with ID: ${teamRef.id}, linked to event: $_selectedEventId',
        );

        _teamNameController.clear();
        _teamPasswordController.clear();
        setState(() {
          _selectedEventId = null;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created successfully')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print('Error creating team: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating team: $e')));
      }
    }
  }

  Widget _buildEventDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Associate with League Event',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedEventId,
          items:
              _leagueEvents.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final eventName = data['eventName'] ?? 'Unnamed Event';
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(eventName),
                );
              }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEventId = value;
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffF7F7F9),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
            hintText: 'Select a league event',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select an event';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Team',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teamNameController,
                decoration: const InputDecoration(
                  labelText: 'Team Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a team name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teamPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Team Password',
                  border: OutlineInputBorder(),
                  helperText: 'Players will use this password to join the team',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a team password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('League Events', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh events list',
                    onPressed: () {
                      _fetchLeagueEvents();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing league events...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_leagueEvents.isEmpty)
                const Text(
                  "No league events available. Please create a league event first.",
                )
              else
                _buildEventDropdown(),
              const SizedBox(height: 24),
              Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _createTeam,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 24,
                            ),
                            child: Text('Create Team'),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
