import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/aggregate_score.dart';

class AggregateScoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addMatchPoints(
    String eventId,
    String teamId, {
    required num regularPoints,
    required num bonusPoints,
  }) async {
    final docRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('aggregateScores')
        .doc(teamId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      num currentRegular = 0;
      num currentBonus = 0;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        currentRegular = data['regularPoints'] ?? 0;
        currentBonus = data['bonusPoints'] ?? 0;
      }

      final newRegular = currentRegular + regularPoints;
      final newBonus = currentBonus + bonusPoints;
      final total = newRegular + newBonus;

      transaction.set(
        docRef,
        {
          'regularPoints': newRegular,
          'bonusPoints': newBonus,
          'total': total,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<List<AggregateScore>> getAggregateScores(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('aggregateScores')
          .get();

      return snapshot.docs
          .map((doc) => AggregateScore.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting aggregate scores: $e');
      return [];
    }
  }
}
