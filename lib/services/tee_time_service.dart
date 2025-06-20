import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tee_time_slot.dart';

class TeeTimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<TeeTimeSlot>> getSlots(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _firestore
        .collection('teeTimeSlots')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('time', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TeeTimeSlot.fromFirestore(doc)).toList(),
        );
  }

  Future<void> holdSlot(String slotId, String userId) async {
    await _firestore.collection('teeTimeSlots').doc(slotId).update({
      'status': 'held',
      'heldBy': userId,
    });
  }

  Future<void> bookSlot({
    required String dateId,
    required String slotId,
    required String userId,
  }) async {
    final slotRef = _firestore
        .collection('teeTimes')
        .doc(dateId)
        .collection('slots')
        .doc(slotId);

    final bookingRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookings')
        .doc(slotId);

    await _firestore.runTransaction((transaction) async {
      final slotSnap = await transaction.get(slotRef);

      if (slotSnap.exists) {
        final data = slotSnap.data() as Map<String, dynamic>;
        final status = data['status'];
        final bookedByUid = data['bookedByUid'];

        if (status != 'open' && !(status == 'held' && bookedByUid == userId)) {
          throw Exception('Slot already booked');
        }
      }

      final bookingSnap = await transaction.get(bookingRef);
      if (bookingSnap.exists) {
        throw Exception('Already booked');
      }

      transaction.set(
        slotRef,
        {
          'status': 'booked',
          'bookedByUid': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        bookingRef,
        {
          'slotId': slotId,
          'dateId': dateId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<void> blockSlot(String slotId, {String? reason}) async {
    await _firestore.collection('teeTimeSlots').doc(slotId).update({
      'status': 'blocked',
      if (reason != null) 'reason': reason,
    });
  }
}
