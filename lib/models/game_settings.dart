class GameSettings {
  final bool doubleSixBonus;      
  final bool killToEnter;         
  final bool safeZonesEnabled;    
  final bool autoMoveUnambiguous; 
  final bool prisonRule;          
  final bool teamPlay;            
  final int playerCount; // 2, 3, or 4 players

  const GameSettings({
    this.doubleSixBonus = true,
    this.killToEnter = true,
    this.safeZonesEnabled = true,
    this.autoMoveUnambiguous = true,
    this.prisonRule = true,
    this.teamPlay = true,
    this.playerCount = 4,
  });

  GameSettings copyWith({
    bool? doubleSixBonus,
    bool? killToEnter,
    bool? safeZonesEnabled,
    bool? autoMoveUnambiguous,
    bool? prisonRule,
    bool? teamPlay,
    int? playerCount,
  }) {
    return GameSettings(
      doubleSixBonus: doubleSixBonus ?? this.doubleSixBonus,
      killToEnter: killToEnter ?? this.killToEnter,
      safeZonesEnabled: safeZonesEnabled ?? this.safeZonesEnabled,
      autoMoveUnambiguous: autoMoveUnambiguous ?? this.autoMoveUnambiguous,
      prisonRule: prisonRule ?? this.prisonRule,
      teamPlay: teamPlay ?? this.teamPlay,
      playerCount: playerCount ?? this.playerCount,
    );
  }
}