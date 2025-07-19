class Award {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final String color;
  final int order;
  final bool isPositive; // true for good awards, false for fun/worst awards

  Award({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.color,
    required this.order,
    this.isPositive = true,
  });
}

class PlayerStat {
  final String playerId;
  final String playerName;
  final String? teamId;
  final String? teamName;
  final num value;
  final String displayValue;
  final Map<String, dynamic> additionalData;

  PlayerStat({
    required this.playerId,
    required this.playerName,
    this.teamId,
    this.teamName,
    required this.value,
    required this.displayValue,
    this.additionalData = const {},
  });
}

class AwardCategory {
  final Award award;
  final List<PlayerStat> stats;
  final bool isLoading;

  AwardCategory({
    required this.award,
    required this.stats,
    this.isLoading = false,
  });
}
