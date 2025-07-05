import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mgm_gc/models/tee_time_model.dart';

class SeedSlots {
  static Future<void> generateSlotsForDate(DateTime date) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String dateId = DateFormat('yyyy-MM-dd').format(date);

    // Set start and end times
    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      6,
      0,
    ); // 6:00 AM
    final endTime = DateTime(
      date.year,
      date.month,
      date.day,
      17,
      45,
    ); // 5:45 PM

    // Calculate number of 15-minute slots
    final slotDuration = const Duration(minutes: 15);
    final totalMinutes = endTime.difference(startTime).inMinutes;
    final numberOfSlots = (totalMinutes / slotDuration.inMinutes).floor();

    // Get batch for efficient writes
    final batch = firestore.batch();

    // Check if slots already exist
    final existingSlots =
        await firestore
            .collection('teeTimes')
            .doc(dateId)
            .collection('slots')
            .get();

    if (existingSlots.docs.isNotEmpty) {
      throw Exception(
        'Slots already exist for this date. Delete them first or choose another date.',
      );
    }

    // Create slots
    for (int i = 0; i < numberOfSlots; i++) {
      final slotStartTime = startTime.add(slotDuration * i);
      final slotEndTime = slotStartTime.add(slotDuration);

      final slotId = DateFormat('HHmm').format(slotStartTime);
      final slotRef = firestore
          .collection('teeTimes')
          .doc(dateId)
          .collection('slots')
          .doc(slotId);

      final slot = TeeTimeModel(
        id: slotId,
        startTime: slotStartTime,
        endTime: slotEndTime,
        status: TeeTimeStatus.open,
      );

      batch.set(slotRef, slot.toFirestore());
    }

    // Commit the batch
    await batch.commit();
  }

  static Future<void> deleteAllSlotsForDate(DateTime date) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String dateId = DateFormat('yyyy-MM-dd').format(date);

    final snapshot =
        await firestore
            .collection('teeTimes')
            .doc(dateId)
            .collection('slots')
            .get();

    final batch = firestore.batch();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
