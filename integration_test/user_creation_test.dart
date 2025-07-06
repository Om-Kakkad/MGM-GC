import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mgm_gc/firebase_options.dart';
import 'package:mgm_gc/models/user_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Use Firebase emulators for testing
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets('Create multiple users with complete profiles', (tester) async {
    final auth = FirebaseAuth.instance;
    final store = FirebaseFirestore.instance;

    // Clear existing users first for clean testing
    await _clearExistingUsers(store);

    // Test data: email, password, first name, last name, gender, handicap, isMember, membershipId
    final testUsers = [
      // First user should become admin automatically
      UserTestData(
        email: 'admin_user@example.com',
        password: 'AdminPass123!',
        firstName: 'Admin',
        lastName: 'User',
        gender: 'Male',
        dateOfBirth: DateTime(1980, 5, 15),
        phoneNumber: '555-123-4567',
        handicap: 8.5,
        isMember: true,
        membershipId: 'MGM-001',
        playingInLeague: false,
      ),
      // Regular users with varying data
      UserTestData(
        email: 'regular_user1@example.com',
        password: 'UserPass123!',
        firstName: 'John',
        lastName: 'Smith',
        gender: 'Male',
        dateOfBirth: DateTime(1985, 7, 22),
        phoneNumber: '555-222-3333',
        handicap: 12.0,
        isMember: true,
        membershipId: 'MGM-002',
        playingInLeague: false,
      ),
      UserTestData(
        email: 'regular_user2@example.com',
        password: 'UserPass123!',
        firstName: 'Sarah',
        lastName: 'Johnson',
        gender: 'Female',
        dateOfBirth: DateTime(1990, 3, 10),
        phoneNumber: '555-444-5555',
        handicap: 18.5,
        isMember: false,
        membershipId: null,
        playingInLeague: false,
      ),
      UserTestData(
        email: 'league_player@example.com',
        password: 'LeaguePass123!',
        firstName: 'Michael',
        lastName: 'Williams',
        gender: 'Male',
        dateOfBirth: DateTime(1982, 11, 5),
        phoneNumber: '555-666-7777',
        handicap: 5.5,
        isMember: true,
        membershipId: 'MGM-003',
        playingInLeague: true,
        teamId: null, // Will be assigned later if joining a team
        teamName: null,
      ),
      UserTestData(
        email: 'casual_player@example.com',
        password: 'CasualPass123!',
        firstName: 'Emma',
        lastName: 'Garcia',
        gender: 'Female',
        dateOfBirth: DateTime(1995, 8, 30),
        phoneNumber: '555-888-9999',
        handicap: 24.0,
        isMember: false,
        membershipId: null,
        playingInLeague: false,
      ),
    ];

    // Store created user IDs for verification
    final createdUserIds = <String>[];
    UserCredential?
    firstUserCredentials; // Changed from final and removed invalid constructor

    // 1. Create all users
    for (int i = 0; i < testUsers.length; i++) {
      final userData = testUsers[i];
      print('Creating user ${i + 1}/${testUsers.length}: ${userData.email}');

      // Create user in Firebase Auth
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: userData.email,
        password: userData.password,
      );

      // Save first user credentials (admin user) for later verification
      if (i == 0) {
        firstUserCredentials = userCredential;
      }

      final uid = userCredential.user!.uid;
      createdUserIds.add(uid);

      // Create the initial user model with complete profile data
      final userModel = UserModel(
        uid: uid,
        email: userData.email,
        role:
            'user', // Default role - should be overridden to admin for first user
        firstName: userData.firstName,
        lastName: userData.lastName,
        dateOfBirth: userData.dateOfBirth,
        gender: userData.gender,
        phoneNumber: userData.phoneNumber,
        golfDetails: GolfDetails(
          handicap: userData.handicap,
          isMember: userData.isMember,
          membershipId: userData.membershipId,
          playingInLeague: userData.playingInLeague,
          teamId: userData.teamId,
          teamName: userData.teamName,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user data to Firestore
      await store.collection('users').doc(uid).set(userModel.toMap());

      // Sign out before creating next user
      await auth.signOut();

      // Wait briefly to ensure function triggers run
      await Future.delayed(const Duration(seconds: 1));
    }

    // Sign in as the first user (admin) before verification
    await auth.signInWithEmailAndPassword(
      email: testUsers[0].email,
      password: testUsers[0].password,
    );

    // 2. Verify users were created and have correct data
    for (int i = 0; i < testUsers.length; i++) {
      final userData = testUsers[i];
      final uid = createdUserIds[i];

      print('Verifying user ${i + 1}/${testUsers.length}: ${userData.email}');

      // Get the user document from Firestore
      final userDoc = await store.collection('users').doc(uid).get();
      expect(userDoc.exists, true, reason: 'User document should exist');

      final userMap = userDoc.data()!;

      // Verify basic info
      expect(userMap['email'], userData.email);
      expect(userMap['firstName'], userData.firstName);
      expect(userMap['lastName'], userData.lastName);
      expect(userMap['gender'], userData.gender);
      expect(userMap['phoneNumber'], userData.phoneNumber);

      // Verify golf details exist
      expect(userMap['golfDetails'], isNotNull);

      // Verify specific golf details
      expect(userMap['golfDetails']['handicap'], userData.handicap);
      expect(userMap['golfDetails']['isMember'], userData.isMember);
      expect(userMap['golfDetails']['membershipId'], userData.membershipId);
      expect(
        userMap['golfDetails']['playingInLeague'],
        userData.playingInLeague,
      );

      // Check for admin role on first user
      if (i == 0) {
        expect(userMap['role'], 'admin', reason: 'First user should be admin');
      } else {
        expect(
          userMap['role'],
          'user',
          reason: 'Other users should be regular users',
        );
      }
    }

    // Sign out after completing verification
    await auth.signOut();

    print('Successfully created and verified ${testUsers.length} users');
    print('First user has admin role, remaining users have user role');
  });
}

/// Helper class to organize test user data
class UserTestData {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final String phoneNumber;
  final double handicap;
  final bool isMember;
  final String? membershipId;
  final bool playingInLeague;
  final String? teamId;
  final String? teamName;

  UserTestData({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.handicap,
    required this.isMember,
    this.membershipId,
    required this.playingInLeague,
    this.teamId,
    this.teamName,
  });
}

/// Helper function to clear existing users for clean testing
Future<void> _clearExistingUsers(FirebaseFirestore store) async {
  try {
    final userDocs = await store.collection('users').get();
    final batch = store.batch();

    for (final doc in userDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('Cleared ${userDocs.docs.length} existing users');
  } catch (e) {
    print('Error clearing users: $e');
  }
}
