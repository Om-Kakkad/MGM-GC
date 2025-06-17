import 'package:cloud_firestore/cloud_firestore.dart';

class AggregateScoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addMatchPoints(
    String eventId,
    String teamId,
    num regularPoints,
    num bonusPoints,
  ) async {
    final ref = _firestore
        .collection('events')
        .doc(eventId)
        .collection('aggregateScores')
        .doc(teamId);

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final currentRegular = (doc.data()?['regularPoints'] ?? 0) as num;
      final currentBonus = (doc.data()?['bonusPoints'] ?? 0) as num;
      tx.set(
        ref,
        {
          'regularPoints': currentRegular + regularPoints,
          'bonusPoints': currentBonus + bonusPoints,
        },
        SetOptions(merge: true),
      );
    });
  }
}
