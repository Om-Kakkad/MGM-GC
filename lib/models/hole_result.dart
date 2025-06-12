
class HoleResult {
  final int strokesA;
  final int strokesB;
  final String result; // "W" | "L" | "AS"

  const HoleResult({required this.strokesA, required this.strokesB, required this.result});

  Map<String, dynamic> toMap() => {
        'strokesA': strokesA,
        'strokesB': strokesB,
        'result': result,
      };

  factory HoleResult.fromMap(Map<String, dynamic> map) {
    return HoleResult(
      strokesA: map['strokesA'] ?? 0,
      strokesB: map['strokesB'] ?? 0,
      result: map['result'] ?? 'AS',
    );
  }
}
