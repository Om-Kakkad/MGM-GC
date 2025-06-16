import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class TeamRequestsPage extends StatefulWidget {
  const TeamRequestsPage({super.key});

  @override
  State<TeamRequestsPage> createState() => _TeamRequestsPageState();
}

class _TeamRequestsPageState extends State<TeamRequestsPage> {
  String? _selectedTeam;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Team Join Requests',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('team_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('requestDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return const Center(child: Text('No pending team join requests'));
          }

          final teamNames = <String>{};
          for (var doc in requests) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['teamName'] != null) {
              teamNames.add(data['teamName']);
            }
          }

          final filtered = _selectedTeam == null
              ? requests
              : requests.where((d) =>
                  (d.data() as Map<String, dynamic>)['teamName'] == _selectedTeam)
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButton<String>(
                  value: _selectedTeam ?? 'All Teams',
                  items: ['All Teams', ...teamNames]
                      .map(
                        (name) => DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTeam = value == 'All Teams' ? null : value;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final request =
                        filtered[index].data() as Map<String, dynamic>;
                    final requestId = filtered[index].id;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
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
                        request['userName'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Email: ${request['userEmail']}'),
                      Text('Team: ${request['teamName']}'),
                      Text('Date: ${_formatDate(request['requestDate'])}'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _rejectRequest(context, requestId),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed:
                                () => _approveRequest(
                                  context,
                                  requestId,
                                  request['userId'],
                                  request['teamId'],
                                  request['eventId'],
                                  request['teamName'],
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff0D6EFD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        },
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }

    return 'Invalid date';
  }

  Future<void> _approveRequest(
    BuildContext context,
    String requestId,
    String userId,
    String teamId,
    String eventId,
    String teamName,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Start a batch operation
      final batch = firestore.batch();

      // 1. Update user role and golf details
      batch.update(firestore.collection('users').doc(userId), {
        'role': 'league_player',
        'golfDetails.teamId': teamId,
        'golfDetails.teamName': teamName,
        'golfDetails.eventId': eventId,
        'golfDetails.playingInLeague': true,
      });

      // 2. Add user to team's players array
      batch.update(
        firestore
            .collection('events')
            .doc(eventId)
            .collection('teams')
            .doc(teamId),
        {
          'players': FieldValue.arrayUnion([userId]),
        },
      );

      // 3. Mark request as approved
      batch.update(firestore.collection('team_requests').doc(requestId), {
        'status': 'approved',
        'processedDate': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request approved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving request: $e')));
    }
  }

  Future<void> _rejectRequest(BuildContext context, String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('team_requests')
          .doc(requestId)
          .update({
            'status': 'rejected',
            'processedDate': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request rejected')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting request: $e')));
    }
  }
}
