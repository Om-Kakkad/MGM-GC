import 'package:cloud_firestore/cloud_firestore.dart';

class Sponsor {
  final String id;
  final String name;
  final String area;
  final String logoUrl;
  final String websiteUrl;
  final String eventId;

  Sponsor({
    required this.id,
    required this.name,
    required this.area,
    required this.logoUrl,
    required this.websiteUrl,
    required this.eventId,
  });

  factory Sponsor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sponsor(
      id: doc.id,
      name: data['name'] ?? '',
      area: data['area'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      websiteUrl: data['websiteUrl'] ?? '',
      eventId: data['eventId'] ?? '',
    );
  }
}
