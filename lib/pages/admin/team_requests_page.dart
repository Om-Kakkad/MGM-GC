import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class TeamRequestsPage extends StatefulWidget {
  const TeamRequestsPage({super.key});

  @override
  State<TeamRequestsPage> createState() => _TeamRequestsPageState();
}

class _TeamRequestsPageState extends State<TeamRequestsPage>
    with SingleTickerProviderStateMixin {
  String? _selectedTeam;
  String? _selectedProcessedTeam;
  final Map<String, TextEditingController> _handicapControllers = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Clean up all controllers
    for (var controller in _handicapControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Pending Requests"),
            Tab(text: "Processed Requests"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingRequestsTab(), _buildProcessedRequestsTab()],
      ),
    );
  }

  Widget _buildPendingRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
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

        final filtered =
            _selectedTeam == null
                ? requests
                : requests
                    .where(
                      (d) =>
                          (d.data() as Map<String, dynamic>)['teamName'] ==
                          _selectedTeam,
                    )
                    .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<String>(
                value: _selectedTeam ?? 'All Teams',
                items:
                    ['All Teams', ...teamNames]
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
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
                  final userId = request['userId'];

                  // Create a controller for this request if it doesn't exist
                  if (!_handicapControllers.containsKey(requestId)) {
                    _handicapControllers[requestId] = TextEditingController(
                      text: '0',
                    );
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .get(),
                    builder: (context, userSnapshot) {
                      // Default handicap value
                      double handicap = 0.0;

                      // If we have user data, update the handicap
                      if (userSnapshot.connectionState ==
                              ConnectionState.done &&
                          userSnapshot.hasData &&
                          userSnapshot.data!.exists) {
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;

                        // Try to get handicap from golfDetails or root level
                        final golfDetails =
                            userData?['golfDetails'] as Map<String, dynamic>?;
                        handicap =
                            (golfDetails?['handicap'] ??
                                    userData?['handicap'] ??
                                    0.0)
                                .toDouble();

                        // Update controller text if it's not already set
                        if (_handicapControllers[requestId]!.text == '0') {
                          _handicapControllers[requestId]!.text =
                              handicap.toString();
                        }
                      }

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

                              // Handicap display and edit field
                              Row(
                                children: [
                                  Text('Handicap: '),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _handicapControllers[requestId],
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        hintText: 'Enter handicap',
                                      ),
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                  ),
                                ],
                              ),

                              Text(
                                'Date: ${_formatDate(request['requestDate'])}',
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed:
                                        () =>
                                            _rejectRequest(context, requestId),
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
                                          double.tryParse(
                                                _handicapControllers[requestId]!
                                                    .text,
                                              ) ??
                                              0.0,
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
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProcessedRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('team_requests')
              .where('status', whereIn: ['approved', 'rejected'])
              .orderBy('processedDate', descending: true)
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
          return const Center(child: Text('No processed team join requests'));
        }

        final teamNames = <String>{};
        for (var doc in requests) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['teamName'] != null) {
            teamNames.add(data['teamName']);
          }
        }

        final filtered =
            _selectedProcessedTeam == null
                ? requests
                : requests
                    .where(
                      (d) =>
                          (d.data() as Map<String, dynamic>)['teamName'] ==
                          _selectedProcessedTeam,
                    )
                    .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<String>(
                value: _selectedProcessedTeam ?? 'All Teams',
                items:
                    ['All Teams', ...teamNames]
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProcessedTeam =
                        value == 'All Teams' ? null : value;
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
                  final userId = request['userId'];
                  final status = request['status'] as String;
                  final isApproved = status == 'approved';

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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  request['userName'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isApproved
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isApproved ? 'APPROVED' : 'REJECTED',
                                  style: TextStyle(
                                    color:
                                        isApproved
                                            ? Colors.green.shade800
                                            : Colors.red.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Email: ${request['userEmail']}'),
                          Text('Team: ${request['teamName']}'),

                          if (isApproved && request['approvedHandicap'] != null)
                            Text('Handicap: ${request['approvedHandicap']}'),

                          Text(
                            'Request Date: ${_formatDate(request['requestDate'])}',
                          ),
                          Text(
                            'Processed Date: ${_formatDate(request['processedDate'])}',
                          ),

                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    () => _rollbackRequest(
                                      context,
                                      requestId,
                                      request,
                                    ),
                                icon: const Icon(Icons.restore),
                                label: const Text('Rollback'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
    double handicap,
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
        'golfDetails.handicap': handicap, // Include updated handicap
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
        'approvedHandicap': handicap, // Record the handicap that was approved
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

  Future<void> _rollbackRequest(
    BuildContext context,
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final String userId = requestData['userId'];
      final String status = requestData['status'];

      // Start a batch operation
      final batch = firestore.batch();

      // If request was approved, we need to undo team membership
      if (status == 'approved') {
        final String teamId = requestData['teamId'];
        final String eventId = requestData['eventId'];

        // 1. Update user to remove team membership
        batch.update(firestore.collection('users').doc(userId), {
          'role': 'user', // Change back to regular user
          'golfDetails.teamId': FieldValue.delete(),
          'golfDetails.teamName': FieldValue.delete(),
          'golfDetails.eventId': FieldValue.delete(),
          'golfDetails.playingInLeague': false,
        });

        // 2. Remove user from team's players array
        batch.update(
          firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(teamId),
          {
            'players': FieldValue.arrayRemove([userId]),
          },
        );
      }

      // 3. Mark request as pending again
      batch.update(firestore.collection('team_requests').doc(requestId), {
        'status': 'pending',
        'processedDate': FieldValue.delete(),
        'approvedHandicap':
            FieldValue.delete(), // Remove approved handicap if exists
      });

      // Commit the batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rolled back to pending successfully'),
        ),
      );

      // Switch to the pending tab
      _tabController.animateTo(0);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rolling back request: $e')));
    }
  }
}
