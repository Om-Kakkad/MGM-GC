class AggregateScore {
  final String? teamId;
  final num regularPoints;
  final num bonusPoints;
  final num total;

  AggregateScore({
    this.teamId,
    required this.regularPoints,
    required this.bonusPoints,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'regularPoints': regularPoints,
      'bonusPoints': bonusPoints,
      'total': total,
    };
  }

  factory AggregateScore.fromMap(Map<String, dynamic> map, String id) {
    return AggregateScore(
      teamId: id,
      regularPoints: map['regularPoints'] ?? 0,
      bonusPoints: map['bonusPoints'] ?? 0,
      total: map['total'] ?? 0,
    );
  }
}
