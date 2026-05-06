class MatchRecord {
  final String winnerLabel;
  final List<String> playerNames;
  final List<bool> playerIsAI;
  final DateTime playedAt;
  final int stars;
  final String statusText;

  const MatchRecord({
    required this.winnerLabel,
    required this.playerNames,
    required this.playerIsAI,
    required this.playedAt,
    this.stars = 1,
    this.statusText = '',
  });

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      winnerLabel: json['winnerLabel'],
      playerNames: List<String>.from(json['playerNames']),
      playerIsAI: List<bool>.from(json['playerIsAI']),
      playedAt: DateTime.parse(json['playedAt']),
      stars: json['stars'] ?? 1,
      statusText: json['statusText'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'winnerLabel': winnerLabel,
    'playerNames': playerNames,
    'playerIsAI': playerIsAI,
    'playedAt': playedAt.toIso8601String(),
    'stars': stars,
    'statusText': statusText,
  };
}