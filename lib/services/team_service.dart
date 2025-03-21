import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mgm_gc/models/team.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new team
  Future<String> createTeam(Team team) async {
    try {
      // Create the team document - using 'teams' instead of 'Teams'
      DocumentReference teamRef = await _firestore.collection('teams').add({
        'teamName': team.teamName,
        'teamPassword': team.teamPassword,
        'eventID': team.eventID,
        'players': team.players,
      });

      // Update the team with its ID
      await teamRef.update({'teamID': teamRef.id});

      // Update the event document to include this team
      await _firestore.collection('events').doc(team.eventID).update({
        'teamIDs': FieldValue.arrayUnion([teamRef.id]),
      });

      return teamRef.id;
    } catch (e) {
      print('Error creating team: $e');
      rethrow;
    }
  }

  // Get all league events
  Future<List<Map<String, dynamic>>> getLeagueEvents() async {
    try {
      print("Fetching league events..."); // Debug print

      // First check what events are available
      QuerySnapshot allEvents = await _firestore.collection('events').get();
      print("Total events found: ${allEvents.docs.length}");

      // Debug all events
      for (var doc in allEvents.docs) {
        var data = doc.data() as Map<String, dynamic>;
        print(
          "Event ID: ${doc.id}, Type: ${data['eventType']}, Name: ${data['eventName'] ?? data['name']}",
        );
      }

      // Try the actual query with case-insensitive comparison
      QuerySnapshot snapshot = await _firestore.collection('events').get();

      print("Found ${snapshot.docs.length} events total"); // Debug print

      // Filter in code rather than in query to handle case sensitivity
      final leagueEvents =
          snapshot.docs
              .where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String eventType =
                    (data['eventType'] ?? '').toString().toLowerCase();
                return eventType == 'league';
              })
              .map((doc) {
                var data = doc.data() as Map<String, dynamic>;

                // Add ID to data
                data['id'] = doc.id;

                // Normalize field names
                if (!data.containsKey('eventName') &&
                    data.containsKey('name')) {
                  data['eventName'] = data['name'];
                }

                print(
                  "Found league event: ${data['eventName']} (ID: ${doc.id})",
                );
                return data;
              })
              .toList();

      print("Filtered to ${leagueEvents.length} league events");
      return leagueEvents;
    } catch (e) {
      print('Error fetching league events: $e');
      return [];
    }
  }

  // Get a specific league event by ID
  Future<Map<String, dynamic>?> getLeagueEventById(String eventId) async {
    try {
      DocumentSnapshot eventDoc =
          await _firestore.collection('events').doc(eventId).get();

      if (!eventDoc.exists) {
        return null;
      }

      Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;

      // Add ID to data
      eventData['id'] = eventDoc.id;

      return eventData;
    } catch (e) {
      print('Error fetching league event: $e');
      return null;
    }
  }

  // Get all dates for a league event
  Future<List<DateTime>> getLeagueEventDates(String eventId) async {
    try {
      Map<String, dynamic>? eventData = await getLeagueEventById(eventId);

      if (eventData == null || !eventData.containsKey('eventDates')) {
        return [];
      }

      // Convert Firestore timestamps to DateTime objects
      List<DateTime> dates = [];
      var eventDates = eventData['eventDates'] as List<dynamic>;

      for (var date in eventDates) {
        if (date is Timestamp) {
          dates.add(date.toDate());
        }
      }

      return dates;
    } catch (e) {
      print('Error fetching league event dates: $e');
      return [];
    }
  }
}
