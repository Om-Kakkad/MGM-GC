import 'package:flutter/material.dart';
import 'package:mgm_gc/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mgm_gc/pages/login/login.dart';
import 'package:mgm_gc/pages/signup/signup.dart';
import 'package:mgm_gc/pages/home/home_page.dart';
import 'package:mgm_gc/pages/admin/admin_panel.dart';
import 'package:mgm_gc/pages/league/league_features.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> createAdminAccountIfNoneExists() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Check if any admin exists
  final QuerySnapshot adminQuery =
      await firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

  if (adminQuery.docs.isEmpty) {
    // No admin exists, create one
    final UserCredential adminCredential = await auth
        .createUserWithEmailAndPassword(
          email: 'admin@example.com', // Replace with your desired admin email
          password: 'Admin@123', // Replace with your desired admin password
        );

    final User adminUser = adminCredential.user!;
    await firestore.collection('users').doc(adminUser.uid).set({
      'uid': adminUser.uid,
      'email': adminUser.email,
      'role': 'admin',
      'firstName': 'Admin',
      'lastName': 'User',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('Admin account created with email: ${adminUser.email}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Create admin account if none exists
  //await createAdminAccountIfNoneExists();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => Login(),
        '/signup': (context) => Signup(),
        '/home': (context) => HomePage(),
        '/admin': (context) => AdminPanel(),
        '/league': (context) => LeagueFeatures(),
      },
    );
  }
}
