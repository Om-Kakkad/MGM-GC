import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mgm_gc/firebase_options.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart run seed_slots.dart YYYY-MM-DD');
    exit(1);
  }

  final dateString = arguments.first;
  final date = DateTime.tryParse(dateString);
  if (date == null || dateString.length != 10) {
    stderr.writeln('Invalid date format. Use YYYY-MM-DD.');
    exit(1);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;
  final dateId = dateString.replaceAll('-', '');

  final start = DateTime(date.year, date.month, date.day, 6, 0);
  final end = DateTime(date.year, date.month, date.day, 17, 45);

  final batch = firestore.batch();
  for (var time = start; !time.isAfter(end); time = time.add(const Duration(minutes: 15))) {
    final timeId = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final docRef = firestore.collection('teeTimes').doc(dateId).collection('slots').doc(timeId);
    batch.set(docRef, <String, dynamic>{'time': timeId, 'status': 'open'});
  }

  await batch.commit();
  print('Seeded tee times for $dateString');
}
