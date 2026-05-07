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
           int scoreA = _evaluateAiMove(a, currentPlayers, ctrlId, prioritizePrison, currentPool: pool);
           int scoreB = _evaluateAiMove(b, currentPlayers, ctrlId, prioritizePrison, currentPool: pool);
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
  int _evaluateAiMove(AiMove move, List<Player> players, int myId, bool prioritizePrison, {List<int> currentPool = const []}) {
    int score = move.dieValue * 10;
    final targetPos = move.target.targetPos;
    final targetState = move.target.targetState;
    final currentPos = move.piece.pos;
    final currentState = move.piece.state;

    int piecesOut = players[myId].pieces.where((p) => p.state != PieceState.yard).length;
    int prisoners = players[myId].pieces.where((p) => p.state == PieceState.prison).length;

    // --- BOARD GEOMETRY & CHOKE POINT TRACKING ---
    // Each player has two own-colored stops: [startCell, secondStop].
    // The SECOND STOP is the prime "border block" choke point — a colored safe square
    // located exactly 3 tiles before the home-stretch entry (Red=47, Green=8, Yellow=21, Blue=34).
    // A 2-piece block here is nearly unpassable for all opponents and must be preserved at all costs.
    final mySecondStop = kMyStops[myId]![1];
    bool isTargetSecondSafe = targetPos == mySecondStop;   // Moving TO own border-block choke point
    bool isCurrentSecondSafe = currentPos == mySecondStop; // Piece currently AT own border-block choke point

    final myFirstStop = kMyStops[myId]![0];
    bool isTargetFirstSafe = targetPos == myFirstStop;
    bool isCurrentFirstSafe = currentPos == myFirstStop;

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

    // Check if piece is behind second stop and will pass it without landing
    int distToSecondStop = (mySecondStop - currentPos) % 52;
    bool isBehindSecondStop = distToSecondStop > 0 && distToSecondStop <= 6;
    bool willPassSecondStop = isBehindSecondStop && distToSecondStop < move.dieValue && targetState == PieceState.board;

    // Check if piece is past second stop (between second stop and home stretch entry, or in home stretch)
    bool isPastSecondStop = false;
    if (currentState == PieceState.homeStretch) {
      isPastSecondStop = true; // In home stretch, definitely passed second stop
    } else if (currentState == PieceState.board) {
      int distFromSecondStop = (currentPos - mySecondStop) % 52;
      // Second stop is 3 cells before home stretch entry
      if (distFromSecondStop > 0 && distFromSecondStop <= 3) {
        isPastSecondStop = true;
      }
    }

    // Count pieces at second stop for block assessment
    int piecesAtSecondStop = players[myId].pieces.where((p) => p.state == PieceState.board && p.pos == mySecondStop).length;

    // Count pieces at first stop for block assessment
    int piecesAtFirstStop = players[myId].pieces.where((p) => p.state == PieceState.board && p.pos == myFirstStop).length;

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

    // Penalty for passing second stop without landing on it
    if (willPassSecondStop) {
      score -= 100000; // Extremely high penalty - NEVER pass second stop without landing
    }

    // Prioritize freeing prisoners on special rolls
    if (prioritizePrison && currentState == PieceState.prison && targetState == PieceState.board) {
      score += 30000;
    }

    // High priority: Release prisoners when only one piece on board and dice is 6
    int piecesOnBoard = players[myId].pieces.where((p) => p.state == PieceState.board || p.state == PieceState.homeStretch).length;
    if (piecesOnBoard <= 1 && prisoners > 0 && move.dieValue == 6) {
      if (currentState == PieceState.prison && targetState == PieceState.board) {
        score += 50000; // Highest priority - free prisoners when vulnerable
      }
    }

    // Extra priority for getting pieces out of prison/yard when rolling 6s
    if (move.dieValue == 6) {
      if (currentState == PieceState.prison && targetState == PieceState.board) {
        score += 40000; // High priority to free prisoners on 6
      }
      if (currentState == PieceState.yard && targetState == PieceState.board) {
        score += 35000; // High priority to get pieces out on 6
      }
    }

    // 🌟 GOD TIER: The Ultimate Choke Point 🌟
    if (formingChokePoint) {
      score += 200000; // Absolute highest priority - over everything including hits and other safe zones
    }

    // TOP TIER MOVES
    if (isHit) {
      score += 60000; // Higher than first border penalty (50000) - prioritize hitting over staying on first border
      
      // Bonus: remaining dice might lead to another hit
      if (currentPool.isNotEmpty) {
        int remainingDiceSum = currentPool.where((d) => d != move.dieValue).fold(0, (sum, d) => sum + d);
        if (remainingDiceSum > 0 && targetState == PieceState.board) {
          // Check if remaining dice can reach another opponent from target position
          for (var p in players) {
            if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
            for (var pc in p.pieces) {
              if (pc.state == PieceState.board) {
                int distToOpponent = (pc.pos - targetPos) % 52;
                if (distToOpponent > 0 && distToOpponent <= remainingDiceSum) {
                  score += 10000; // Bonus for setting up multi-dice hit
                }
              }
            }
          }
        }
      }
    }
    if (targetState == PieceState.home) {
      // Entering home is highly valuable, but NEVER worth breaking the border-block choke point.
      // When breakingChokePoint is also true the net score stays deeply negative (-88000).
      score += 12000;
    }

    // HIGH TIER TACTICS
    if (formingBlock && _isOwnColoredSafe(myId, targetPos) && !isTargetFirstSafe && !isTargetSecondSafe) {
      score += 15000; // Common stops only - higher priority than white cell and start/second border
    }
    
    if (currentlyInDanger && !targetInDanger) {
      score += 6000; // Smart evasion: Running for your life to safety
    } else if (currentlyInDanger && targetInDanger) {
      score += 1000; // Running from one threat to another (desperation)
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

    // 🛑 SACRED DEFENSE: NEVER BREAK THE BORDER-BLOCK CHOKE POINT 🛑
    // Moving away from own second stop while a partner piece still guards it destroys the
    // impassable 2-piece block — far worse than skipping a home entry or a kill opportunity.
    // Net vs home entry: -100000 + 12000 = -88000 → AI will NOT advance to home through here.
    if (breakingChokePoint) {
      score -= 100000;
    }

    // PENALTY: Extremely reluctant to move ANY piece from second stop (border block position)
    // If 2+ pieces already blocking, reduce penalty since extra pieces aren't needed for block
    if (isCurrentSecondSafe) {
      if (piecesAtSecondStop >= 2) {
        score -= 30000; // Reduced penalty - 2+ pieces already blocking
      } else {
        score -= 150000; // Full penalty - need to preserve the block
      }
    }

    // PENALTY: Reluctant to move pieces from first stop (start cell)
    // If 2+ pieces already there, reduce penalty since block is formed
    if (isCurrentFirstSafe) {
      if (piecesAtFirstStop >= 2) {
        score -= 10000; // Reduced penalty - 2+ pieces already blocking
      } else {
        score -= 50000; // Full penalty - preserve pieces at first stop
      }
    }

    if (targetInDanger && !isHit && !formingBlock) {
      score -= 4000; // AI refuses to commit suicide blindly into enemy fire
    }

    if (leavingVulnerable) {
      score -= 5000; // AI refuses to break normal blocks if it leaves a piece defenseless
    }

    // Don't arbitrarily break up safe pieces when we have other moves
    // (Exclude first/second stops as they have their own specific penalties)
    if (currentState == PieceState.board && _isOwnColoredSafe(myId, currentPos) && sameColorAtCurrent > 0 && !isHit && !breakingChokePoint && !isCurrentFirstSafe && !isCurrentSecondSafe) {
      score -= 2000;
    }

    // 50% priority reduction for pieces past second stop until they enter home
    // Unless no other moves available, pieces past second stop should not be moved
    if (isPastSecondStop && targetState != PieceState.home) {
      score = (score * 0.5).toInt(); // 50% reduction as requested
    }

    return score;
  }

  List<int> get _effectiveSafeZones => settings.safeZonesEnabled ? kSafeZones : [];

  bool _isOwnColoredSafe(int playerId, int pos) {
    return kMyStops.containsKey(playerId) && kMyStops[playerId]!.contains(pos);
  }

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
      // Player finished, end turn normally. Partner will play in their own turn series.
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