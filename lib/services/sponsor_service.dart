import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sponsor.dart';

class SponsorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> addSponsor(String eventId, Sponsor sponsor) async {
    final ref = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('sponsors')
        .add(sponsor.toMap());
    return ref.id;
  }

  Stream<List<Sponsor>> getSponsors(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('sponsors')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Sponsor.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> deleteSponsor(String eventId, String sponsorId) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .collection('sponsors')
        .doc(sponsorId)
        .delete();
  }
}
