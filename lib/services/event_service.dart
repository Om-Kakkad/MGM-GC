import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mgm_gc/models/event.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Register a user for an event
  Future<void> registerForEvent(String eventId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('You must be logged in to register for events.');
      }

      // Check if user is already registered
      final registrationCheck =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('registrations')
              .doc(userId)
              .get();

      if (registrationCheck.exists) {
        throw Exception('You are already registered for this event.');
      }

      // Add registration
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .doc(userId)
          .set({
            'registeredAt': FieldValue.serverTimestamp(),
            'userId': userId,
            'status': 'confirmed',
          });

      // Also update the user's events collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('events')
          .doc(eventId)
          .set({
            'registeredAt': FieldValue.serverTimestamp(),
            'status': 'confirmed',
          });
    } catch (e) {
      print('Error registering for event: $e');
      rethrow;
    }
  }

  // Check if a user is registered for an event
  Future<bool> isUserRegistered(String eventId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return false;
      }

      final doc =
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('registrations')
              .doc(userId)
              .get();

      return doc.exists;
    } catch (e) {
      print('Error checking registration: $e');
      return false;
    }
  }
}
