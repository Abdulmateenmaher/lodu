import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/board_constants.dart';
import '../models/game_models.dart';
import '../models/game_settings.dart';
import '../models/move_destination.dart';
import '../models/match_record.dart';
import '../services/audio_service.dart';
import 'game_logic.dart';

enum GamePhase { setup, play, end }

class GameNotifier extends ChangeNotifier {
  GamePhase phase = GamePhase.setup;
  List<Player> players = [];
  int turnSlot = 0;
  List<int> dicePool = [];
  int consecutiveExtra = 0;
  bool canRoll = false;
  int? selectedDieIndex;
  bool isRolling = false;
  bool _aiTurnActive = false; 
  String? toast;
  GameSettings settings = const GameSettings();
  List<MatchRecord> history = [];

  // GLOBAL TRACKER: Has the first 6 of the match been rolled?
  bool matchFirstSixRolled = false;

  GameNotifier() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('match_history');
    if (str != null) {
      final List decoded = jsonDecode(str);
      history = decoded.map((e) => MatchRecord.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = history.map((e) => e.toJson()).toList();
    prefs.setString('match_history', jsonEncode(jsonList));
  }

  void updateSettings(GameSettings s) {
    settings = s;
    notifyListeners();
  }

  void startGame(List<Map<String, dynamic>> configs) {
    AudioService.play('start_game');

    List<int> activeIds = [0, 1, 2, 3];
    if (settings.playerCount == 2) activeIds = [1, 3]; // Green & Blue
    if (settings.playerCount == 3) activeIds = [0, 1, 3]; // Red, Green, Blue
    
    // Disable team play for 2 or 3 players
    if (settings.playerCount < 4) {
      settings = settings.copyWith(teamPlay: false);
    }

    players = List.generate(
      4,
      (id) => Player(
        id: id,
        isAI: configs[id]['isAI'] as bool,
        isActive: activeIds.contains(id),
        partnerId: (id + 2) % 4,
        name: configs[id]['name'] as String? ?? '',
        pieces: List.generate(4, (pId) => Piece(id: pId, color: id)),
      ),
    );
    
    turnSlot = activeIds[0];
    dicePool = [];
    consecutiveExtra = 0;
    canRoll = true;
    selectedDieIndex = null;
    _aiTurnActive = false;
    matchFirstSixRolled = false; // Reset the global 6 tracker for the new match
    phase = GamePhase.play;
    _showToast('Match Started!');
    notifyListeners();

    if (players[turnSlot].isAI) {
      Timer(const Duration(milliseconds: 600), rollDice);
    }
  }

  void leaveMatch() => resetToSetup();

  void _showToast(String msg, [int ms = 2000]) {
    toast = msg;
    notifyListeners();
    Timer(Duration(milliseconds: ms), () {
      toast = null;
      notifyListeners();
    });
  }

  int get activePlayerId => turnSlot;

  int getControlPlayerId([List<Player>? p]) {
    final ps = p ?? players;
    final act = ps[turnSlot];
    if (act.finished && act.isHelper) return act.partnerId;
    return act.id;
  }

  void _autoSelectDie() {
    if (dicePool.isEmpty) {
      selectedDieIndex = null;
      return;
    }
    
    // Auto-select the die that actually has valid moves (preferring the larger one)
    final pCtrl = players[getControlPlayerId()];
    if (!pCtrl.isAI) {
      for (int i = 0; i < dicePool.length; i++) {
        bool canMove = false;
        for (final pc in pCtrl.pieces) {
          if (pc.state == PieceState.home || pc.hasKilledThisTurn) continue;
          final dest = calculateDestination(pCtrl, pc, dicePool[i], players, pool: dicePool, dieIndex: i, settings: settings);
          if (dest != null) { canMove = true; break; }
        }
        if (canMove) {
          selectedDieIndex = i;
          return;
        }
      }
    }
    selectedDieIndex = 0;
  }

  void rollDice() {
    if (!canRoll || isRolling) return;
    isRolling = true;
    canRoll = false;
    AudioService.play('rolling');
    notifyListeners();

    Timer(const Duration(milliseconds: 350), () {
      final actId = activePlayerId;
      final newPlayers = _deepCopyPlayers(players);
      final activeP = newPlayers[actId];

      final d1 = Random().nextInt(6) + 1;
      final d2 = Random().nextInt(6) + 1;

      bool prioritizePrison = (d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1));

      if (activeP.finished && !activeP.isHelper) {
        if (d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1)) {
          activeP.isHelper = true;
          isRolling = false;
          players = newPlayers;
          notifyListeners();
          Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
          return;
        } else {
          isRolling = false;
          players = newPlayers;
          notifyListeners();
          Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
          return;
        }
      }

      bool extra = false;
      final newPool = List<int>.from(dicePool);
      final isDoubleSix = d1 == 6 && d2 == 6;
      final isDoubleOne = d1 == 1 && d2 == 1;

      // RULE: First 6 of the Entire Match
      bool isSixOrDoubleOne = (d1 == 6 || d2 == 6 || isDoubleOne);
      bool isGlobalFirstSix = !matchFirstSixRolled && isSixOrDoubleOne;

      if (isGlobalFirstSix) {
        matchFirstSixRolled = true; // Mark that the match's first 6 has happened
        
        bool hasFour = (d1 == 6 && d2 == 4) || (d2 == 6 && d1 == 4);
        
        newPool.clear();
        if (hasFour) {
          // The 6,4 jackpot -> 4*6 + 4
          newPool.addAll([6, 6, 6, 6, 4]);
        AudioService.play('six_four');
        } else if (isDoubleSix) {
          // Rolled 6,6 -> Add exactly ONE extra 6
          newPool.addAll([6, 6, 6]);
          extra = true; // Treat this as an extra turn as well since it's a huge bonus
        } else if (isDoubleOne) {
          // Rolled 1,1 -> Add exactly ONE extra 6
          newPool.addAll([6, 6, 6]);
          extra = true; // Treat this as an extra turn as well since it's a huge bonus
        } else {
          // Rolled 6 and something else (e.g. 6, 2) -> Add exactly ONE extra 6
          newPool.addAll([d1, d2, 6]);
        }
      } else {
        // Standard rules for the rest of the game
        if (settings.doubleSixBonus && (isDoubleSix || isDoubleOne)) {
          extra = consecutiveExtra < 3;
          newPool.addAll([6, 6]);
        } else {
          newPool.addAll([d1, d2]);
        }
        if (d1 == d2 && (d1 == 6 || d1 == 1)) {
          extra = true;
        }
      }

      newPool.sort((a, b) => b.compareTo(a));
      isRolling = false;
      players = newPlayers;
      dicePool = newPool;
      consecutiveExtra = extra ? consecutiveExtra + 1 : 0;
      canRoll = extra;
      
      if (extra && !isGlobalFirstSix) AudioService.play('extra_turn');
      
      _autoSelectDie();
      notifyListeners();

      Timer(const Duration(milliseconds: 140), () {
        _checkAndAutoPlay(newPool, newPlayers, extra, prioritizePrison);
      });
    });
  }

  void _checkAndAutoPlay(List<int> pool, List<Player> currentPlayers, bool currentCanRoll, bool prioritizePrison) {
    final snapSlot = turnSlot;
    final actId = snapSlot;
    final actPlayer = currentPlayers[actId];
    final ctrlId = actPlayer.finished && actPlayer.isHelper ? actPlayer.partnerId : actPlayer.id;
    final pCtrl = currentPlayers[ctrlId];

    final allMoves = getAllValidMoves(pCtrl, pool, currentPlayers, settings);

    if (actPlayer.isAI) {
      if (_aiTurnActive) return;
      _aiTurnActive = true;

      if (currentCanRoll) {
        Timer(const Duration(milliseconds: 490), () {
          if (turnSlot != snapSlot) return;
          _aiTurnActive = false;
          rollDice();
        });
        return;
      }

      if (pCtrl.finished && !pCtrl.isHelper) {
        Timer(const Duration(milliseconds: 350), () {
          _aiTurnActive = false;
          _endTurn(currentPlayers);
        });
        return;
      }

      if (allMoves.isNotEmpty) {
        // AI Intelligence
        allMoves.sort((a, b) {
           int scoreA = _evaluateAiMove(a, currentPlayers, ctrlId, prioritizePrison);
           int scoreB = _evaluateAiMove(b, currentPlayers, ctrlId, prioritizePrison);
           return scoreB.compareTo(scoreA); // Highest first
        });
        final best = allMoves.first;
        Timer(const Duration(milliseconds: 500), () {
          if (turnSlot != snapSlot) return;
          _aiTurnActive = false;
          _executeMove(best.piece, best.target, best.dieIndex, currentPlayers, pool, currentCanRoll);
        });
      } else {
        Timer(const Duration(milliseconds: 420), () {
          AudioService.play('no_move_chance');
          _aiTurnActive = false;
          _endTurn(currentPlayers);
        });
      }
      return;
    }

    // Human player
    if (pCtrl.finished && !pCtrl.isHelper) {
      Timer(const Duration(milliseconds: 280), () => _endTurn(currentPlayers));
      return;
    }

    if (allMoves.isEmpty && !currentCanRoll && pool.isNotEmpty) {
      AudioService.play('no_move_chance');
      Timer(const Duration(milliseconds: 1120), () => _endTurn(currentPlayers));
      return;
    }

    if (!settings.autoMoveUnambiguous) return;

    if (pool.length == 1 && allMoves.length == 1 && !currentCanRoll) {
      final only = allMoves.first;
      Timer(const Duration(milliseconds: 420), () => _executeMove(only.piece, only.target, only.dieIndex, currentPlayers, pool, currentCanRoll));
      return;
    }
  }


  // ULTRA-IQ HUMAN-LIKE AI EVALUATION
  int _evaluateAiMove(AiMove move, List<Player> players, int myId, bool prioritizePrison) {
    int score = move.dieValue * 10;
    final targetPos = move.target.targetPos;
    final targetState = move.target.targetState;
    final currentPos = move.piece.pos;
    final currentState = move.piece.state;

    int piecesOut = players[myId].pieces.where((p) => p.state != PieceState.yard).length;
    int prisoners = players[myId].pieces.where((p) => p.state == PieceState.prison).length;

    // --- BOARD GEOMETRY & CHOKE POINT TRACKING ---
    int startPos = myId * 13; // Standard 4-player 52-tile base offset calculation
    int getDistFromStart(int pos) {
      if (pos < 0) return -1;
      int dist = (pos - startPos) % 52;
      return dist < 0 ? dist + 52 : dist;
    }
    
    int targetDist = getDistFromStart(targetPos);
    int currentDist = getDistFromStart(currentPos);

    // Identify the crucial "Second Safe Area" (The star square in the player's 1st quadrant)
    bool isTargetSecondSafe = _effectiveSafeZones.contains(targetPos) && targetDist > 0 && targetDist <= 13;
    bool isCurrentSecondSafe = _effectiveSafeZones.contains(currentPos) && currentDist > 0 && currentDist <= 13;

    // 1. Hit Assessment
    bool isHit = false;
    if (targetState == PieceState.board && !_effectiveSafeZones.contains(targetPos)) {
      isHit = hasOpponent(targetPos, myId, players);
    }

    // 2. Block Assessment
    int sameColorAtTarget = 0;
    if (targetState == PieceState.board || targetState == PieceState.homeStretch) {
      sameColorAtTarget = players[myId].pieces.where((p) => p != move.piece && p.state == targetState && p.pos == targetPos).length;
    }
    bool formingBlock = sameColorAtTarget == 1; // Creates a 2-piece block

    int sameColorAtCurrent = 0;
    if (currentState == PieceState.board) {
      sameColorAtCurrent = players[myId].pieces.where((p) => p != move.piece && p.state == PieceState.board && p.pos == currentPos).length;
    }
    // Leaving a block of 2, means 1 piece is left behind alone and unprotected!
    bool leavingVulnerable = sameColorAtCurrent == 1 && !_effectiveSafeZones.contains(currentPos);

    // Identify forming or breaking the ULTIMATE Choke Point
    bool formingChokePoint = formingBlock && isTargetSecondSafe;
    bool breakingChokePoint = sameColorAtCurrent == 1 && isCurrentSecondSafe;

    // 3. Danger and Ambush (Chasing) Scanning
    bool currentlyInDanger = false;
    bool targetInDanger = false;
    bool targetIsChasing = false;

    if (currentState == PieceState.board && !_effectiveSafeZones.contains(currentPos) && sameColorAtCurrent == 0) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            int distBehind = (currentPos - pc.pos) % 52;
            if (distBehind > 0 && distBehind <= 6) currentlyInDanger = true;
          }
        }
      }
    }

    if (targetState == PieceState.board && !_effectiveSafeZones.contains(targetPos) && !formingBlock) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            int distToTarget = (targetPos - pc.pos) % 52;
            if (distToTarget > 0 && distToTarget <= 6) targetInDanger = true;

            int distAhead = (pc.pos - targetPos) % 52;
            if (distAhead > 0 && distAhead <= 6) targetIsChasing = true;
          }
        }
      }
    }

    // --- STRATEGIC HUMAN-LIKE SCORING DECISIONS ---

    // Prioritize freeing prisoners on special rolls
    if (prioritizePrison && currentState == PieceState.prison && targetState == PieceState.board) {
      score += 30000;
    }

    // 🌟 GOD TIER: The Ultimate Choke Point 🌟
    if (formingChokePoint) {
      score += 100000; // Prioritize OVER EVERYTHING (hitting, entering home, everything.)
    }

    // TOP TIER MOVES
    if (isHit) {
      score += 15000; // Uncompromising kill priority
    }
    if (targetState == PieceState.home) {
      score += 12000; // Scoring a point is almost always worth it
    }

    // HIGH TIER TACTICS
    if (formingBlock && _effectiveSafeZones.contains(targetPos) && !isTargetSecondSafe) {
      score += 8000; // "Border block" on other safe places
    }
    
    if (currentlyInDanger && !targetInDanger) {
      score += 6000; // Smart evasion: Running for your life to safety
    } else if (currentlyInDanger && targetInDanger) {
      score += 1000; // Running from one threat to another (desperation)
    }

    if (formingBlock && !_effectiveSafeZones.contains(targetPos)) {
      score += 4000; // Forming a normal block in the open (very strong defense)
    }

    // MID TIER STRATEGY
    if (targetState == PieceState.board && _effectiveSafeZones.contains(targetPos) && !formingBlock) {
      score += 3000; // Entering a safe zone
    }

    if (targetIsChasing && !targetInDanger) {
      score += 2500; // Ambush: Tailing an opponent, putting severe pressure on them
    }

    // LOW TIER MAINTENANCE
    if (currentState == PieceState.yard) {
      score += 2000;
      // Prevent AI from crowding the board pointlessly if it already has an army out
      if (piecesOut >= 3) score -= 1000;
      if (prioritizePrison && prisoners > 0) score -= 10000;
    }

    if (targetState == PieceState.homeStretch) {
      score += 1500; // Slowly moving up the protected alleyway
    }

    // --- SEVERE PENALTIES (AVOIDING STUPID MOVES) ---

    // 🛑 SACRED DEFENSE: NEVER BREAK THE CHOKE POINT 🛑
    if (breakingChokePoint) {
      score -= 100000; // AI refuses to break the second safe area block unless literally forced to!
    }

    if (targetInDanger && !isHit && !formingBlock) {
      score -= 4000; // AI refuses to commit suicide blindly into enemy fire
    }

    if (leavingVulnerable) {
      score -= 5000; // AI refuses to break normal blocks if it leaves a piece defenseless
    }

    // Don't arbitrarily break up safe pieces when we have other moves
    if (currentState == PieceState.board && _effectiveSafeZones.contains(currentPos) && sameColorAtCurrent > 0 && !isHit && !breakingChokePoint) {
      score -= 2000;
    }

    return score;
  }

  List<int> get _effectiveSafeZones => settings.safeZonesEnabled ? kSafeZones : [];

  String _nameOf(Player p) => p.name.isNotEmpty ? p.name : (p.isAI ? 'Bot ${kColors[p.id]!.name}' : kColors[p.id]!.name);

  void handleDieClick(int index) {
    if (players[activePlayerId].isAI || isRolling || index >= dicePool.length) return;
    selectedDieIndex = index;
    notifyListeners();
  }

  void handlePieceClick(Piece piece) {
    final actId = activePlayerId;
    final ctrlId = getControlPlayerId(players);
    if (piece.color != ctrlId || isRolling || players[actId].isAI) return;
    if (selectedDieIndex == null || piece.hasKilledThisTurn) return;

    final pCtrl = players[ctrlId];
    final moveVal = dicePool[selectedDieIndex!];
    final dest = calculateDestination(pCtrl, piece, moveVal, players, pool: dicePool, dieIndex: selectedDieIndex!, settings: settings);
    
    if (dest != null) {
      _executeMove(piece, dest, selectedDieIndex!, players, dicePool, canRoll);
    }
  }

  void _executeMove(Piece piece, MoveDestination target, int dieIndexUsed, List<Player> currentPlayers, List<int> currentPool, bool currentCanRoll) {
    AudioService.play('moving_piece');
    final newPlayers = _deepCopyPlayers(currentPlayers);
    final ctrlId = getControlPlayerId(currentPlayers);
    final pCtrl = newPlayers[ctrlId];
    final pPiece = pCtrl.pieces.firstWhere((pc) => pc.id == piece.id && pc.color == piece.color);

    pPiece.state = target.targetState;
    pPiece.pos = target.targetPos;

    bool rewardTurn = currentCanRoll;
    if (target.targetState == PieceState.home) {
      AudioService.play('reach_goal');
      rewardTurn = true;
    }

    final newPool = List<int>.from(currentPool)..removeAt(dieIndexUsed);

    // Form block check for audio
    if (target.targetState == PieceState.board) {
      int sameColor = pCtrl.pieces.where((p) => p.state == PieceState.board && p.pos == target.targetPos).length;
      if (sameColor == 2) AudioService.play('block_border');
    }

    if (target.targetState == PieceState.board && !_effectiveSafeZones.contains(target.targetPos)) {
      for (final op in newPlayers) {
        if (op.id != ctrlId && op.id != pCtrl.partnerId && op.isActive) {
          for (final opc in op.pieces) {
            if (opc.state == PieceState.board && opc.pos == target.targetPos) {
              op.timesHit++; // Record hit for Unscathed status
              AudioService.play('hit_piece');
              if (settings.prisonRule) {
                opc.state = PieceState.prison;
                opc.pos = -2;
                opc.prisonerOf = ctrlId;
              } else {
                opc.state = PieceState.yard;
                opc.pos = -1;
                opc.prisonerOf = null;
              }
              pCtrl.hasKilled = true;
              pPiece.hasKilledThisTurn = true;
            }
          }
        }
      }
    }

    if (!settings.killToEnter) pCtrl.hasKilled = true;

    final justFinished = !pCtrl.finished && pCtrl.pieces.every((pc) => pc.state == PieceState.home);
    if (justFinished) pCtrl.finished = true;

    players = newPlayers;
    dicePool = newPool;
    canRoll = rewardTurn;
    _autoSelectDie();

    final team1Done = newPlayers[0].finished && newPlayers[2].finished;
    final team2Done = newPlayers[1].finished && newPlayers[3].finished;
    final soloDone = newPlayers.any((p) => p.finished);
    
    final gameOver = (settings.teamPlay && (team1Done || team2Done)) || (!settings.teamPlay && soloDone);

    if (gameOver) {
      AudioService.play('wining');
      int stars = 1;
      String statusDesc = "";
      List<String> winners = [];
      List<String> losers = [];
      int unscathedWinners = 0;

      if (settings.teamPlay) {
        if (team1Done) {
          winners.addAll([_nameOf(newPlayers[0]), _nameOf(newPlayers[2])]);
          losers.addAll([_nameOf(newPlayers[1]), _nameOf(newPlayers[3])]);
          if (newPlayers[0].timesHit == 0) unscathedWinners++;
          if (newPlayers[2].timesHit == 0) unscathedWinners++;
        } else {
          winners.addAll([_nameOf(newPlayers[1]), _nameOf(newPlayers[3])]);
          losers.addAll([_nameOf(newPlayers[0]), _nameOf(newPlayers[2])]);
          if (newPlayers[1].timesHit == 0) unscathedWinners++;
          if (newPlayers[3].timesHit == 0) unscathedWinners++;
        }
        stars = unscathedWinners > 0 ? unscathedWinners + 1 : 1;
      } else {
        Player winner = newPlayers.firstWhere((p) => p.finished);
        winners.add(_nameOf(winner));
        losers.addAll(newPlayers.where((p) => p.isActive && !p.finished).map((p) => _nameOf(p)));
        if (winner.timesHit == 0) stars = 2; // Single unscathed
      }

      String winnerStr = winners.join(' and ');
      String loserStr = losers.join(' and ');
      statusDesc = "$winnerStr won the game from $loserStr";
      if (unscathedWinners > 0 || stars >= 2) {
        statusDesc += " unscathed!";
      } else {
        statusDesc += "!";
      }

      history.add(MatchRecord(
        winnerLabel: winners.join(' & '),
        playerNames: newPlayers.where((p) => p.isActive).map(_nameOf).toList(),
        playerIsAI: newPlayers.where((p) => p.isActive).map((p) => p.isAI).toList(),
        playedAt: DateTime.now(),
        stars: stars,
        statusText: statusDesc,
      ));
      _saveHistory();
      
      phase = GamePhase.end;
      notifyListeners();
      return;
    }

    if (justFinished) {
      // Cannot help partner in this same turn series.
      dicePool = [];
      canRoll = false;
      notifyListeners();
      Timer(const Duration(milliseconds: 300), () => _endTurn(newPlayers));
      return;
    }

    notifyListeners();

    if (newPool.isEmpty && !rewardTurn) {
      Timer(const Duration(milliseconds: 210), () => _endTurn(newPlayers));
    } else {
      Timer(const Duration(milliseconds: 140), () {
        _checkAndAutoPlay(newPool, newPlayers, rewardTurn, false);
      });
    }
  }

  void _endTurn([List<Player>? latestPlayers]) {
    _aiTurnActive = false;
    final ps = latestPlayers ?? players;
    final newPlayers = _deepCopyPlayers(ps);
    for (final p in newPlayers) {
      for (final pc in p.pieces) {
        pc.hasKilledThisTurn = false;
      }
    }
    players = newPlayers;
    
    // Skip inactive players
    do {
      turnSlot = (turnSlot + 1) % 4;
    } while (!players[turnSlot].isActive);

    dicePool = [];
    consecutiveExtra = 0;
    canRoll = true;
    selectedDieIndex = null;
    notifyListeners();

    if (players[turnSlot].isAI) {
      Timer(const Duration(milliseconds: 560), rollDice);
    }
  }

  void resetToSetup() {
    phase = GamePhase.setup;
    players = [];
    dicePool = [];
    notifyListeners();
  }

  List<Player> _deepCopyPlayers(List<Player> source) {
    return source.map((p) => Player(
      id: p.id,
      isAI: p.isAI,
      isActive: p.isActive,
      partnerId: p.partnerId,
      name: p.name,
      hasKilled: p.hasKilled,
      finished: p.finished,
      isHelper: p.isHelper,
      hasRolledFirstSix: p.hasRolledFirstSix,
      timesHit: p.timesHit,
      pieces: p.pieces.map((pc) => Piece(
        id: pc.id, color: pc.color, state: pc.state,
        pos: pc.pos, prisonerOf: pc.prisonerOf,
        hasKilledThisTurn: pc.hasKilledThisTurn,
      )).toList(),
    )).toList();
  }
}