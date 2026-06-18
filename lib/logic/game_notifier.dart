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

      final allHome = activeP.pieces.every((pc) => pc.state == PieceState.home);
      if (allHome && !activeP.finished) {
        // 🔥 CRITICAL: Clear the dice pool before the winning roll attempt
        // When all pieces are home and player has an extra turn, any leftover
        // dice from the previous turn must be discarded. The player gets a
        // fresh roll to attempt the winning condition.
        dicePool = [];
        
        // Winning condition: single 6, double 6, or double 1 (treated like double 6)
        bool winningRoll = d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1) || (d1 == 6 && d2 == 6);
        if (winningRoll) {
          activeP.finished = true;
          // Immediately become a helper if in team play!
          if (settings.teamPlay) {
            activeP.isHelper = true;
          }
          isRolling = false;
          players = newPlayers;
          notifyListeners();
          if (_checkGameOver(newPlayers)) return;
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

      bool prioritizePrison = (d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1));
      bool isQualifyingRoll = (d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1) || (d1 == 6 && d2 == 6));

      if (activeP.finished && !activeP.isHelper) {
        // Already finished but not a helper yet - needs a 6, double 6, or double 1 to become helper
        if (isQualifyingRoll) {
          activeP.isHelper = true;
          dicePool = [];
          isRolling = false;
          canRoll = false;
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

      if (actPlayer.finished && !actPlayer.isHelper) {
        Timer(const Duration(milliseconds: 350), () {
          _aiTurnActive = false;
          _endTurn(currentPlayers);
        });
        return;
      }

      if (actPlayer.finished && actPlayer.isHelper && allMoves.isEmpty) {
        Timer(const Duration(milliseconds: 425), () {
          _aiTurnActive = false;
          _endTurn(currentPlayers);
        });
        return;
      }

      if (allMoves.isNotEmpty) {
        // AI Intelligence
         allMoves.sort((a, b) {
            int scoreA = _evaluateAiMove(a, currentPlayers, ctrlId, prioritizePrison, currentPool: pool, dieIndices: a.dieIndices);
            int scoreB = _evaluateAiMove(b, currentPlayers, ctrlId, prioritizePrison, currentPool: pool, dieIndices: b.dieIndices);
            return scoreB.compareTo(scoreA); // Highest first
         });
        final best = allMoves.first;
        Timer(const Duration(milliseconds: 500), () {
          if (turnSlot != snapSlot) return;
          _aiTurnActive = false;
          _executeMove(best.piece, best.target, best.dieIndices, currentPlayers, pool, currentCanRoll);
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
    if (actPlayer.finished && !actPlayer.isHelper) {
      Timer(const Duration(milliseconds: 280), () => _endTurn(currentPlayers));
      return;
    }

    if (allMoves.isEmpty && !currentCanRoll && pool.isNotEmpty) {
      AudioService.play('no_move_chance');
      Timer(const Duration(milliseconds: 1120), () => _endTurn(currentPlayers));
      return;
    }

    // Auto-move if only one valid move available
    if (allMoves.length == 1 && !currentCanRoll) {
      final only = allMoves.first;
      Timer(const Duration(milliseconds: 420), () => _executeMove(only.piece, only.target, only.dieIndices, currentPlayers, pool, currentCanRoll));
      return;
    }
  }


  // ULTRA-IQ HUMAN-LIKE AI EVALUATION
  int _evaluateAiMove(AiMove move, List<Player> players, int myId, bool prioritizePrison, {List<int> currentPool = const [], List<int> dieIndices = const []}) {
      List<int> remainingDice = [];
    for (int k = 0; k < currentPool.length; k++) {
      if (!dieIndices.contains(k)) remainingDice.add(currentPool[k]);
    }

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

    bool isCurrentlyOnSafePlace = false;
    if (currentState == PieceState.board) {
      isCurrentlyOnSafePlace = _effectiveSafeZones.contains(currentPos) || _isOwnColoredSafe(myId, currentPos);
    }
    
    // Priority for pieces on white/common squares over safe places
    if (currentState == PieceState.board) {
      if (!isCurrentlyOnSafePlace) {
        score += 4000; // Strong bonus to move pieces off exposed/common squares
      } else {
        score -= 4000; // Strong penalty to leave safe places (unless overridden by hits/blocks/chokepoints)
      }
    }

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
    // Use (value + 52) % 52 to handle negative values correctly (same as C# backend)
    int distToSecondStop = (mySecondStop - currentPos + 52) % 52;
    bool isBehindSecondStop = distToSecondStop > 0 && distToSecondStop <= 6;
    bool willPassSecondStop = isBehindSecondStop && distToSecondStop < move.dieValue && targetState == PieceState.board;

    // Check if piece is past second stop (between second stop and home stretch entry, or in home stretch)
    bool isPastSecondStop = false;
    if (currentState == PieceState.homeStretch) {
      isPastSecondStop = true; // In home stretch, definitely passed second stop
    } else if (currentState == PieceState.board) {
      int distFromSecondStop = (currentPos - mySecondStop + 52) % 52;
      // Second stop is 3 cells before home stretch entry
      if (distFromSecondStop > 0 && distFromSecondStop <= 3) {
        isPastSecondStop = true;
      }
    }

    // Check if piece is AT the second stop (the border block position)
    bool pieceAtSecondStop = currentState == PieceState.board && currentPos == mySecondStop;

    // Check if moving this piece from second stop will enter home stretch or home
    bool movingFromSecondStopIntoHome = pieceAtSecondStop && (targetState == PieceState.homeStretch || targetState == PieceState.home);

    // Count pieces at second stop for block assessment
    int piecesAtSecondStop = players[myId].pieces.where((p) => p.state == PieceState.board && p.pos == mySecondStop).length;

    // Count pieces at first stop for block assessment
    int piecesAtFirstStop = players[myId].pieces.where((p) => p.state == PieceState.board && p.pos == myFirstStop).length;

    // Count pieces NOT at second stop and not past it (these are the ones that need attention)
    int piecesNeedingHelp = players[myId].pieces.where((p) {
      if (p.state == PieceState.home || p.state == PieceState.homeStretch) return false;
      if (p.state == PieceState.board) {
        // Use (value + 52) % 52 to handle negative values correctly (same as C# backend)
        int distFromStop = (p.pos - mySecondStop + 52) % 52;
        if (distFromStop <= 3) return false; // At or past second stop
      }
      return true;
    }).length;

    // Check if any piece is on opponent start borders
    bool hasPieceOnOpponentStart = false;
    for (var p in players) {
      if (p.id != myId && p.partnerId != myId && p.isActive) {
        int oppFirstStop = kMyStops[p.id]![0];
        hasPieceOnOpponentStart = players[myId].pieces.any((pc) => pc.state == PieceState.board && pc.pos == oppFirstStop);
        if (hasPieceOnOpponentStart) break;
      }
    }

    // Calculate opponent pieces out for prioritization
    int opponentPiecesOut = 0;
    for (var p in players) {
      if (p.id != myId && p.partnerId != myId && p.isActive) {
        opponentPiecesOut += p.pieces.where((pc) => pc.state != PieceState.yard).length;
      }
    }
    int myOut = piecesOut;

    // 3. Danger and Ambush (Chasing) Scanning
    bool currentlyInDanger = false;
    bool targetInDanger = false;
    bool targetIsChasing = false;

    int minThreatDist = 7; // Initialize to max possible +1
    if (currentState == PieceState.board && !_effectiveSafeZones.contains(currentPos) && sameColorAtCurrent == 0) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            // Use (value + 52) % 52 to handle negative values correctly (same as C# backend)
            int distBehind = (currentPos - pc.pos + 52) % 52;
            if (distBehind > 0 && distBehind <= 6) {
              currentlyInDanger = true;
              if (distBehind < minThreatDist) minThreatDist = distBehind;
            }
          }
        }
      }
    }

    if (targetState == PieceState.board && !_effectiveSafeZones.contains(targetPos) && !formingBlock) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            // Use (value + 52) % 52 to handle negative values correctly (same as C# backend)
            int distToTarget = (targetPos - pc.pos + 52) % 52;
            if (distToTarget > 0 && distToTarget <= 6) targetInDanger = true;

            int distAhead = (pc.pos - targetPos + 52) % 52;
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

    // 🔥 ENHANCED: Prevent moving from second stop into home stretch/home
    // The second stop is the critical border block position. Moving into home
    // from there should be DEPRIORITIZED in favor of moving other pieces that
    // are exposed or need to be freed.
    if (movingFromSecondStopIntoHome) {
      score -= 200000; // Massive penalty - never sacrifice the border block
    }

    // 🔥 ENHANCED: Strong penalty for moving ANY piece at second stop
    if (pieceAtSecondStop && targetState != PieceState.home) {
      // If other pieces need help (exposed, in yard, in prison), strongly prefer them
      if (piecesNeedingHelp > 0) {
        score -= 120000 + (piecesNeedingHelp * 10000);
      }
    }

    // 🔥 ENHANCED: Boost for freeing pieces that need help when we have pieces at second stop
    if (piecesNeedingHelp > 0) {
      // Boost for moving pieces that are NOT at/past second stop
      bool moveHelpsNeedy = !pieceAtSecondStop && !isPastSecondStop;
      if (moveHelpsNeedy) {
        score += 50000; // Strong bonus for moving needy pieces
        if (currentlyInDanger) score += 30000; // Extra if they're in danger
      }
    }

    // Prioritize freeing prisoners on special rolls
    if (prioritizePrison && currentState == PieceState.prison && targetState == PieceState.board) {
      score += 30000;
    }

    // High priority: Release prisoners when only one piece on board and dice is 6
    int piecesOnBoard = players[myId].pieces.where((p) => p.state == PieceState.board || p.state == PieceState.homeStretch).length;
    if (piecesOnBoard <= 2 && prisoners > 0 && move.dieValue == 6) {
      if (currentState == PieceState.prison && targetState == PieceState.board) {
        score += 50000; // Highest priority - free prisoners when vulnerable
      }
    }

    // Extra priority for getting pieces out of prison/yard when rolling 6/double-6/double-1
    // Prisoners (Prison) are MORE important than yard pieces
    if (move.dieValue == 6) {
      int outDiff = opponentPiecesOut - myOut;
      if (currentState == PieceState.prison && targetState == PieceState.board) {
        score += 30000; // Prisoners are top priority - higher than yard
        score += 10000 * (outDiff + 1); // Boost when opponent is further ahead
        if (piecesOnBoard <= 1) score += 10000; // Extra priority when vulnerable (no or one piece on board)
      }
      if (currentState == PieceState.yard && targetState == PieceState.board) {
        score += 20000; // Yard pieces are secondary
        score += 8000 * (outDiff + 1); // Boost when opponent is further ahead
      }
    }

    // When 3+ pieces are stuck in yard and roll is a 6/double-6/double-1,
    // heavily prioritize pulling pieces out of prison over yard
    int piecesInYard = players[myId].pieces.where((p) => p.state == PieceState.yard).length;
    if (prioritizePrison && piecesInYard >= 3 && prisoners > 0) {
      if (currentState == PieceState.prison && targetState == PieceState.board) {
        score += 22000; // Bonus: break prisoner block before touching yard
      }
    }

    // Enhancement 3: High priority for finishing all pieces
    int otherPiecesHome = players[myId].pieces.where((p) => p != move.piece && p.state == PieceState.home).length;
    bool isFinishing = targetState == PieceState.home && otherPiecesHome == 3;
    if (isFinishing) {
      score += 150000;
      if (remainingDice.contains(6)) {
        score += 20000;
      }
    }

    // 🌟 GOD TIER: The Ultimate Choke Point 🌟
    if (formingChokePoint) {
      score += 200000; // Absolute highest priority - over everything including hits and other safe zones
    }

    // HIGH PRIORITY: Block first stop
    if (formingBlock && isTargetFirstSafe) {
      score += 40000; // Prioritize blocking first stop after choke point
    }

    // TOP TIER MOVES
    if (isHit) {
      score += 60000; // Higher than first border penalty (50000) - prioritize hitting over staying on first border
      
      // Bonus: remaining dice might lead to another hit
      if (remainingDice.isNotEmpty) {
        int remainingDiceSum = remainingDice.fold(0, (sum, d) => sum + d);
        if (remainingDiceSum > 0 && targetState == PieceState.board) {
          // Check if remaining dice can reach another opponent from target position
          for (var p in players) {
            if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
              for (var pc in p.pieces) {
              if (pc.state == PieceState.board) {
                // Use (value + 52) % 52 to handle negative values correctly (same as C# backend)
                int distToOpponent = (pc.pos - targetPos + 52) % 52;
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
      // Reduce priority if other pieces are still out
      int piecesNotHome = players[myId].pieces.where((p) => p.state != PieceState.home).length;
      if (piecesNotHome > 1) {
        score -= 5000;
      }
    }

    // HIGH TIER TACTICS
    if (formingBlock && _isOwnColoredSafe(myId, targetPos) && !isTargetFirstSafe && !isTargetSecondSafe) {
      score += 5000; // Common stops - lower priority than border stops
    }

    // Prioritize landing on own safe zones even without forming block
    if (_isOwnColoredSafe(myId, targetPos) && !formingBlock) {
      score += 8000;
    }

    // PENALTY: Never permit stacking two pieces on blank squares
    if (formingBlock && !_isOwnColoredSafe(myId, targetPos)) {
      score -= 100000; // Extremely discourage stacking on non-safe squares
    }
    
    if (currentlyInDanger && !targetInDanger) {
      score += 6000 + (7 - minThreatDist) * 1000; // Smart evasion: More bonus for closer threats
    } else if (currentlyInDanger && targetInDanger) {
      score += 1000; // Running from one threat to another (desperation)
    }



    // MID TIER STRATEGY
    if (targetState == PieceState.board && _effectiveSafeZones.contains(targetPos) && !formingBlock) {
      score += 3000; // Entering a safe zone
    }

    if (targetIsChasing && !targetInDanger) {
      score += 4000; // Ambush: Tailing an opponent, putting severe pressure on them
    }

    // Estimate future hit potential from target position
    int futureHitPotential = 0;
    if (targetState == PieceState.board) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            // Use (value + 52) % 52 to handle negative values correctly (same as C# backend)
            int dist = (pc.pos - targetPos + 52) % 52;
            if (dist > 0 && dist <= 6) futureHitPotential++;
          }
        }
      }
      score += futureHitPotential * 2000; // Bonus for positioning to hit opponents next turn
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
        score -= 5000; // Reduced penalty - 2+ pieces already blocking
      } else {
        score -= 20000; // Reduced penalty to prioritize moving from first stop
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
    if (selectedDieIndex != null && piece.hasKilledThisTurn) return;

    final pCtrl = players[ctrlId];
    final allValidMoves = getAllValidMoves(pCtrl, dicePool, players, settings);
    if (allValidMoves.length == 1) return; // Auto-move will handle single valid moves

    if (selectedDieIndex != null) {
      // Single die selected
      int moveVal = dicePool[selectedDieIndex!];
      final dest = calculateDestination(pCtrl, piece, moveVal, players, pool: dicePool, dieIndex: selectedDieIndex!, settings: settings);
      if (dest != null) {
        _executeMove(piece, dest, [selectedDieIndex!], players, dicePool, canRoll);
      }
    } else if (dicePool.length == 2) {
      // No die selected, check if combined is possible
      // First check if any single moves are possible
      bool hasSingleMove = false;
      for (int i = 0; i < dicePool.length; i++) {
        final dest = calculateDestination(pCtrl, piece, dicePool[i], players, pool: dicePool, dieIndex: i, settings: settings);
        if (dest != null) {
          hasSingleMove = true;
          break;
        }
      }
      if (!hasSingleMove) {
        // Try combined only if no single moves
        int moveVal = dicePool[0] + dicePool[1];
        final dest = calculateDestination(pCtrl, piece, moveVal, players, pool: [], dieIndex: -1, settings: settings);
        if (dest != null) {
          _executeMove(piece, dest, [0, 1], players, dicePool, canRoll);
        }
      }
    }
  }

  bool _checkGameOver(List<Player> newPlayers) {
    final team1Done = newPlayers[0].finished && newPlayers[2].finished;
    final team2Done = newPlayers[1].finished && newPlayers[3].finished;
    final soloDone = newPlayers.any((p) => p.finished);

    final gameOver = (settings.teamPlay && (team1Done || team2Done)) || (!settings.teamPlay && soloDone);

    if (gameOver) {

        Player winner = newPlayers.firstWhere((p) => p.finished);

        final losers = <String>[];
        losers.addAll(newPlayers.where((p) => p.isActive && !p.finished).map((p) => _nameOf(p)));

        final playerNames = newPlayers.map((p) => _nameOf(p)).toList();
        final playerIsAI = newPlayers.map((p) => p.isAI).toList();

        history.add(MatchRecord(
          winnerLabel: _nameOf(winner),
          playerNames: playerNames,
          playerIsAI: playerIsAI,
          playedAt: DateTime.now(),
          stars: 3,
          statusText: losers.isEmpty ? 'Solo Victory!' : 'Defeated: ${losers.join(', ')}',
        ));

        phase = GamePhase.end;

        _aiTurnActive = false;

        AudioService.stopAll();
      notifyListeners();
      return true;
    }
    return false;
  }

  void _executeMove(Piece piece, MoveDestination target, List<int> dieIndicesUsed, List<Player> currentPlayers, List<int> currentPool, bool currentCanRoll) {
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

    final newPool = List<int>.from(currentPool);
    for (int idx in dieIndicesUsed.reversed) {
      newPool.removeAt(idx);
    }

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

    players = newPlayers;
    dicePool = newPool;
    canRoll = rewardTurn;
    _autoSelectDie();

    if (_checkGameOver(newPlayers)) return;

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
    
    // Skip inactive players. Also in solo play, skip finished players. 
    // In team play, finished players are NOT skipped so they can take turns to roll for their partners (helpers).
    do {
      turnSlot = (turnSlot + 1) % 4;
    } while (!players[turnSlot].isActive || (players[turnSlot].finished && !settings.teamPlay));

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