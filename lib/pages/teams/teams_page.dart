import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/team.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  _TeamsPageState createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  String? _selectedEventId;
  List<Team> _teams = [];

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
      final querySnapshot =
          await _firestore
              .collection('events')
              .orderBy('createdAt', descending: true)
              .get();

      final events =
          querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['eventName'] ?? 'Unnamed Event',
              'type': data['eventType'] ?? 'Unknown',
              'date': data['date'],
            };
          }).toList();

      setState(() {
        _events = events;
        _isLoading = false;
      });

      // Auto-select first event if available
      if (events.isNotEmpty) {
        _selectEvent(events.first['id']);
      }
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

  Future<void> _selectEvent(String eventId) async {
    setState(() {
      _selectedEventId = eventId;
      _isLoading = true;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .get();

      final teams =
          querySnapshot.docs.map((doc) {
            return Team.fromFirestore(doc);
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

  Future<List<Map<String, dynamic>>> _getTeamPlayersInfo(
    List<String> playerIds,
  ) async {
    if (playerIds.isEmpty) return [];

    try {
      final List<Map<String, dynamic>> playersInfo = [];

      for (String playerId in playerIds) {
        final playerDoc =
            await _firestore.collection('users').doc(playerId).get();
        if (playerDoc.exists) {
          final data = playerDoc.data()!;
          playersInfo.add({
            'id': playerId,
            'name':
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            'email': data['email'] ?? '',
            'handicap': data['golfDetails']?['handicap'],
          });
        }
      }

      return playersInfo;
    } catch (e) {
      print('Error getting player info: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Teams',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Event Selector
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Event',
                      style: GoogleFonts.raleway(
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedEventId,
                      hint: const Text('Choose an event'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items:
                          _events.map((event) {
                            return DropdownMenuItem<String>(
                              value: event['id'],
                              child: Text(
                                '${event['name']} (${event['type']})',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          _selectEvent(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Teams List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedEventId == null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Please select an event to view teams',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _teams.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No teams found for this event',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: () => _selectEvent(_selectedEventId!),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _teams.length,
                        itemBuilder: (context, index) {
                          final team = _teams[index];
                          return _buildTeamCard(team);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTeamDetailsDialog(team),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff0D6EFD).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group,
                      color: Color(0xff0D6EFD),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.teamName,
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${team.players.length} players',
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
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),

              if (team.players.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Quick Players Preview
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getTeamPlayersInfo(team.players.take(3).toList()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading players...'),
                        ],
                      );
                    }

                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final players = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Players:',
                            style: GoogleFonts.raleway(
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...players.map((player) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      player['name'].isEmpty
                                          ? player['email']
                                          : player['name'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (player['handicap'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'HC: ${player['handicap'].toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (team.players.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '... and ${team.players.length - 3} more',
                                style: GoogleFonts.raleway(
                                  textStyle: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }

                    return const Text(
                      'Unable to load player information',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showTeamDetailsDialog(Team team) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xff0D6EFD).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.group, color: Color(0xff0D6EFD)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        team.teamName,
                        style: GoogleFonts.raleway(
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Team Players
                if (team.players.isNotEmpty) ...[
                  Text(
                    'Team Players (${team.players.length})',
                    style: GoogleFonts.raleway(
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getTeamPlayersInfo(team.players),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        final players = snapshot.data!;
                        return Column(
                          children:
                              players.map((player) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(
                                        0xff0D6EFD,
                                      ).withOpacity(0.1),
                                      child: const Icon(
                                        Icons.person,
                                        color: Color(0xff0D6EFD),
                                      ),
                                    ),
                                    title: Text(
                                      player['name'].isEmpty
                                          ? player['email']
                                          : player['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle:
                                        player['name'].isNotEmpty
                                            ? Text(player['email'])
                                            : null,
                                    trailing:
                                        player['handicap'] != null
                                            ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                'HC: ${player['handicap'].toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            )
                                            : null,
                                  ),
                                );
                              }).toList(),
                        );
                      }

                      return const Text('Unable to load player information');
                    },
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No players in this team yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
