class MatchRecord {
  final String winnerLabel;
  final List<String> playerNames;
  final List<bool> playerIsAI;
  final DateTime playedAt;

  const MatchRecord({
    required this.winnerLabel,
    required this.playerNames,
    required this.playerIsAI,
    required this.playedAt,
  });
}
