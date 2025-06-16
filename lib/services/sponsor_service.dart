import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sponsor.dart';

class SponsorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> _getActiveEventId() async {
    try {
      final doc = await _firestore.collection('config').doc('activeEvent').get();
      return doc.data()?['eventId'] as String?;
    } catch (e) {
      print('Error fetching active event id: $e');
      return null;
    }
  }

  Future<List<Sponsor>> getSponsors() async {
    try {
      final eventId = await _getActiveEventId();
      if (eventId == null) return [];
      final snapshot = await _firestore
          .collection('sponsors')
          .where('eventId', isEqualTo: eventId)
          .get();
      return snapshot.docs.map((d) => Sponsor.fromFirestore(d)).toList();
    } catch (e) {
      print('Error fetching sponsors: $e');
      return [];
    }
  }
}
