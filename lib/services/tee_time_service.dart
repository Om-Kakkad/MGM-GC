import 'package:cloud_firestore/cloud_firestore.dart';

class TeeTimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getSlotsForDate(DateTime date) async {
    final doc = await _firestore
        .collection('teeTimes')
        .doc(_formatDate(date))
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['slots'] ?? []);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getBookingsForUser(String uid) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .get();
    return snapshot.docs
        .map((d) => {...(d.data()), 'id': d.id})
        .toList();
  }

  Future<void> bookSlot(
    DateTime date,
    Map<String, dynamic> slot,
    String uid,
  ) async {
    await _firestore.collection('bookings').add({
      'userId': uid,
      'date': Timestamp.fromDate(date),
      'slot': slot,
    });
  }

  Future<void> cancelBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).delete();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
