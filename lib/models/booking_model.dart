import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String teeTimeId;
  final String dateId;
  final String userId;
  final String?
  bookerName; // Add this field to store the name of the user who made the booking
  final DateTime bookingDate;
  final DateTime startTime;
  final DateTime endTime;
  final List<PlayerInfo> players;
  final bool isPaid;
  final double? amountPaid;
  final bool isSharedBooking;
  final String? primaryBookingId;

  BookingModel({
    required this.id,
    required this.teeTimeId,
    required this.dateId,
    required this.userId,
    this.bookerName,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.players = const [],
    this.isPaid = false,
    this.amountPaid,
    this.isSharedBooking = false,
    this.primaryBookingId,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Convert players data to PlayerInfo objects
    List<PlayerInfo> playersList = [];
    if (data['players'] != null) {
      if (data['players'] is List) {
        // Handle legacy format (just strings)
        playersList =
            List<String>.from(data['players'])
                .map((name) => PlayerInfo(name: name, isRegistered: false))
                .toList();
      } else if (data['players'] is Map) {
        // Handle new format (map of player objects)
        Map<String, dynamic> playersMap = Map<String, dynamic>.from(
          data['players'],
        );
        playersMap.forEach((key, value) {
          if (value is Map) {
            playersList.add(
              PlayerInfo.fromMap(Map<String, dynamic>.from(value)),
            );
          }
        });
      }
    }

    return BookingModel(
      id: doc.id,
      teeTimeId: data['teeTimeId'],
      dateId: data['dateId'],
      userId: data['userId'],
      bookerName: data['bookerName'],
      bookingDate: (data['bookingDate'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      players: playersList,
      isPaid: data['isPaid'] ?? false,
      amountPaid: (data['amountPaid'] as num?)?.toDouble(),
      isSharedBooking: data['isSharedBooking'] ?? false,
      primaryBookingId: data['primaryBookingId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    // Convert PlayerInfo objects to map for Firestore
    Map<String, Map<String, dynamic>> playersMap = {};
    for (int i = 0; i < players.length; i++) {
      playersMap['player_$i'] = players[i].toMap();
    }

    return {
      'teeTimeId': teeTimeId,
      'dateId': dateId,
      'userId': userId,
      'bookerName': bookerName,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'players': playersMap,
      'isPaid': isPaid,
      'amountPaid': amountPaid,
      'isSharedBooking': isSharedBooking,
      'primaryBookingId': primaryBookingId,
    };
  }

  bool get isUpcoming => startTime.isAfter(DateTime.now());
}

class PlayerInfo {
  final String name;
  final String? userId; // User ID for registered users, null for non-registered
  final bool isRegistered;

  PlayerInfo({required this.name, this.userId, this.isRegistered = false});

  factory PlayerInfo.fromMap(Map<String, dynamic> map) {
    return PlayerInfo(
      name: map['name'] ?? '',
      userId: map['userId'],
      isRegistered: map['isRegistered'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'userId': userId, 'isRegistered': isRegistered};
  }
}
