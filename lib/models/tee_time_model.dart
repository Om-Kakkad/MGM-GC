import 'package:cloud_firestore/cloud_firestore.dart';

enum TeeTimeStatus { open, held, booked, blocked }

class TeeTimeModel {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final TeeTimeStatus status;
  final String? bookedByUid;
  final List<String> players;
  final String? reason;

  TeeTimeModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.bookedByUid,
    this.players = const [],
    this.reason,
  });

  factory TeeTimeModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TeeTimeModel(
      id: doc.id,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: TeeTimeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => TeeTimeStatus.open,
      ),
      bookedByUid: data['bookedByUid'],
      players: List<String>.from(data['players'] ?? []),
      reason: data['reason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status.toString().split('.').last,
      'bookedByUid': bookedByUid,
      'players': players,
      'reason': reason,
    };
  }

  TeeTimeModel copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    TeeTimeStatus? status,
    String? bookedByUid,
    List<String>? players,
    String? reason,
  }) {
    return TeeTimeModel(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      bookedByUid: bookedByUid ?? this.bookedByUid,
      players: players ?? this.players,
      reason: reason ?? this.reason,
    );
  }
}
