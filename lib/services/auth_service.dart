import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mgm_gc/models/user_model.dart';

import '../pages/home/home.dart';
import '../pages/registration/registration_page.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password
  Future<void> signup({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Navigate to registration page to complete profile
      await Future.delayed(const Duration(seconds: 1));
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (BuildContext context) =>
                    RegistrationPage(user: userCredential.user!),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with that email.';
      }
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "An error occurred during sign up.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }

  // Sign in with email and password
  Future<void> signin({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      await Future.delayed(const Duration(seconds: 1));
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (BuildContext context) => const Home()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'invalid-email') {
        message = 'No user found for that email.';
      } else if (e.code == 'invalid-credential') {
        message = 'Wrong password provided for that user.';
      }
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "An error occurred during sign in.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }

  // Sign out
  Future<void> signout({required BuildContext context}) async {
    await _auth.signOut();
    await Future.delayed(const Duration(seconds: 1));
    if (context.mounted) {
      // Use named route instead of MaterialPageRoute
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // Save user profile data
  Future<bool> saveUserProfile({
    required UserModel user,
    required BuildContext context,
    String? teamPassword,
  }) async {
    try {
      // Check if user already exists and has an admin role
      final existingUserDoc =
          await _firestore.collection('users').doc(user.uid).get();
      String role = user.role;

      // Preserve admin role if it already exists
      if (existingUserDoc.exists &&
          existingUserDoc.data()?['role'] == 'admin') {
        role = 'admin';
      }

      // Check team password if applicable
      if (user.golfDetails.playingInLeague &&
          user.golfDetails.teamId != null &&
          teamPassword != null) {
        // We need to find which event this team belongs to
        // Query all events and their team subcollections
        final eventsSnapshot = await _firestore.collection('events').get();
        DocumentSnapshot? teamDoc;
        String? eventId;

        // Search through each event's teams subcollection
        for (var eventDoc in eventsSnapshot.docs) {
          final currentEventId = eventDoc.id;
          final teamRef = _firestore
              .collection('events')
              .doc(currentEventId)
              .collection('teams')
              .doc(user.golfDetails.teamId);

          final tempTeamDoc = await teamRef.get();

          if (tempTeamDoc.exists) {
            teamDoc = tempTeamDoc;
            eventId = currentEventId;
            break;
          }
        }

        if (teamDoc == null || !teamDoc.exists) {
          Fluttertoast.showToast(
            msg: "Team not found",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Colors.black54,
            textColor: Colors.white,
            fontSize: 14.0,
          );
          return false;
        }

        final teamData = teamDoc.data() as Map<String, dynamic>?;
        if (teamData == null) {
          Fluttertoast.showToast(
            msg: "Invalid team data",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Colors.black54,
            textColor: Colors.white,
            fontSize: 14.0,
          );
          return false;
        }

        // Check both possible password field names
        final correctPassword =
            teamData['teamPassword'] ?? teamData['password'];

        if (correctPassword != teamPassword) {
          Fluttertoast.showToast(
            msg: "Incorrect team password",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: Colors.black54,
            textColor: Colors.white,
            fontSize: 14.0,
          );
          return false;
        }

        // If the team password is correct, update the role to league_player
        if (correctPassword == teamPassword && eventId != null) {
          // Get the associated event for the team to determine brackets
          String? assignedBracket;

          // Try to determine the player's bracket if they have a handicap
          if (user.golfDetails.handicap != null) {
            // Fetch the event document to get bracket definitions
            final eventDoc =
                await _firestore.collection('events').doc(eventId).get();

            if (eventDoc.exists) {
              final eventData = eventDoc.data();
              final brackets = eventData?['brackets'];

              if (brackets != null) {
                // Check which bracket the player falls into based on handicap
                final double handicap = user.golfDetails.handicap!;

                // Check gold bracket
                final goldBracket = brackets['gold'];
                if (goldBracket != null &&
                    handicap >= goldBracket['minHandicap'] &&
                    handicap <= goldBracket['maxHandicap']) {
                  assignedBracket = 'gold';
                }

                // Check silver bracket
                final silverBracket = brackets['silver'];
                if (silverBracket != null &&
                    handicap >= silverBracket['minHandicap'] &&
                    handicap <= silverBracket['maxHandicap']) {
                  assignedBracket = 'silver';
                }

                // Check bronze bracket
                final bronzeBracket = brackets['bronze'];
                if (bronzeBracket != null &&
                    handicap >= bronzeBracket['minHandicap'] &&
                    handicap <= bronzeBracket['maxHandicap']) {
                  assignedBracket = 'bronze';
                }
              }
            }
          }

          // Create a new user model with the updated role and bracket
          // BUT preserve admin role if it was set
          final updatedUser = UserModel(
            uid: user.uid,
            email: user.email,
            role:
                role == 'admin'
                    ? 'admin'
                    : 'league_player', // Keep admin role if present
            firstName: user.firstName,
            lastName: user.lastName,
            dateOfBirth: user.dateOfBirth,
            gender: user.gender,
            phoneNumber: user.phoneNumber,
            golfDetails: GolfDetails(
              handicap: user.golfDetails.handicap,
              isMember: user.golfDetails.isMember,
              membershipId: user.golfDetails.membershipId,
              playingInLeague: user.golfDetails.playingInLeague,
              teamId: user.golfDetails.teamId,
              teamName: user.golfDetails.teamName,
              eventId: eventId, // Store event ID in user's golf details
              bracket: assignedBracket, // Add bracket assignment
            ),
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          );

          // Save the updated user model
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(updatedUser.toMap());

          // Add the user to the team's players array
          await _firestore
              .collection('events')
              .doc(eventId)
              .collection('teams')
              .doc(user.golfDetails.teamId)
              .update({
                'players': FieldValue.arrayUnion([user.uid]),
              });
        } else {
          // Save original user data to Firestore, but with preserved admin role if it exists
          final updatedUser = UserModel(
            uid: user.uid,
            email: user.email,
            role: role, // Use the preserved role (admin or user)
            firstName: user.firstName,
            lastName: user.lastName,
            dateOfBirth: user.dateOfBirth,
            gender: user.gender,
            phoneNumber: user.phoneNumber,
            golfDetails: user.golfDetails,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          );

          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(updatedUser.toMap());
        }
      } else {
        // Save original user data to Firestore, but with preserved admin role if it exists
        final updatedUser = UserModel(
          uid: user.uid,
          email: user.email,
          role: role, // Use the preserved role (admin or user)
          firstName: user.firstName,
          lastName: user.lastName,
          dateOfBirth: user.dateOfBirth,
          gender: user.gender,
          phoneNumber: user.phoneNumber,
          golfDetails: user.golfDetails,
          createdAt: user.createdAt,
          updatedAt: user.updatedAt,
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(updatedUser.toMap());
      }

      // Update display name in Firebase Auth
      await _auth.currentUser?.updateDisplayName(
        '${user.firstName} ${user.lastName}',
      );

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }

      return true;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error saving profile: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      return false;
    }
  }

  // Get teams for dropdown - updated to handle nested collections
  Stream<List<Team>> getTeams() {
    // First get all events
    return _firestore.collection('events').snapshots().asyncMap((
      eventSnapshot,
    ) async {
      List<Team> allTeams = [];

      // For each event, get its teams subcollection
      for (var eventDoc in eventSnapshot.docs) {
        final eventId = eventDoc.id;
        final teamsSnapshot =
            await _firestore
                .collection('events')
                .doc(eventId)
                .collection('teams')
                .get();

        // Convert each team doc to a Team object
        for (var doc in teamsSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['eventId'] = eventId; // Add event ID to the data

          allTeams.add(
            Team(
              id: doc.id,
              name: data['teamName'] ?? data['name'] ?? 'Unnamed Team',
              password: data['teamPassword'] ?? data['password'] ?? '',
              eventId: eventId,
            ),
          );
        }
      }

      return allTeams;
    });
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Get user data from Firestore
        UserModel userModel = await getUserData(user.uid);
        return userModel;
      }
    } catch (e) {
      print("Error signing in: $e");
      return null;
    }
    return null;
  }

  // Get user data from Firestore
  Future<UserModel> getUserData(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } else {
      // Create a new user document if it doesn't exist
      UserModel newUser = UserModel(
        uid: uid,
        email: currentUser?.email ?? '',
        role: 'user',
      );
      await _firestore.collection('users').doc(uid).set(newUser.toMap());
      return newUser;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Update user role to league player
  Future<void> updateToLeaguePlayer(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'role': 'league_player',
    });
  }

  // Check team password and update user role if correct
  Future<bool> validateTeamPassword(String password) async {
    try {
      DocumentSnapshot teamDoc =
          await _firestore.collection('teams').doc('league').get();
      if (teamDoc.exists) {
        String correctPassword =
            (teamDoc.data() as Map<String, dynamic>)['password'] ?? '';
        if (password == correctPassword && currentUser != null) {
          await updateToLeaguePlayer(currentUser!.uid);
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error validating team password: $e");
      return false;
    }
  }
}
