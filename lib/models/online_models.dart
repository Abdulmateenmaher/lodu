import '../models/game_models.dart';
import '../models/game_settings.dart';

enum OnlineGamePhase { waiting, play, end }

class OnlineRoom {
  final String roomId;
  final String hostName;
  final List<OnlinePlayer> players;
  final OnlineGamePhase phase;
  final int turnSlot;
  final List<int> dicePool;
  final bool canRoll;
  final bool matchFirstSixRolled;
  final int consecutiveExtra;
  final int? selectedDieIndex;
  final OnlineSettings settings;

  const OnlineRoom({
    required this.roomId,
    required this.hostName,
    required this.players,
    required this.phase,
    required this.turnSlot,
    required this.dicePool,
    required this.canRoll,
    required this.matchFirstSixRolled,
    required this.consecutiveExtra,
    this.selectedDieIndex,
    required this.settings,
  });

  factory OnlineRoom.fromJson(Map<String, dynamic> j) => OnlineRoom(
        roomId: j['roomId'] ?? '',
        hostName: j['hostName'] ?? '',
        players: (j['players'] as List).map((p) => OnlinePlayer.fromJson(p as Map<String, dynamic>)).toList(),
        phase: OnlineGamePhase.values[j['phase'] ?? 0],
        turnSlot: j['turnSlot'] ?? 0,
        dicePool: List<int>.from(j['dicePool'] ?? []),
        canRoll: j['canRoll'] ?? false,
        matchFirstSixRolled: j['matchFirstSixRolled'] ?? false,
        consecutiveExtra: j['consecutiveExtra'] ?? 0,
        selectedDieIndex: j['selectedDieIndex'],
        settings: OnlineSettings.fromJson(j['settings'] as Map<String, dynamic>? ?? {}),
      );
}

class OnlinePlayer {
  final int id;
  final bool isAI;
  final bool isActive;
  final int partnerId;
  final String name;
  final bool hasKilled;
  final bool finished;
  final bool isHelper;
  final bool hasRolledFirstSix;
  final int timesHit;
  final List<OnlinePiece> pieces;
  final String? connectionId;

  const OnlinePlayer({
    required this.id,
    required this.isAI,
    required this.isActive,
    required this.partnerId,
    required this.name,
    required this.hasKilled,
    required this.finished,
    required this.isHelper,
    required this.hasRolledFirstSix,
    required this.timesHit,
    required this.pieces,
    this.connectionId,
  });

  factory OnlinePlayer.fromJson(Map<String, dynamic> j) => OnlinePlayer(
        id: j['id'],
        isAI: j['isAI'] ?? false,
        isActive: j['isActive'] ?? true,
        partnerId: j['partnerId'] ?? ((j['id'] as int) + 2) % 4,
        name: j['name'] ?? '',
        hasKilled: j['hasKilled'] ?? false,
        finished: j['finished'] ?? false,
        isHelper: j['isHelper'] ?? false,
        hasRolledFirstSix: j['hasRolledFirstSix'] ?? false,
        timesHit: j['timesHit'] ?? 0,
        pieces: (j['pieces'] as List).map((p) => OnlinePiece.fromJson(p as Map<String, dynamic>)).toList(),
        connectionId: j['connectionId'],
      );

  Player toLocalPlayer() => Player(
        id: id,
        isAI: isAI,
        isActive: isActive,
        partnerId: partnerId,
        name: name,
        hasKilled: hasKilled,
        finished: finished,
        isHelper: isHelper,
        hasRolledFirstSix: hasRolledFirstSix,
        timesHit: timesHit,
        pieces: pieces.map((p) => p.toLocalPiece()).toList(),
      );
}


class OnlinePiece {
  final int id;
  final int color;
  final PieceState state;
  final int pos;
  final int? prisonerOf;
  final bool hasKilledThisTurn;

  const OnlinePiece({
    required this.id,
    required this.color,
    required this.state,
    required this.pos,
    this.prisonerOf,
    required this.hasKilledThisTurn,
  });

  static const _stateMap = {
    0: PieceState.yard,
    1: PieceState.board,
    2: PieceState.homeStretch,
    3: PieceState.home,
    4: PieceState.prison,
  };

  factory OnlinePiece.fromJson(Map<String, dynamic> j) => OnlinePiece(
        id: j['id'],
        color: j['color'],
        state: _stateMap[j['state']] ?? PieceState.yard,
        pos: j['pos'] ?? -1,
        prisonerOf: j['prisonerOf'],
        hasKilledThisTurn: j['hasKilledThisTurn'] ?? false,
      );

  Piece toLocalPiece() => Piece(
        id: id,
        color: color,
        state: state,
        pos: pos,
        prisonerOf: prisonerOf,
        hasKilledThisTurn: hasKilledThisTurn,
      );
}

// ── Settings ───────────────────────────────────────────────────────────────

class OnlineSettings {
  final bool doubleSixBonus;
  final bool killToEnter;
  final bool safeZonesEnabled;
  final bool prisonRule;
  final bool teamPlay;
  final bool autoMoveUnambiguous;
  final int playerCount;
  final bool finalSixFinish;
  final int diceCount;
  final bool skipOnDoubleThree;
  final bool blostOnDoubleFour;

  const OnlineSettings({
    this.doubleSixBonus = true,
    this.killToEnter = true,
    this.safeZonesEnabled = true,
    this.prisonRule = true,
    this.teamPlay = true,
    this.autoMoveUnambiguous = true,
    this.playerCount = 4,
    this.finalSixFinish = true,
    this.diceCount = 2,
    this.skipOnDoubleThree = false,
    this.blostOnDoubleFour = false,
  });

  factory OnlineSettings.fromJson(Map<String, dynamic> j) => OnlineSettings(
        doubleSixBonus: j['doubleSixBonus'] ?? true,
        killToEnter: j['killToEnter'] ?? true,
        safeZonesEnabled: j['safeZonesEnabled'] ?? true,
        prisonRule: j['prisonRule'] ?? true,
        teamPlay: j['teamPlay'] ?? true,
        autoMoveUnambiguous: j['autoMoveUnambiguous'] ?? true,
        playerCount: j['playerCount'] ?? 4,
        finalSixFinish: j['finalSixFinish'] ?? true,
        diceCount: j['diceCount'] ?? 2,
        skipOnDoubleThree: j['skipOnDoubleThree'] ?? false,
        blostOnDoubleFour: j['blostOnDoubleFour'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'doubleSixBonus': doubleSixBonus,
        'killToEnter': killToEnter,
        'safeZonesEnabled': safeZonesEnabled,
        'prisonRule': prisonRule,
        'teamPlay': teamPlay,
        'autoMoveUnambiguous': autoMoveUnambiguous,
        'playerCount': playerCount,
        'finalSixFinish': finalSixFinish,
        'diceCount': diceCount,
        'skipOnDoubleThree': skipOnDoubleThree,
        'blostOnDoubleFour': blostOnDoubleFour,
      };

  GameSettings toLocalSettings() => GameSettings(
        doubleSixBonus: doubleSixBonus,
        killToEnter: killToEnter,
        safeZonesEnabled: safeZonesEnabled,
        autoMoveUnambiguous: autoMoveUnambiguous,
        prisonRule: prisonRule,
        teamPlay: teamPlay,
        playerCount: playerCount,
        finalSixFinish: finalSixFinish,
        diceCount: diceCount,
        skipOnDoubleThree: skipOnDoubleThree,
        blostOnDoubleFour: blostOnDoubleFour,
      );
}

// ── Lobby list ─────────────────────────────────────────────────────────────

class RoomSummary {
  final String roomId;
  final String hostName;
  final int filledSlots;
  final int maxSlots;
  final String settingsLabel;

  const RoomSummary({
    required this.roomId,
    required this.hostName,
    required this.filledSlots,
    required this.maxSlots,
    required this.settingsLabel,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> j) => RoomSummary(
        roomId: j['roomId'] ?? '',
        hostName: j['hostName'] ?? '',
        filledSlots: j['filledSlots'] ?? 0,
        maxSlots: j['maxSlots'] ?? 4,
        settingsLabel: j['settings'] ?? '',
      );
}
