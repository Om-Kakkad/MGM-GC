import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/match_model.dart';
import '../../services/match_service.dart';
import '../../services/team_service.dart';

class MatchCreationForm extends StatefulWidget {
  const MatchCreationForm({super.key});

  @override
  _MatchCreationFormState createState() => _MatchCreationFormState();
}

class _MatchCreationFormState extends State<MatchCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final MatchService _matchService = MatchService();
  final TeamService _teamService = TeamService();

  // Form state variables
  bool _isLoading = false;
  List<Map<String, dynamic>> _leagueEvents = [];
  List<Map<String, dynamic>> _teamAOptions = [];
  List<Map<String, dynamic>> _teamBOptions = [];
  List<Map<String, dynamic>> _teamAPlayers = [];
  List<Map<String, dynamic>> _teamBPlayers = [];
  List<DateTime> _availableDates = [];

  // Selected values
  String? _selectedEventId;
  String? _selectedTeamAId;
  String? _selectedTeamBId;
  String _matchType = '4-ball';
  DateTime? _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Selected players
  List<String> _selectedTeamAPlayerIds = [];
  List<String> _selectedTeamBPlayerIds = [];

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
      final events = await _matchService.getLeagueEvents();
      setState(() {
        _leagueEvents = events;
        _isLoading = false;
      });
    } catch (e) {
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

  Future<void> _loadTeams() async {
    if (_selectedEventId == null) return;

    setState(() {
      _isLoading = true;
      _selectedTeamAId = null;
      _selectedTeamBId = null;
      _teamAOptions = [];
      _teamBOptions = [];
      _availableDates = [];
      _selectedDate = null;
    });

    try {
      // Load teams for the selected event
      final teams = await _matchService.getTeamsByEvent(_selectedEventId!);

      // Load available dates for the selected event
      final dates = await _teamService.getLeagueEventDates(_selectedEventId!);

      setState(() {
        _teamAOptions = teams;
        _teamBOptions = teams;
        _availableDates = dates;
        _isLoading = false;
      });

      if (teams.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No teams found for this event. Please create teams for this event first.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      if (dates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No dates available for this event. Please add dates to the event first.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load teams or dates: $e')),
        );
      }
    }
  }

  Future<void> _loadTeamPlayers(String teamId, bool isTeamA) async {
    setState(() {
      _isLoading = true;
      if (isTeamA) {
        _teamAPlayers = [];
        _selectedTeamAPlayerIds = [];
      } else {
        _teamBPlayers = [];
        _selectedTeamBPlayerIds = [];
      }
    });

    try {
      final players = await _matchService.getPlayersByTeam(teamId);
      setState(() {
        if (isTeamA) {
          _teamAPlayers = players;
        } else {
          _teamBPlayers = players;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load players: $e')));
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  DateTime _combineDateTime() {
    if (_selectedDate == null) {
      return DateTime.now(); // Fallback, should not happen
    }
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  bool _validatePlayerCounts() {
    if (_matchType == '2-ball') {
      // For 2-ball, ensure equal number of players from both teams
      return _selectedTeamAPlayerIds.length == _selectedTeamBPlayerIds.length;
    } else {
      // For 4-ball, allow any number of players
      return _selectedTeamAPlayerIds.isNotEmpty &&
          _selectedTeamBPlayerIds.isNotEmpty;
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a match date')),
        );
        return;
      }

      if (!_validatePlayerCounts()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _matchType == '2-ball'
                  ? 'For 2-ball matches, both teams must have the same number of players'
                  : 'Each team must have at least one player selected',
            ),
          ),
        );
        return;
      }

      // Check for null values again to be extra safe
      if (_selectedEventId == null || _selectedEventId!.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select an event')));
        return;
      }

      if (_selectedTeamAId == null || _selectedTeamAId!.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select Team A')));
        return;
      }

      if (_selectedTeamBId == null || _selectedTeamBId!.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select Team B')));
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Ensure all necessary fields are safe for Firestore
        print('Creating match with:');
        print('Event ID: ${_selectedEventId ?? "null"}');
        print('Team A ID: ${_selectedTeamAId ?? "null"}');
        print('Team B ID: ${_selectedTeamBId ?? "null"}');
        print('Team A Players: $_selectedTeamAPlayerIds');
        print('Team B Players: $_selectedTeamBPlayerIds');

        // Create match with all values explicitly initialized
        final matchDateTime = _combineDateTime();
        final match = Match(
          eventID: _selectedEventId!,
          teams: [_selectedTeamAId!, _selectedTeamBId!],
          players: {
            'teamA': _selectedTeamAPlayerIds,
            'teamB': _selectedTeamBPlayerIds,
          },
          matchType: _matchType,
          matchDateTime: matchDateTime,
          holeResults: [], // Explicitly empty array
          matchStatus: 'active',
        );

        // Try to identify any null values in the match
        final Map<String, dynamic> debugMap = {
          'eventID': match.eventID,
          'teams': match.teams,
          'players': match.players,
          'matchType': match.matchType,
          'matchDateTime': match.matchDateTime,
          'holeResults': match.holeResults,
          'matchStatus': match.matchStatus,
        };

        print('Match object properties:');
        debugMap.forEach((key, value) {
          print('$key: ${value?.toString() ?? "null"} (${value?.runtimeType})');
        });

        // Create the match with error handling but proceed if we get a valid ID
        String? matchId;
        try {
          matchId = await _matchService.createMatch(match);
          print('Match created successfully with ID: $matchId');
        } catch (e) {
          print('Error after match creation: $e');
          print('Error stack trace: ${StackTrace.current}');

          // Check if we got a matchId despite the error
          if (matchId != null) {
            print(
              'Match was created with ID: $matchId, continuing despite error',
            );
          } else {
            throw e; // Re-throw if no match was created
          }
        }

        // If we reach here, either everything worked or we have a matchId despite errors
        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match created successfully!')),
        );

        // Navigate back to admin panel regardless of minor errors
        Navigator.pop(context);
      } catch (e) {
        print('Match creation error details:');
        print('Error: $e');
        print('Stack trace: ${StackTrace.current}');
        print('Event ID: $_selectedEventId');
        print('Team A ID: $_selectedTeamAId');
        print('Team B ID: $_selectedTeamBId');

        setState(() {
          _isLoading = false;
        });

        // Show a more detailed error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error creating match: ${e.toString().split('\n')[0]}',
            ),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'DISMISS',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } else {
      // Form validation failed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Match',
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
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Match Details'),
                      const SizedBox(height: 16),

                      // Event Selection
                      _buildDropdown(
                        label: 'League Event',
                        hint: 'Select a league event',
                        value: _selectedEventId,
                        items:
                            _leagueEvents.map((event) {
                              return DropdownMenuItem<String>(
                                value: event['id'],
                                child: Text(
                                  event['eventName'] ?? 'Unnamed Event',
                                ),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an event';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _selectedEventId = value;
                          });
                          _loadTeams();
                        },
                      ),
                      const SizedBox(height: 20),

                      // Match Type
                      _buildDropdown(
                        label: 'Match Type',
                        hint: 'Select match type',
                        value: _matchType,
                        items: const [
                          DropdownMenuItem(
                            value: '4-ball',
                            child: Text('4-ball'),
                          ),
                          DropdownMenuItem(
                            value: '2-ball',
                            child: Text('2-ball'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _matchType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Match Date (Chips)
                      if (_availableDates.isNotEmpty) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Match Date',
                              style: GoogleFonts.raleway(
                                textStyle: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xffF7F7F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    _availableDates.map((date) {
                                      final bool isSelected =
                                          _selectedDate == date;
                                      final DateFormat formatter = DateFormat(
                                        'EEE, MMM d, yyyy',
                                      );
                                      return ChoiceChip(
                                        label: Text(formatter.format(date)),
                                        selected: isSelected,
                                        selectedColor: Colors.blue,
                                        labelStyle: TextStyle(
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedDate =
                                                selected ? date : null;
                                          });
                                        },
                                      );
                                    }).toList(),
                              ),
                            ),
                          ],
                        ),

                        // Match Time
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Match Time',
                              style: GoogleFonts.raleway(
                                textStyle: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectTime(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF7F7F9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedTime.format(context),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const Icon(Icons.access_time),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 30),
                      _buildSectionTitle('Team Selection'),
                      const SizedBox(height: 16),

                      // Team A Selection
                      _buildDropdown(
                        label: 'Team A',
                        hint: 'Select Team A',
                        value: _selectedTeamAId,
                        items:
                            _teamAOptions.map((team) {
                              return DropdownMenuItem<String>(
                                value: team['id'],
                                child: Text(team['teamName'] ?? 'Unnamed Team'),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select Team A';
                          }
                          if (value == _selectedTeamBId) {
                            return 'Team A and Team B must be different';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _selectedTeamAId = value;
                          });
                          if (value != null) {
                            _loadTeamPlayers(value, true);
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Team B Selection
                      _buildDropdown(
                        label: 'Team B',
                        hint: 'Select Team B',
                        value: _selectedTeamBId,
                        items:
                            _teamBOptions.map((team) {
                              return DropdownMenuItem<String>(
                                value: team['id'],
                                child: Text(team['teamName'] ?? 'Unnamed Team'),
                              );
                            }).toList(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select Team B';
                          }
                          if (value == _selectedTeamAId) {
                            return 'Team A and Team B must be different';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _selectedTeamBId = value;
                          });
                          if (value != null) {
                            _loadTeamPlayers(value, false);
                          }
                        },
                      ),

                      const SizedBox(height: 30),
                      _buildSectionTitle('Player Selection'),

                      if (_teamAPlayers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Team A Players',
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPlayerSelection(
                          _teamAPlayers,
                          _selectedTeamAPlayerIds,
                          true,
                        ),
                      ],

                      if (_teamBPlayers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Team B Players',
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPlayerSelection(
                          _teamBPlayers,
                          _selectedTeamBPlayerIds,
                          false,
                        ),
                      ],

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0D6EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    "Create Match",
                                    style: GoogleFonts.raleway(
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.raleway(
        textStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    // Handle empty items list to avoid issues
    if (items.isEmpty) {
      items =
          [
                DropdownMenuItem<T>(
                  value: null,
                  child: Text('No options available'),
                ),
              ]
              as List<DropdownMenuItem<T>>;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffF7F7F9),
            hintText: hint,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          // Make dropdown always require a selection
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ],
    );
  }

  Widget _buildPlayerSelection(
    List<Map<String, dynamic>> players,
    List<String> selectedPlayerIds,
    bool isTeamA,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffF7F7F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: players.length,
        itemBuilder: (context, index) {
          final player = players[index];
          final playerId = player['id'];
          final isSelected = selectedPlayerIds.contains(playerId);

          return CheckboxListTile(
            title: Text(player['email'] ?? 'Unknown'),
            subtitle:
                player['handicap'] != null
                    ? Text('Handicap: ${player['handicap']}')
                    : null,
            value: isSelected,
            onChanged: (selected) {
              setState(() {
                if (selected!) {
                  selectedPlayerIds.add(playerId);
                } else {
                  selectedPlayerIds.remove(playerId);
                }
              });
            },
          );
        },
      ),
    );
  }
}
