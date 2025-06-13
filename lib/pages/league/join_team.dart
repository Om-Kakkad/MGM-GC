import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';

class JoinTeamPage extends StatefulWidget {
  const JoinTeamPage({super.key});

  @override
  _JoinTeamPageState createState() => _JoinTeamPageState();
}

class _JoinTeamPageState extends State<JoinTeamPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _teams = [];
  String? _selectedTeamId;
  String? _selectedEventId;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllTeams();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTeams() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all events
      final eventsSnapshot = await _firestore.collection('events').get();
      List<Map<String, dynamic>> allTeams = [];

      // For each event, get its teams
      for (var eventDoc in eventsSnapshot.docs) {
        final eventId = eventDoc.id;
        final eventData = eventDoc.data();
        final eventName =
            eventData['eventName'] ?? eventData['name'] ?? 'Unnamed Event';

        // Get teams for this event
        final teamsSnapshot =
            await _firestore
                .collection('events')
                .doc(eventId)
                .collection('teams')
                .get();

        for (var teamDoc in teamsSnapshot.docs) {
          final teamData = teamDoc.data();
          allTeams.add({
            'id': teamDoc.id,
            'teamName': teamData['teamName'] ?? 'Unnamed Team',
            'eventId': eventId,
            'eventName': eventName,
            'displayName': '${teamData['teamName']} ($eventName)',
          });
        }
      }

      setState(() {
        _teams = allTeams;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading teams: $e');
      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: "Error loading teams: $e",
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _requestToJoinTeam() async {
    if (_selectedTeamId == null || _selectedEventId == null) {
      Fluttertoast.showToast(
        msg: "Please select a team",
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter the team password",
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the team to check password
      final teamDoc =
          await _firestore
              .collection('events')
              .doc(_selectedEventId)
              .collection('teams')
              .doc(_selectedTeamId)
              .get();

      if (!teamDoc.exists) {
        Fluttertoast.showToast(
          msg: "Team not found",
          toastLength: Toast.LENGTH_LONG,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final teamData = teamDoc.data()!;
      final correctPassword = teamData['teamPassword'] ?? teamData['password'];

      if (_passwordController.text != correctPassword) {
        Fluttertoast.showToast(
          msg: "Incorrect team password",
          toastLength: Toast.LENGTH_LONG,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user info
      final user = _auth.currentUser;
      if (user == null) {
        Fluttertoast.showToast(
          msg: "Please log in first",
          toastLength: Toast.LENGTH_LONG,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      // Create a team join request
      await _firestore.collection('team_requests').add({
        'userId': user.uid,
        'userEmail': user.email,
        'userFirstName': userData?['firstName'] ?? '',
        'userLastName': userData?['lastName'] ?? '',
        'teamId': _selectedTeamId,
        'eventId': _selectedEventId,
        'teamName': teamData['teamName'] ?? 'Unnamed Team',
        'requestDate': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      Fluttertoast.showToast(
        msg:
            "Join request submitted successfully! An admin will review your request.",
        toastLength: Toast.LENGTH_LONG,
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error requesting to join team: $e');
      Fluttertoast.showToast(
        msg: "Error requesting to join team: $e",
        toastLength: Toast.LENGTH_LONG,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Join a Team',
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
                    Text(
                      'Select a Team to Join',
                      style: GoogleFonts.raleway(
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_teams.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No teams available to join'),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Team',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items:
                            _teams.map((team) {
                              return DropdownMenuItem<String>(
                                value: team['id'],
                                child: Text(team['displayName']),
                                onTap: () {
                                  setState(() {
                                    _selectedEventId = team['eventId'];
                                  });
                                },
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTeamId = value;
                          });
                        },
                      ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Team Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      obscureText: true,
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0D6EFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _requestToJoinTeam,
                        child: Text(
                          'Request to Join Team',
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Note: Your request will be reviewed by an admin before you are added to the team.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
    );
  }
}
