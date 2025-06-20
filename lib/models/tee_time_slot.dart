import 'package:cloud_firestore/cloud_firestore.dart';

class TeeTimeSlot {
  final String id;
  final DateTime time;
  final String status; // available, held, booked, blocked
  final String? heldBy;
  final String? bookedBy;

  TeeTimeSlot({
    required this.id,
    required this.time,
    required this.status,
    this.heldBy,
    this.bookedBy,
  });

  factory TeeTimeSlot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeeTimeSlot(
      id: doc.id,
      time: (data['time'] as Timestamp).toDate(),
      status: data['status'] ?? 'available',
      heldBy: data['heldBy'],
      bookedBy: data['bookedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': Timestamp.fromDate(time),
      'status': status,
      if (heldBy != null) 'heldBy': heldBy,
      if (bookedBy != null) 'bookedBy': bookedBy,
    };
  }
}
