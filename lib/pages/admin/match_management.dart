import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mgm_gc/services/delete_service.dart';

class MatchManagementPage extends StatefulWidget {
  const MatchManagementPage({super.key});

  @override
  _MatchManagementPageState createState() => _MatchManagementPageState();
}

class _MatchManagementPageState extends State<MatchManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeleteService _deleteService = DeleteService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _matches = [];
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
      final eventsSnapshot = await _firestore.collection('events').get();
      setState(() {
        _events = eventsSnapshot.docs;
        if (_events.isNotEmpty && _selectedEventId == null) {
          _selectedEventId = _events.first.id;
          _loadMatches(_selectedEventId!);
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

  Future<void> _loadMatches(String eventId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Already using the correct nested collection path
      final matchesSnapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('matches')
              .orderBy('matchDateTime', descending: true)
              .get();

      List<Map<String, dynamic>> matches = [];
      for (var doc in matchesSnapshot.docs) {
        Map<String, dynamic> match = doc.data() as Map<String, dynamic>;
        match['id'] = doc.id;
        match['eventId'] = eventId;
        matches.add(match);
      }

      setState(() {
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading matches: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading matches: $e')));
    }
  }

  Future<void> _deleteMatch(String eventId, String matchId) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Match'),
                content: const Text(
                  'Are you sure you want to delete this match? This action cannot be undone.',
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
      // Use the deleteMatchWithCascade method from DeleteService
      await _deleteService.deleteMatchWithCascade(eventId, matchId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match deleted successfully')),
      );

      _loadMatches(eventId);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting match: $e')));
    }
  }

  Future<String> _getTeamName(String eventId, String teamId) async {
    try {
      final doc =
          await _firestore
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Match Management',
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
                          'Matches',
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/create-match').then(
                              (_) =>
                                  _selectedEventId != null
                                      ? _loadMatches(_selectedEventId!)
                                      : null,
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

                  // Event selector
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
                          _loadMatches(value);
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
                            : _matches.isEmpty
                            ? Center(
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
                                    'No matches available',
                                    style: GoogleFonts.raleway(
                                      textStyle: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Click "Create Match" to add a new match',
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
                              itemCount: _matches.length,
                              itemBuilder: (context, index) {
                                final matchData = _matches[index];
                                final matchId = matchData['id'];
                                final eventId = matchData['eventId'];

                                // Format date
                                final DateTime matchDate =
                                    (matchData['matchDateTime'] as Timestamp)
                                        .toDate();
                                final String formattedDate = DateFormat(
                                  'MMM dd, yyyy - hh:mm a',
                                ).format(matchDate);

                                // Get match status and type
                                final String matchStatus =
                                    matchData['matchStatus'] ?? 'active';
                                final String matchType =
                                    matchData['matchType'] ?? '4-ball';

                                // Get team IDs for display
                                final List<String> teamIds = List<String>.from(
                                  matchData['teams'] ?? [],
                                );

                                return FutureBuilder<List<String>>(
                                  future: Future.wait(
                                    teamIds.map(
                                      (id) => _getTeamName(eventId, id),
                                    ),
                                  ),
                                  builder: (context, snapshot) {
                                    final String teamsDisplay =
                                        snapshot.data != null
                                            ? snapshot.data!.join(' vs ')
                                            : 'Loading teams...';

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
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    teamsDisplay,
                                                    style: GoogleFonts.raleway(
                                                      textStyle:
                                                          const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                      matchStatus,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    matchStatus.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
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
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                // View Details Button
                                                OutlinedButton(
                                                  onPressed: () {
                                                    // TODO: Navigate to match details page when available
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Match details view not implemented yet',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'View Details',
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Delete Button
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed:
                                                      () => _deleteMatch(
                                                        eventId,
                                                        matchId,
                                                      ),
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
                            ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () =>
                _selectedEventId != null
                    ? _loadMatches(_selectedEventId!)
                    : _loadEvents(),
        backgroundColor: const Color(0xff0D6EFD),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
