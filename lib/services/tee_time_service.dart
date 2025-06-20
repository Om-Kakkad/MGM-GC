import 'package:cloud_firestore/cloud_firestore.dart';

class TeeTimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getSlotsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('teeTimeSlots')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('time', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('time')
        .snapshots();
  }

  Future<void> blockSlot(String slotId, bool isBlocked) async {
    await _firestore
        .collection('teeTimeSlots')
        .doc(slotId)
        .update({'blocked': isBlocked});
  }

  Future<void> holdSlot(String slotId, bool isHeld) async {
    await _firestore
        .collection('teeTimeSlots')
        .doc(slotId)
        .update({'held': isHeld});
  }
}
