import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? phoneNumber;
  final GolfDetails golfDetails;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.phoneNumber,
    this.golfDetails = const GolfDetails(
      isMember: false,
      playingInLeague: false,
    ),
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    final rawGolfDetails = data['golfDetails'];
    final Map<String, dynamic> golfDetailsMap =
        rawGolfDetails is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawGolfDetails)
            : rawGolfDetails is Map
            ? Map<String, dynamic>.from(rawGolfDetails)
            : <String, dynamic>{};

    // Backward compatibility for older user documents that stored these
    // values at the root level instead of under golfDetails.
    if (!golfDetailsMap.containsKey('handicap') && data['handicap'] != null) {
      golfDetailsMap['handicap'] = data['handicap'];
    }
    if (!golfDetailsMap.containsKey('isMember') && data['isMember'] != null) {
      golfDetailsMap['isMember'] = data['isMember'];
    }
    if (!golfDetailsMap.containsKey('membershipId') &&
        data['membershipId'] != null) {
      golfDetailsMap['membershipId'] = data['membershipId'];
    }
    if (!golfDetailsMap.containsKey('playingInLeague') &&
        data['playingInLeague'] != null) {
      golfDetailsMap['playingInLeague'] = data['playingInLeague'];
    }
    if (!golfDetailsMap.containsKey('teamId') && data['teamId'] != null) {
      golfDetailsMap['teamId'] = data['teamId'];
    }
    if (!golfDetailsMap.containsKey('teamName') && data['teamName'] != null) {
      golfDetailsMap['teamName'] = data['teamName'];
    }
    if (!golfDetailsMap.containsKey('eventId') && data['eventId'] != null) {
      golfDetailsMap['eventId'] = data['eventId'];
    }
    if (!golfDetailsMap.containsKey('bracket') && data['bracket'] != null) {
      golfDetailsMap['bracket'] = data['bracket'];
    }

    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      firstName: data['firstName'],
      lastName: data['lastName'],
      dateOfBirth:
          data['dateOfBirth'] != null
              ? (data['dateOfBirth'] is DateTime
                  ? data['dateOfBirth']
                  : (data['dateOfBirth'] as Timestamp).toDate())
              : null,
      gender: data['gender'],
      phoneNumber: data['phoneNumber'],
      golfDetails:
          golfDetailsMap.isNotEmpty
              ? GolfDetails.fromMap(golfDetailsMap)
              : const GolfDetails(isMember: false, playingInLeague: false),
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] is DateTime
                  ? data['createdAt']
                  : (data['createdAt'] as Timestamp).toDate())
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] is DateTime
                  ? data['updatedAt']
                  : (data['updatedAt'] as Timestamp).toDate())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'golfDetails': golfDetails.toMap(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class GolfDetails {
  final double? handicap;
  final bool isMember;
  final String? membershipId;
  final bool playingInLeague;
  final String? teamId;
  final String? teamName;
  final String? eventId; // Field to store event ID
  final String? bracket; // Field to store player's bracket

  const GolfDetails({
    this.handicap,
    this.isMember = false,
    this.membershipId,
    this.playingInLeague = false,
    this.teamId,
    this.teamName,
    this.eventId,
    this.bracket,
  });

  Map<String, dynamic> toMap() {
    return {
      'handicap': handicap,
      'isMember': isMember,
      'membershipId': membershipId,
      'playingInLeague': playingInLeague,
      'teamId': teamId,
      'teamName': teamName,
      'eventId': eventId,
      'bracket': bracket,
    };
  }

  factory GolfDetails.fromMap(Map<String, dynamic> map) {
    return GolfDetails(
      handicap: _toDouble(map['handicap']),
      isMember: _toBool(map['isMember']),
      membershipId: _toNullableString(map['membershipId']),
      playingInLeague: _toBool(map['playingInLeague']),
      teamId: _toNullableString(map['teamId']),
      teamName: _toNullableString(map['teamName']),
      eventId: _toNullableString(map['eventId']),
      bracket: _toNullableString(map['bracket']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }
}

class Team {
  final String id;
  final String name;
  final String password;
  final String eventId; // Event ID this team belongs to

  Team({
    required this.id,
    required this.name,
    required this.password,
    required this.eventId,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'password': password, 'eventId': eventId};
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] ?? '',
      // Check for both field name possibilities
      name: map['teamName'] ?? map['name'] ?? '',
      // Check for both password field names
      password: map['teamPassword'] ?? map['password'] ?? '',
      // Get the event ID
      eventId: map['eventID'] ?? map['eventId'] ?? '',
    );
  }
}
