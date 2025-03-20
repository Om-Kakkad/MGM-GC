import 'package:flutter/material.dart';
import 'package:mgm_gc/models/team.dart';
import 'package:mgm_gc/services/team_service.dart';

class TeamCreationForm extends StatefulWidget {
  const TeamCreationForm({super.key});

  @override
  State<TeamCreationForm> createState() => _TeamCreationFormState();
}

class _TeamCreationFormState extends State<TeamCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final TeamService _teamService = TeamService();

  String _teamName = '';
  String _teamPassword = '';
  String? _selectedEventId;

  List<Map<String, dynamic>> _leagueEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLeagueEvents();
  }

  Future<void> _loadLeagueEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _teamService.getLeagueEvents();
      print("Loaded ${events.length} league events"); // Debug print

      // Debug each event
      for (var event in events) {
        print("Event: ${event['eventName']} - ID: ${event['id']}");
      }

      setState(() {
        _leagueEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading league events: $e"); // Better error logging
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
      });

      try {
        Team newTeam = Team(
          teamName: _teamName,
          teamPassword: _teamPassword,
          eventID: _selectedEventId!,
          players: [],
        );

        await _teamService.createTeam(newTeam);

        setState(() {
          _isLoading = false;
        });

        // Reset the form
        _formKey.currentState!.reset();
        _selectedEventId = null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created successfully!')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating team: $e')));
      }
    }
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
                onSaved: (value) {
                  _teamName = value!;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
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
                onSaved: (value) {
                  _teamPassword = value!;
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
                      _loadLeagueEvents();
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
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select League Event',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select a league event'),
                  value: _selectedEventId,
                  items:
                      _leagueEvents.map((event) {
                        String id = event['id'] ?? '';
                        String name = event['eventName'] ?? 'Unnamed Event';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(name),
                        );
                      }).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an event';
                    }
                    return null;
                  },
                  onChanged: (newValue) {
                    setState(() {
                      _selectedEventId = newValue;
                    });
                  },
                ),
              const SizedBox(height: 24),
              Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _submitForm,
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
