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
    if (settings.playerCount == 2) activeIds = [1, 3];
    if (settings.playerCount == 3) activeIds = [0, 1, 3];
    if (settings.playerCount < 4) {
      settings = settings.copyWith(teamPlay: false);
    }
    players = List.generate(4, (id) => Player(
      id: id,
      isAI: configs[id]['isAI'] as bool,
      isActive: activeIds.contains(id),
      partnerId: (id + 2) % 4,
      name: configs[id]['name'] as String? ?? '',
      pieces: List.generate(4, (pId) => Piece(id: pId, color: id)),
    ));
    turnSlot = activeIds[0];
    dicePool = [];
    consecutiveExtra = 0;
    canRoll = true;
    selectedDieIndex = null;
    _aiTurnActive = false;
    matchFirstSixRolled = false;
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
    if (dicePool.isEmpty) { selectedDieIndex = null; return; }
    final pCtrl = players[getControlPlayerId()];
    if (!pCtrl.isAI) {
      for (int i = 0; i < dicePool.length; i++) {
        bool canMove = false;
        for (final pc in pCtrl.pieces) {
          if (pc.state == PieceState.home || pc.hasKilledThisTurn) continue;
          final dest = calculateDestination(pCtrl, pc, dicePool[i], players, pool: dicePool, dieIndex: i, settings: settings);
          if (dest != null) { canMove = true; break; }
        }
        if (canMove) { selectedDieIndex = i; return; }
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

      if (settings.teamPlay && activeP.finished && activeP.isHelper) {
        final partnerId = activeP.partnerId;
        final partner = newPlayers[partnerId];
        if (partner.finished) {
          isRolling = false; players = newPlayers; notifyListeners();
          if (_checkGameOver(newPlayers)) return;
          Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
          return;
        }
      }

      final allHome = activeP.pieces.every((pc) => pc.state == PieceState.home);
      if (allHome && !activeP.finished) {
        dicePool = [d1, d2];
        isRolling = false; players = newPlayers; notifyListeners();
        Timer(const Duration(milliseconds: 400), () {
          bool winningRoll = d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1) || (d1 == 6 && d2 == 6);
          if (winningRoll) {
            activeP.finished = true;
            if (settings.teamPlay) activeP.isHelper = true;
            players = newPlayers; notifyListeners();
            if (_checkGameOver(newPlayers)) return;
            Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
          } else {
            players = newPlayers; notifyListeners();
            Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
          }
        });
        return;
      }

      bool prioritizePrison = (d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1));
      bool isQualifyingRoll = (d1 == 6 || d2 == 6 || (d1 == 1 && d2 == 1) || (d1 == 6 && d2 == 6));

      if (activeP.finished && !activeP.isHelper) {
        if (isQualifyingRoll) {
          activeP.isHelper = true; dicePool = []; isRolling = false; canRoll = false;
          players = newPlayers; notifyListeners();
          Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
        } else {
          isRolling = false; players = newPlayers; notifyListeners();
          Timer(const Duration(milliseconds: 700), () => _endTurn(newPlayers));
        }
        return;
      }

      bool extra = false;
      final newPool = List<int>.from(dicePool);
      final isDoubleSix = d1 == 6 && d2 == 6;
      final isDoubleOne = d1 == 1 && d2 == 1;
      bool isSixOrDoubleOne = (d1 == 6 || d2 == 6 || isDoubleOne);
      bool isGlobalFirstSix = !matchFirstSixRolled && isSixOrDoubleOne;

      if (isGlobalFirstSix) {
        matchFirstSixRolled = true;
        bool hasFour = (d1 == 6 && d2 == 4) || (d2 == 6 && d1 == 4);
        newPool.clear();
        if (hasFour) { newPool.addAll([6, 6, 6, 6, 4]); AudioService.play('six_four'); }
        else if (isDoubleSix) { newPool.addAll([6, 6, 6]); extra = true; }
        else if (isDoubleOne) { newPool.addAll([6, 6, 6]); extra = true; }
        else { newPool.addAll([d1, d2, 6]); }
      } else {
        if (settings.doubleSixBonus && (isDoubleSix || isDoubleOne)) { extra = consecutiveExtra < 3; newPool.addAll([6, 6]); }
        else { newPool.addAll([d1, d2]); }
        if (d1 == d2 && (d1 == 6 || d1 == 1)) extra = true;
      }

      newPool.sort((a, b) => b.compareTo(a));
      isRolling = false; players = newPlayers; dicePool = newPool;
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
          _aiTurnActive = false; rollDice();
        });
        return;
      }
      if (actPlayer.finished && !actPlayer.isHelper) {
        Timer(const Duration(milliseconds: 350), () { _aiTurnActive = false; _endTurn(currentPlayers); });
        return;
      }
      if (actPlayer.finished && actPlayer.isHelper && allMoves.isEmpty) {
        Timer(const Duration(milliseconds: 425), () { _aiTurnActive = false; _endTurn(currentPlayers); });
        return;
      }
      if (allMoves.isNotEmpty) {
        allMoves.sort((a, b) {
          int scoreA = _evaluateAiMove(a, currentPlayers, ctrlId, prioritizePrison, currentPool: pool, dieIndices: a.dieIndices);
          int scoreB = _evaluateAiMove(b, currentPlayers, ctrlId, prioritizePrison, currentPool: pool, dieIndices: b.dieIndices);
          return scoreB.compareTo(scoreA);
        });
        final best = allMoves.first;
        Timer(const Duration(milliseconds: 500), () {
          if (turnSlot != snapSlot) return;
          _aiTurnActive = false;
          _executeMove(best.piece, best.target, best.dieIndices, currentPlayers, pool, currentCanRoll);
        });
      } else {
        Timer(const Duration(milliseconds: 420), () { AudioService.play('no_move_chance'); _aiTurnActive = false; _endTurn(currentPlayers); });
      }
      return;
    }

    if (actPlayer.finished && !actPlayer.isHelper) {
      Timer(const Duration(milliseconds: 280), () => _endTurn(currentPlayers));
      return;
    }
    if (allMoves.isEmpty && !currentCanRoll && pool.isNotEmpty) {
      AudioService.play('no_move_chance');
      Timer(const Duration(milliseconds: 400), () => _endTurn(currentPlayers));
      return;
    }
    if (allMoves.length == 1 && !currentCanRoll) {
      final only = allMoves.first;
      Timer(const Duration(milliseconds: 420), () => _executeMove(only.piece, only.target, only.dieIndices, currentPlayers, pool, currentCanRoll));
      return;
    }
  }

  int _evaluateAiMove(AiMove move, List<Player> players, int myId, bool prioritizePrison, {List<int> currentPool = const [], List<int> dieIndices = const []}) {
    List<int> remainingDice = [];
    for (int k = 0; k < currentPool.length; k++) {
      if (!dieIndices.contains(k)) remainingDice.add(currentPool[k]);
    }

    final targetPos = move.target.targetPos;
    final targetState = move.target.targetState;
    final currentPos = move.piece.pos;
    final currentState = move.piece.state;

    int score = move.dieValue * 10;

    int remainingUtility = 0;
    bool isCombinedMove = dieIndices.length >= 2;
    if (isCombinedMove) {
      int maxSingleInPool = currentPool.isNotEmpty ? currentPool.reduce((a, b) => a > b ? a : b) : 0;
      bool combinedNecessary = false;
      bool combinedForHit = false;
      if (targetState == PieceState.home || targetState == PieceState.homeStretch) {
        combinedNecessary = move.dieValue > maxSingleInPool;
      } else if (targetState == PieceState.board && !_effectiveSafeZones.contains(targetPos)) {
        for (var p in players) {
          if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
          for (var pc in p.pieces) {
            if (pc.state == PieceState.board && pc.pos == targetPos) {
              bool couldHitWithSingle = false;
              for (var dice in currentPool) {
                if (dieIndices.contains(currentPool.indexOf(dice))) continue;
                if (dice == (targetPos - currentPos + 52) % 52) { couldHitWithSingle = true; break; }
              }
              if (!couldHitWithSingle) { combinedNecessary = true; combinedForHit = true; }
            }
          }
        }
        if (!combinedForHit) {
          for (var dice in currentPool) {
            final testDest = calculateDestination(players[myId], move.piece, dice, players, pool: currentPool, dieIndex: 0, settings: settings);
            if (testDest != null && testDest.targetState == PieceState.board && testDest.targetPos == targetPos) {
              combinedNecessary = false; combinedForHit = false;
            }
          }
        }
      }
      if (combinedNecessary && combinedForHit) score += 40000;
      else if (combinedNecessary) score += 20000;
      else score -= 3000 * (dieIndices.length - 1);
      remainingUtility = remainingDice.fold(0, (sum, d) => sum + d) ~/ 2;
    } else {
      remainingUtility = remainingDice.fold(0, (sum, d) => sum + d);
    }
    score += remainingUtility;

    int piecesOut = players[myId].pieces.where((p) => p.state != PieceState.yard).length;
    int prisoners = players[myId].pieces.where((p) => p.state == PieceState.prison).length;
    int piecesOnBoard = players[myId].pieces.where((p) => p.state == PieceState.board || p.state == PieceState.homeStretch).length;

    final mySecondStop = kMyStops[myId]![1];
    bool isTargetSecondSafe = targetPos == mySecondStop;
    bool isCurrentSecondSafe = currentPos == mySecondStop;
    final myFirstStop = kMyStops[myId]![0];
    bool isTargetFirstSafe = targetPos == myFirstStop;
    bool isCurrentFirstSafe = currentPos == myFirstStop;

    bool isCurrentlyOnSafePlace = false;
    if (currentState == PieceState.board) {
      isCurrentlyOnSafePlace = _effectiveSafeZones.contains(currentPos) || _isOwnColoredSafe(myId, currentPos);
    }
    if (currentState == PieceState.board) {
      score += isCurrentlyOnSafePlace ? -4000 : 4000;
    }

    bool isHit = false;
    int hitCount = 0;
    if (targetState == PieceState.board && !_effectiveSafeZones.contains(targetPos)) {
      isHit = hasOpponent(targetPos, myId, players);
      if (isHit) {
        for (var p in players) {
          if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
          for (var pc in p.pieces) {
            if (pc.state == PieceState.board && pc.pos == targetPos) hitCount++;
          }
        }
      }
    }

    int sameColorAtTarget = 0;
    if (targetState == PieceState.board || targetState == PieceState.homeStretch) {
      sameColorAtTarget = players[myId].pieces.where((p) => p != move.piece && p.state == targetState && p.pos == targetPos).length;
    }
    bool formingBlock = sameColorAtTarget == 1;
    bool joiningBlock = sameColorAtTarget >= 1;

    int sameColorAtCurrent = 0;
    if (currentState == PieceState.board) {
      sameColorAtCurrent = players[myId].pieces.where((p) => p != move.piece && p.state == PieceState.board && p.pos == currentPos).length;
    }
    bool leavingVulnerable = sameColorAtCurrent == 1 && !_effectiveSafeZones.contains(currentPos);
    bool formingChokePoint = formingBlock && isTargetSecondSafe;
    bool breakingChokePoint = sameColorAtCurrent == 1 && isCurrentSecondSafe;

    int distToSecondStop = (mySecondStop - currentPos + 52) % 52;
    bool isBehindSecondStop = distToSecondStop > 0 && distToSecondStop <= 6;
    bool willPassSecondStop = isBehindSecondStop && distToSecondStop < move.dieValue && targetState == PieceState.board;

    bool isPastSecondStop = false;
    if (currentState == PieceState.homeStretch) {
      isPastSecondStop = true;
    } else if (currentState == PieceState.board) {
      int distFromSecondStop = (currentPos - mySecondStop + 52) % 52;
      if (distFromSecondStop > 0 && distFromSecondStop <= 3) isPastSecondStop = true;
    }

    int piecesAtSecondStop = players[myId].pieces.where((p) => p.state == PieceState.board && p.pos == mySecondStop).length;
    int piecesAtFirstStop = players[myId].pieces.where((p) => p.state == PieceState.board && p.pos == myFirstStop).length;

    int piecesNeedingHelp = players[myId].pieces.where((p) {
      if (p.state == PieceState.home || p.state == PieceState.homeStretch) return false;
      if (p.state == PieceState.board) {
        int distFromStop = (p.pos - mySecondStop + 52) % 52;
        if (distFromStop <= 3) return false;
      }
      return true;
    }).length;

    int opponentPiecesOut = 0;
    for (var p in players) {
      if (p.id != myId && p.partnerId != myId && p.isActive) {
        opponentPiecesOut += p.pieces.where((pc) => pc.state != PieceState.yard).length;
      }
    }
    int myOut = piecesOut;

    bool currentlyInDanger = false;
    bool targetInDanger = false;
    bool targetIsChasing = false;
    int minThreatDist = 7;
    if (currentState == PieceState.board && !_effectiveSafeZones.contains(currentPos) && sameColorAtCurrent == 0) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            int distBehind = (currentPos - pc.pos + 52) % 52;
            if (distBehind > 0 && distBehind <= 6) { currentlyInDanger = true; if (distBehind < minThreatDist) minThreatDist = distBehind; }
          }
        }
      }
    }

    int threatCountNearTarget = 0;
    int chaseCountFromTarget = 0;
    if (targetState == PieceState.board && !_effectiveSafeZones.contains(targetPos) && !formingBlock) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            int dt = (targetPos - pc.pos + 52) % 52;
            if (dt > 0 && dt <= 6) { targetInDanger = true; threatCountNearTarget++; }
            int da = (pc.pos - targetPos + 52) % 52;
            if (da > 0 && da <= 6) { targetIsChasing = true; chaseCountFromTarget++; }
          }
        }
      }
    }

    // ========== FIX 1: SECOND BORDER BLOCK = ABSOLUTE TOP PRIORITY ==========
    
    // CRITICAL: Apply isPastSecondStop multiplier EARLY before the major scoring
    // so it reduces the base score but NOT the strategic bonuses below.
    // This fixes the bug where the multiplier at the end was reducing second stop bonuses.
    if (isPastSecondStop && targetState != PieceState.home) {
      int distToHomeEntry = 3 - ((currentPos - mySecondStop + 52) % 52);
      if (distToHomeEntry <= 2) score = (score * 0.3).toInt();
      else score = (score * 0.5).toInt();
    }

    // Pieces behind second stop that CAN land on it = high priority  
    if (isBehindSecondStop && !willPassSecondStop) {
      if (distToSecondStop == move.dieValue && targetState == PieceState.board && !isHit) {
        score += 250000; // Land exactly on second stop = extremely high
      }
    }

    // HUGE penalty for passing over second stop without landing
    if (willPassSecondStop) {
      score -= 300000; // MASSIVE penalty - never pass over second stop
      
      // FIX 2: Even stronger penalty when other pieces exist that could move
      // If there are other pieces not at/past second stop, passing over it is
      // even more unacceptable
      if (piecesNeedingHelp > 0) {
        score -= 200000; // Extra penalty when other pieces could move instead
      }
    }

    // Forming the 2-piece block on second stop is the TOP strategic priority
    if (formingChokePoint) {
      score += 500000; // MAXIMUM - forming the ultimate choke point
    }

    // Landing ON second stop (even without forming block yet) is very high priority
    if (isTargetSecondSafe && targetState == PieceState.board) {
      if (sameColorAtTarget == 0) {
        score += 200000; // First piece on second stop = setup for block
      }
    }

    // Moving FROM second stop = extremely penalized (breaking block)
    if (breakingChokePoint) {
      score -= 250000; // Never break the established block
    }
    if (isCurrentSecondSafe) {
      if (piecesAtSecondStop >= 2) {
        score -= 80000;
      } else {
        score -= 300000;
      }
    }

    // ========== FIX 1: 6 IN POOL = PRISONER > YARD, BUT YARD STILL HIGH ==========
    bool hasSixInPool = currentPool.contains(6);
    int piecesInYard = players[myId].pieces.where((p) => p.state == PieceState.yard).length;

    // Prisoner -> Yard: ABSOLUTE TOP priority (especially when 6 in pool)
    if (currentState == PieceState.prison && targetState == PieceState.yard) {
      score += 500000; // Base max
      if (hasSixInPool) score += 300000; // Using a 6
      if (prisoners >= 1) score += 200000;
      if (prisoners >= 2) score += 200000 * prisoners;
      
      // When 2+ pieces in yard AND prisoner exists, prisoners get super-priority
      // because the yard pieces are safe at home but prisoners are trapped
      if (piecesInYard >= 2 && prisoners > 0) {
        score += 300000; // Extra: many yard pieces safe, but prisoners need rescue
      }
      
      if (piecesOnBoard <= 2) score += 200000;
      int outDiff = opponentPiecesOut - myOut;
      if (outDiff > 0) score += 50000 * (outDiff + 1);
    }

    // Yard -> Board: high priority, but defers to prisoners when they exist
    if (currentState == PieceState.yard && targetState == PieceState.board) {
      if (prisoners > 0) {
        score -= 150000 * prisoners; // STRONG defer to prisoners
      } else {
        // No prisoners - release yard pieces with high priority
        score += 200000;
        if (hasSixInPool) score += 100000;
        // When 2+ yard pieces exist and 6 in pool, urgency is higher
        if (piecesInYard >= 2 && hasSixInPool) score += 80000;
        int myOnBoard = piecesOnBoard;
        if (myOnBoard <= 1) score += 80000;
        int outDiff = opponentPiecesOut - myOut;
        if (outDiff > 0) score += 30000 * (outDiff + 1);
      }
    }

    int otherPiecesHome = players[myId].pieces.where((p) => p != move.piece && p.state == PieceState.home).length;
    bool isFinishing = targetState == PieceState.home && otherPiecesHome == 3;
    if (isFinishing) {
      score += 400000; // Winning move - very high, but below prisoner escape
      if (remainingDice.contains(6)) score += 50000;
    }

    if (formingBlock && isTargetFirstSafe) {
      score += 150000; // Blocking first stop is good defense
    }

    if (isHit) {
      score += 100000 + (hitCount * 80000);
      if (remainingDice.isNotEmpty) {
        int remainingDiceSum = remainingDice.fold(0, (sum, d) => sum + d);
        if (remainingDiceSum > 0 && targetState == PieceState.board) {
          for (var p in players) {
            if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
            for (var pc in p.pieces) {
              if (pc.state == PieceState.board) {
                int distToOpponent = (pc.pos - targetPos + 52) % 52;
                if (distToOpponent > 0 && distToOpponent <= remainingDiceSum) score += 20000;
              }
            }
          }
        }
      }
    }

    if (joiningBlock && !_isOwnColoredSafe(myId, targetPos) && _effectiveSafeZones.contains(targetPos)) {
      bool isOpponentColored = false;
      for (var p in players) {
        if (p.id != myId && p.partnerId != myId && p.isActive) {
          if (_isOwnColoredSafe(p.id, targetPos)) { isOpponentColored = true; break; }
        }
      }
      score += isOpponentColored ? 150000 : 50000;
    }

    if (threatCountNearTarget >= 2 && !formingBlock && !isHit) {
      score -= 50000 * threatCountNearTarget;
    } else if (threatCountNearTarget >= 1 && !formingBlock && !isHit) {
      score -= 15000;
    }

    if (chaseCountFromTarget > 1) score += 50000;

    if (targetState == PieceState.home) {
      score += 12000;
      int piecesNotHome = players[myId].pieces.where((p) => p.state != PieceState.home).length;
      if (piecesNotHome <= 2) score += 15000;
      else if (piecesNotHome >= 3 && piecesNeedingHelp > 1) score -= 40000;
    }

    if (formingBlock && _isOwnColoredSafe(myId, targetPos) && !isTargetFirstSafe && !isTargetSecondSafe) score += 5000;
    if (_isOwnColoredSafe(myId, targetPos) && !formingBlock) score += 8000;
    if (formingBlock && !_isOwnColoredSafe(myId, targetPos)) score -= 200000;

    if (currentlyInDanger && !targetInDanger) score += 6000 + (7 - minThreatDist) * 1000;
    else if (currentlyInDanger && targetInDanger) score += 1000;

    if (targetState == PieceState.board && _effectiveSafeZones.contains(targetPos) && !formingBlock) score += 3000;
    if (targetIsChasing && !targetInDanger) score += 4000 + (chaseCountFromTarget * 3000);

    int futureHitPotential = 0;
    if (targetState == PieceState.board) {
      for (var p in players) {
        if (p.id == myId || p.partnerId == myId || !p.isActive) continue;
        for (var pc in p.pieces) {
          if (pc.state == PieceState.board) {
            int dist = (pc.pos - targetPos + 52) % 52;
            if (dist > 0 && dist <= 6) futureHitPotential++;
          }
        }
      }
      score += futureHitPotential * 2000;
      if (joiningBlock && futureHitPotential > 0) score += 30000;
    }

    if (currentState == PieceState.yard || currentState == PieceState.prison) {
      score -= 5000; // Slight penalty to encourage emergency exit for board pieces
    }

    if (targetState == PieceState.homeStretch) score += 1500;

    // FIX 3: Extra pieces at first stop (3+) should actively move out
    // Only 2 pieces needed for blocking - 3rd+ piece is wasted
    if (isCurrentFirstSafe) {
      if (piecesAtFirstStop >= 3) {
        // 3rd+ piece at first stop - encourage it to move!
        score += 40000; // Bonus for moving extra blocking piece
      } else if (piecesAtFirstStop == 2) {
        score -= 5000; // Block is formed - keep it
      } else {
        score -= 20000; // Need to maintain the block
      }
    }

    if (targetInDanger && !isHit && !formingBlock) score -= 4000 * (threatCountNearTarget + 1);
    if (leavingVulnerable) score -= 5000;
    if (currentState == PieceState.board && _isOwnColoredSafe(myId, currentPos) && sameColorAtCurrent > 0 && !isHit && !breakingChokePoint && !isCurrentFirstSafe && !isCurrentSecondSafe) score -= 2000;

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
    if (allValidMoves.length == 1) return;
    if (selectedDieIndex != null) {
      int moveVal = dicePool[selectedDieIndex!];
      final dest = calculateDestination(pCtrl, piece, moveVal, players, pool: dicePool, dieIndex: selectedDieIndex!, settings: settings);
      if (dest != null) _executeMove(piece, dest, [selectedDieIndex!], players, dicePool, canRoll);
    } else if (dicePool.length == 2) {
      bool hasSingleMove = false;
      for (int i = 0; i < dicePool.length; i++) {
        final dest = calculateDestination(pCtrl, piece, dicePool[i], players, pool: dicePool, dieIndex: i, settings: settings);
        if (dest != null) { hasSingleMove = true; break; }
      }
      if (!hasSingleMove) {
        int moveVal = dicePool[0] + dicePool[1];
        final dest = calculateDestination(pCtrl, piece, moveVal, players, pool: [], dieIndex: -1, settings: settings);
        if (dest != null) _executeMove(piece, dest, [0, 1], players, dicePool, canRoll);
      }
    }
  }

  bool _checkGameOver(List<Player> newPlayers) {
    final team1Done = newPlayers[0].finished && newPlayers[2].finished;
    final team2Done = newPlayers[1].finished && newPlayers[3].finished;
    final soloDone = newPlayers.any((p) => p.finished);
    final gameOver = (settings.teamPlay && (team1Done || team2Done)) || (!settings.teamPlay && soloDone);
    if (gameOver) {
      String winnerLabel;
      if (settings.teamPlay && team1Done) {
        final names = <String>[];
        if (newPlayers[0].finished) names.add(_nameOf(newPlayers[0]));
        if (newPlayers[2].finished) names.add(_nameOf(newPlayers[2]));
        winnerLabel = names.join(' + ');
      } else if (settings.teamPlay && team2Done) {
        final names = <String>[];
        if (newPlayers[1].finished) names.add(_nameOf(newPlayers[1]));
        if (newPlayers[3].finished) names.add(_nameOf(newPlayers[3]));
        winnerLabel = names.join(' + ');
      } else {
        winnerLabel = _nameOf(newPlayers.firstWhere((p) => p.finished));
      }
      final losers = <String>[];
      losers.addAll(newPlayers.where((p) => p.isActive && !p.finished).map((p) => _nameOf(p)));
      final playerNames = newPlayers.map((p) => _nameOf(p)).toList();
      final playerIsAI = newPlayers.map((p) => p.isAI).toList();
      history.add(MatchRecord(winnerLabel: winnerLabel, playerNames: playerNames, playerIsAI: playerIsAI, playedAt: DateTime.now(), stars: 3, statusText: losers.isEmpty ? 'Solo Victory!' : 'Defeated: ${losers.join(', ')}'));
      _saveHistory();
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
    if (target.targetState == PieceState.home) { AudioService.play('reach_goal'); rewardTurn = true; }
    final newPool = List<int>.from(currentPool);
    for (int idx in dieIndicesUsed.reversed) { newPool.removeAt(idx); }
    if (target.targetState == PieceState.board) {
      int sameColor = pCtrl.pieces.where((p) => p.state == PieceState.board && p.pos == target.targetPos).length;
      if (sameColor == 2) AudioService.play('block_border');
    }
    if (target.targetState == PieceState.board && !_effectiveSafeZones.contains(target.targetPos)) {
      for (final op in newPlayers) {
        if (op.id != ctrlId && op.id != pCtrl.partnerId && op.isActive) {
          for (final opc in op.pieces) {
            if (opc.state == PieceState.board && opc.pos == target.targetPos) {
              op.timesHit++; AudioService.play('hit_piece');
              if (settings.prisonRule) { opc.state = PieceState.prison; opc.pos = -2; opc.prisonerOf = ctrlId; }
              else { opc.state = PieceState.yard; opc.pos = -1; opc.prisonerOf = null; }
              pCtrl.hasKilled = true; pPiece.hasKilledThisTurn = true;
            }
          }
        }
      }
    }
    if (!settings.killToEnter) pCtrl.hasKilled = true;
    players = newPlayers; dicePool = newPool; canRoll = rewardTurn;
    _autoSelectDie();
    if (_checkGameOver(newPlayers)) return;
    notifyListeners();
    if (newPool.isEmpty && !rewardTurn) {
      Timer(const Duration(milliseconds: 210), () => _endTurn(newPlayers));
    } else {
      Timer(const Duration(milliseconds: 140), () { _checkAndAutoPlay(newPool, newPlayers, rewardTurn, false); });
    }
  }

  void _endTurn([List<Player>? latestPlayers]) {
    _aiTurnActive = false;
    final ps = latestPlayers ?? players;
    final newPlayers = _deepCopyPlayers(ps);
    for (final p in newPlayers) { for (final pc in p.pieces) { pc.hasKilledThisTurn = false; } }
    players = newPlayers;
    do { turnSlot = (turnSlot + 1) % 4; }
    while (!players[turnSlot].isActive || (players[turnSlot].finished && !settings.teamPlay));
    dicePool = []; consecutiveExtra = 0; canRoll = true; selectedDieIndex = null;
    notifyListeners();
    if (players[turnSlot].isAI) { Timer(const Duration(milliseconds: 560), rollDice); }
  }

  void resetToSetup() { phase = GamePhase.setup; players = []; dicePool = []; notifyListeners(); }

  List<Player> _deepCopyPlayers(List<Player> source) {
    return source.map((p) => Player(id: p.id, isAI: p.isAI, isActive: p.isActive, partnerId: p.partnerId, name: p.name, hasKilled: p.hasKilled, finished: p.finished, isHelper: p.isHelper, hasRolledFirstSix: p.hasRolledFirstSix, timesHit: p.timesHit, pieces: p.pieces.map((pc) => Piece(id: pc.id, color: pc.color, state: pc.state, pos: pc.pos, prisonerOf: pc.prisonerOf, hasKilledThisTurn: pc.hasKilledThisTurn)).toList())).toList();
  }
}