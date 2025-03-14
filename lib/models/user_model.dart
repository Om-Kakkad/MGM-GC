class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String gender;
  final String phoneNumber;
  final GolfDetails golfDetails;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.phoneNumber,
    required this.golfDetails,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName ?? '$firstName $lastName',
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

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      dateOfBirth: map['dateOfBirth']?.toDate() ?? DateTime.now(),
      gender: map['gender'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      golfDetails: GolfDetails.fromMap(map['golfDetails'] ?? {}),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }
}

class GolfDetails {
  final double? handicap;
  final bool isMember;
  final String? membershipId;
  final bool playingInLeague;
  final String? teamId;
  final String? teamName;

  GolfDetails({
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
      name: map['name'] ?? '',
      password: map['password'] ?? '',
    );
  }
}
