import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String name;
  final int par;
  final double courseRating;
  final double slopeRating;
  final List<int> holePars;
  final List<int> strokeIndexes;
  final int pcc; // Playing Condition Calculation for the day (-1 to +3)

  CourseModel({
    required this.id,
    required this.name,
    required this.par,
    required this.courseRating,
    required this.slopeRating,
    required this.holePars,
    required this.strokeIndexes,
    this.pcc = 0,
  });

  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return CourseModel(
      id: doc.id,
      name: data['name'] ?? 'Golf Course',
      par: data['par'] ?? 72,
      courseRating: (data['courseRating'] as num?)?.toDouble() ?? 72.0,
      slopeRating: (data['slopeRating'] as num?)?.toDouble() ?? 113.0,
      holePars: List<int>.from(data['holePars'] ?? List.filled(18, 4)),
      strokeIndexes: List<int>.from(
        data['strokeIndexes'] ?? List.generate(18, (i) => i + 1),
      ),
      pcc: data['pcc'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'par': par,
      'courseRating': courseRating,
      'slopeRating': slopeRating,
      'holePars': holePars,
      'strokeIndexes': strokeIndexes,
      'pcc': pcc,
    };
  }

  // Default course data for MGM Golf Club
  factory CourseModel.defaultCourse() {
    return CourseModel(
      id: 'default',
      name: 'MGM Golf Club',
      par: 69,
      courseRating: 69.0,
      slopeRating: 113.0,
      holePars: [3, 3, 4, 4, 5, 3, 5, 4, 3, 4, 5, 3, 5, 3, 4, 3, 4, 4],
      strokeIndexes: [
        18,
        8,
        2,
        10,
        4,
        14,
        6,
        16,
        12,
        9,
        1,
        13,
        3,
        15,
        11,
        17,
        7,
        5,
      ],
    );
  }
}
