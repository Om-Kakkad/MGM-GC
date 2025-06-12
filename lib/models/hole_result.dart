
/// Representation of a single hole result.
///
/// The revised scoring system tracks only which side won the hole
/// (Team A, Team B, or the hole being all square). Stroke counts are no
/// longer persisted.
class HoleResult {
  /// `result` is one of:
  ///  - `"A"`  → Team A wins the hole
  ///  - `"B"`  → Team B wins the hole
  ///  - `"AS"` → Hole halved (all square)
  final String result;

  const HoleResult({required this.result});

  Map<String, dynamic> toMap() => {
        'result': result,
      };

  factory HoleResult.fromMap(Map<String, dynamic> map) {
    return HoleResult(
      result: map['result'] ?? 'AS',
    );
  }
}
