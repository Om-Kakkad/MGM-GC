import 'package:cloud_firestore/cloud_firestore.dart';

class AggregateScoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getAggregateScores() async {
    try {
      final snapshot = await _firestore
          .collection('teamTotals')
          .orderBy('total', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching aggregate scores: $e');
      return [];
    }
  }
}
