
class Sponsor {
  final String? id;
  final String sponsorName;
  final String area;
  final String logoUrl;
  final String websiteUrl;

  Sponsor({
    this.id,
    required this.sponsorName,
    required this.area,
    required this.logoUrl,
    required this.websiteUrl,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'sponsorName': sponsorName,
      'area': area,
      'logoUrl': logoUrl,
      'websiteUrl': websiteUrl,
    };
    if (id != null) {
      map['id'] = id!;
    }
    return map;
  }

  factory Sponsor.fromMap(Map<String, dynamic> map, String id) {
    return Sponsor(
      id: id,
      sponsorName: map['sponsorName'] ?? '',
      area: map['area'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      websiteUrl: map['websiteUrl'] ?? '',
    );
  }
}
