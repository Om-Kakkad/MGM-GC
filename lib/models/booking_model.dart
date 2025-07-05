import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String teeTimeId;
  final String dateId;
  final String userId;
  final DateTime bookingDate;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> players;
  final bool isPaid;
  final double? amountPaid;

  BookingModel({
    required this.id,
    required this.teeTimeId,
    required this.dateId,
    required this.userId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.players = const [],
    this.isPaid = false,
    this.amountPaid,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      teeTimeId: data['teeTimeId'],
      dateId: data['dateId'],
      userId: data['userId'],
      bookingDate: (data['bookingDate'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      players: List<String>.from(data['players'] ?? []),
      isPaid: data['isPaid'] ?? false,
      amountPaid: data['amountPaid'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teeTimeId': teeTimeId,
      'dateId': dateId,
      'userId': userId,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'players': players,
      'isPaid': isPaid,
      'amountPaid': amountPaid,
    };
  }

  bool get isUpcoming => startTime.isAfter(DateTime.now());
}
