import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mgm_gc/models/event.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Event>> getEvents() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('events')
              .orderBy('eventDates', descending: false)
              .get();

      return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching events: $e');
      rethrow;
    }
  }

  Future<Event> getEventById(String eventId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('events').doc(eventId).get();

      if (doc.exists) {
        return Event.fromFirestore(doc);
      } else {
        throw Exception('Event not found');
      }
    } catch (e) {
      print('Error fetching event details: $e');
      rethrow;
    }
  }
}
