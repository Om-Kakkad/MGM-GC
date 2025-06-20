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

  Future<void> bookSlot(String slotId, String userId) async {
    final docRef = _firestore.collection('teeTimeSlots').doc(slotId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Slot not found');
      }
      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'available';
      final heldBy = data['heldBy'];
      if (status == 'booked' || status == 'blocked') {
        throw Exception('Slot not available');
      }
      if (status == 'held' && heldBy != userId) {
        throw Exception('Slot held by another user');
      }
      transaction.update(docRef, {
        'status': 'booked',
        'bookedBy': userId,
        'heldBy': FieldValue.delete(),
      });
    });
  }

  Future<void> blockSlot(String slotId, {String? reason}) async {
    await _firestore.collection('teeTimeSlots').doc(slotId).update({
      'status': 'blocked',
      if (reason != null) 'reason': reason,
    });
  }
}
