import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mgm_gc/models/user_model.dart';

import '../pages/home/home.dart';
import '../pages/login/login.dart';
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (BuildContext context) => Login()),
      );
    }
  }

  // Save user profile data
  Future<bool> saveUserProfile({
    required UserModel user,
    required BuildContext context,
    String? teamPassword,
  }) async {
    try {
      // Check team password if applicable
      if (user.golfDetails.playingInLeague &&
          user.golfDetails.teamId != null &&
          teamPassword != null) {
        final teamDoc =
            await _firestore
                .collection('teams')
                .doc(user.golfDetails.teamId)
                .get();

        if (!teamDoc.exists || teamDoc.data()?['password'] != teamPassword) {
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
        if (teamDoc.data()?['password'] == teamPassword) {
          // Create a new user model with the updated role
          final updatedUser = UserModel(
            uid: user.uid,
            email: user.email,
            role: 'league_player',
            firstName: user.firstName,
            lastName: user.lastName,
            dateOfBirth: user.dateOfBirth,
            gender: user.gender,
            phoneNumber: user.phoneNumber,
            golfDetails: user.golfDetails,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          );

          // Save the updated user model
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(updatedUser.toMap());
        } else {
          // Save original user data to Firestore
          await _firestore.collection('users').doc(user.uid).set(user.toMap());
        }
      } else {
        // Save original user data to Firestore
        await _firestore.collection('users').doc(user.uid).set(user.toMap());
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

  // Get teams for dropdown
  Stream<List<Team>> getTeams() {
    return _firestore.collection('teams').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Team.fromMap(data);
      }).toList();
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
