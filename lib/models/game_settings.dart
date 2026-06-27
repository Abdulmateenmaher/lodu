class GameSettings {
  final bool doubleSixBonus;
  final bool killToEnter;
  final bool safeZonesEnabled;
  final bool autoMoveUnambiguous;
  final bool prisonRule;
  final bool teamPlay;
  final int playerCount; // 2, 3, or 4 players
  final bool finalSixFinish;      // End match with a final 6(s)
  final int diceCount;            // 1 or 2 dice for rolling
  final bool skipOnDoubleThree;   // 3,3 skips next player turn
  final bool blostOnDoubleFour;   // 4,4 = blost: 2 extra 6s + hit all unprotected

  const GameSettings({
    this.doubleSixBonus = true,
    this.killToEnter = true,
    this.safeZonesEnabled = true,
    this.autoMoveUnambiguous = true,
    this.prisonRule = true,
    this.teamPlay = true,
    this.playerCount = 4,
    this.finalSixFinish = true,
    this.diceCount = 2,
    this.skipOnDoubleThree = false,
    this.blostOnDoubleFour = false,
  });

  GameSettings copyWith({
    bool? doubleSixBonus,
    bool? killToEnter,
    bool? safeZonesEnabled,
    bool? autoMoveUnambiguous,
    bool? prisonRule,
    bool? teamPlay,
    int? playerCount,
    bool? finalSixFinish,
    int? diceCount,
    bool? skipOnDoubleThree,
    bool? blostOnDoubleFour,
  }) {
    return GameSettings(
      doubleSixBonus: doubleSixBonus ?? this.doubleSixBonus,
      killToEnter: killToEnter ?? this.killToEnter,
      safeZonesEnabled: safeZonesEnabled ?? this.safeZonesEnabled,
      autoMoveUnambiguous: autoMoveUnambiguous ?? this.autoMoveUnambiguous,
      prisonRule: prisonRule ?? this.prisonRule,
      teamPlay: teamPlay ?? this.teamPlay,
      playerCount: playerCount ?? this.playerCount,
      finalSixFinish: finalSixFinish ?? this.finalSixFinish,
      diceCount: diceCount ?? this.diceCount,
      skipOnDoubleThree: skipOnDoubleThree ?? this.skipOnDoubleThree,
      blostOnDoubleFour: blostOnDoubleFour ?? this.blostOnDoubleFour,
    );
  }
}
