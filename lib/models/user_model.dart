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
          data['golfDetails'] != null
              ? GolfDetails.fromMap(data['golfDetails'])
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

  const GolfDetails({
    this.handicap,
    required this.isMember,
    this.membershipId,
    required this.playingInLeague,
    this.teamId,
    this.teamName,
  });

  Map<String, dynamic> toMap() {
    return {
      'handicap': handicap,
      'isMember': isMember,
      'membershipId': membershipId,
      'playingInLeague': playingInLeague,
      'teamId': teamId,
      'teamName': teamName,
    };
  }

  factory GolfDetails.fromMap(Map<String, dynamic> map) {
    return GolfDetails(
      handicap: map['handicap']?.toDouble(),
      isMember: map['isMember'] ?? false,
      membershipId: map['membershipId'],
      playingInLeague: map['playingInLeague'] ?? false,
      teamId: map['teamId'],
      teamName: map['teamName'],
    );
  }
}

class Team {
  final String id;
  final String name;
  final String password;

  Team({required this.id, required this.name, required this.password});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'password': password};
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] ?? '',
      // Check for both field name possibilities (teamName from new teams or name from older teams)
      name: map['teamName'] ?? map['name'] ?? '',
      // Check for both password field names
      password: map['teamPassword'] ?? map['password'] ?? '',
    );
  }
}
