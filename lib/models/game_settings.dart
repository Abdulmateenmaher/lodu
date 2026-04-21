class GameSettings {
  final bool doubleSixBonus;      // rolling 6+6 or 1+1 gives extra roll
  final bool killToEnter;         // must kill before entering home stretch
  final bool safeZonesEnabled;    // safe zones protect pieces
  final bool autoMoveUnambiguous; // auto-move when only 1 choice
  final bool prisonRule;          // captured pieces go to prison (need 6 to escape)
  final bool teamPlay;            // partners share win condition

  const GameSettings({
    this.doubleSixBonus = true,
    this.killToEnter = true,
    this.safeZonesEnabled = true,
    this.autoMoveUnambiguous = true,
    this.prisonRule = true,
    this.teamPlay = true,
  });

  GameSettings copyWith({
    bool? doubleSixBonus,
    bool? killToEnter,
    bool? safeZonesEnabled,
    bool? autoMoveUnambiguous,
    bool? prisonRule,
    bool? teamPlay,
  }) {
    return GameSettings(
      doubleSixBonus: doubleSixBonus ?? this.doubleSixBonus,
      killToEnter: killToEnter ?? this.killToEnter,
      safeZonesEnabled: safeZonesEnabled ?? this.safeZonesEnabled,
      autoMoveUnambiguous: autoMoveUnambiguous ?? this.autoMoveUnambiguous,
      prisonRule: prisonRule ?? this.prisonRule,
      teamPlay: teamPlay ?? this.teamPlay,
    );
  }
}
