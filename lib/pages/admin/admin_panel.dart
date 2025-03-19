import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'event_creation_form.dart';
import 'package:mgm_gc/pages/admin/team_creation.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
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
      appBar: AppBar(title: const Text('Admin Panel')),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildUsersTab(),
          _buildEventsTab(),
          const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: TeamCreationForm(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Teams'),
        ],
      ),
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
                onSelected: (value) {
                  _firestore.collection('users').doc(userId).update({
                    'role': value,
                  });
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
}
